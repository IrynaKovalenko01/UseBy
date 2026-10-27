import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String?)
    case decodingFailed(String)
    case missingAPIKey(String)
    case noFoodKeeperData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL could not be created."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .httpStatus(status, message):
            return message.map { "API request failed (HTTP \(status)): \($0)" }
                ?? "API request failed with HTTP status \(status)."
        case let .decodingFailed(message):
            return "Could not read the API response: \(message)"
        case let .missingAPIKey(service):
            return "Missing \(service) API key. Configure it in your Xcode run scheme."
        case .noFoodKeeperData:
            return "No FoodKeeper data was found. Check the dataset URL or add the official JSON dataset to the app bundle."
        }
    }
}

/// Shared HTTP helper for the read-only API clients in this folder.
enum APIHTTP {
    static func get(
        url: URL,
        headers: [String: String] = [:],
        session: URLSession = .shared
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw APIError.httpStatus(httpResponse.statusCode, body)
        }
        return data
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    static func makeURL(base: String, path: String = "", query: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: base + path) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }
}
