import SwiftUI

@main
enum Main {
    static func main() {
        if CommandLine.arguments.contains("--once") {
            runOnce()
        } else {
            ClaudeUsageBarApp.main()
        }
    }

    /// One-shot diagnostic: read the Keychain token, fetch usage, print it, exit.
    /// Exercises the same code paths the menu-bar app uses, without the GUI.
    ///   swift run ClaudeUsageBar --once
    private static func runOnce() {
        let done = DispatchSemaphore(value: 0)
        Task {
            defer { done.signal() }
            do {
                let token = try KeychainReader.readToken()
                let response = try await UsageClient().fetch(token: token)
                let s = response.fiveHour
                let w = response.sevenDay
                print("session:  \(UsageFormat.percentText(s?.utilization))  resets \(UsageFormat.relativeReset(s?.resetsAt) ?? "?")")
                print("weekly:   \(UsageFormat.percentText(w?.utilization))  resets \(UsageFormat.relativeReset(w?.resetsAt) ?? "?")")
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

struct ClaudeUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsagePopover(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Forces accessory activation policy so the app lives only in the menu bar
/// (no Dock icon) even when launched via `swift run` without an app bundle.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

/// The always-visible status-bar text, e.g. "S 47% · W 5%".
struct MenuBarLabel: View {
    let store: UsageStore

    var body: some View {
        switch store.phase {
        case .loading:
            Text("⋯")
        case .needsReauth:
            Text("⚠︎ 再認証")
        case .error:
            Text("S – · W –")
        case .ok:
            Text(text)
                .monospacedDigit()
                .foregroundStyle(UsageFormat.color(for: peak))
        }
    }

    private var text: String {
        let s = UsageFormat.percentText(store.session?.utilization)
        let w = UsageFormat.percentText(store.weekly?.utilization)
        return "S \(s) · W \(w)"
    }

    private var peak: Double? {
        UsageFormat.peak(store.session?.utilization, store.weekly?.utilization)
    }
}
