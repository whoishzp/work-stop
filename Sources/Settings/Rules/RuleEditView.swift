import SwiftUI

struct RuleEditView: View {
    @Binding var rule: ReminderRule
    @State private var showDeleteAlert = false
    @State private var newHour = 9
    @State private var newMinute = 0
    @State private var showTimePicker = false
    @State private var previewTheme: ThemeColors? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                basicSection
                timingSection
                textSection
                themeSection
                controlSection
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(rule.name)
        .sheet(isPresented: Binding(
            get: { previewTheme != nil },
            set: { if !$0 { previewTheme = nil } }
        )) {
            if let t = previewTheme {
                ThemePreviewView(theme: t, ruleName: rule.name, reminderText: rule.reminderText)
                    .frame(width: 720, height: 480)
            }
        }
        .alert("删除规则", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                RulesStore.shared.deleteRules(at: IndexSet(
                    RulesStore.shared.rules.indices.filter { RulesStore.shared.rules[$0].id == rule.id }
                ))
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定删除规则「\(rule.name)」？此操作不可撤销。")
        }
    }

    // MARK: - Basic

    private var basicSection: some View {
        sectionCard("基本信息") {
            HStack {
                Text("规则名称")
                    .frame(width: 80, alignment: .leading)
                TextField("如：专注提醒", text: $rule.name)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("启用")
                    .frame(width: 80, alignment: .leading)
                Toggle("", isOn: $rule.isEnabled)
                    .labelsHidden()
                Spacer()
            }
        }
    }

    // MARK: - Timing

    private var timingSection: some View {
        sectionCard("提醒时机") {
            // Mode picker
            HStack {
                Text("触发方式")
                    .frame(width: 80, alignment: .leading)
                Picker("", selection: $rule.triggerMode) {
                    Text("循环提醒").tag(TriggerMode.interval)
                    Text("定点提醒").tag(TriggerMode.scheduled)
                    Text("一次提醒").tag(TriggerMode.once)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)
                Spacer()
            }

            if rule.triggerMode == .interval {
                intervalConfig
            } else if rule.triggerMode == .scheduled {
                scheduledConfig
            } else {
                onceConfig
            }

            Divider()

            // Followup reminder (applies to all modes)
            HStack(alignment: .center) {
                Text("跟进提醒")
                    .frame(width: 80, alignment: .leading)
                TextField("", value: $rule.followupMinutes, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: rule.followupMinutes) { v in
                        rule.followupMinutes = max(0, min(120, v))
                    }
                Stepper("", value: $rule.followupMinutes, in: 0...120)
                    .labelsHidden()
                Text("分钟")
                    .foregroundColor(.secondary)
                Spacer()
                Text("关闭蒙层后 N 分钟再提醒一次（0 = 不跟进）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Shared: duration + closeable
            HStack(alignment: .center) {
                Text("提示时长")
                    .frame(width: 80, alignment: .leading)
                TextField("", value: $rule.durationSeconds, format: .number)
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: rule.durationSeconds) { v in
                        rule.durationSeconds = max(0, min(120, v))
                    }
                Stepper("", value: $rule.durationSeconds, in: 0...120)
                    .labelsHidden()
                Text("秒")
                    .foregroundColor(.secondary)
                Spacer()
                Text("0 = 随时可关闭")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .top) {
                Text("可立即关闭")
                    .frame(width: 80, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("忽略提示时长，弹窗出现后立即可关", isOn: $rule.canCloseImmediately)
                    Text("开启后「提示时长」设置失效")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var intervalConfig: some View {
        HStack(alignment: .center) {
            Text("提示间隔")
                .frame(width: 80, alignment: .leading)
            TextField("", value: $rule.intervalMinutes, format: .number)
                .frame(width: 64)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .onChange(of: rule.intervalMinutes) { v in
                    rule.intervalMinutes = max(1, min(480, v))
                }
            Stepper("", value: $rule.intervalMinutes, in: 1...480)
                .labelsHidden()
            Text("分钟")
                .foregroundColor(.secondary)
            Spacer()
            Text("每隔此时间触发一次")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var scheduledConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Time list
            if rule.scheduledTimes.isEmpty {
                Text("还没有添加定点时间")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(rule.scheduledTimes) { t in
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.accentColor)
                                .font(.subheadline)
                            Text(t.displayText)
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                            Spacer()
                            Button {
                                rule.scheduledTimes.removeAll { $0.id == t.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.06))
                        .cornerRadius(8)
                    }
                }
            }

            // Add time row
            HStack(spacing: 10) {
                Text("添加时刻")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 60)

                Picker("时", selection: $newHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d 时", h)).tag(h)
                    }
                }
                .frame(width: 80)

                Picker("分", selection: $newMinute) {
                    ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { m in
                        Text(String(format: "%02d 分", m)).tag(m)
                    }
                }
                .frame(width: 80)

                Button {
                    let newTime = ScheduledTime(hour: newHour, minute: newMinute)
                    if !rule.scheduledTimes.contains(where: { $0.hour == newHour && $0.minute == newMinute }) {
                        rule.scheduledTimes.append(newTime)
                        rule.scheduledTimes.sort { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }
                    }
                } label: {
                    Label("添加", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            Text("可添加多个定点时刻，每天到点触发")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var onceConfig: some View {
        HStack(alignment: .center) {
            Text("触发时刻")
                .frame(width: 80, alignment: .leading)
            DatePicker("", selection: $rule.onceDate)
                .datePickerStyle(.compact)
                .labelsHidden()
            Spacer()
            Text("到时触发一次后自动停用")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Text

    private var textSection: some View {
        sectionCard("提示文字") {
            TextEditor(text: $rule.reminderText)
                .font(.body)
                .frame(height: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Theme

    private var themeSection: some View {
        sectionCard("蒙层风格") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ThemeColors.all, id: \.id) { theme in
                    ThemeCard(theme: theme, isSelected: rule.themeId == theme.id) {
                        previewTheme = theme
                    }
                    .onTapGesture { rule.themeId = theme.id }
                }
            }
        }
    }

    // MARK: - Controls

    private var controlSection: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("删除此规则", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Section Card Helper

    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}

// ThemeCard lives in Sources/Settings/Rules/ThemeCard.swift
