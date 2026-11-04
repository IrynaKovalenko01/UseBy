import Testing
import Foundation
import SwiftData
@testable import UseBy

// Cutoff tests: purple = expired, red = 0–2 days, yellow = 3–7 days, green = 8+ days
@Suite("Urgency color cutoffs")
struct UrgencyCutoffTests {

    // Creates an in-memory PantryItem so tests don't touch disk
    private func makeItem(daysFromNow: Int) throws -> PantryItem {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PantryItem.self, configurations: config)
        let context = ModelContext(container)
        let expiry = try #require(Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now))
        let item = PantryItem(name: "Test", category: "Dairy", storage: .fridge,
                              quantity: 1, expiryDate: expiry)
        context.insert(item)
        return item
    }

    @Test func itemExpiredYesterdayIsExpired() throws {
        let item = try makeItem(daysFromNow: -1)
        #expect(item.urgency == .expired)
    }

    @Test func itemExpiredLastWeekIsExpired() throws {
        let item = try makeItem(daysFromNow: -7)
        #expect(item.urgency == .expired)
    }

    @Test func itemExpiringInThreeDaysIsSoon() throws {
        let item = try makeItem(daysFromNow: 3)
        #expect(item.urgency == .soon)
    }

    @Test func itemExpiringInSevenDaysIsSoon() throws {
        let item = try makeItem(daysFromNow: 7)
        #expect(item.urgency == .soon)
    }

    @Test func itemExpiringInEightDaysIsSafe() throws {
        let item = try makeItem(daysFromNow: 8)
        #expect(item.urgency == .safe)
    }
}
