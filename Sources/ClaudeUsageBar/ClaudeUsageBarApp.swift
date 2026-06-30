import AppKit
import SwiftUI

@main
enum Main {
    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            exit(SelfTest.run())
        }
        if CommandLine.arguments.contains("--once") {
            runOnce()
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    /// One-shot diagnostic: read the Keychain token, fetch usage, print it, exit.
    /// Exercises the same code paths the menu-bar app uses, without the GUI.
    ///   swift run ClaudeUsageBar --once
    private static func runOnce() {
        let done = DispatchSemaphore(value: 0)
        Task {
            defer { done.signal() }
            do {
                let creds = try KeychainReader.read()
                let settings = ClaudeConfig.read()
                let client = UsageClient()
                print("plan:     \(UsageFormat.planName(creds.subscriptionType) ?? "?")")
                print("model:    \(UsageFormat.modelName(settings.model) ?? "?")")
                print("effort:   \(UsageFormat.effortName(settings.effortLevel) ?? "?")")
                if let profile = try? await client.fetchProfile(token: creds.accessToken) {
                    print("org:      \(profile.organization?.name ?? "?")")
                    print("email:    \(profile.account?.email ?? "?")")
                }
                let response = try await client.fetch(token: creds.accessToken)
                let s = response.fiveHour
                let w = response.sevenDay
                print("session:  \(UsageFormat.percentText(s?.utilization))  resets \(UsageFormat.resetDescription(s?.resetsAt) ?? "?")")
                print("weekly:   \(UsageFormat.percentText(w?.utilization))  resets \(UsageFormat.resetDescription(w?.resetsAt) ?? "?")")
                if let opus = response.sevenDayOpus?.utilization {
                    print("opus:     \(UsageFormat.percentText(opus))")
                }
            } catch {
                print("ERROR: \(error)")
            }
        }
        done.wait()
        exit(0)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar only: no Dock icon, no app menu.
        NSApp.setActivationPolicy(.accessory)
        statusController = StatusController()
    }
}

/// Owns the NSStatusItem and its popover. AppKit's status button lets us render
/// a two-line attributed title (which SwiftUI's MenuBarExtra label cannot fit).
@MainActor
final class StatusController {
    private let store = UsageStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init() {
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            // Allow the attributed newline to actually wrap to a second line.
            button.lineBreakMode = .byWordWrapping
        }

        popover.behavior = .transient
        let hosting = NSHostingController(rootView: UsagePopover(store: store))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting

        render()
        observe()
    }

    /// Re-render the title whenever the tracked store values change, then re-arm
    /// (Observation fires onChange once per tracking scope).
    private func observe() {
        withObservationTracking {
            _ = store.phase
            _ = store.session?.utilization
            _ = store.weekly?.utilization
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.render()
                self?.observe()
            }
        }
    }

    private func render() {
        guard let button = statusItem.button else { return }
        // Render the two lines to an image: the status bar centers an image
        // vertically (unlike a text title, which sits high), so this keeps the
        // label centered on both notched and external displays.
        button.image = MenuBarTitle.image(MenuBarTitle.make(store))
        button.imagePosition = .imageOnly
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            Task { await store.refresh() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

/// Builds and renders the two-line menu-bar label:
///   S 47%
///   W 5%
enum MenuBarTitle {
    /// Tweak these to taste. The line height is the box per line; the two boxes
    /// must fit the menu bar height (~22pt), so keep ~11 or less.
    static let fontSize: CGFloat = 11
    static let weight: NSFont.Weight = .semibold
    static let lineHeight: CGFloat = 11
    /// Extra downward shift (points) applied on top of vertical centering.
    static let verticalNudge: CGFloat = 3.0

    static var font: NSFont { .monospacedDigitSystemFont(ofSize: fontSize, weight: weight) }

    @MainActor
    static func make(_ store: UsageStore) -> NSAttributedString {
        // Each line is "<label>\t<value>": labels (S/W) sit left-aligned at the
        // margin, values are pulled to a right-aligned tab stop so the percent
        // column lines up. needsReauth has no value column (no tab).
        let line1: String
        let line2: String
        let color: NSColor
        var twoColumn = true

        let hasData = store.session != nil || store.weekly != nil

        if case .needsReauth = store.phase {
            (line1, line2, color) = ("⚠︎", "認証", .systemOrange)
            twoColumn = false
        } else if hasData {
            // Show the latest known values even if the most recent refresh
            // errored (e.g. a transient 429) — better than blanking to "–".
            line1 = "S\t\(UsageFormat.percentText(store.session?.utilization))"
            line2 = "W\t\(UsageFormat.percentText(store.weekly?.utilization))"
            let peak = UsageFormat.peak(store.session?.utilization, store.weekly?.utilization)
            color = UsageFormat.nsColor(for: peak)
        } else if case .error = store.phase {
            (line1, line2, color) = ("S\t–", "W\t–", .secondaryLabelColor)
        } else {
            (line1, line2, color) = ("S\t⋯", "W\t", .secondaryLabelColor)
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineSpacing = 0
        paragraph.maximumLineHeight = lineHeight
        paragraph.minimumLineHeight = lineHeight
        if twoColumn {
            // Right-aligned column end, wide enough for the label + widest value.
            let labelWidth = ("W" as NSString).size(withAttributes: [.font: font]).width
            let valueWidth = ("100%" as NSString).size(withAttributes: [.font: font]).width
            let column = ceil(labelWidth + 1 + valueWidth)
            paragraph.tabStops = [NSTextTab(textAlignment: .right, location: column)]
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        return NSAttributedString(string: "\(line1)\n\(line2)", attributes: attributes)
    }

    /// Rasterizes the two-line title into a (non-template, so colored) image as
    /// tall as the menu bar. We center the *ink* (cap-height of the two lines),
    /// not the line boxes — line boxes carry empty descender space at the bottom
    /// which otherwise makes the text look top-heavy. Uses a flipped canvas
    /// (origin top-left) so the layout math reads top-down.
    static func image(_ attributed: NSAttributedString) -> NSImage {
        let width = ceil(attributed.size().width)
        let height = NSStatusBar.system.thickness
        let cap = font.capHeight
        let ascent = font.ascender

        // Ink block spans line1 cap-top down to line2 baseline: lineHeight + cap.
        // Center that block, then back out the box top from the cap top.
        let inkTop = (height - (lineHeight + cap)) / 2
        let y0 = inkTop - (ascent - cap) + verticalNudge

        let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            attributed.draw(in: NSRect(x: 0, y: y0, width: width, height: lineHeight * 2 + 6))
            return true
        }
        image.isTemplate = false
        return image
    }
}
