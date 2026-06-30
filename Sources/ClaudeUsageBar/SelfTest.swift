import AppKit
import Foundation
import SwiftUI

/// Lightweight, dependency-free unit checks for the pure formatting/parsing
/// logic. Run with `swift run ClaudeUsageBar --selftest` (exits non-zero on
/// failure). XCTest/Swift Testing aren't usable with a Command Line Tools-only
/// install, so this keeps the lib layer test-covered and CI-able without them.
enum SelfTest {
    static func run() -> Int32 {
        var failures = 0
        func check(_ condition: Bool, _ label: String) {
            if condition {
                print("ok   - \(label)")
            } else {
                print("FAIL - \(label)")
                failures += 1
            }
        }

        // percentText
        check(UsageFormat.percentText(nil) == "–", "percentText(nil)")
        check(UsageFormat.percentText(0) == "0%", "percentText(0)")
        check(UsageFormat.percentText(47) == "47%", "percentText(47)")
        check(UsageFormat.percentText(46.4) == "46%", "percentText(46.4) rounds down")
        check(UsageFormat.percentText(46.6) == "47%", "percentText(46.6) rounds up")
        check(UsageFormat.percentText(100) == "100%", "percentText(100)")

        // severity thresholds
        check(UsageFormat.severity(for: nil) == .unknown, "severity(nil)")
        check(UsageFormat.severity(for: 69.9) == .normal, "severity 69.9 normal")
        check(UsageFormat.severity(for: 70) == .warning, "severity 70 warning")
        check(UsageFormat.severity(for: 89.9) == .warning, "severity 89.9 warning")
        check(UsageFormat.severity(for: 90) == .critical, "severity 90 critical")

        // peak
        check(UsageFormat.peak(nil, nil) == nil, "peak(nil,nil)")
        check(UsageFormat.peak(10, nil) == 10, "peak(10,nil)")
        check(UsageFormat.peak(nil, 20) == 20, "peak(nil,20)")
        check(UsageFormat.peak(30, 20) == 30, "peak(30,20)")

        // planName
        check(UsageFormat.planName(nil) == nil, "planName(nil)")
        check(UsageFormat.planName("") == nil, "planName(empty)")
        check(UsageFormat.planName("pro") == "Pro", "planName(pro)")
        check(UsageFormat.planName("max") == "Max", "planName(max)")
        check(UsageFormat.planName("max_5x") == "Max 5×", "planName(max_5x)")
        check(UsageFormat.planName("max_20x") == "Max 20×", "planName(max_20x)")
        check(UsageFormat.planName("team") == "Team", "planName(team)")
        check(UsageFormat.planName("custom") == "Custom", "planName(custom)")

        // modelName
        check(UsageFormat.modelName(nil) == nil, "modelName(nil)")
        check(UsageFormat.modelName("opus") == "Opus", "modelName(opus)")
        check(UsageFormat.modelName("sonnet") == "Sonnet", "modelName(sonnet)")
        check(UsageFormat.modelName("claude-opus-4-8") == "Opus 4.8", "modelName(claude-opus-4-8)")
        check(UsageFormat.modelName("claude-3-5-sonnet") == "Sonnet 3.5", "modelName(claude-3-5-sonnet)")
        check(UsageFormat.modelName("custommodel") == "Custommodel", "modelName(unknown)")

        // effortName
        check(UsageFormat.effortName(nil) == nil, "effortName(nil)")
        check(UsageFormat.effortName("high") == "High", "effortName(high)")
        check(UsageFormat.effortName("xhigh") == "xHigh", "effortName(xhigh)")
        check(UsageFormat.effortName("max") == "Max", "effortName(max)")

        // ISODate
        check(ISODate.parse(nil) == nil, "ISODate(nil)")
        check(ISODate.parse("not a date") == nil, "ISODate(garbage)")
        let micros = ISODate.parse("2026-06-30T05:19:59.797027+00:00")
        let plain = ISODate.parse("2026-06-30T05:19:59Z")
        check(micros != nil, "ISODate microseconds parses")
        check(plain != nil, "ISODate second precision parses")
        if let micros, let plain {
            check(abs(micros.timeIntervalSince1970 - plain.timeIntervalSince1970) < 1.0,
                  "ISODate microseconds ≈ plain")
        }

        // countdown
        check(UsageFormat.countdown(to: Date(timeIntervalSinceNow: -60)) == nil, "countdown(past)")
        check(UsageFormat.countdown(to: Date(timeIntervalSinceNow: 3600)) != nil, "countdown(future)")

        // color mapping (SwiftUI + AppKit) by severity
        check(UsageFormat.color(for: nil) == Color.secondary, "color(nil)")
        check(UsageFormat.color(for: 50) == Color.green, "color(50)=green")
        check(UsageFormat.color(for: 80) == Color.yellow, "color(80)=yellow")
        check(UsageFormat.color(for: 95) == Color.red, "color(95)=red")
        check(UsageFormat.nsColor(for: nil) == NSColor.secondaryLabelColor, "nsColor(nil)")
        check(UsageFormat.nsColor(for: 50) == NSColor.systemGreen, "nsColor(50)=green")
        check(UsageFormat.nsColor(for: 80) == NSColor.systemYellow, "nsColor(80)=yellow")
        check(UsageFormat.nsColor(for: 95) == NSColor.systemRed, "nsColor(95)=red")

        // reset/relative display
        check(UsageFormat.resetDescription(nil) == nil, "resetDescription(nil)")
        check(UsageFormat.resetDescription("2027-01-15T12:00:00Z") != nil, "resetDescription(future w/ countdown)")
        check(UsageFormat.resetDescription("2020-01-01T00:00:00Z") != nil, "resetDescription(past, no countdown)")
        check(UsageFormat.relative(from: nil) == nil, "relative(nil)")
        check(UsageFormat.relative(from: Date(timeIntervalSinceNow: -120)) != nil, "relative(past)")

        // reauthNotice: only within the next hour
        check(UsageFormat.reauthNotice(expiresAt: nil) == nil, "reauthNotice(nil)")
        check(UsageFormat.reauthNotice(expiresAt: Date(timeIntervalSinceNow: -60)) == nil, "reauthNotice(expired)")
        check(UsageFormat.reauthNotice(expiresAt: Date(timeIntervalSinceNow: 7200)) == nil, "reauthNotice(2h away)")
        check(UsageFormat.reauthNotice(expiresAt: Date(timeIntervalSinceNow: 1800)) != nil, "reauthNotice(30m away)")

        // JSON decoding — sample payloads matching the live endpoints, so a
        // schema change in a future CLI release is caught here.
        let usageJSON = Data("""
        {"five_hour":{"utilization":47.0,"resets_at":"2026-06-30T05:19:59.797027+00:00"},
         "seven_day":{"utilization":5,"resets_at":"2026-07-06T23:59:59+00:00"},
         "seven_day_opus":null,"seven_day_sonnet":null}
        """.utf8)
        if let usage = try? JSONDecoder().decode(UsageResponse.self, from: usageJSON) {
            check(usage.fiveHour?.utilization == 47, "decode usage five_hour")
            check(usage.sevenDay?.utilization == 5, "decode usage seven_day")
            check(usage.sevenDayOpus == nil, "decode usage seven_day_opus null")
            check(ISODate.parse(usage.fiveHour?.resetsAt) != nil, "decode usage resets_at parses")
        } else {
            check(false, "decode UsageResponse")
        }

        let profileJSON = Data("""
        {"account":{"email":"x@example.com","display_name":"Tak"},
         "organization":{"name":"Personal","subscription_status":"active"}}
        """.utf8)
        let profileDecoder = JSONDecoder()
        profileDecoder.keyDecodingStrategy = .convertFromSnakeCase
        if let profile = try? profileDecoder.decode(ProfileResponse.self, from: profileJSON) {
            check(profile.account?.email == "x@example.com", "decode profile email")
            check(profile.account?.displayName == "Tak", "decode profile display_name→displayName")
            check(profile.organization?.name == "Personal", "decode profile org name")
            check(profile.organization?.subscriptionStatus == "active", "decode profile subscription_status")
        } else {
            check(false, "decode ProfileResponse")
        }

        print(failures == 0 ? "\nAll self-tests passed." : "\n\(failures) self-test(s) FAILED.")
        return failures == 0 ? 0 : 1
    }
}
