import Foundation
import SwiftData

/// Vaibhav Paranji - 11/9/2026

/// One entry on the shopping list. It mirrors PantryItem (minus the expiry
/// date) so the two can be compared directly.
@Model
final class ShoppingItem {
    var name: String
    var category: String
    var storageRaw: String
    var quantity: Int
    var barcode: String?
    var addedDate: Date

    init(
        name: String,
        category: String = "Other",
        storage: StorageLocation = .fridge,
        quantity: Int = 1,
        barcode: String? = nil
    ) {
        self.name = name
        self.category = category
        self.storageRaw = storage.rawValue
        self.quantity = max(1, quantity)
        self.barcode = barcode
        self.addedDate = .now
    }

    var storage: StorageLocation {
        StorageLocation(rawValue: storageRaw) ?? .fridge
    }
}

extension ShoppingItem: GroceryItem {}

extension ShoppingItem {
    /// Adds an item to the list. If the same product is already there,
    /// its quantity goes up instead of creating a duplicate.
    static func add(_ newItem: ShoppingItem, in context: ModelContext) {
        guard !newItem.normalizedName.isEmpty else { return }
        let existing = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []

        if let match = existing.first(where: { $0.isSameProduct(as: newItem) }) {
            match.quantity = min(match.quantity + newItem.quantity, 99)
        } else {
            context.insert(newItem)
        }
    }

    /// Takes a purchased pantry item off the shopping list.
    ///
    /// The entry the user tapped (`linked`) is handled first, then any other
    /// entries that are the same product. Each entry is reduced by the
    /// quantity bought and deleted when it reaches zero. Leftover quantity
    /// carries to the next matching entry.
    static func fulfill(
        with bought: PantryItem,
        linked: ShoppingItem? = nil,
        in context: ModelContext
    ) {
        var remaining = bought.quantity
        guard remaining > 0 else { return }

        let all = (try? context.fetch(FetchDescriptor<ShoppingItem>(
            sortBy: [SortDescriptor(\.addedDate)]
        ))) ?? []

        var candidates: [ShoppingItem] = []
        if let linked { candidates.append(linked) }
        candidates += all.filter { $0 !== linked && $0.isSameProduct(as: bought) }

        for entry in candidates where remaining > 0 {
            if entry.quantity <= remaining {
                remaining -= entry.quantity
                context.delete(entry)
            } else {
                entry.quantity -= remaining
                remaining = 0
            }
        }
    }
}

extension ModelContext {
    /// Use this instead of `insert` for new pantry items. Every way of
    /// adding to the pantry (form, scanner, future features) then updates
    /// the shopping list automatically.
    func addToPantry(_ item: PantryItem, from shoppingItem: ShoppingItem? = nil) {
        insert(item)
        ShoppingItem.fulfill(with: item, linked: shoppingItem, in: self)
    }
}