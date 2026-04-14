import SwiftUI

struct SettingsView: View {
    @StateObject private var store = RulesStore.shared
    @State private var selectedTab: Tab = .status
    @State private var selectedRuleId: UUID?
    @ObservedObject private var offWork = OffWorkState.shared

    enum Tab: String, CaseIterable {
        case status      = "当前状态"
        case rules       = "规则配置"
        case appSettings = "系统设置"

        var icon: String {
            switch self {
            case .status:      return "chart.bar.fill"
            case .rules:       return "gearshape.fill"
            case .appSettings: return "gearshape.2.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(minWidth: 620, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Custom Toolbar

    private var toolbar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()

            offWorkButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(selectedTab == tab ? Color.accentColor : Color.clear)
            .foregroundColor(selectedTab == tab ? .white : .secondary)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }

    private var offWorkButton: some View {
        Button {
            if offWork.isActive {
                OffWorkManager.shared.exit(restore: true)
            } else {
                OffWorkManager.shared.enter()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: offWork.isActive ? "moon.zzz.fill" : "moon.zzz")
                    .font(.system(size: 12, weight: .medium))
                Text(offWork.isActive ? "取消下班" : "下班")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(offWork.isActive ? Color.orange : Color(NSColor.systemRed))
            .foregroundColor(.white)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .help(offWork.isActive ? "退出下班模式，恢复提醒计时" : "进入下班模式：黑幕遮屏，暂停所有提醒")
        .padding(.trailing, 4)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .status:
            statusTab
        case .rules:
            rulesTab
        case .appSettings:
            AppSettingsView(embedded: true)
        }
    }

    // MARK: - Status Tab

    private var statusTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "bell.fill", title: "提醒规则状态", subtitle: "实时显示每条规则的倒计时")
                StatusView()
                if !store.rules.isEmpty {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation { selectedTab = .rules }
                        } label: {
                            Label("管理规则", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rules Tab

    private var rulesTab: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                List(selection: $selectedRuleId) {
                    ForEach(store.rules) { rule in
                        RuleRowView(rule: rule).tag(rule.id)
                    }
                    .onDelete { store.deleteRules(at: $0) }
                    .onMove { store.rules.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.inset)

                Divider()

                Button {
                    store.addRule()
                    selectedRuleId = store.rules.last?.id
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("新增规则")
                            .font(.system(size: 13))
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 280)

            // Detail pane
            if let id = selectedRuleId,
               let idx = store.rules.firstIndex(where: { $0.id == id }) {
                RuleEditView(rule: $store.rules[idx])
            } else {
                emptyRuleDetail
            }
        }
    }

    private var emptyRuleDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48))
                .foregroundColor(Color.secondary.opacity(0.4))
            Text("选择规则编辑")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("从左侧选择已有规则，或点击 + 新建")
                .font(.subheadline)
                .foregroundColor(Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Rule Row

private struct RuleRowView: View {
    let rule: ReminderRule

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(ThemeColors.find(rule.themeId).primary).opacity(rule.isEnabled ? 1 : 0.4))
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.body)
                    .foregroundColor(rule.isEnabled ? .primary : .secondary)
                Text("每 \(rule.intervalMinutes) 分钟 · \(ThemeColors.find(rule.themeId).name)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !rule.isEnabled {
                Image(systemName: "pause.fill")
                    .foregroundColor(.secondary)
                    .font(.caption2)
            }
        }
        .padding(.vertical, 2)
    }
}
