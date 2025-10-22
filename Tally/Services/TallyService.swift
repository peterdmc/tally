import Foundation
import SwiftUI
import SwiftData
import Combine

// Background service scaffold: manages modes and simulates ATEM updates.
final class TallyService: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case setup = "Setup"
        case live = "Live"
        var id: String { rawValue }
    }

    @Published var mode: Mode = .setup
    private var timerCancellable: AnyCancellable?
    private var modelContext: ModelContext?

    // Bind a model container so the service can work without UI
    func bind(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
    }

    // Start mock ATEM polling independent of UI, operating directly on SwiftData
    func startATEMMock() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let context = self.modelContext else { return }
                do {
                    var devices = try context.fetch(FetchDescriptor<TallyDeviceItem>())
                    guard !devices.isEmpty else { return }
                    let liveIndex = devices.firstIndex(where: { $0.isLive }) ?? -1
                    let nextIndex = (liveIndex + 1) % devices.count
                    for i in devices.indices {
                        devices[i].isLive = (i == nextIndex)
                        devices[i].isPreview = (i == ((nextIndex + 1) % devices.count))
                        devices[i].colorHex = devices[i].isLive ? "#FF0000" : (devices[i].isPreview ? "#00FFFF" : "#00FF00")
                        devices[i].lastSeen = .now
                    }
                } catch {
                    // In a real service, consider logging
                }
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // Placeholder: detect USB Atom device in setup mode
    func simulateUSBDetection(into context: ModelContext) {
        let device = TallyDeviceItem(name: "ATOM-\(Int.random(in: 100...999))", isConnected: true, isRegistered: false, wifiSSID: nil, isPreview: false, isLive: false, colorHex: "#00FF00")
        context.insert(device)
    }

    // Placeholder: register device onto Wi-Fi known to the Mac
    func register(_ item: TallyDeviceItem, ssid: String) {
        item.isRegistered = true
        item.wifiSSID = ssid
    }

    // Placeholder: publish color/state to ATOM device
    func publishState(to item: TallyDeviceItem) {
        _ = item // no-op for now
    }
}
