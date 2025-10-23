//
//  AtemService.swift
//  Tally
//
//  Created by Peter Manoharan on 23/10/2025.
//

import Foundation
import Network

// MARK: - ATEM Protocol Constants

enum ATEMCommand: String {
    case programInput = "PrgI"
    case previewInput = "PrvI"
    case productIdentifier = "_pin"
    case topology = "_top"
    
    var bytes: [UInt8] {
        return Array(self.rawValue.utf8)
    }
}

// MARK: - ATEM Packet Structure

struct ATEMPacket {
    var flags: UInt8
    var length: UInt16
    var sessionId: UInt16
    var acknowledgement: UInt16
    var packageId: UInt16
    var data: Data
    
    // Packet flags
    static let flagConnect: UInt8 = 0x10
    static let flagHello: UInt8 = 0x02
    static let flagAck: UInt8 = 0x80
    static let flagRetransmit: UInt8 = 0x20
    static let flagResponse: UInt8 = 0x08
    
    func toData() -> Data {
        var data = Data()
        data.append(flags)
        data.append(0x00) // Reserved
        data.append(contentsOf: withUnsafeBytes(of: length.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: sessionId.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: acknowledgement.bigEndian) { Data($0) })
        data.append(0x00) // Unknown
        data.append(0x00) // Unknown
        data.append(contentsOf: withUnsafeBytes(of: packageId.bigEndian) { Data($0) })
        data.append(0x00) // Reserved
        data.append(0x00) // Reserved
        data.append(self.data)
        return data
    }
    
    static func parse(from data: Data) -> ATEMPacket? {
        guard data.count >= 12 else { return nil }
        
        let flags = data[0]
        let length = UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) })
        let sessionId = UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) })
        let acknowledgement = UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: 6, as: UInt16.self) })
        let packageId = UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: 10, as: UInt16.self) })
        let payload = data.count > 12 ? data.subdata(in: 12..<data.count) : Data()
        
        return ATEMPacket(
            flags: flags,
            length: length,
            sessionId: sessionId,
            acknowledgement: acknowledgement,
            packageId: packageId,
            data: payload
        )
    }
}

// MARK: - ATEM Command Parser

struct ATEMCommandData {
    let name: String
    let data: Data
}

class ATEMCommandParser {
    static func parseCommands(from data: Data) -> [ATEMCommandData] {
        var commands: [ATEMCommandData] = []
        var offset = 0
        
        while offset + 8 <= data.count {
            let length = Int(UInt16(bigEndian: data.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: UInt16.self)
            }))
            
            guard length >= 8, offset + length <= data.count else { break }
            
            let nameData = data.subdata(in: (offset + 4)..<(offset + 8))
            let name = String(data: nameData, encoding: .ascii) ?? ""
            let commandData = length > 8 ? data.subdata(in: (offset + 8)..<(offset + length)) : Data()
            
            commands.append(ATEMCommandData(name: name, data: commandData))
            offset += length
        }
        
        return commands
    }
}

// MARK: - ATEM Connection

class ATEMConnection {
    private var connection: NWConnection?
    private var sessionId: UInt16 = 0
    private var remotePackageId: UInt16 = 0
    private var localPackageId: UInt16 = 1
    private var isConnected = false
    private let queue = DispatchQueue(label: "com.atem.connection")
    
    // Callbacks
    var onProgramInputChanged: ((UInt16, UInt16) -> Void)? // (mixEffect, inputId)
    var onPreviewInputChanged: ((UInt16, UInt16) -> Void)? // (mixEffect, inputId)
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    
    // Current state
    private var currentProgramInput: [UInt16: UInt16] = [:] // [mixEffect: inputId]
    private var currentPreviewInput: [UInt16: UInt16] = [:] // [mixEffect: inputId]
    
    func connect(to host: String, port: UInt16 = 9910) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        connection = NWConnection(to: endpoint, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Connection ready")
                self?.sendHandshake()
            case .failed(let error):
                print("Connection failed: \(error)")
                self?.onDisconnected?()
            case .cancelled:
                print("Connection cancelled")
                self?.onDisconnected?()
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
        receiveData()
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }
    
