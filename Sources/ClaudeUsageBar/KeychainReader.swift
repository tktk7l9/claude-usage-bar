import Foundation
import Security

enum KeychainError: Error {
    case notFound
    case badData
}

/// The credentials blob Claude Code stores in the macOS Keychain under the
/// generic-password service "Claude Code-credentials". Shape confirmed
/// 2026-06-30: { claudeAiOauth: { accessToken, refreshToken, expiresAt, ... } }.
private struct ClaudeCredentials: Decodable {
    struct OAuth: Decodable {
        let accessToken: String
        /// Epoch milliseconds.
        let expiresAt: Double?
    }
    let claudeAiOauth: OAuth
}

enum KeychainReader {
    static let service = "Claude Code-credentials"

    /// Reads the current OAuth access token from the Keychain. Claude Code
    /// refreshes this item during normal use, so reading it fresh on every poll
    /// gives us the latest valid token without implementing OAuth refresh here.
    ///
    /// The first read (and any read after the app is re-signed) triggers the
    /// macOS Keychain access dialog — choose "Always Allow".
    static func readToken() throws -> String {
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

        guard let creds = try? JSONDecoder().decode(ClaudeCredentials.self, from: data) else {
            throw KeychainError.badData
        }
        return creds.claudeAiOauth.accessToken
    }
}
