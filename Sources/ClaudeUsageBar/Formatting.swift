import SwiftUI

/// Shared helpers for turning usage numbers into display strings/colors.
enum UsageFormat {
    /// "47%" / "–" for a 0–100 utilization value.
    static func percentText(_ value: Double?) -> String {
        guard let value else { return "–" }
        return "\(Int(value.rounded()))%"
    }

    /// Severity color by utilization: green < 70 ≤ yellow < 90 ≤ red.
    static func color(for value: Double?) -> Color {
        guard let value else { return .secondary }
        switch value {
        case ..<70: return .green
        case ..<90: return .yellow
        default: return .red
        }
    }

    /// The higher of two utilizations (drives the menu-bar label color).
    static func peak(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (x?, y?): return max(x, y)
        case let (x?, nil): return x
        case let (nil, y?): return y
        default: return nil
        }
    }

    /// "約2時間後" style relative reset text from an ISO8601 string.
    static func relativeReset(_ isoString: String?) -> String? {
        relative(from: ISODate.parse(isoString))
    }

    /// "5分前" / "2時間後" relative text from a Date.
    static func relative(from date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
