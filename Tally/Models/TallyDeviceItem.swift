//
//  Item.swift
//  Tally
//
//  Created by Peter Manoharan on 21/10/2025.
//

import Foundation
import SwiftData

// Note: This @Model represents an Atom device in our app. We keep the name "Item" to avoid touching project settings.
@Model
final class TallyDeviceItem {
    // Core identity
    var name: String = "ATOM Blaster"
    var createdAt: Date = Date.now

    // Device status
    var isConnected: Bool = false
    var isRegistered: Bool = false
    var wifiSSID: String?

    // Tally state from ATEM
    var isPreview: Bool = false
    var isLive: Bool = false

    // UI color hint for the ATOM screen (hex string, e.g., "#FF0000")
    var colorHex: String = "#00FF00"

    // Last time we saw the device (USB or network heartbeat)
    var lastSeen: Date = Date.now

    // Backwards compatibility with the original template (not used)
    var timestamp: Date = Date.now

    init(
        name: String,
        isConnected: Bool = false,
        isRegistered: Bool = false,
        wifiSSID: String? = nil,
        isPreview: Bool = false,
        isLive: Bool = false,
        colorHex: String = "#00FF00",
        now: Date = .now
    ) {
        self.name = name
        self.createdAt = now
        self.isConnected = isConnected
        self.isRegistered = isRegistered
        self.wifiSSID = wifiSSID
        self.isPreview = isPreview
        self.isLive = isLive
        self.colorHex = colorHex
        self.lastSeen = now
        self.timestamp = now
    }
}
