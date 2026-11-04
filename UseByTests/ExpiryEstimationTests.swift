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

    // Milk in the fridge with no number, just "package use-by date", should go to default number for 7 days
    @Test func milkPackageDate(){
        let milk = makeFood(["Refrigerate_Metric": "Package use-by date"])
        let expiry = ExpiryEstimation.estimate(for: milk, storage: .fridge, from: start)
        #expect(daysAfterStart(expiry) == 7)
    }

    // Milk in the pantry, FoodKeeper has nothing, should go to default
    @Test func milkPantry(){
        let milk = makeFood([:])
        let expiry = ExpiryEstimation.estimate(for: milk, storage: .pantry, from: start)
        #expect(daysAfterStart(expiry) == 7)
    }
}