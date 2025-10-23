//
//  AtemUI.swift
//  Tally
//
//  Created by Peter Manoharan on 23/10/2025.
//

import SwiftUI

class ATEMManager: ObservableObject {
    @Published var isConnected = false
    @Published var programInput: UInt16 = 0
    @Published var previewInput: UInt16 = 0
    @Published var discoveredDevices: [(ip: String, name: String)] = []
    
    private let connection = ATEMConnection()
    private let discovery = ATEMDiscovery()
    
    init() {
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        // Connection callbacks
        connection.onConnected = { [weak self] in
            self?.isConnected = true
            print("✅ Connected to ATEM")
        }
        
        connection.onDisconnected = { [weak self] in
            self?.isConnected = false
            print("❌ Disconnected from ATEM")
        }
        
        connection.onProgramInputChanged = { [weak self] mixEffect, inputId in
            print("📺 Program changed to input: \(inputId)")
            self?.programInput = inputId
            // Trigger your custom events here
        }
        
        connection.onPreviewInputChanged = { [weak self] mixEffect, inputId in
            print("👁️ Preview changed to input: \(inputId)")
            self?.previewInput = inputId
            // Trigger your custom events here
        }
        
        // Discovery callbacks
        discovery.onDeviceFound = { [weak self] ip, name in
            print("🔍 Found device: \(name) at \(ip)")
            self?.discoveredDevices.append((ip, name))
        }
    }
    
    func startDiscovery() {
        discovery.startDiscovery()
    }
    
    func connect(to ip: String) {
        connection.connect(to: ip)
    }
    
    func disconnect() {
        connection.disconnect()
    }
}

// Usage in SwiftUI
struct ATEMControlView: View {
    @StateObject private var atemManager = ATEMManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text(atemManager.isConnected ? "✅ Connected" : "❌ Disconnected")
                .font(.headline)
            
            Text("Program: \(atemManager.programInput)")
            Text("Preview: \(atemManager.previewInput)")
            
            Button("Discover ATEMs") {
                atemManager.startDiscovery()
            }
            
            Button("Connect to 192.168.1.240") {
                atemManager.connect(to: "192.168.1.240")
            }
            
            List(atemManager.discoveredDevices, id: \.ip) { device in
                HStack {
                    Text(device.name)
                    Spacer()
                    Text(device.ip)
                        .foregroundColor(.gray)
                    Button("Connect") {
                        atemManager.connect(to: device.ip)
                    }
                }
            }
        }
        .padding()
    }
}
