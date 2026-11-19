import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A normalized view of a row from the USDA FSIS FoodKeeper dataset.
/// FoodKeeper is published as a downloadable dataset, not as a conventional
/// query API. The reader accepts the official JSON shape and preserves raw fields.
struct FoodKeeperEntry: Identifiable {
    let id: String
    let name: String
    let category: String?
    let pantry: String?
    let refrigerator: String?
    let freezer: String?
    let afterOpening: String?
    let tips: String?
    let rawFields: [String: String]
}

/// Read-only reader for USDA FSIS FoodKeeper data.
///
/// By default it first looks for `foodkeeper.json` in the app bundle, then
/// downloads the official English JSON dataset. Add the downloaded dataset to
/// the Xcode app target if you want lookups to work offline and avoid a network
/// request on first use.
actor USDAFoodKeeperAPI {
    static let shared = USDAFoodKeeperAPI()

    static let officialDatasetURL = URL(string: "https://www.fsis.usda.gov/shared/data/EN/foodkeeper.json")!
    
    private let datasetURL: URL
    private let bundle: Bundle
    private let session: URLSession
    private var cachedEntries: [FoodKeeperEntry]?
    
    init(
        datasetURL: URL = USDAFoodKeeperAPI.officialDatasetURL,
        bundle: Bundle = .main,
        session: URLSession = .shared
    ) {
        self.datasetURL = datasetURL
        self.bundle = bundle
        self.session = session
    }
    
    /// Loads and caches all available FoodKeeper rows.
    func loadEntries(forceRefresh: Bool = false) async throws -> [FoodKeeperEntry] {
        if !forceRefresh, let cachedEntries { return cachedEntries }
        
        let jsonData: Data
        if !forceRefresh, let localURL = bundle.url(forResource: "foodkeeper", withExtension: "json"),
           let localData = try? Data(contentsOf: localURL) {
            jsonData = localData
        } else {
            jsonData = try await APIHTTP.get(url: datasetURL, headers: [
                "User-Agent": "UseBy/1.0 (food pantry tracking app)"
            ], session: session)
        }
        
        let entries = try Self.parseEntries(from: jsonData)
        guard !entries.isEmpty else { throw APIError.noFoodKeeperData }
        cachedEntries = entries
        return entries
    }
    
    /// Case-insensitive search across product name and category.
    func search(query: String, limit: Int = 30) async throws -> [FoodKeeperEntry] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        let entries = try await loadEntries()
        return Array(entries.filter {
            $0.name.localizedCaseInsensitiveContains(term) ||
            ($0.category?.localizedCaseInsensitiveContains(term) ?? false)
        }.prefix(max(1, limit)))
    }
    
    /// Returns the best name match. This is deliberately not an expiration-date
    /// calculator: FoodKeeper gives storage guidance and ranges, not a guaranteed
    /// safety/expiration date for an individual package.
    func bestMatch(for productName: String) async throws -> FoodKeeperEntry? {
        let term = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return nil }
        let entries = try await loadEntries()
        let normalizedTerm = Self.normalize(term)
        let queryTokens = Self.tokens(in: term)

        // Prefer exact product names. The old first-contains match could select
        // an unrelated entry (for example, "buttermilk" for a query of "milk").
        if let exact = entries.first(where: { Self.normalize($0.name) == normalizedTerm }) {
            return exact
        }

        // Then accept simple singular/plural variations such as Avocado/Avocados.
        if let pluralMatch = entries.first(where: {
            let name = Self.normalize($0.name)
            return name == normalizedTerm + "s" || normalizedTerm == name + "s" ||
                   name == normalizedTerm + "es" || normalizedTerm == name + "es"
        }) {
            return pluralMatch
        }

        // Finally compare whole words, not arbitrary substrings. This avoids
        // matching "apple" to "applesauce" or "milk" to "buttermilk".
        return entries.first(where: { entry in
            let nameTokens = Self.tokens(in: entry.name)
            return queryTokens.contains { queryToken in
                nameTokens.contains { nameToken in
                    nameToken == queryToken || nameToken == queryToken + "s" || queryToken == nameToken + "s"
                }
            }
        })
    }
    
    private static func parseEntries(from data: Data) throws -> [FoodKeeperEntry] {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
        
        var dictionaries: [[String: Any]] = []
        collectDictionaries(in: root, into: &dictionaries)
        
        return dictionaries.compactMap { dictionary in
            let fields = dictionary.reduce(into: [String: String]()) { result, pair in
                if let value = stringValue(pair.value) {
                    result[pair.key] = value
                }
            }
            let name = firstValue(in: fields, matching: ["product", "productname", "food", "item", "name"])
            guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            
            return FoodKeeperEntry(
                id: firstValue(in: fields, matching: ["id", "productid"]) ?? name,
                name: name,
                category: firstValue(in: fields, matching: ["category", "foodcategory", "group"]),
                pantry: firstValue(in: fields, matching: ["pantry", "pantrystorage", "pantryunopened", "pantryafteropening"]),
                refrigerator: firstValue(in: fields, matching: ["refrigerator", "refrigerated", "refrigeratorunopened", "refrigeratorafteropening"]),
                freezer: firstValue(in: fields, matching: ["freezer", "frozen", "freezerunopened", "freezerafteropening"]),
                afterOpening: firstValue(in: fields, matching: ["afteropening", "openedstorage", "afteropened"]),
                tips: firstValue(in: fields, matching: ["tips", "storageadvice", "storageinstructions", "comments"]),
                rawFields: fields
            )
        }
    }
    
    private static func collectDictionaries(in value: Any, into result: inout [[String: Any]]) {
        if let dictionary = value as? [String: Any] {
            result.append(dictionary)
            for nestedValue in dictionary.values {
                collectDictionaries(in: nestedValue, into: &result)
            }
        } else if let array = value as? [Any] {
            var isOneFood = true
            if array.isEmpty {
                isOneFood = false
            }
            for element in array {
                if let piece = element as? [String: Any] {
                    if piece.count != 1 {
                        isOneFood = false
                    }
                } else {
                    isOneFood = false
                }
            }
            
            if isOneFood {
                var merged: [String: Any] = [:]
                for element in array {
                    if let piece = element as? [String: Any] {
                        for (key, value) in piece {
                            merged[key] = value
                        }
                    }
                }
                result.append(merged)
                return
            }
            
            for nestedValue in array {
                collectDictionaries(in: nestedValue, into: &result)
            }
        }
    }
    
    private static func stringValue(_ value: Any) -> String? {
        if value is NSNull { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if let array = value as? [Any] {
            let strings = array.compactMap(stringValue)
            return strings.isEmpty ? nil : strings.joined(separator: ", ")
        }
        return nil
    }
    
    private static func firstValue(in fields: [String: String], matching candidates: [String]) -> String? {
        let normalizedFields = Dictionary(fields.map { (normalize($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
        for candidate in candidates {
            if let value = normalizedFields[candidate], !value.isEmpty { return value }
        }
        // Do not use broad substring matching here. A request for the Pantry
        // guidance field must not accidentally return Pantry_Min or Pantry_Metric;
        // those numeric fields are handled separately by ExpiryEstimation.
        return nil
    }
    
    private static func normalize(_ string: String) -> String {
        string.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func tokens(in string: String) -> [String] {
        string.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { normalize(String($0)) }
            .filter { !$0.isEmpty }
    }
}
