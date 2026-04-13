import SwiftUI

struct StatusView: View {
    @ObservedObject private var store = RulesStore.shared
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.rules.isEmpty {
                emptyCard
            } else {
                ForEach(store.rules) { rule in
                    RuleCard(rule: rule, now: now)
                }
            }
        }
        .onReceive(ticker) { now = $0 }
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("还没有规则")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("切换到「规则配置」添加第一条提醒")
                .font(.subheadline)
                .foregroundColor(Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
    }
}

// MARK: - Rule Card

private struct RuleCard: View {
    let rule: ReminderRule
    let now: Date

    private var theme: ThemeColors { ThemeColors.find(rule.themeId) }

    private var remaining: TimeInterval? {
        guard rule.isEnabled,
              let fireDate = RuleTimerManager.shared.nextFireDate(for: rule.id)
        else { return nil }
        return max(0, fireDate.timeIntervalSince(now))
    }

    private var progress: Double {
        guard rule.isEnabled,
              let r = remaining
        else { return 0 }
        let total = Double(rule.intervalMinutes * 60)
        return 1.0 - (r / total)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(Color(theme.primary))
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack {
                    Text(rule.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(rule.isEnabled ? .primary : .secondary)

                    Spacer()

                    statusBadge
                }

                if rule.isEnabled, let r = remaining {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(theme.primary).opacity(0.7), Color(theme.primary)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    // Countdown + meta row
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatRemaining(r))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(r < 60 ? Color(theme.primary) : .primary)

                        Spacer()

                        Text(metaText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !rule.isEnabled {
                    Text("已暂停")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(14)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        Group {
            if !rule.isEnabled {
                Label("已暂停", systemImage: "pause.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let r = remaining, r < 10 {
                Label("即将触发", systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundColor(Color(theme.primary))
            } else {
                Label("运行中", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    private var metaText: String {
        let modePart: String
        switch rule.triggerMode {
        case .interval:
            modePart = "每 \(rule.intervalMinutes) 分钟"
        case .scheduled:
            let times = rule.scheduledTimes.map { $0.displayText }.joined(separator: " / ")
            modePart = times.isEmpty ? "定点（无时刻）" : "定点 \(times)"
        }
        let parts: [String] = [
            modePart,
            theme.name,
            rule.canCloseImmediately ? "随时可关" : "\(rule.durationSeconds) 秒后可关",
        ]
        return parts.joined(separator: " · ")
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s >= 3600 {
            return "距提醒 \(s / 3600) 时 \((s % 3600) / 60) 分"
        } else if s >= 60 {
            return "距提醒 \(s / 60) 分 \(s % 60) 秒"
        } else {
            return "距提醒 \(s) 秒"
        }
    }
}
