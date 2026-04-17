import SwiftUI
import AppKit

// MARK: - Inline Shortcut Row

/// A self-contained row that displays current shortcut + handles recording via NSEvent local monitor.
private struct ShortcutRow: View {
    let label: String
    let hint: String
    @Binding var shortcut: OffWorkShortcut?

    @State private var isRecording = false
    @State private var localMonitor: Any?

    var body: some View {
        HStack(spacing: 12) {
            // Shortcut badge
            Text(isRecording ? "请按下组合键…" : (shortcut?.displayString ?? "未设置"))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(isRecording ? .accentColor : (shortcut != nil ? .primary : .secondary))
                .frame(minWidth: 100, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color(NSColor.separatorColor),
                                lineWidth: isRecording ? 1.5 : 1)
                )

            if isRecording {
                Button("取消") { stopRecording(captured: nil) }
                    .buttonStyle(.bordered).controlSize(.small)
            } else {
                Button(shortcut != nil ? "重新录制" : "录制") { startRecording() }
                    .buttonStyle(.bordered).controlSize(.small)
                if shortcut != nil {
                    Button("清除") { shortcut = nil }
                        .buttonStyle(.bordered).controlSize(.small)
                        .foregroundColor(.red)
                }
            }
        }
        .onDisappear { stopRecording(captured: nil) }
    }

    private func startRecording() {
        HotkeyManager.isAnyRecording = true
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape → cancel
            if event.keyCode == 53 {
                stopRecording(captured: nil)
                return event
            }
            let relevant: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let mods = event.modifierFlags.intersection(relevant)
            guard !mods.isEmpty,
                  let key = event.charactersIgnoringModifiers?.lowercased(),
                  !key.isEmpty else { return event }
            let sc = OffWorkShortcut(key: key, modifiers: mods.rawValue, keyCode: event.keyCode)
            stopRecording(captured: sc)
            return nil  // consume the event
        }
    }

    private func stopRecording(captured: OffWorkShortcut?) {
        HotkeyManager.isAnyRecording = false
        isRecording = false
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let sc = captured { shortcut = sc }
    }
}

// MARK: - Manual run feedback

private struct ManualRunFeedback: Equatable {
    var success: Bool
    var title: String
    var subtitle: String
}

// MARK: - AppearanceModeCard

