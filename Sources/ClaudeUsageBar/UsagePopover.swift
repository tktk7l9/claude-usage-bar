import SwiftUI

/// Detail view shown when the menu-bar item is clicked.
struct UsagePopover: View {
    let store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Claude 使用状況")
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            switch store.phase {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("読み込み中…").foregroundStyle(.secondary)
                }
            case .needsReauth:
                reauthView
            case .error(let message):
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .ok:
                meters
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 280)
    }

    /// "プラン Pro · モデル Opus · 努力 xHigh" — omits unavailable parts.
    private var subtitle: String? {
        var parts: [String] = []
        if let plan = store.plan { parts.append("プラン \(plan)") }
        if let model = store.model { parts.append("モデル \(model)") }
        if let effort = store.effort { parts.append("努力 \(effort)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder private var meters: some View {
        VStack(alignment: .leading, spacing: 12) {
            MeterRow(title: "セッション", window: store.session)
            MeterRow(title: "週間", window: store.weekly)
            if store.opus != nil {
                MeterRow(title: "Opus（週間）", window: store.opus)
            }
        }
    }

    private var reauthView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("再認証が必要です", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Claude Code で一度コマンドを実行するとトークンが更新されます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if store.org != nil || store.email != nil {
                VStack(alignment: .leading, spacing: 1) {
                    if let org = store.org {
                        Text(org)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let email = store.email {
                        Text(email)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            HStack {
                if let relative = UsageFormat.relative(from: store.lastUpdated) {
                    Text("更新: \(relative)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("更新") {
                    Task { await store.refresh() }
                }
                .buttonStyle(.borderless)
                Button("終了") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

/// A labeled progress meter for a single usage window.
private struct MeterRow: View {
    let title: String
    let window: UsageResponse.Window?

    var body: some View {
        let utilization = window?.utilization
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(UsageFormat.percentText(utilization))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(UsageFormat.color(for: utilization))
            }
            ProgressView(value: (utilization ?? 0) / 100)
                .tint(UsageFormat.color(for: utilization))
            if let reset = UsageFormat.resetDescription(window?.resetsAt) {
                Text("リセット \(reset)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
