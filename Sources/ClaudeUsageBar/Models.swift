import Foundation

/// Response from `GET https://api.anthropic.com/api/oauth/usage` — the private
/// OAuth endpoint Claude Code's `/usage` command uses. Schema confirmed live on
/// 2026-06-30 against CLI 2.1.196. All fields are optional so a schema change in
/// a future CLI release degrades gracefully instead of crashing the decode.
struct UsageResponse: Decodable {
    /// `utilization` is a percentage on a 0–100 scale (e.g. 47.0).
    /// `resetsAt` is ISO8601 with microseconds + offset, e.g. "2026-06-30T05:19:59.797027+00:00".
    struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let sevenDayOpus: Window?
    let sevenDaySonnet: Window?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
    }
}

/// Response from `GET https://api.anthropic.com/api/oauth/profile` — account
/// and organization metadata. Decoded with `.convertFromSnakeCase`; all fields
/// optional so a schema change degrades gracefully.
struct ProfileResponse: Decodable {
    struct Account: Decodable {
        let email: String?
        let displayName: String?
    }
    struct Organization: Decodable {
        let name: String?
        let subscriptionStatus: String?
    }
    let account: Account?
    let organization: Organization?
}

/// Lenient ISO8601 parser. The endpoint returns microsecond precision which
/// `ISO8601DateFormatter` with `.withFractionalSeconds` does not always accept,
/// so fall back to stripping the fractional part.
enum ISODate {
    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }

        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let stripped = string.replacingOccurrences(
            of: #"\.\d+"#, with: "", options: .regularExpression
        )
        return plain.date(from: stripped)
    }
}
