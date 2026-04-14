import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: Tab = .appSettings
    @ObservedObject private var offWork = OffWorkState.shared

    enum Tab: String, CaseIterable {
        case appSettings = "系统设置"
        case reminder    = "定时提醒"
        case feHelper    = "Fe助手"

        var icon: String {
            switch self {
            case .appSettings: return "gearshape.2.fill"
            case .reminder:    return "bell.badge.fill"
            case .feHelper:    return "wrench.and.screwdriver.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(minWidth: 780, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                offWorkButton
            }
        }
    }

    // MARK: - Left Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { tab in
                sidebarTabButton(tab)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
        .frame(width: 156)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func sidebarTabButton(_ tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundColor(selectedTab == tab ? .white : .secondary)
        }
        .buttonStyle(GlassTabButtonStyle(isSelected: selectedTab == tab, cornerRadius: 8))
    }

    // MARK: - Off-Work Button

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
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .appSettings: AppSettingsView(embedded: true)
        case .reminder:    ReminderView()
        case .feHelper:    FeHelperView()
        }
    }
}
