import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct SpoonacularRecipeSearchResponse: Decodable {
    let results: [SpoonacularRecipe]?
    let offset: Int?
    let number: Int?
    let totalResults: Int?
}

struct SpoonacularRecipe: Decodable, Identifiable {
    let id: Int
    let title: String
    let image: URL?
    let usedIngredientCount: Int?
    let missedIngredientCount: Int?
    let usedIngredients: [SpoonacularIngredient]?
    let missedIngredients: [SpoonacularIngredient]?
    let readyInMinutes: Int?
    let servings: Int?
    let summary: String?
    let instructions: String?
    let sourceUrl: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, image, summary, instructions, servings
        case usedIngredientCount, missedIngredientCount, usedIngredients, missedIngredients
        case readyInMinutes, sourceUrl
    }
}

struct SpoonacularIngredient: Decodable, Identifiable {
    let id: Int?
    let name: String
    let amount: Double?
    let unit: String?
    let original: String?
    let image: String?
}

struct SpoonacularProductSearchResponse: Decodable {
    let products: [SpoonacularProduct]?
    let totalProducts: Int?
    let type: String?
}

struct SpoonacularProduct: Decodable, Identifiable {
    let id: Int
    let title: String?
    let image: URL?
    let upc: String?
    let breadcrumbs: [String]?
    let generatedText: String?
}

struct SpoonacularRecipeInformation: Decodable, Identifiable {
    let id: Int
    let title: String
    let image: URL?
    let readyInMinutes: Int?
    let servings: Int?
    let sourceUrl: URL?
    let summary: String?
    let instructions: String?
    let extendedIngredients: [SpoonacularIngredient]?
}

/// Alex's key: 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
struct SpoonacularAPI {
    private let baseURL = "https://api.spoonacular.com"
    private let apiKey = "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"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Finds recipes using pantry ingredients, prioritizing those that use more
    /// of the ingredients you already have when ranking is 1.
    func recipesByIngredients(
        _ ingredients: [String],
        number: Int = 10,
        ranking: Int = 1,
        ignorePantry: Bool = true
    ) async throws -> [SpoonacularRecipe] {
        let cleaned = ingredients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return [] }
        let url = try makeURL(path: "/recipes/findByIngredients", query: [
            URLQueryItem(name: "ingredients", value: cleaned.joined(separator: ",")),
            URLQueryItem(name: "number", value: String(max(1, min(number, 100)))),
            URLQueryItem(name: "ranking", value: ranking == 2 ? "2" : "1"),
            URLQueryItem(name: "ignorePantry", value: String(ignorePantry))
        ])
        let data = try await APIHTTP.get(url: url, headers: ["x-api-key": try requireAPIKey()], session: session)
        return try APIHTTP.decode([SpoonacularRecipe].self, from: data)
    }

    /// Searches recipes by a free-text query and optionally includes nutrition.
    func searchRecipes(query: String, number: Int = 10, includeNutrition: Bool = false) async throws -> SpoonacularRecipeSearchResponse {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return SpoonacularRecipeSearchResponse(results: [], offset: 0, number: 0, totalResults: 0) }
        let url = try makeURL(path: "/recipes/complexSearch", query: [
            URLQueryItem(name: "query", value: term),
            URLQueryItem(name: "number", value: String(max(1, min(number, 100)))),
            URLQueryItem(name: "addRecipeInformation", value: "true"),
            URLQueryItem(name: "addRecipeNutrition", value: String(includeNutrition))
        ])
        let data = try await APIHTTP.get(url: url, headers: ["x-api-key": try requireAPIKey()], session: session)
        return try APIHTTP.decode(SpoonacularRecipeSearchResponse.self, from: data)
    }

    /// Gets details, instructions, and ingredient information for a recipe ID.
    func recipeInformation(id: Int) async throws -> SpoonacularRecipeInformation {
        let url = try makeURL(path: "/recipes/\(id)/information", query: [
            URLQueryItem(name: "includeNutrition", value: "false")
        ])
        let data = try await APIHTTP.get(url: url, headers: ["x-api-key": try requireAPIKey()], session: session)
        return try APIHTTP.decode(SpoonacularRecipeInformation.self, from: data)
    }

    /// Searches grocery products by text.
    func searchProducts(query: String, number: Int = 10) async throws -> [SpoonacularProduct] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        let url = try makeURL(path: "/food/products/search", query: [
            URLQueryItem(name: "query", value: term),
            URLQueryItem(name: "number", value: String(max(1, min(number, 100))))
        ])
        let data = try await APIHTTP.get(url: url, headers: ["x-api-key": try requireAPIKey()], session: session)
        return try APIHTTP.decode(SpoonacularProductSearchResponse.self, from: data).products ?? []
    }

    /// Looks up a grocery product by UPC barcode.
    func productByUPC(_ upc: String) async throws -> SpoonacularProduct {
        let code = upc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { throw APIError.invalidURL }
        let url = try makeURL(path: "/food/products/upc/\(code)")
        let data = try await APIHTTP.get(url: url, headers: ["x-api-key": try requireAPIKey()], session: session)
        return try APIHTTP.decode(SpoonacularProduct.self, from: data)
    }

    private func makeURL(path: String, query: [URLQueryItem] = []) throws -> URL {
        try APIHTTP.makeURL(base: baseURL, path: path, query: query)
    }

    private func requireAPIKey() throws -> String {
        guard !apiKey.isEmpty else { throw APIError.missingAPIKey("Spoonacular") }
        return apiKey
    }
}
