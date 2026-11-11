import Foundation

/// Estimates a best-quality/use-by reminder from FoodKeeper guidance where possible,
/// then uses conservative, clearly-labelled local fallback guidance when FoodKeeper
/// has no numeric value (for example, "until ripe" or "package use-by date").
/// These estimates are not food-safety guarantees.
enum ExpiryEstimation {
    private static let genericFallbackDays = 3

    private struct FallbackRule {
        let productTerms: [String]
        let pantryDays: Int?
        let fridgeDays: Int?
        let freezerDays: Int?
        let explanation: String

        func days(for storage: StorageLocation) -> Int? {
            switch storage {
            case .pantry: return pantryDays
            case .fridge: return fridgeDays
            case .freezer: return freezerDays
            }
        }
    }

    // Values are rounded DOWN from the midpoint of published ranges so reminders
    // are not pushed later than the average guidance. These are storage-quality
    // estimates, not guarantees of safety. Sources are listed in the project README.
    private static let fallbackRules: [FallbackRule] = [
        FallbackRule(productTerms: ["almond milk", "oat milk", "soy milk", "rice milk", "coconut milk"], pantryDays: nil, fridgeDays: 7, freezerDays: nil, explanation: "Typical opened non-dairy milk storage guidance"),
        FallbackRule(productTerms: ["milk powder", "powdered milk"], pantryDays: 365, fridgeDays: nil, freezerDays: nil, explanation: "Typical storage guidance for powdered milk"),
        FallbackRule(productTerms: ["milk", "fresh milk", "whole milk", "skim milk", "2 percent milk", "2% milk"], pantryDays: nil, fridgeDays: 6, freezerDays: 90, explanation: "Average refrigerated milk storage guidance"),
        FallbackRule(productTerms: ["apple", "apples"], pantryDays: 21, fridgeDays: 17, freezerDays: 240, explanation: "Average storage guidance for whole apples"),
        FallbackRule(productTerms: ["avocado", "avocados"], pantryDays: 3, fridgeDays: 3, freezerDays: nil, explanation: "Average ripening/storage guidance for avocados"),
        FallbackRule(productTerms: ["banana", "bananas"], pantryDays: 4, fridgeDays: 2, freezerDays: 60, explanation: "Average ripening/storage guidance for bananas"),
        FallbackRule(productTerms: ["apricot", "apricots"], pantryDays: 3, fridgeDays: 2, freezerDays: nil, explanation: "Average ripening/storage guidance for apricots"),
        FallbackRule(productTerms: ["kiwi", "kiwifruit"], pantryDays: 10, fridgeDays: 3, freezerDays: nil, explanation: "Average ripening/storage guidance for kiwi"),
        FallbackRule(productTerms: ["peach", "peaches", "nectarine", "nectarines"], pantryDays: 4, fridgeDays: 4, freezerDays: 60, explanation: "Average ripening/storage guidance for peaches and nectarines"),
        FallbackRule(productTerms: ["pear", "pears"], pantryDays: 7, fridgeDays: 4, freezerDays: 60, explanation: "Average ripening/storage guidance for pears"),
        FallbackRule(productTerms: ["plum", "plums"], pantryDays: 5, fridgeDays: 4, freezerDays: 60, explanation: "Average ripening/storage guidance for plums"),
        FallbackRule(productTerms: ["mango", "mangos", "mangoes"], pantryDays: 7, fridgeDays: 7, freezerDays: 60, explanation: "Average ripening/storage guidance for mangoes"),
        FallbackRule(productTerms: ["papaya", "papayas"], pantryDays: 4, fridgeDays: 7, freezerDays: 60, explanation: "Average ripening/storage guidance for papaya"),
        FallbackRule(productTerms: ["tomato", "tomatoes"], pantryDays: 6, fridgeDays: 4, freezerDays: 60, explanation: "Average storage guidance for tomatoes"),
        FallbackRule(productTerms: ["strawberry", "strawberries", "blueberry", "blueberries", "raspberry", "raspberries", "blackberry", "blackberries", "berries"], pantryDays: nil, fridgeDays: 4, freezerDays: 180, explanation: "Average refrigerated storage guidance for berries"),
        FallbackRule(productTerms: ["grape", "grapes"], pantryDays: 1, fridgeDays: 7, freezerDays: 30, explanation: "Average storage guidance for grapes"),
        FallbackRule(productTerms: ["orange", "oranges", "lemon", "lemons", "lime", "limes", "grapefruit", "citrus"], pantryDays: 10, fridgeDays: 10, freezerDays: nil, explanation: "Average storage guidance for citrus fruit"),
        FallbackRule(productTerms: ["watermelon", "cantaloupe", "honeydew", "melon", "melons"], pantryDays: 3, fridgeDays: 3, freezerDays: 30, explanation: "Average ripening/storage guidance for melons"),
        FallbackRule(productTerms: ["pineapple", "pineapples"], pantryDays: 4, fridgeDays: 6, freezerDays: 300, explanation: "Average ripening/storage guidance for pineapple"),
        FallbackRule(productTerms: ["cherry", "cherries"], pantryDays: nil, fridgeDays: 4, freezerDays: 180, explanation: "Average refrigerated storage guidance for cherries"),
        FallbackRule(productTerms: ["cucumber", "cucumbers"], pantryDays: nil, fridgeDays: 4, freezerDays: nil, explanation: "Average refrigerated storage guidance for cucumbers"),
        FallbackRule(productTerms: ["carrot", "carrots"], pantryDays: nil, fridgeDays: 21, freezerDays: 240, explanation: "Average refrigerated storage guidance for carrots"),
        FallbackRule(productTerms: ["broccoli"], pantryDays: nil, fridgeDays: 4, freezerDays: 240, explanation: "Average refrigerated storage guidance for broccoli"),
        FallbackRule(productTerms: ["lettuce", "spinach", "kale"], pantryDays: nil, fridgeDays: 5, freezerDays: nil, explanation: "Average refrigerated storage guidance for leafy greens"),
        FallbackRule(productTerms: ["potato", "potatoes"], pantryDays: 30, fridgeDays: nil, freezerDays: nil, explanation: "Average cool, dark pantry storage guidance for potatoes"),
        FallbackRule(productTerms: ["bread", "loaf"], pantryDays: 5, fridgeDays: 7, freezerDays: 90, explanation: "Typical storage guidance for bread"),
        FallbackRule(productTerms: ["ground beef", "ground turkey", "ground chicken", "ground pork", "ground meat"], pantryDays: nil, fridgeDays: 1, freezerDays: 90, explanation: "Conservative storage guidance for ground meat"),
        FallbackRule(productTerms: ["chicken", "turkey", "poultry"], pantryDays: nil, fridgeDays: 1, freezerDays: 180, explanation: "Conservative storage guidance for raw poultry"),
        FallbackRule(productTerms: ["beef", "pork", "lamb", "steak", "pork chops", "lamb chops"], pantryDays: nil, fridgeDays: 3, freezerDays: 180, explanation: "Conservative storage guidance for raw meat"),
        FallbackRule(productTerms: ["salmon", "fish", "shrimp", "seafood", "cod", "tilapia"], pantryDays: nil, fridgeDays: 1, freezerDays: 90, explanation: "Conservative storage guidance for seafood"),
        FallbackRule(productTerms: ["eggs", "egg"], pantryDays: nil, fridgeDays: 21, freezerDays: nil, explanation: "Average refrigerated storage guidance for shell eggs"),
        FallbackRule(productTerms: ["yogurt", "yoghurt"], pantryDays: nil, fridgeDays: 10, freezerDays: 45, explanation: "Average refrigerated storage guidance for yogurt"),
        FallbackRule(productTerms: ["hard cheese", "cheddar", "swiss", "parmesan"], pantryDays: nil, fridgeDays: 21, freezerDays: 180, explanation: "Average storage guidance for hard cheese"),
        FallbackRule(productTerms: ["soft cheese", "cottage cheese", "ricotta", "brie"], pantryDays: nil, fridgeDays: 7, freezerDays: nil, explanation: "Average storage guidance for soft cheese"),
        FallbackRule(productTerms: ["leftovers", "cooked rice", "cooked pasta", "cooked meat"], pantryDays: nil, fridgeDays: 3, freezerDays: 60, explanation: "Conservative storage guidance for cooked leftovers")
    ]

