import SwiftUI

struct SettingsView: View {
    @StateObject private var store = RulesStore.shared
    @State private var selectedTab: Tab = .status
    @State private var selectedRuleId: UUID?

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
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(minWidth: 620, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()

            Text("WorkStop")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.secondary.opacity(0.5))
                .padding(.trailing, 8)
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
            .background(
                selectedTab == tab
                    ? Color.accentColor
                    : Color.clear
            )
            .foregroundColor(selectedTab == tab ? .white : .secondary)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .status:
            statusTab
        case .rules:
            rulesTab
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
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $selectedRuleId) {
                ForEach(store.rules) { rule in
                    RuleRowView(rule: rule).tag(rule.id)
                }
                .onDelete { store.deleteRules(at: $0) }
                .onMove { store.rules.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 190)
            .navigationTitle("提醒规则")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.addRule()
                        selectedRuleId = store.rules.last?.id
                    } label: {
                        Label("新增", systemImage: "plus")
                    }
                }
            }
        } detail: {
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
