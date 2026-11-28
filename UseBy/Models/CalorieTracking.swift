import Foundation
import SwiftData

/// Vaibhav Paranji - 11/27/2026

/// Sex coefficient used by Mifflin–St Jeor; it is an equation input, not a
/// statement about a person's gender or a medical classification.
enum CalorieCalculationSex: String, CaseIterable, Identifiable {
    case female
    case male

    var id: String { rawValue }
    /// Mifflin–St Jeor equation offset for the selected coefficient.
    var equationOffset: Double { self == .male ? 5 : -161 }
    var label: String { self == .male ? "Male coefficient" : "Female coefficient" }
}

/// Activity multipliers used to estimate total daily energy expenditure.
enum CalorieActivityLevel: String, CaseIterable, Identifiable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive

    var id: String { rawValue }

    /// Scales resting calorie needs to approximate total daily energy use.
    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        }
    }

    var label: String {
        switch self {
        case .sedentary: "Sedentary"
        case .lightlyActive: "Lightly active"
        case .moderatelyActive: "Moderately active"
        case .veryActive: "Very active"
        }
    }
}

/// Optional calorie adjustment applied to the maintenance estimate.
enum CalorieGoal: String, CaseIterable, Identifiable {
    case maintain
    case gradualWeightLoss
    case gradualWeightGain

    var id: String { rawValue }

    /// Small gradual adjustment from estimated maintenance calories.
    var calorieAdjustment: Double {
        switch self {
        case .maintain: 0
        case .gradualWeightLoss: -300
        case .gradualWeightGain: 250
        }
    }

    var label: String {
        switch self {
        case .maintain: "Maintain weight"
        case .gradualWeightLoss: "Gradual weight loss"
        case .gradualWeightGain: "Gradual weight gain"
        }
    }
}

/// Calculates an approximate adult calorie target; returns nil for invalid
/// or unsupported profile inputs rather than presenting a misleading result.
enum CalorieTargetCalculator {
    /// Estimates daily calories from resting needs, activity, and the selected
    /// gradual goal, then rounds the result to the nearest 50 kcal.
    static func recommendedCalories(
        age: Int,
        heightCentimeters: Double,
        weightKilograms: Double,
        calculationSex: CalorieCalculationSex,
        activityLevel: CalorieActivityLevel,
        goal: CalorieGoal
    ) -> Int? {
        guard (18...100).contains(age),
              (100...250).contains(heightCentimeters),
              (30...400).contains(weightKilograms) else {
            return nil
        }

        // Mifflin–St Jeor resting estimate in kcal/day:
        // 10*weight(kg) + 6.25*height(cm) - 5*age + sex coefficient.
        let restingCalories =
            10 * weightKilograms
            + 6.25 * heightCentimeters
            - 5 * Double(age)
            + calculationSex.equationOffset
        // Apply activity first, then the selected gradual goal adjustment.
        let dailyCalories =
            restingCalories * activityLevel.multiplier + goal.calorieAdjustment

        guard dailyCalories.isFinite, dailyCalories > 0 else { return nil }
        let roundedTarget = Int((dailyCalories / 50).rounded() * 50)
        return roundedTarget > 0 ? roundedTarget : nil
    }
}

/// A locally stored meal or food entry used to total the user's daily intake.
@Model
final class CalorieMeal {
    /// User-entered meal or recipe-serving name.
    var name: String
    /// Calories recorded for the complete logged serving/meal.
    var calories: Int
    /// Used to place the meal on the correct daily total.
    var consumedAt: Date

    /// Creates a meal record; the timestamp defaults to when it is logged.
    init(name: String, calories: Int, consumedAt: Date = .now) {
        self.name = name
        self.calories = calories
        self.consumedAt = consumedAt
    }

    /// Sums only meals on the specified local calendar day.
    static func totalCalories(in meals: [CalorieMeal], on date: Date) -> Int {
        meals
            .filter { Calendar.current.isDate($0.consumedAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.calories }
    }
}

/// On-device calorie settings. A manual target takes precedence over an
/// estimate calculated from the optional adult profile fields.
@Model
final class CalorieProfile {
    /// Optional personal inputs for an adult calorie estimate.
    var age: Int?
    var heightCentimeters: Double?
    var weightKilograms: Double?
    /// Persist enum raw values so the model stores stable, simple values.
    var calculationSexRaw: String?
    var activityLevelRaw: String?
    var goalRaw: String?
    /// User override; when present it is used instead of the calculated target.
    var manualDailyTarget: Int?

    init(
        age: Int? = nil,
        heightCentimeters: Double? = nil,
        weightKilograms: Double? = nil,
        calculationSexRaw: String? = nil,
        activityLevelRaw: String? = nil,
        goalRaw: String? = nil,
        manualDailyTarget: Int? = nil
    ) {
        self.age = age
        self.heightCentimeters = heightCentimeters
        self.weightKilograms = weightKilograms
        self.calculationSexRaw = calculationSexRaw
        self.activityLevelRaw = activityLevelRaw
        self.goalRaw = goalRaw
        self.manualDailyTarget = manualDailyTarget
    }

    /// Returns nil until every input needed by the equation is present and valid.
    var estimatedDailyTarget: Int? {
        guard let age,
              let heightCentimeters,
              let weightKilograms,
              let calculationSex = calculationSexRaw.flatMap(CalorieCalculationSex.init(rawValue:)),
              let activityLevel = activityLevelRaw.flatMap(CalorieActivityLevel.init(rawValue:)),
              let goal = goalRaw.flatMap(CalorieGoal.init(rawValue:)) else {
            return nil
        }

        return CalorieTargetCalculator.recommendedCalories(
            age: age,
            heightCentimeters: heightCentimeters,
            weightKilograms: weightKilograms,
            calculationSex: calculationSex,
            activityLevel: activityLevel,
            goal: goal
        )
    }

    /// Target shown by the tracker: manual override first, estimate otherwise.
    var recommendedDailyTarget: Int? {
        manualDailyTarget ?? estimatedDailyTarget
    }
}

/// Small built-in recipe ideas used if online recommendations or nutrition
/// data are unavailable. Their calorie values are approximate.
struct OfflineCalorieRecipe: Identifiable {
    let title: String
    let ingredients: String
    let caloriesPerServing: Int

    var id: String { title }

    static let suggestions = [
        OfflineCalorieRecipe(
            title: "Greek Yogurt Berry Bowl",
            ingredients: "Greek yogurt, berries, oats",
            caloriesPerServing: 300
        ),
        OfflineCalorieRecipe(
            title: "Veggie Omelet with Toast",
            ingredients: "Eggs, spinach, vegetables, whole-grain toast",
            caloriesPerServing: 400
        ),
        OfflineCalorieRecipe(
            title: "Lentil and Tomato Soup",
            ingredients: "Lentils, tomatoes, carrots, onion",
            caloriesPerServing: 450
        ),
        OfflineCalorieRecipe(
            title: "Chicken and Rice Bowl",
            ingredients: "Chicken, rice, broccoli",
            caloriesPerServing: 550
        ),
        OfflineCalorieRecipe(
            title: "Salmon with Potatoes",
            ingredients: "Salmon, potatoes, green vegetables",
            caloriesPerServing: 650
        )
    ]

    /// Keeps only ideas within the remaining daily calorie budget, ordered
    /// from the closest fit down to the lightest suggestion.
    static func suggestions(fitting calorieBudget: Int) -> [OfflineCalorieRecipe] {
        suggestions
            .filter { $0.caloriesPerServing <= calorieBudget }
            .sorted { $0.caloriesPerServing > $1.caloriesPerServing }
    }
}
