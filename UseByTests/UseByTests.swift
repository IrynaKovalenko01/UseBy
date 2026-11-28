// Mohd Ramzan

import Testing
import Foundation
import SwiftData
import SwiftUI
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


// Shopping-list tests use an in-memory context to verify quantity fulfillment,
// renamed items, add-back behavior, and form stability after deletion.
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

    private func makePantryItem(
        name: String,
        quantity: Int = 1,
        barcode: String? = nil
    ) -> PantryItem {
        PantryItem(
            name: name,
            category: "Dairy",
            storage: .fridge,
            quantity: quantity,
            barcode: barcode,
            expiryDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        )
    }

    private func shoppingItems(in context: ModelContext) throws -> [ShoppingItem] {
        try context.save()
        return try context.fetch(FetchDescriptor<ShoppingItem>())
    }

    /// Buying the requested amount removes the completed list entry.
    @Test func buyingFullQuantityRemovesShoppingItem() throws {
        let store = try makeStore()
        store.context.insert(ShoppingItem(name: "Milk", quantity: 2))

        store.context.addToPantry(makePantryItem(name: "Milk", quantity: 2))

        #expect(try shoppingItems(in: store.context).isEmpty)
    }

    /// The opt-in add-back choice recreates a list entry with the bought count.
    @Test func choosingToAddBackRecreatesShoppingListItem() throws {
        let store = try makeStore()
        let linked = ShoppingItem(name: "Milk", quantity: 2)
        store.context.insert(linked)

        store.context.addToPantry(
            makePantryItem(name: "Milk", quantity: 2),
            from: linked,
            addBackToShoppingList: true
        )

        let items = try shoppingItems(in: store.context)
        #expect(items.count == 1)
        #expect(items.first?.name == "Milk")
        #expect(items.first?.quantity == 2)
    }

    /// A renamed linked entry remains, while a different matching entry is
    /// still eligible to be fulfilled by the purchase.
    @Test func renamedLinkedItemDoesNotFulfillShoppingItem() throws {
        let store = try makeStore()
        let linked = ShoppingItem(name: "Captain Crunch", quantity: 1, barcode: "123")
        let matching = ShoppingItem(name: "Honey Nut Cheerios", quantity: 1)
        store.context.insert(linked)
        store.context.insert(matching)

        store.context.addToPantry(
            makePantryItem(name: "Honey Nut Cheerios", quantity: 1, barcode: "123"),
            from: linked
        )

        let items = try shoppingItems(in: store.context)
        #expect(items.count == 1)
        #expect(items.first?.name == "Captain Crunch")
    }

    /// The add form can still build its body after fulfillment deletes the
    /// SwiftData object it was originally opened with.
    @Test func addFormBodyRemainsSafeAfterLinkedItemIsDeleted() throws {
        let store = try makeStore()
        let linked = ShoppingItem(name: "Milk", quantity: 2)
        store.context.insert(linked)
        let addItemView = AddItemView(shoppingItem: linked)

        store.context.addToPantry(
            makePantryItem(name: "Milk", quantity: 2),
            from: linked
        )

        #expect(try shoppingItems(in: store.context).isEmpty)
        _ = addItemView.body
    }

    /// Buying fewer units preserves the unpurchased quantity on the list.
    @Test func buyingPartialQuantityLeavesRemainderOnList() throws {
        let store = try makeStore()
        store.context.insert(ShoppingItem(name: "Milk", quantity: 3))

        store.context.addToPantry(makePantryItem(name: "Milk", quantity: 1))

        let items = try shoppingItems(in: store.context)
        #expect(items.count == 1)
        #expect(items.first?.quantity == 2)
    }

    /// Pantry adds unrelated to the list must not remove any list entries.
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

@Suite("Calorie tracking")
struct CalorieTrackingTests {

    /// Verifies equation inputs, activity multiplier, goal adjustment, and
    /// rounding together against a known adult example.
    @Test func calculatesAdultDailyTargetFromProfile() {
        let target = CalorieTargetCalculator.recommendedCalories(
            age: 30,
            heightCentimeters: 170,
            weightKilograms: 70,
            calculationSex: .female,
            activityLevel: .moderatelyActive,
            goal: .gradualWeightLoss
        )

        #expect(target == 1950)
    }

    /// The personalized estimate is intentionally unavailable for minors.
    @Test func rejectsUnderageProfileForEstimatedTarget() {
        let target = CalorieTargetCalculator.recommendedCalories(
            age: 17,
            heightCentimeters: 170,
            weightKilograms: 70,
            calculationSex: .female,
            activityLevel: .moderatelyActive,
            goal: .maintain
        )

        #expect(target == nil)
    }

    /// A manually entered target takes precedence while the estimate remains
    /// available as a calculated value.
    @Test func manualTargetOverridesPersonalizedEstimate() {
        let profile = CalorieProfile(
            age: 30,
            heightCentimeters: 170,
            weightKilograms: 70,
            calculationSexRaw: CalorieCalculationSex.female.rawValue,
            activityLevelRaw: CalorieActivityLevel.moderatelyActive.rawValue,
            goalRaw: CalorieGoal.maintain.rawValue,
            manualDailyTarget: 2100
        )

        #expect(profile.estimatedDailyTarget == 2250)
        #expect(profile.recommendedDailyTarget == 2100)
    }

    /// Older meal entries do not contribute to the selected day's intake.
    @Test func mealTotalsOnlyIncludeSelectedCalendarDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let meals = [
            CalorieMeal(name: "Breakfast", calories: 400, consumedAt: today),
            CalorieMeal(name: "Lunch", calories: 650, consumedAt: today),
            CalorieMeal(name: "Yesterday", calories: 900, consumedAt: yesterday)
        ]

        #expect(CalorieMeal.totalCalories(in: meals, on: today) == 1050)
    }

    /// Offline recipe ideas stay under budget and are sorted toward its limit.
    @Test func offlineRecipesStayWithinBudgetAndPreferClosestFit() {
        let suggestions = OfflineCalorieRecipe.suggestions(fitting: 500)

        #expect(suggestions.map(\.caloriesPerServing) == [450, 400, 300])
    }

    /// Spoonacular nutrition decoding finds and rounds its Calories nutrient.
    @Test func readsCaloriesFromSpoonacularNutrition() throws {
        let data = Data(
            #"{"nutrients":[{"name":"Calories","amount":321.6,"unit":"kcal"}]}"#.utf8
        )
        let nutrition = try JSONDecoder().decode(SpoonacularNutrition.self, from: data)

        #expect(nutrition.caloriesPerServing == 322)
    }
}
