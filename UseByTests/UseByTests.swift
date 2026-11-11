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


// Alex Kuznetsov
@Suite("Expiration date workflows")
struct ExpirationDateWorkflowTests {

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PantryItem.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeFoodKeeperEntry(fields: [String: String]) -> FoodKeeperEntry {
        FoodKeeperEntry(
            id: "test-milk",
            name: "Milk",
            category: nil,
            pantry: nil,
            refrigerator: nil,
            freezer: nil,
            afterOpening: nil,
            tips: nil,
            rawFields: fields
        )
    }

    private var referenceDate: Date {
        Calendar.current.date(
            from: DateComponents(year: 2027, month: 1, day: 1)
        )!
    }

    private func daysBetween(_ start: Date, and end: Date) -> Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: end)
        ).day!
    }

    // Scenario 1: Add an item with a manually selected expiration date.
    @Test func addingItemWithManualExpirationDatePersistsSelectedDate() throws {
        let context = try makeContext()
        let manualDate = Calendar.current.date(
            byAdding: .day,
            value: 12,
            to: referenceDate
        )!

        let item = PantryItem(
            name: "Milk",
            category: "Dairy",
            storage: .fridge,
            quantity: 1,
            expiryDate: manualDate
        )
        context.insert(item)
        try context.save()

        let savedItems = try context.fetch(FetchDescriptor<PantryItem>())
        #expect(savedItems.count == 1)
        #expect(savedItems.first?.name == "Milk")
        #expect(savedItems.first?.expiryDate == manualDate)
    }

    // Scenario 2: Add an item using a FoodKeeper estimate.
    @Test func addingItemWithEstimatedExpirationDatePersistsEstimate() throws {
        let context = try makeContext()
        let milk = makeFoodKeeperEntry(fields: [
            "Refrigerate_Min": "2",
            "Refrigerate_Metric": "Weeks"
        ])
        let estimatedDate = ExpiryEstimation.estimate(
            for: milk,
            storage: .fridge,
            from: referenceDate
        )

        let item = PantryItem(
            name: "Milk",
            category: "Dairy",
            storage: .fridge,
            quantity: 1,
            expiryDate: estimatedDate
        )
        context.insert(item)
        try context.save()

        let savedItems = try context.fetch(FetchDescriptor<PantryItem>())
        #expect(savedItems.count == 1)
        #expect(savedItems.first?.expiryDate == estimatedDate)
        #expect(daysBetween(referenceDate, and: savedItems[0].expiryDate) == 14)
    }

    // Scenario 3: Edit an existing item, replacing its manual date with an estimate
    @Test func editingItemFromManualDateToEstimatedDateUpdatesSavedDate() throws {
        let context = try makeContext()
        let originalManualDate = Calendar.current.date(
            byAdding: .day,
            value: 20,
            to: referenceDate
        )!
        let item = PantryItem(
            name: "Milk",
            category: "Dairy",
            storage: .fridge,
            quantity: 1,
            expiryDate: originalManualDate
        )
        context.insert(item)
        try context.save()

        let milk = makeFoodKeeperEntry(fields: [
            "Refrigerate_Min": "1",
            "Refrigerate_Metric": "Weeks"
        ])
        let estimatedDate = ExpiryEstimation.estimate(
            for: milk,
            storage: item.storage,
            from: referenceDate
        )

        // Represents the Edit view applying the selected estimation to the item
        item.expiryDate = estimatedDate
        try context.save()

        let savedItems = try context.fetch(FetchDescriptor<PantryItem>())
        #expect(savedItems.count == 1)
        #expect(savedItems[0].expiryDate == estimatedDate)
        #expect(savedItems[0].expiryDate != originalManualDate)
        #expect(daysBetween(referenceDate, and: savedItems[0].expiryDate) == 7)
    }

    // Scenario 4: Changing storage recalculates the estimate using that location's data.
    @Test func changingStorageLocationRecalculatesEstimatedDate() throws {
        let context = try makeContext()
        let milk = makeFoodKeeperEntry(fields: [
            "Refrigerate_Min": "1",
            "Refrigerate_Metric": "Weeks",
            "Freeze_Min": "3",
            "Freeze_Metric": "Months"
        ])

        let fridgeEstimate = ExpiryEstimation.estimate(
            for: milk,
            storage: .fridge,
            from: referenceDate
        )
        let item = PantryItem(
            name: "Milk",
            category: "Dairy",
            storage: .fridge,
            quantity: 1,
            expiryDate: fridgeEstimate
        )
        context.insert(item)
        try context.save()

        // Represents changing the Edit view's storage picker from Fridge to Freezer.
        let newStorage = StorageLocation.freezer
        let freezerEstimate = ExpiryEstimation.estimate(
            for: milk,
            storage: newStorage,
            from: referenceDate
        )
        item.storageRaw = newStorage.rawValue
        item.expiryDate = freezerEstimate
        try context.save()

        let savedItems = try context.fetch(FetchDescriptor<PantryItem>())
        #expect(savedItems.count == 1)
        #expect(savedItems[0].storage == .freezer)
        #expect(savedItems[0].expiryDate == freezerEstimate)
        #expect(daysBetween(referenceDate, and: savedItems[0].expiryDate) == 90)
        #expect(savedItems[0].expiryDate != fridgeEstimate)
    }
}
