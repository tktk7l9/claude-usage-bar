import Foundation

enum UsageError: Error {
    case unauthorized
    case http(Int)
    case network(Error)
}

/// Isolates everything specific to the private OAuth endpoint (URL, headers,
/// status handling). If a future CLI release changes the contract, this file
/// plus Models.swift are the only places to touch.
struct UsageClient {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    func fetch(token: String) async throws -> UsageResponse {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("claude-usage-bar/0.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UsageError.http(-1)
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        case 401, 403:
            throw UsageError.unauthorized
        default:
            throw UsageError.http(http.statusCode)
        }
    }
}
