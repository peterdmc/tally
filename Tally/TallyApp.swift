//
//  TallyApp.swift
//  Tally
//
//  Created by Peter Manoharan on 21/10/2025.
//

import SwiftUI
import SwiftData

@main
struct TallyApp: App {
    @StateObject private var service: TallyService

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TallyDeviceItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let svc = TallyService()
        _service = StateObject(wrappedValue: svc)
        // Bind the shared model container so the service can run without UI
        svc.bind(modelContainer: sharedModelContainer)
        svc.startATEMMock()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            AppCommands(service: service)
        }
    }
}

private struct AppCommands: Commands {
    @ObservedObject var service: TallyService

    var body: some Commands {
        // Place within File menu after New Item group
        CommandGroup(after: .newItem) {
            Divider()
            Picker("Mode", selection: $service.mode) {
                ForEach(TallyService.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .keyboardShortcut("m", modifiers: [.command, .shift])
            // Quick actions
            Button("Switch to Live") { service.mode = .live }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Switch to Setup") { service.mode = .setup }
                .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }
}
