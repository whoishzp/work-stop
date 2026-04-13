import SwiftUI

struct SettingsView: View {
    @StateObject private var store = RulesStore.shared
    @State private var selectedTab: Tab = .status
    @State private var selectedRuleId: UUID?
    @ObservedObject private var offWork = OffWorkState.shared

    enum Tab: String, CaseIterable {
        case status = "当前状态"
        case rules  = "规则配置"
        var icon: String {
            switch self {
            case .status: return "chart.bar.fill"
            case .rules:  return "gearshape.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 640, minHeight: 480)
        .toolbar {
            // Tab switcher — left side
            ToolbarItem(placement: .navigation) {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            // Off-work button — right side
            ToolbarItemGroup(placement: .primaryAction) {
                offWorkButton
                if selectedTab == .rules {
                    Button {
                        store.addRule()
                        selectedRuleId = store.rules.last?.id
                    } label: {
                        Label("新增规则", systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle("WorkStop")
    }

    // MARK: - Off-Work Button

    private var offWorkButton: some View {
        Group {
            if offWork.isActive {
                Button {
                    OffWorkManager.shared.exit(restore: true)
                } label: {
                    Label("取消下班", systemImage: "moon.zzz.fill")
                        .foregroundColor(.orange)
                }
                .help("退出下班模式，恢复提醒计时")
            } else {
                Button {
                    OffWorkManager.shared.enter()
                } label: {
                    Label("下班", systemImage: "moon.zzz")
                }
                .help("进入下班模式：黑幕遮屏，暂停所有提醒")
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        switch selectedTab {
        case .status:
            statusSidebar
        case .rules:
            rulesSidebar
        }
    }

    private var statusSidebar: some View {
        List {
            ForEach(store.rules) { rule in
                RuleStatusRowBrief(rule: rule)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("规则列表")
    }

    private var rulesSidebar: some View {
        List(selection: $selectedRuleId) {
            ForEach(store.rules) { rule in
                RuleRowView(rule: rule).tag(rule.id)
            }
            .onDelete { store.deleteRules(at: $0) }
            .onMove { store.rules.move(fromOffsets: $0, toOffset: $1) }
        }
        .listStyle(.sidebar)
        .navigationTitle("提醒规则")
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selectedTab {
        case .status:
            statusDetail
        case .rules:
            rulesDetail
        }
    }

    private var statusDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StatusView()
                if !store.rules.isEmpty {
                    HStack {
                        Spacer()
                        Button { selectedTab = .rules } label: {
                            Label("管理规则", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var rulesDetail: some View {
        if let id = selectedRuleId,
           let idx = store.rules.firstIndex(where: { $0.id == id }) {
            RuleEditView(rule: $store.rules[idx])
        } else {
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
    }
}

// MARK: - Status Sidebar Brief Row

private struct RuleStatusRowBrief: View {
    let rule: ReminderRule

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(ThemeColors.find(rule.themeId).primary).opacity(rule.isEnabled ? 1 : 0.3))
                .frame(width: 8, height: 8)
            Text(rule.name)
                .font(.body)
                .foregroundColor(rule.isEnabled ? .primary : .secondary)
            Spacer()
            if !rule.isEnabled {
                Image(systemName: "pause.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
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
