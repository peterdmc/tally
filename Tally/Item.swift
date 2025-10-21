//
//  Item.swift
//  Tally
//
//  Created by Peter Manoharan on 21/10/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
