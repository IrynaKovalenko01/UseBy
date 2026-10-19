//
//  Item.swift
//  UseBy
//
//  Created by ikoval2 on 10/19/26.
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
