import Testing
import Foundation
@testable import UseBy

// Tyler Todd 11/3/26
// tests for ExpiryEstimation, uses fake FoodKeeper data so no internet is needed

@MainActor
struct ExpiryEstimationTests {

     // lets just pick a fixed start date (Jan 1, 2027) so the results are always the same
    var start: Date {
        var date = Date.now
        if let fixed = Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 1)) {
            date = fixed
        }
        return date
    }

    // makes a fake food from FoodKeeper, only filling in the fields we're testing
    func makeFood(_ fields: [String: String]) -> FoodKeeperEntry {
        return FoodKeeperEntry(id: "1", name: "Milk", category: nil,
                               pantry: nil, refrigerator: nil, freezer: nil,
                               afterOpening: nil, tips: nil, rawFields: fields)
    }

    // counts how many days after the start date our estimate landed
    func daysAfterStart(_ date: Date) -> Int {
        var days = 0
        if let count = Calendar.current.dateComponents([.day], from: start, to: date).day {
            days = count
        }
        return days
    }

    // 4 tests, one for each case

    // Milk in the freezer, only has the Date of purchase, 3 months should be 90 days
    @Test func milkFreezer(){
        let milk = makeFood(["DOP_Freeze_Min": "3", "DOP_Freeze_Metric": "Months"])
        let expiry = ExpiryEstimation.estimate(for: milk, storage: .freezer, from: start)
        #expect(daysAfterStart(expiry) == 90)
    }

    // Milk in the fridge with the normal fields, 1 week is 7 days
    @Test func milkFridge(){
        let milk = makeFood(["Refrigerate_Min": "1", "Refrigerate_Metric": "Weeks"])
        let expiry = ExpiryEstimation.estimate(for: milk, storage: .fridge, from: start)
        #expect(daysAfterStart(expiry) == 7)
    }

    // Milk in the fridge with no number, just "package use-by date", uses the 6-day average fallback
    @Test func milkPackageDate(){
        let milk = makeFood(["Refrigerate_Metric": "Package use-by date"])
        let expiry = ExpiryEstimation.estimate(for: milk, storage: .fridge, from: start)
        #expect(daysAfterStart(expiry) == 6)
    }

    // Milk in the pantry, FoodKeeper has nothing, uses the conservative generic fallback
    @Test func milkPantry(){
        let milk = makeFood([:])
        let expiry = ExpiryEstimation.estimate(for: milk, storage: .pantry, from: start)
        #expect(daysAfterStart(expiry) == 3)
    }

    @Test func detectsUsableShelfLife() {
        let milk = makeFood(["Refrigerate_Min": "1", "Refrigerate_Metric": "Weeks"])
        #expect(ExpiryEstimation.hasUsableShelfLife(for: milk, storage: .fridge))
        #expect(!ExpiryEstimation.hasUsableShelfLife(for: milk, storage: .pantry))
    }

    @Test func avocadoPantryUntilRipeUsesAverageThreeDayRipeningEstimate() {
        let avocado = FoodKeeperEntry(
            id: "avocado",
            name: "Avocados",
            category: "Fruit",
            pantry: "Until ripe",
            refrigerator: nil,
            freezer: nil,
            afterOpening: nil,
            tips: nil,
            rawFields: ["Pantry": "Until ripe"]
        )
        let expiry = ExpiryEstimation.estimate(for: avocado, storage: .pantry, from: start)
        #expect(daysAfterStart(expiry) == 3)
        #expect(!ExpiryEstimation.hasUsableShelfLife(for: avocado, storage: .pantry))
        #expect(ExpiryEstimation.fallbackMessage(for: avocado, storage: .pantry).contains("3-day"))
    }

    @Test func avocadoEstimateExplainsItIsAnApproximation() {
        let avocado = FoodKeeperEntry(
            id: "avocado",
            name: "Avocado",
            category: "Fruit",
            pantry: "Until ripe",
            refrigerator: nil,
            freezer: nil,
            afterOpening: nil,
            tips: nil,
            rawFields: ["Pantry": "Until ripe"]
        )
        #expect(ExpiryEstimation.fallbackMessage(for: avocado, storage: .pantry).contains("approximate"))
    }
}

// Fallback coverage for common products whose FoodKeeper values are qualitative
// (for example, "until ripe" or "package use-by date") or unavailable.
extension ExpiryEstimationTests {
    @Test func appleFridgeUsesConservativeAverageStorageEstimate() {
        #expect(ExpiryEstimation.fallbackDays(for: "Apples", storage: .fridge) == 17)
        let expiry = ExpiryEstimation.estimate(for: "Apple", storage: .fridge, from: start)
        #expect(daysAfterStart(expiry) == 17)
    }

    @Test func avocadoPantryAndFridgeHaveConservativePublishedEstimates() {
        #expect(ExpiryEstimation.fallbackDays(for: "Avocado", storage: .pantry) == 3)
        #expect(ExpiryEstimation.fallbackDays(for: "Avocado", storage: .fridge) == 3)
    }

    @Test func milkPackageDateGetsClearlyLabelledFallback() {
        let milk = makeFood(["Refrigerate": "Package use-by date"])
        let expiry = ExpiryEstimation.estimate(for: milk, storage: .fridge, from: start)
        #expect(daysAfterStart(expiry) == 6)
        #expect(ExpiryEstimation.fallbackMessage(for: milk, storage: .fridge).contains("6-day"))
    }

    @Test func commonUntilRipeFruitHasProductSpecificFallback() {
        #expect(ExpiryEstimation.fallbackDays(for: "Bananas", storage: .pantry) == 4)
        #expect(ExpiryEstimation.fallbackDays(for: "Peaches", storage: .pantry) == 4)
        #expect(ExpiryEstimation.fallbackDays(for: "Pears", storage: .pantry) == 7)
        #expect(ExpiryEstimation.fallbackDays(for: "Mango", storage: .pantry) == 7)
    }

    @Test func numericTextualRangeUsesAverageAndRoundsDown() {
        let apple = FoodKeeperEntry(
            id: "range",
            name: "Apples",
            category: "Fruit",
            pantry: nil,
            refrigerator: "1-2 weeks",
            freezer: nil,
            afterOpening: nil,
            tips: nil,
            rawFields: ["Refrigerate": "1-2 weeks"]
        )
        let expiry = ExpiryEstimation.estimate(for: apple, storage: .fridge, from: start)
        #expect(daysAfterStart(expiry) == 10)
        #expect(ExpiryEstimation.hasUsableShelfLife(for: apple, storage: .fridge))
    }

    @Test func unknownProductStillGetsExplicitGenericEstimate() {
        let expiry = ExpiryEstimation.estimate(for: "Mystery ingredient", storage: .fridge, from: start)
        #expect(daysAfterStart(expiry) == 3)
        #expect(ExpiryEstimation.fallbackMessage(for: "Mystery ingredient", storage: .fridge).contains("generic 3-day"))
    }

    @Test func applesauceDoesNotAccidentallyMatchFreshAppleRule() {
        #expect(ExpiryEstimation.fallbackDays(for: "Applesauce", storage: .fridge) == nil)
    }
}
