import SwiftUI

/// Merged view for "定时提醒" — combines 当前状态 and 规则配置 with internal sub-tabs.
struct ReminderView: View {
    @StateObject private var store = RulesStore.shared
    @State private var selectedSubTab: SubTab = .status
    @State private var selectedRuleId: UUID?
    @State private var installState: InstallState = .idle

    enum InstallState { case idle, success, partial, failure }

    enum SubTab: String, CaseIterable {
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
            subTabBar
            Divider()
            subContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sub Tab Bar

    private var subTabBar: some View {
        HStack(spacing: 8) {
            ForEach(SubTab.allCases, id: \.self) { tab in
                subTabButton(tab)
            }
            Spacer()
            installSkillButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var installSkillButton: some View {
        Button {
            let result = ReminderSkillExporter.installAll(rules: store.rules)
            installState = result.cursor && result.claude ? .success
                         : (result.cursor || result.claude) ? .partial
                         : .failure
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { installState = .idle }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: iconForInstallState)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colorForInstallState)
                Text(labelForInstallState)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(installState == .idle ? .primary : colorForInstallState)
            }
            .animation(.easeInOut(duration: 0.2), value: installState)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("写入 Cursor (~/.cursor/skills/) 和 Claude (~/.claude/CLAUDE.md)")
    }

    private var iconForInstallState: String {
        switch installState {
        case .idle:    return "square.and.arrow.down"
        case .success: return "checkmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        }
    }

    private var colorForInstallState: Color {
        switch installState {
        case .idle:    return .accentColor
        case .success: return .green
        case .partial: return .orange
        case .failure: return .red
        }
    }

    private var labelForInstallState: String {
        switch installState {
        case .idle:    return "安装 Skill"
        case .success: return "已安装"
        case .partial: return "部分成功"
        case .failure: return "安装失败"
        }
    }

    private func subTabButton(_ tab: SubTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) { selectedSubTab = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon).font(.system(size: 11, weight: .medium))
                Text(tab.rawValue).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(selectedSubTab == tab ? .white : .secondary)
        }
        .buttonStyle(GlassTabButtonStyle(isSelected: selectedSubTab == tab, cornerRadius: 6))
    }

    // MARK: - Sub Content

    @ViewBuilder
    private var subContent: some View {
        switch selectedSubTab {
        case .status: statusContent
        case .rules:  rulesContent
        }
    }

    // MARK: - Status Content

    private var statusContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "bell.fill", title: "提醒规则状态", subtitle: "实时显示每条规则的倒计时")
                StatusView()
                if !store.rules.isEmpty {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation { selectedSubTab = .rules }
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

    // MARK: - Rules Content

    private var rulesContent: some View {
        HSplitView {
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
                        Image(systemName: "plus.circle.fill").foregroundColor(.accentColor)
                        Text("新增规则").font(.system(size: 13)).foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 160, idealWidth: 180, maxWidth: 240)

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
            Text("选择规则编辑").font(.title3).foregroundColor(.secondary)
            Text("从左侧选择已有规则，或点击 + 新建").font(.subheadline).foregroundColor(Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Rule Row (local copy to avoid SettingsView scope issues)

private struct RuleRowView: View {
    let rule: ReminderRule

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(ThemeColors.find(rule.themeId).primary).opacity(rule.isEnabled ? 1 : 0.4))
                .frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name).font(.body).foregroundColor(rule.isEnabled ? .primary : .secondary)
                Text("每 \(rule.intervalMinutes) 分钟 · \(ThemeColors.find(rule.themeId).name)")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            if !rule.isEnabled {
                Image(systemName: "pause.fill").foregroundColor(.secondary).font(.caption2)
            }
        }
        .padding(.vertical, 2)
    }
}
