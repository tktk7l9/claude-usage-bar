import Foundation

enum UsageError: Error {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)
    case network(Error)
}

/// Isolates everything specific to the private OAuth endpoints (URLs, headers,
/// status handling). If a future CLI release changes the contract, this file
/// plus Models.swift are the only places to touch.
struct UsageClient {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let profileURL = URL(string: "https://api.anthropic.com/api/oauth/profile")!

    func fetch(token: String) async throws -> UsageResponse {
        let data = try await get(Self.usageURL, token: token)
        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }

    func fetchProfile(token: String) async throws -> ProfileResponse {
        let data = try await get(Self.profileURL, token: token)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ProfileResponse.self, from: data)
    }

    private func get(_ url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
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
            return data
        case 401, 403:
            throw UsageError.unauthorized
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            throw UsageError.rateLimited(retryAfter: retryAfter)
        default:
            throw UsageError.http(http.statusCode)
        }
    }
}
