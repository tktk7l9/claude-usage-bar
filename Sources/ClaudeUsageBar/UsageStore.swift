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
    private(set) var sonnet: UsageResponse.Window?
    private(set) var lastUpdated: Date?
    private(set) var phase: Phase = .loading
    /// Account plan (e.g. "Pro"), Claude Code default model ("Opus") and effort
    /// ("xHigh"). org/email come from the profile endpoint (fetched once).
    private(set) var plan: String?
    private(set) var model: String?
    private(set) var effort: String?
    private(set) var org: String?
    private(set) var email: String?
    private(set) var subscriptionStatus: String?
    private(set) var tokenExpiresAt: Date?

    private let client = UsageClient()
    private var pollTask: Task<Void, Never>?
    private var lastAttempt: Date?
    private var profileLoaded = false
    /// Extra seconds to wait before the next poll, set when rate-limited or on
    /// transient errors so we don't hammer the endpoint.
    private var backoff: TimeInterval = 0

    /// Minimum gap between fetches so wake + popover-open + the timed poll
    /// firing together don't burst the endpoint (which returns 429).
    private let minGap: TimeInterval = 8

    /// Poll interval in seconds. Override with `defaults write
    /// com.tktk7l9.claude-usage-bar pollInterval 90`. The endpoint is a cheap
    /// metadata read and does not consume plan usage; floored at 30s.
    var pollInterval: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: "pollInterval")
        return stored >= 30 ? stored : 60
    }

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        start()
    }

    /// Fetches account/org info once (rarely changes). Best-effort and triggered
    /// after a successful usage fetch, so it retries on later polls if the first
    /// attempt failed (e.g. a transient 429) — no extra request once loaded.
    private func loadProfile(token: String) async {
        guard !profileLoaded else { return }
        do {
            let profile = try await client.fetchProfile(token: token)
            org = profile.organization?.name
            email = profile.account?.email
            subscriptionStatus = profile.organization?.subscriptionStatus
            if org != nil || email != nil { profileLoaded = true }
        } catch {
            // ignore; org/email are optional and will be retried next poll
        }
    }

    /// Launches the background polling loop. Safe to call again; cancels any
    /// existing loop first.
    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh(force: true)
                try? await Task.sleep(for: .seconds(self.pollInterval + self.backoff))
            }
        }
    }

    /// `force` (timed poll) bypasses the min-gap throttle. UI-triggered
    /// refreshes (popover open, wake) pass force=false and are throttled.
    /// On error the last good values are kept so the menu bar doesn't blank.
    func refresh(force: Bool = false) async {
        if !force, let last = lastAttempt, Date().timeIntervalSince(last) < minGap {
            return
        }
        lastAttempt = Date()
        // Local, cheap, token-independent: refresh the configured model/effort.
        let settings = ClaudeConfig.read()
        model = UsageFormat.modelName(settings.model)
        effort = UsageFormat.effortName(settings.effortLevel)
        do {
            let creds = try KeychainReader.read()
            plan = UsageFormat.planName(creds.subscriptionType)
            tokenExpiresAt = creds.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) }
            let response = try await client.fetch(token: creds.accessToken)
            session = response.fiveHour
            weekly = response.sevenDay
            opus = response.sevenDayOpus
            sonnet = response.sevenDaySonnet
            lastUpdated = Date()
            phase = .ok
            backoff = 0
            await loadProfile(token: creds.accessToken)
        } catch UsageError.unauthorized {
            phase = .needsReauth
            backoff = 0
        } catch UsageError.rateLimited(let retryAfter) {
            phase = .error("レート制限中（自動再試行）")
            backoff = max(retryAfter ?? 120, 120)
        } catch is KeychainError {
            phase = .error("Keychainからトークンを読めません")
            backoff = 0
        } catch UsageError.http(let code) {
            phase = .error("HTTP \(code)")
            backoff = 30
        } catch {
            phase = .error("更新に失敗しました")
            backoff = 30
        }
    }
}
