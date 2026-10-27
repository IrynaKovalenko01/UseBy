import Foundation
import SwiftData

enum StorageLocation: String, CaseIterable, Identifiable {
    case fridge = "Fridge"
    case freezer = "Freezer"
    case pantry = "Pantry"

    var id: String { rawValue }
}

enum Urgency : Equatable {
    case urgent
    case soon
    case safe
}

@Model
final class PantryItem {
    var name: String
    var category: String
    var storageRaw: String
    var quantity: Int
    var expiryDate: Date
    var addedDate: Date

    init(name: String, category: String, storage: StorageLocation,
         quantity: Int, expiryDate: Date) {
        self.name = name
        self.category = category
        self.storageRaw = storage.rawValue
        self.quantity = quantity
        self.expiryDate = expiryDate
        self.addedDate = .now
    }

    var storage: StorageLocation {
        StorageLocation(rawValue: storageRaw) ?? .fridge
    }

    var daysLeft: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let expiry = calendar.startOfDay(for: expiryDate)
        return calendar.dateComponents([.day], from: today, to: expiry).day ?? 0
    }

    // Red = 2 days or less, yellow = within a week, green = safe
    var urgency: Urgency {
        if daysLeft <= 2 { return .urgent }
        if daysLeft <= 7 { return .soon }
        return .safe
    }
}
