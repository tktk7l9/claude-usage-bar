import AppKit
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

    /// Friendly model name from a Claude Code model id/alias, e.g.
    /// "opus" → "Opus", "claude-opus-4-8" → "Opus 4.8".
    static func modelName(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        let family: String?
        if lower.contains("opus") { family = "Opus" }
        else if lower.contains("sonnet") { family = "Sonnet" }
        else if lower.contains("haiku") { family = "Haiku" }
        else if lower.contains("fable") { family = "Fable" }
        else { family = nil }

        guard let family else {
            return raw.prefix(1).uppercased() + raw.dropFirst()
        }
        if let range = lower.range(of: #"\d+[-.]\d+"#, options: .regularExpression) {
            let version = lower[range].replacingOccurrences(of: "-", with: ".")
            return "\(family) \(version)"
        }
        return family
    }

    /// Friendly effort level, e.g. "xhigh" → "xHigh".
    static func effortName(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        switch raw.lowercased() {
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "xhigh": return "xHigh"
        case "max": return "Max"
        default: return raw.prefix(1).uppercased() + raw.dropFirst()
        }
    }

    /// Friendly plan name from the Keychain `subscriptionType`, e.g.
    /// "pro" → "Pro", "max_20x" → "Max 20×".
    static func planName(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        if lower.contains("max") {
            if lower.contains("20") { return "Max 20×" }
            if lower.contains("5") { return "Max 5×" }
            return "Max"
        }
        if lower.hasPrefix("pro") { return "Pro" }
        if lower.hasPrefix("free") { return "Free" }
        if lower.hasPrefix("team") { return "Team" }
        if lower.hasPrefix("enterprise") { return "Enterprise" }
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    /// AppKit variant of `color(for:)` for the NSStatusItem title.
    static func nsColor(for value: Double?) -> NSColor {
        guard let value else { return .secondaryLabelColor }
        switch value {
        case ..<70: return .systemGreen
        case ..<90: return .systemYellow
        default: return .systemRed
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

    /// Reset description with minute precision, e.g.
    /// "14:19（あと3時間21分）" or "7/6(火) 23:59（あと6日10時間）".
    static func resetDescription(_ isoString: String?) -> String? {
        guard let date = ISODate.parse(isoString) else { return nil }
        let absolute = absoluteTime(date)
        if let cd = countdown(to: date) {
            return "\(absolute)（あと\(cd)）"
        }
        return absolute
    }

    /// Wall-clock reset time to the minute, contextualized by day:
    /// today → "14:19", tomorrow → "明日 14:19", else → "7/6(火) 23:59".
    static func absoluteTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'明日' HH:mm"
        } else {
            formatter.dateFormat = "M/d'('E')' HH:mm"
        }
        return formatter.string(from: date)
    }

    /// Minute-precision countdown to a future date, e.g. "3時間21分" /
    /// "6日10時間". Returns nil if the date is in the past.
    static func countdown(to date: Date) -> String? {
        let now = Date()
        guard date > now else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.calendar = Calendar.current
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        return formatter.string(from: now, to: date)
    }

    /// "5分前" / "2時間後" relative text from a Date (used for "last updated").
    static func relative(from date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
