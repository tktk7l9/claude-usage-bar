import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UsageStore {
    enum Phase: Equatable {
        case loading
        case ok
        case needsReauth
        case error(String)
    }

    private(set) var session: UsageResponse.Window?
    private(set) var weekly: UsageResponse.Window?
    private(set) var opus: UsageResponse.Window?
    private(set) var lastUpdated: Date?
    private(set) var phase: Phase = .loading

    private let client = UsageClient()
    private var pollTask: Task<Void, Never>?

    /// Poll interval in seconds. Override with `defaults write
    /// com.tktk7l9.claude-usage-bar pollInterval 30`. The endpoint is a cheap
    /// metadata read and does not consume plan usage, but we floor at 15s.
    var pollInterval: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: "pollInterval")
        return stored >= 15 ? stored : 60
    }

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        start()
    }

    /// Launches the background polling loop. Safe to call again; cancels any
    /// existing loop first.
    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.pollInterval))
            }
        }
    }

    func refresh() async {
        do {
            let token = try KeychainReader.readToken()
            let response = try await client.fetch(token: token)
            session = response.fiveHour
            weekly = response.sevenDay
            opus = response.sevenDayOpus
            lastUpdated = Date()
            phase = .ok
        } catch UsageError.unauthorized {
            phase = .needsReauth
        } catch is KeychainError {
            phase = .error("Keychainからトークンを読めません")
        } catch UsageError.http(let code) {
            phase = .error("HTTP \(code)")
        } catch {
            phase = .error("更新に失敗しました")
        }
    }
}
