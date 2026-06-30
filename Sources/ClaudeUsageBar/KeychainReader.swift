import Foundation
import Security

enum KeychainError: Error {
    case notFound
    case badData
}

enum KeychainReader {
    static let service = "Claude Code-credentials"

    /// What we extract from the Keychain credentials blob.
    struct Credentials {
        let accessToken: String
        /// e.g. "pro" / "max" — the plan tied to the logged-in account.
        let subscriptionType: String?
    }

    /// The credentials blob Claude Code stores in the macOS Keychain under the
    /// generic-password service "Claude Code-credentials". Shape confirmed
    /// 2026-06-30: { claudeAiOauth: { accessToken, refreshToken, expiresAt,
    /// scopes, subscriptionType, rateLimitTier } }.
    private struct Blob: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
            let subscriptionType: String?
        }
        let claudeAiOauth: OAuth
    }

    /// Reads the current OAuth credentials from the Keychain. Claude Code
    /// refreshes this item during normal use, so reading it fresh on every poll
    /// gives us the latest valid token without implementing OAuth refresh here.
    ///
    /// The first read (and any read after the app is re-signed) triggers the
    /// macOS Keychain access dialog — choose "Always Allow".
    static func read() throws -> Credentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.notFound
        }

        guard let blob = try? JSONDecoder().decode(Blob.self, from: data) else {
            throw KeychainError.badData
        }
        return Credentials(
            accessToken: blob.claudeAiOauth.accessToken,
            subscriptionType: blob.claudeAiOauth.subscriptionType
        )
    }

    /// Convenience for callers that only need the token.
    static func readToken() throws -> String {
        try read().accessToken
    }
}
