import Foundation
import SwiftData

/// Vaibhav Paranji - 11/9/2026

/// One entry on the shopping list. It mirrors PantryItem (minus the expiry
/// date) so the two can be compared directly.
@Model
final class ShoppingItem {
    /// Product identity and pantry defaults copied into the add-to-pantry form.
    var name: String
    var category: String
    var storageRaw: String
    /// Number of units still needed; partial purchases decrement this value.
    var quantity: Int
    var barcode: String?
    /// Stable ordering for consuming matching list entries oldest-first.
    var addedDate: Date

    /// Creates a persisted list entry, normalizing quantity to a useful range.
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

    /// Converts the persisted storage string back to the app's enum.
    var storage: StorageLocation {
        StorageLocation(rawValue: storageRaw) ?? .fridge
    }
}

extension ShoppingItem: GroceryItem {}

extension ShoppingItem {
    /// Adds an item to the list. If the same product is already there,
    /// its quantity goes up instead of creating a duplicate.
    static func add(_ newItem: ShoppingItem, in context: ModelContext) {
        // Ignore blank names so they cannot create unmatchable list entries.
        guard !newItem.normalizedName.isEmpty else { return }
        let existing = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []

        // Merge duplicate products instead of showing the same grocery twice.
        if let match = existing.first(where: { $0.isSameProduct(as: newItem) }) {
            match.quantity = min(match.quantity + newItem.quantity, 99)
        } else {
            context.insert(newItem)
        }
    }

    /// Takes a purchased pantry item off the shopping list.
    ///
    /// The tapped entry is handled first only if its name still matches the
    /// purchased item, then any other entries for the same product. Each entry
    /// is reduced by the quantity bought and deleted when it reaches zero.
    /// Leftover quantity carries to the next matching entry.
    static func fulfill(
        with bought: PantryItem,
        linked: ShoppingItem? = nil,
        in context: ModelContext
    ) {
        var remaining = bought.quantity
        // A non-positive purchase must not change anything on the list.
        guard remaining > 0 else { return }

        // Fetch in age order so excess purchased units reduce the oldest
        // matching list entries first.
        let all = (try? context.fetch(FetchDescriptor<ShoppingItem>(
            sortBy: [SortDescriptor(\.addedDate)]
        ))) ?? []

        var candidates: [ShoppingItem] = []
        // Prefer the row the user opened, but only if its current name still
        // identifies the product they are adding to the pantry.
        if let linked,
           !linked.normalizedName.isEmpty,
           linked.normalizedName == bought.normalizedName {
            candidates.append(linked)
        }
        // A renamed linked row is left alone; other genuinely matching rows
        // can still be fulfilled by this purchase.
        candidates += all.filter { $0 !== linked && $0.isSameProduct(as: bought) }

        for entry in candidates where remaining > 0 {
            if entry.quantity <= remaining {
                // This purchase covers the whole entry; carry any extra units
                // over to the next matching entry.
                remaining -= entry.quantity
                context.delete(entry)
            } else {
                // Keep the unpurchased balance on the list.
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
    func addToPantry(
        _ item: PantryItem,
        from shoppingItem: ShoppingItem? = nil,
        addBackToShoppingList: Bool = false
    ) {
        // Every pantry-entry path shares the same fulfillment behavior.
        insert(item)
        ShoppingItem.fulfill(with: item, linked: shoppingItem, in: self)

        // Recreate a list entry only after the user opts in from the
        // shopping-list add form. ShoppingItem.add merges any duplicate.
        if addBackToShoppingList {
            ShoppingItem.add(
                ShoppingItem(
                    name: item.name,
                    category: item.category,
                    storage: item.storage,
                    quantity: item.quantity,
                    barcode: item.barcode
                ),
                in: self
            )
        }
    }
}