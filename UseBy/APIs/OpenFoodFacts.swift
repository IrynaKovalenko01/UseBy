import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Public models

struct OFFProductResponse: Decodable {
    let status: Int?
    let statusVerbose: String?
    let product: OFFProduct?

    enum CodingKeys: String, CodingKey {
        case status
        case statusVerbose = "status_verbose"
        case product
    }
}

struct OFFProduct: Decodable, Identifiable {
    var id: String { code ?? productName ?? UUID().uuidString }

    let code: String?
    let productName: String?
    let brands: String?
    let categories: String?
    let categoriesTags: [String]?
    let ingredientsText: String?
    let imageURL: URL?
    let quantity: String?
    let nutriScoreGrade: String?

    enum CodingKeys: String, CodingKey {
        case code, brands, categories, quantity
        case productName = "product_name"
        case categoriesTags = "categories_tags"
        case ingredientsText = "ingredients_text"
        case imageURL = "image_url"
        case nutriScoreGrade = "nutriscore_grade"
    }
}

struct OFFSearchResponse: Decodable {
    let count: Int?
    let page: Int?
    let products: [OFFProduct]?
}

/// Read-only access to the Open Food Facts v2 API. No API key is required.
struct OpenFoodFactsAPI {
    private let baseURL = "https://world.openfoodfacts.org"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Retrieves one product using its barcode (EAN/UPC).
    func product(barcode: String) async throws -> OFFProduct? {
        let safeBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeBarcode.isEmpty else { return nil }
        let url = try APIHTTP.makeURL(
            base: baseURL,
            path: "/api/v2/product/\(safeBarcode).json",
            query: [URLQueryItem(name: "fields", value: "code,product_name,brands,categories,categories_tags,ingredients_text,image_url,quantity,nutriscore_grade")]
        )
        let data = try await APIHTTP.get(url: url, headers: [
            "User-Agent": "UseBy/1.0 (food pantry tracking app)"
        ], session: session)
        let result = try APIHTTP.decode(OFFProductResponse.self, from: data)
        return result.status == 1 ? result.product : nil
    }

    /// Searches products by name. Open Food Facts asks clients to keep searches reasonable.
    func searchProducts(query: String, pageSize: Int = 10, page: Int = 1) async throws -> [OFFProduct] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        let url = try APIHTTP.makeURL(
            base: baseURL,
            path: "/cgi/search.pl",
            query: [
                URLQueryItem(name: "search_terms", value: term),
                URLQueryItem(name: "search_simple", value: "1"),
                URLQueryItem(name: "action", value: "process"),
                URLQueryItem(name: "json", value: "1"),
                URLQueryItem(name: "page_size", value: String(max(1, min(pageSize, 50)))),
                URLQueryItem(name: "page", value: String(max(1, page))),
                URLQueryItem(name: "fields", value: "code,product_name,brands,categories,categories_tags,ingredients_text,image_url,quantity,nutriscore_grade")
            ]
        )
        let data = try await APIHTTP.get(url: url, headers: [
            "User-Agent": "UseBy/1.0 (food pantry tracking app)"
        ], session: session)
        return try APIHTTP.decode(OFFSearchResponse.self, from: data).products ?? []
    }
}