    /// True when FoodKeeper has a numeric duration for the selected storage method.
    /// Numeric ranges are accepted; for Min fields the first/lower value is used.
    static func hasUsableShelfLife(for entry: FoodKeeperEntry, storage: StorageLocation) -> Bool {
        if numericShelfLifeDays(in: entry, storage: storage) != nil { return true }
        return textualDurationDays(in: entry, storage: storage) != nil
    }

    /// Date based on numeric FoodKeeper data when available, otherwise a known
    /// product/storage fallback, and finally a clearly-labelled 3-day generic reminder.
    static func estimate(
        for entry: FoodKeeperEntry,
        storage: StorageLocation,
        from start: Date = .now
    ) -> Date {
        let days = numericShelfLifeDays(in: entry, storage: storage)
            ?? textualDurationDays(in: entry, storage: storage)
            ?? fallbackDays(for: entry.name, storage: storage)
            ?? genericFallbackDays
        return date(after: days, from: start)
    }

    /// Allows the UI to produce an estimate even when the USDA lookup has no exact
    /// match or the dataset cannot be reached. Unknown products receive a 7-day
    /// placeholder, explicitly identified as generic rather than USDA guidance.
    static func estimate(
        for productName: String,
        storage: StorageLocation,
        from start: Date = .now
    ) -> Date {
        date(after: fallbackDays(for: productName, storage: storage) ?? genericFallbackDays, from: start)
    }

