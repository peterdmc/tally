import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [TallyDeviceItem]
    @State private var selection = Set<TallyDeviceItem.ID>()
    @EnvironmentObject private var service: TallyService

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name).font(.headline)
                                HStack(spacing: 8) {
                                    Badge(text: item.isConnected ? "Connected" : "Disconnected", color: item.isConnected ? .green : .gray)
                                    Badge(text: item.isRegistered ? (item.wifiSSID ?? "Registered") : "Not Registered", color: item.isRegistered ? .blue : .orange)
                                    Badge(text: item.isLive ? "LIVE" : (item.isPreview ? "PREVIEW" : "IDLE"), color: item.isLive ? .red : (item.isPreview ? .cyan : .green))
                                }
                                .font(.caption)
                            }
                            Spacer()
                            if service.mode == .setup {
                                Menu("Actions") {
                                    Button("Register on Wi‑Fi…") {
                                        service.register(item, ssid: "ExampleSSID")
                                    }
                                    Button("Publish test state") {
                                        service.publishState(to: item)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: deleteSelectedItems) {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selection.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    if service.mode == .setup {
                        Button {
                            service.simulateUSBDetection(into: modelContext)
                        } label: {
                            Label("Simulate USB Atom", systemImage: "tray.and.arrow.down")
                        }
                    }
                }
            }
        } detail: {
            Text("Select a device")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
    
    private func deleteSelectedItems() {
        withAnimation {
            for id in selection {
                if let item = items.first(where: { $0.id == id }) {
                    modelContext.delete(item)
                }
            }
            selection.removeAll()
        }
    }
}

// Simple badge view for status chips
private struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.2)))
            .overlay(Capsule().stroke(color, lineWidth: 1))
    }
}

#Preview {
    ContentView()
        .environmentObject(TallyService())
        .modelContainer(for: TallyDeviceItem.self, inMemory: true)
}
