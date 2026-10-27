import Foundation
import SwiftData

enum StorageLocation: String, CaseIterable, Identifiable {
    case fridge = "Fridge"
    case freezer = "Freezer"
    case pantry = "Pantry"

    var id: String { rawValue }
}

/// Defines how an item's amount is measured.
///
/// Recreate the data model with this type when the app must distinguish a
/// countable item (for example, three apples) from a weighed item. The raw
/// values are presentation labels for the edit form, and id makes the cases
/// safe to use in SwiftUI's ForEach and Picker.
enum ItemAmountKind: String, CaseIterable, Identifiable {
    case quantity = "Quantity"
    case weight = "Weight"

    var id: String { rawValue }
}

enum Urgency {
    case urgent
    case soon
    case safe
}

/// The SwiftData record for one pantry item.
///
/// A recreated app needs a single persistent model that holds the manual form's
/// name, category, storage, quantity, and expiry date. barcode is optional:
/// manually created items have no code, while scanner-created items keep the
/// exact payload returned by VisionKit. Optional weightGrams preserves the
/// edit screen's alternative weight-based amount without changing the existing
/// quantity-based add flow.
@Model
final class PantryItem {
    var name: String
    var category: String
    var storageRaw: String
    var quantity: Int
    var weightGrams: Double?
    var barcode: String?
    var expiryDate: Date
    var addedDate: Date

    /// Creates a record from the values collected by an add-item workflow.
    ///
    /// Leave barcode as nil for manual entry. Pass the scanner payload for
    /// barcode entry so later views can identify how the item was added. New
    /// optional properties keep existing saved records compatible when the
    /// SwiftData schema evolves.
    init(
        name: String,
        category: String,
        storage: StorageLocation,
        quantity: Int,
        weightGrams: Double? = nil,
        barcode: String? = nil,
        expiryDate: Date
    ) {
        self.name = name
        self.category = category
        self.storageRaw = storage.rawValue
        self.quantity = quantity
        self.weightGrams = weightGrams
        self.barcode = barcode
        self.expiryDate = expiryDate
        self.addedDate = .now
    }

    /// Converts the stored string back into the strongly typed picker value.
    /// Fall back to fridge if an older or corrupted record has an unknown value.
    var storage: StorageLocation {
        StorageLocation(rawValue: storageRaw) ?? .fridge
    }

    /// Derives the edit form's measurement mode from the optional stored weight.
    var amountKind: ItemAmountKind {
        weightGrams == nil ? .quantity : .weight
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
