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