    static func fallbackMessage(for entry: FoodKeeperEntry, storage: StorageLocation) -> String {
        fallbackMessage(for: entry.name, storage: storage, entry: entry)
    }

    static func fallbackMessage(for productName: String, storage: StorageLocation) -> String {
        fallbackMessage(for: productName, storage: storage, entry: nil)
    }

    /// Exposed internally for deterministic tests and the UI's fallback decision.
    static func fallbackDays(for productName: String, storage: StorageLocation) -> Int? {
        let normalized = normalize(productName)
        guard !normalized.isEmpty else { return nil }

        // Prefer the most specific matching product term (e.g. almond milk before milk).
        let matchingRules = fallbackRules
            .flatMap { rule in rule.productTerms.map { (term: normalize($0), rule: rule) } }
            .filter { term in
                matchesProductTerm(term.term, in: productName)
            }
            .sorted { $0.term.count > $1.term.count }

        return matchingRules.first?.rule.days(for: storage)
    }

    private static func fallbackMessage(for productName: String, storage: StorageLocation, entry: FoodKeeperEntry?) -> String {
        if let days = fallbackDays(for: productName, storage: storage),
           let rule = matchingRule(for: productName) {
            let guidance = entry.map { selectedGuidance(in: $0, storage: storage) } ?? nil
            if guidance?.localizedCaseInsensitiveContains("until ripe") == true {
                return "FoodKeeper says to store this item until ripe but gives no number of days. UseBy uses an approximate average of \(days) days based on published produce-storage guidance."
            }
            return "A numeric FoodKeeper duration was unavailable for this storage method. UseBy uses an approximate \(days)-day estimate based on \(rule.explanation.lowercased())."
        }

        return "No product-specific shelf-life guidance was available. UseBy is using a conservative generic 3-day reminder, which may not suit this product. Check the package and the food's condition."
    }

    private static func matchingRule(for productName: String) -> FallbackRule? {
        return fallbackRules
            .flatMap { rule in rule.productTerms.map { (term: normalize($0), rule: rule) } }
            .filter { matchesProductTerm($0.term, in: productName) }
            .sorted { $0.term.count > $1.term.count }
            .first?.rule
    }

    private static func numericShelfLifeDays(in entry: FoodKeeperEntry, storage: StorageLocation) -> Int? {
        let location = fieldPrefix(for: storage)
        for prefix in [location, "DOP_" + location] {
            guard let amountText = entry.rawFields[prefix + "_Min"],
                  let amount = firstNumber(in: amountText), amount > 0,
                  let metric = entry.rawFields[prefix + "_Metric"]?.lowercased() else { continue }
            if let days = convertToDays(amount, metric: metric) { return days }
        }
        return nil
    }