private struct AppearanceModeCard: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(previewBackground)
                        .frame(width: 72, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor),
                                        lineWidth: isSelected ? 2 : 1)
                        )
                    previewIcon
                }
                Text(mode.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var previewBackground: Color {
        switch mode {
        case .system: return Color(NSColor.windowBackgroundColor)
        case .light:  return Color(NSColor.white)
        case .dark:   return Color(NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1))
        }
    }

    @ViewBuilder private var previewIcon: some View {
        switch mode {
        case .system:
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
        case .light:
            Image(systemName: "sun.max.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
        case .dark:
            Image(systemName: "moon.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
        }
    }
}

// MARK: - AppSettingsView

struct AppSettingsView: View {
    var embedded: Bool = false

    @ObservedObject private var settings = AppSettings.shared
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var currentPassword: String = ""
    @State private var showError: String? = nil
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !embedded {
                // Header (only shown when presented as sheet)
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("系统设置").font(.headline)
                        Text("Magicer 应用配置").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("完成") { dismiss() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                Divider()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Appearance section
                    appearanceSection

                    // Off-work password section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("下班模式密码", systemImage: "lock.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)

                            Text("设置后，按 Esc 退出下班黑幕时需输入此密码。留空则无需密码。")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Divider()

                            if settings.hasPassword {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("当前密码状态：")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Label("已设置", systemImage: "lock.fill")
                                            .font(.caption.bold())
                                            .foregroundColor(.green)
                                    }

                                    HStack(spacing: 8) {
                                        SecureField("输入现有密码以修改或清除", text: $currentPassword)
                                            .textFieldStyle(.roundedBorder)
                                        Button("清除密码") { clearPassword() }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .foregroundColor(.red)
                                    }
                                }
                            }

                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(settings.hasPassword ? "新密码" : "设置密码")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    SecureField("输入新密码", text: $newPassword)
                                        .textFieldStyle(.roundedBorder)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("确认密码")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    SecureField("再次输入", text: $confirmPassword)
                                        .textFieldStyle(.roundedBorder)
                                }
                                Button("保存") { savePassword() }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                    .padding(.top, 16)
                            }

                            if let err = showError {
                                Label(err, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if showSuccess {
                                Label("密码已保存", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(4)
                    }

                    // Off-work shortcut section
                    shortcutSection

                    // Boot startup commands section
                    startupCommandsSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: embedded ? 0 : 440, minHeight: embedded ? 0 : 380)
        .frame(maxWidth: embedded ? .infinity : 440, maxHeight: embedded ? .infinity : 460)
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Label("外观模式", systemImage: "circle.lefthalf.filled")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                Text("选择应用的显示外观，深色模式下界面将使用更柔和的暗色调。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                HStack(spacing: 12) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        AppearanceModeCard(mode: mode, isSelected: settings.appearanceMode == mode) {
                            settings.appearanceMode = mode
                        }
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Shortcut Section

    private var shortcutSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 18) {
                Label("全局快捷键", systemImage: "keyboard.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                Text("在任意程序中按下组合键即可触发对应功能，需包含至少一个修饰键（⌘ ⌥ ⇧ ⌃）。点击「录制」后直接按组合键即可，Esc 取消。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Text("下班模式")
                            .font(.system(size: 13))
                            .frame(width: 72, alignment: .leading)
                        ShortcutRow(
                            label: "下班模式",
                            hint: "触发进入/退出下班黑幕",
                            shortcut: $settings.offWorkShortcut
                        )
                    }

                    Divider()

                    HStack(spacing: 16) {
                        Text("Fe 助手")
                            .font(.system(size: 13))
                            .frame(width: 72, alignment: .leading)
                        ShortcutRow(
                            label: "Fe 助手",
                            hint: "快速打开 Fe 助手面板",
                            shortcut: $settings.feHelperShortcut
                        )
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Startup Commands Section

    @State private var newCmdLabel: String = ""
    @State private var newCmdText: String = ""
    @State private var manualRunFeedback: ManualRunFeedback?
    @State private var feedbackDismissWorkItem: DispatchWorkItem?

    private var startupCommandsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Label("开机启动执行命令", systemImage: "terminal.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                Text("Mac 开机后首次启动 Magicer 时自动执行以下 shell 命令。同一次开机多次打开应用只执行一次，后台运行不阻塞启动。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                // Command list
                if settings.startupCommands.isEmpty {
                    Text("暂无命令")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach($settings.startupCommands) { $cmd in
                            HStack(spacing: 8) {
                                Toggle("", isOn: $cmd.isEnabled)
                                    .labelsHidden()
                                    .controlSize(.small)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cmd.label.isEmpty ? "(无标签)" : cmd.label)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(cmd.isEnabled ? .primary : .secondary)
                                    Text(cmd.command)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    let ok = NSPasteboard.general.setString(cmd.command, forType: .string)
                                    let name = cmd.label.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? String(cmd.command.prefix(40))
                                        : cmd.label
                                    feedbackDismissWorkItem?.cancel()
                                    manualRunFeedback = ManualRunFeedback(
                                        success: ok,
                                        title: ok ? "已复制到剪贴板" : "未能复制",
                                        subtitle: ok
                                            ? "「\(name)」的完整 shell 已写入，可在终端或其他应用粘贴。"
                                            : "剪贴板写入失败，请重试。"
                                    )
                                    let work = DispatchWorkItem { manualRunFeedback = nil }
                                    feedbackDismissWorkItem = work
                                    let seconds: TimeInterval = ok ? 3 : 5
                                    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("复制 shell 命令到剪贴板")
                                Button {
                                    StartupCommandRunner.runNow(cmd) { outcome in
                                        let name = outcome.label.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? String(outcome.commandPreview.prefix(40))
                                            : outcome.label
                                        feedbackDismissWorkItem?.cancel()
                                        manualRunFeedback = ManualRunFeedback(
                                            success: outcome.success,
                                            title: outcome.success ? "「\(name)」已执行完成" : "「\(name)」执行未成功",
                                            subtitle: outcome.success
                                                ? "进程已结束，退出码 \(outcome.exitCode ?? 0)。"
                                                : (outcome.errorDetail ?? "")
                                        )
                                        let work = DispatchWorkItem { manualRunFeedback = nil }
                                        feedbackDismissWorkItem = work
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
                                    }
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .help("立即执行此命令")
                                Button {
                                    settings.startupCommands.removeAll { $0.id == cmd.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                            .cornerRadius(6)
                        }
                    }
                }

                if let fb = manualRunFeedback {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: fb.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundColor(fb.success ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fb.title)
                                .font(.subheadline.weight(.semibold))
                            Text(fb.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(fb.success
                                  ? Color.green.opacity(0.12)
                                  : Color.orange.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(fb.success ? Color.green.opacity(0.25) : Color.orange.opacity(0.35), lineWidth: 1)
                    )
                }

                Divider()

                // Add command row
                VStack(alignment: .leading, spacing: 8) {
                    Text("添加开机命令").font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        TextField("标签（如：打开代理）", text: $newCmdLabel)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                        TextField("shell 命令（如：open -a Proxyman）", text: $newCmdText)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            guard !newCmdText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            settings.startupCommands.append(StartupCommand(
                                label: newCmdLabel.isEmpty ? newCmdText : newCmdLabel,
                                command: newCmdText
                            ))
                            newCmdLabel = ""; newCmdText = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(newCmdText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Actions

    private func savePassword() {
        showError = nil
        showSuccess = false

        guard !newPassword.isEmpty else {
            showError = "密码不能为空字符串（支持空格、任意字符）"
            return
        }
        guard newPassword == confirmPassword else {
            showError = "两次输入的密码不一致"
            return
        }
        if settings.hasPassword {
            guard currentPassword == settings.offWorkPassword else {
                showError = "现有密码不正确"
                return
            }
        }

        settings.offWorkPassword = newPassword
        newPassword = ""
        confirmPassword = ""
        currentPassword = ""
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSuccess = false }
    }

    private func clearPassword() {
        showError = nil
        guard settings.hasPassword else { return }
        guard currentPassword == settings.offWorkPassword else {
            showError = "现有密码不正确，无法清除"
            return
        }
        settings.offWorkPassword = ""
        currentPassword = ""
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSuccess = false }
    }
}
