// Mohd Ramzan

import Testing
import Foundation
import SwiftData
@testable import UseBy

@Suite("PantryItem urgency logic")
struct PantryItemTests {

    // Creates an in-memory PantryItem so tests don't touch disk
    private func makeItem(name: String = "Test", daysFromNow: Int) throws -> PantryItem {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PantryItem.self, configurations: config)
        let context = ModelContext(container)
        let expiry = Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now)!
        let item = PantryItem(
            name: name,
            category: "Dairy",
            storage: .fridge,
            quantity: 1,
            expiryDate: expiry
        )
        context.insert(item)
        return item
    }

    @Test func itemExpiringTodayIsUrgent() throws {
        let item = try makeItem(daysFromNow: 0)
        #expect(item.urgency == .urgent)
    }

    @Test func itemExpiringInTwoDaysIsUrgent() throws {
        let item = try makeItem(daysFromNow: 2)
        #expect(item.urgency == .urgent)
    }

    @Test func itemExpiringInFiveDaysIsSoon() throws {
        let item = try makeItem(daysFromNow: 5)
        #expect(item.urgency == .soon)
    }

    @Test func itemExpiringInTenDaysIsSafe() throws {
        let item = try makeItem(daysFromNow: 10)
        #expect(item.urgency == .safe)
    }

    @Test func invalidStorageRawDefaultsToFridge() throws {
        let item = try makeItem(daysFromNow: 5)
        item.storageRaw = "NotAPlace"
        #expect(item.storage == .fridge)
    }
}


// Mo - additional coverage with in-memory SwiftData context
@Suite("PantryItem storage and daysLeft")
struct PantryItemStorageTests {

    private func makeItem(daysFromNow: Int) throws -> PantryItem {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PantryItem.self, configurations: config)
        let context = ModelContext(container)
        let expiry = Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now)!
        let item = PantryItem(name: "Test", category: "Produce", storage: .fridge,
                              quantity: 1, expiryDate: expiry)
        context.insert(item)
        return item
    }

    @Test func invalidStorageRawDefaultsToFridge() throws {
        let item = try makeItem(daysFromNow: 5)
        item.storageRaw = "NotAPlace"
        #expect(item.storage == .fridge)
    }

    @Test func freezerStorageRoundTrips() throws {
        let item = try makeItem(daysFromNow: 30)
        item.storageRaw = StorageLocation.freezer.rawValue
        #expect(item.storage == .freezer)
    }
}

// Vaibhav - Shopping List tests
// Shopping list coverage with in-memory SwiftData context
@Suite("Shopping list fulfillment")
struct ShoppingListTests {

    /// Holds the container so it stays alive for the whole test.
    private struct Store {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeStore() throws -> Store {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PantryItem.self, ShoppingItem.self,
            configurations: config
        )
        return Store(container: container, context: ModelContext(container))
    }

    private func makePantryItem(name: String, quantity: Int = 1) -> PantryItem {
        PantryItem(
            name: name,
            category: "Dairy",
            storage: .fridge,
            quantity: quantity,
            expiryDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        )
    }

    private func shoppingItems(in context: ModelContext) throws -> [ShoppingItem] {
        try context.save()
        return try context.fetch(FetchDescriptor<ShoppingItem>())
    }

    @Test func buyingFullQuantityRemovesShoppingItem() throws {
        let store = try makeStore()
        store.context.insert(ShoppingItem(name: "Milk", quantity: 2))

        store.context.addToPantry(makePantryItem(name: "Milk", quantity: 2))

        #expect(try shoppingItems(in: store.context).isEmpty)
    }

    @Test func buyingPartialQuantityLeavesRemainderOnList() throws {
        let store = try makeStore()
        store.context.insert(ShoppingItem(name: "Milk", quantity: 3))

        store.context.addToPantry(makePantryItem(name: "Milk", quantity: 1))

        let items = try shoppingItems(in: store.context)
        #expect(items.count == 1)
        #expect(items.first?.quantity == 2)
    }

    @Test func itemNotOnShoppingListStillAddsToPantry() throws {
        let store = try makeStore()
        store.context.insert(ShoppingItem(name: "Bread", quantity: 1))

        store.context.addToPantry(makePantryItem(name: "Cheese"))
        try store.context.save()

        let pantry = try store.context.fetch(FetchDescriptor<PantryItem>())
        #expect(pantry.count == 1)
        #expect(try shoppingItems(in: store.context).first?.name == "Bread")
    }
}