    /// Handles guidance values such as "3-5 days" or "1 to 2 weeks".
    /// Uses the floored midpoint of a range; a single number is floored as-is.
    private static func textualDurationDays(in entry: FoodKeeperEntry, storage: StorageLocation) -> Int? {
        guard let text = selectedGuidance(in: entry, storage: storage) else { return nil }
        let lower = text.lowercased()
        guard !lower.contains("until ripe"), !lower.contains("package"), !lower.contains("use-by date"), !lower.contains("use by date") else { return nil }

        let pattern = #"(\d+(?:\.\d+)?)\s*(?:-|–|to)\s*(\d+(?:\.\d+)?)\s*(days?|weeks?|months?|years?)|(?<![\d.])(\d+(?:\.\d+)?)\s*(days?|weeks?|months?|years?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) else { return nil }

        func value(at index: Int) -> Double? {
            guard let range = Range(match.range(at: index), in: lower) else { return nil }
            return Double(lower[range])
        }
        func captureText(at index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: lower) else { return nil }
            return String(lower[range])
        }

        if let first = value(at: 1), let second = value(at: 2), let metric = captureText(at: 3) {
            return convertRangeToDays(first, second, metric: metric)
        }
        if let amount = value(at: 4), let metric = captureText(at: 5) {
            return convertToDays(floor(amount), metric: metric)
        }
        return nil
    }

    private static func selectedGuidance(in entry: FoodKeeperEntry, storage: StorageLocation) -> String? {
        switch storage {
        case .pantry: return entry.pantry ?? entry.rawFields["Pantry"]
        case .fridge: return entry.refrigerator ?? entry.rawFields["Refrigerate"]
        case .freezer: return entry.freezer ?? entry.rawFields["Freeze"]
        }
    }

    private static func firstNumber(in value: String) -> Double? {
        let pattern = #"\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range, in: value) else { return nil }
        return Double(value[range])
    }

    private static func convertToDays(_ amount: Double, metric: String) -> Int? {
        convertRangeToDays(amount, amount, metric: metric)
    }

    private static func convertRangeToDays(_ first: Double, _ second: Double, metric: String) -> Int? {
        let normalizedMetric = metric.lowercased()
        let multiplier: Double
        switch normalizedMetric {
        case "day", "days": multiplier = 1
        case "week", "weeks": multiplier = 7
        case "month", "months": multiplier = 30
        case "year", "years": multiplier = 365
        default: return nil
        }
        let averageDays = ((first + second) / 2) * multiplier
        guard averageDays > 0 else { return nil }
        // Always round down so the reminder is not shifted later by rounding.
        return Int(floor(averageDays))
    }

    private static func date(after days: Int, from start: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: max(1, days), to: start) ?? start
    }

    private static func matchesProductTerm(_ term: String, in productName: String) -> Bool {
        let normalizedTerm = normalize(term)
        let normalizedProduct = normalize(productName)
        guard !normalizedTerm.isEmpty else { return false }
        if normalizedProduct == normalizedTerm || normalizedProduct.hasSuffix(normalizedTerm) ||
            normalizedProduct.hasSuffix(normalizedTerm + "s") || normalizedProduct.hasSuffix(normalizedTerm + "es") {
            return true
        }

        // Match whole words and adjacent multi-word terms. This accepts "Milk, whole"
        // and "Unsweetened almond milk" without treating "applesauce" as an apple.
        let productTokens = tokens(in: productName)
        let termTokens = tokens(in: term)
        guard !termTokens.isEmpty, productTokens.count >= termTokens.count else { return false }
        for start in 0...(productTokens.count - termTokens.count) {
            let candidate = Array(productTokens[start..<(start + termTokens.count)])
            let sameTokens = zip(candidate, termTokens).enumerated().allSatisfy { index, pair in
                let (productToken, termToken) = pair
                if index == termTokens.count - 1 {
                    return productToken == termToken || productToken == termToken + "s" || productToken == termToken + "es"
                }
                return productToken == termToken
            }
            if sameTokens { return true }
        }
        return false
    }

    private static func tokens(in value: String) -> [String] {
        value.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { normalize(String($0)) }
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func fieldPrefix(for storage: StorageLocation) -> String {
        switch storage {
        case .fridge: return "Refrigerate"
        case .freezer: return "Freeze"
        case .pantry: return "Pantry"
        }
    }
}