    private func sendHandshake() {
        // Send initial handshake packet
        let packet = ATEMPacket(
            flags: ATEMPacket.flagConnect | ATEMPacket.flagHello,
            length: 20,
            sessionId: 0,
            acknowledgement: 0,
            packageId: 0,
            data: Data([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        )
        
        sendPacket(packet)
    }
    
    private func sendPacket(_ packet: ATEMPacket) {
        let data = packet.toData()
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }
    
    private func receiveData() {
        connection?.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleReceivedData(data)
            }
            
            if let error = error {
                print("Receive error: \(error)")
            }
            
            // Continue receiving
            self?.receiveData()
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        guard let packet = ATEMPacket.parse(from: data) else {
            print("Failed to parse packet")
            return
        }
        
        // Handle handshake response
        if packet.flags & ATEMPacket.flagHello != 0 {
            sessionId = packet.sessionId
            print("Handshake complete, session ID: \(sessionId)")
            sendAcknowledgement(for: packet)
            return
        }
        
        // Handle acknowledgement
        if packet.flags & ATEMPacket.flagAck != 0 {
            // Remote acknowledged our packet
            return
        }
        
        // Handle data packets
        if packet.data.count > 0 {
            remotePackageId = packet.packageId
            parseCommands(packet.data)
            sendAcknowledgement(for: packet)
            
            if !isConnected {
                isConnected = true
                DispatchQueue.main.async {
                    self.onConnected?()
                }
            }
        }
    }
    
    private func sendAcknowledgement(for packet: ATEMPacket) {
        let ackPacket = ATEMPacket(
            flags: ATEMPacket.flagAck,
            length: 12,
            sessionId: sessionId,
            acknowledgement: packet.packageId,
            packageId: localPackageId,
            data: Data()
        )
        
        sendPacket(ackPacket)
    }
    
    private func parseCommands(_ data: Data) {
        let commands = ATEMCommandParser.parseCommands(from: data)
        
        for command in commands {
            handleCommand(command)
        }
    }
    
    private func handleCommand(_ command: ATEMCommandData) {
        switch command.name {
        case "PrgI": // Program Input
            guard command.data.count >= 4 else { return }
            let mixEffect = UInt16(bigEndian: command.data.withUnsafeBytes {
                $0.load(fromByteOffset: 0, as: UInt16.self)
            })
            let inputId = UInt16(bigEndian: command.data.withUnsafeBytes {
                $0.load(fromByteOffset: 2, as: UInt16.self)
            })
            
            let oldValue = currentProgramInput[mixEffect]
            currentProgramInput[mixEffect] = inputId
            
            if oldValue != inputId {
                print("Program input changed: ME\(mixEffect) -> Input \(inputId)")
                DispatchQueue.main.async {
                    self.onProgramInputChanged?(mixEffect, inputId)
                }
            }
            
        case "PrvI": // Preview Input
            guard command.data.count >= 4 else { return }
            let mixEffect = UInt16(bigEndian: command.data.withUnsafeBytes {
                $0.load(fromByteOffset: 0, as: UInt16.self)
            })
            let inputId = UInt16(bigEndian: command.data.withUnsafeBytes {
                $0.load(fromByteOffset: 2, as: UInt16.self)
            })
            
            let oldValue = currentPreviewInput[mixEffect]
            currentPreviewInput[mixEffect] = inputId
            
            if oldValue != inputId {
                print("Preview input changed: ME\(mixEffect) -> Input \(inputId)")
                DispatchQueue.main.async {
                    self.onPreviewInputChanged?(mixEffect, inputId)
                }
            }
            
        case "_pin": // Product Identification
            if let name = String(data: command.data, encoding: .utf8) {
                print("Connected to: \(name)")
            }
            
        default:
            // Uncomment to see all commands:
            // print("Command: \(command.name)")
            break
        }
    }
    
    // Public accessors
    func getProgramInput(mixEffect: UInt16 = 0) -> UInt16? {
        return currentProgramInput[mixEffect]
    }
    
    func getPreviewInput(mixEffect: UInt16 = 0) -> UInt16? {
        return currentPreviewInput[mixEffect]
    }
}

// MARK: - ATEM Discovery

class ATEMDiscovery {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.atem.discovery")
    
    var onDeviceFound: ((String, String) -> Void)? // (ip, name)
    
    func startDiscovery() {
        // ATEM devices respond to UDP broadcasts on port 9910
        // For simplicity, we'll scan common IP ranges
        // A full implementation would use mDNS/Bonjour
        
        print("Starting ATEM discovery...")
        print("Note: Scanning local network. For production, use Bonjour/mDNS")
        
        // Simple implementation: try to connect to broadcast domain
        // In practice, you'd want to use NWBrowser or Bonjour
        scanLocalNetwork()
    }
    
    func stopDiscovery() {
        listener?.cancel()
    }
    
    private func scanLocalNetwork() {
        // This is a simplified approach
        // For production, use: _blackmagic._tcp (Bonjour service)
        
        // Try common ATEM IP addresses
        let commonIPs = [
            "192.168.1.240", // Default ATEM IP
            "192.168.10.240",
            "10.0.0.240"
        ]
        
        for ip in commonIPs {
            testConnection(to: ip)
        }
    }
    
    private func testConnection(to ip: String) {
        let connection = ATEMConnection()
        connection.onConnected = { [weak self] in
            print("Found ATEM at: \(ip)")
            self?.onDeviceFound?(ip, "ATEM Switcher")
            connection.disconnect()
        }
        connection.connect(to: ip)
        
        // Timeout after 2 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            connection.disconnect()
        }
    }
}
