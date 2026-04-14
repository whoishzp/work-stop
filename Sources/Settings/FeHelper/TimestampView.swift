import SwiftUI

struct TimestampView: View {
    @State private var currentTime: Date = Date()
    @State private var isPaused = false
    @State private var timer: Timer?
    @State private var inputText: String = ""
    @State private var parseResults: [ParseResult] = []
    @State private var parseError: String = ""
    @State private var toastMessage: String = ""
    @State private var toastTask: DispatchWorkItem?

    struct ParseResult: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    // Quick action presets
    enum QuickAction: String, CaseIterable {
        case now       = "当前时间"
        case today     = "今天开始"
        case yesterday = "昨天"
        case thisWeek  = "本周开始"
        case thisMonth = "本月开始"

        var icon: String {
            switch self {
            case .now:       return "clock"
            case .today:     return "sunrise"
            case .yesterday: return "arrow.uturn.left"
            case .thisWeek:  return "calendar.badge.clock"
            case .thisMonth: return "calendar"
            }
        }

        func date() -> Date {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .now:       return now
            case .today:     return cal.startOfDay(for: now)
            case .yesterday: return cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: now)!)
            case .thisWeek:
                var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
                comps.weekday = cal.firstWeekday
                return cal.date(from: comps) ?? now
            case .thisMonth:
                let comps = cal.dateComponents([.year, .month], from: now)
                return cal.date(from: comps) ?? now
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    quickActionsSection
                    inputSection
                    currentTimeSection
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Toast
            if !toastMessage.isEmpty {
                Text(toastMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(20)
                    .padding(.bottom, 20)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
        .onAppear {
            startTimer()
            fillQuickAction(.now)
        }
        .onDisappear { timer?.invalidate() }
        .onChange(of: inputText) { _ in
            parseInput()
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(QuickAction.allCases, id: \.self) { action in
                    Button {
                        fillQuickAction(action)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: action.icon).font(.system(size: 10))
                            Text(action.rawValue).font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("输入时间（支持多种格式）", systemImage: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("试试输入：\n• 1749722690（时间戳）\n• 2025-06-12 18:06:25\n• now / today / yesterday\n• 2025/06/12\n• Jun 12, 2025")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $inputText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 120)
                        .opacity(inputText.isEmpty ? 0.01 : 1)
                }
                .frame(height: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Spacer().frame(height: 22)
                Button {
                    parseInput()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill").font(.system(size: 22)).foregroundColor(.accentColor)
                        Text("解析").font(.caption).foregroundColor(.accentColor)
                    }
                }
                .buttonStyle(.plain)
                Button {
                    inputText = ""
                    parseResults = []
                    parseError = ""
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash").font(.system(size: 14)).foregroundColor(.secondary)
                        Text("清空").font(.caption).foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Current Time Section

    private var currentTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("当前时间", systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    isPaused.toggle()
                    if isPaused { timer?.invalidate() } else { startTimer() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill").font(.system(size: 10))
                        Text(isPaused ? "继续" : "暂停").font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .foregroundColor(.orange)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                timeCell(title: "当前本地时间", value: formatDate(currentTime, format: "yyyy-MM-dd HH:mm:ss"))
                Divider().frame(height: 40)
                timeCell(title: "Unix时间戳(秒)", value: "\(Int(currentTime.timeIntervalSince1970))")
                Divider().frame(height: 40)
                timeCell(title: "Unix时间戳(毫秒)", value: "\(Int64(currentTime.timeIntervalSince1970) * 1000)")
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.15), lineWidth: 1))

            // Parse results
            if !parseError.isEmpty {
                Text("❌ \(parseError)").font(.caption).foregroundColor(.red).padding(8)
                    .background(Color.red.opacity(0.07)).cornerRadius(6)
            } else if !parseResults.isEmpty {
                parseResultsView
            }
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation { toastMessage = message }
        let task = DispatchWorkItem {
            withAnimation { toastMessage = "" }
        }
        toastTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }

    private func timeCell(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
        .onTapGesture(count: 2) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            showToast("已复制 ✓")
        }
        .help("双击复制")
    }

    private var parseResultsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("解析结果", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.green)
            VStack(spacing: 0) {
                ForEach(parseResults) { result in
                    HStack {
                        Text(result.label)
                            .font(.system(size: 11)).foregroundColor(.secondary)
                            .frame(width: 160, alignment: .trailing)
                        Text(result.value)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.value, forType: .string)
                        showToast("已复制 ✓")
                    }
                    .help("双击复制")
                    if result.id != parseResults.last?.id {
                        Divider()
                    }
                }
            }
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Logic

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if !isPaused { currentTime = Date() }
        }
    }

    private func fillQuickAction(_ action: QuickAction) {
        let date = action.date()
        let ts = Int64(date.timeIntervalSince1970)
        inputText = "\(ts)"
        parseInput()
    }

    private func parseInput() {
        parseError = ""
        parseResults = []
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        if let date = parseToDate(raw) {
            buildResults(from: date)
        } else {
            parseError = "无法识别的时间格式，请检查输入"
        }
    }

    private func parseToDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Natural language
        switch trimmed.lowercased() {
        case "now":       return Date()
        case "today":     return Calendar.current.startOfDay(for: Date())
        case "yesterday": return Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        default: break
        }

        // Unix timestamp (seconds or milliseconds)
        if let ts = Double(trimmed), ts.isFinite {
            let adjusted = ts > 1e12 ? ts / 1000 : ts
            // Guard against dates far outside representable range (year ~1-9999)
            guard adjusted > -62_167_219_200 && adjusted < 253_402_300_800 else { return nil }
            return Date(timeIntervalSince1970: adjusted)
        }

        // Datetime string formats
        let fmts = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "MMM dd, yyyy",
            "MMM dd yyyy",
            "dd MMM yyyy",
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in fmts {
            df.dateFormat = fmt
            if let d = df.date(from: trimmed) { return d }
        }
        return nil
    }

    private func buildResults(from date: Date) {
        let tsDouble = date.timeIntervalSince1970
        guard tsDouble.isFinite else { parseError = "时间超出范围"; return }
        let ts = Int64(tsDouble.rounded())
        let tsMs: Int64 = ts.multipliedReportingOverflow(by: 1000).overflow ? ts : ts * 1000
        parseResults = [
            ParseResult(label: "Unix时间戳（秒）", value: "\(ts)"),
            ParseResult(label: "Unix时间戳（毫秒）", value: "\(tsMs)"),
            ParseResult(label: "本地时间", value: formatDate(date, format: "yyyy-MM-dd HH:mm:ss")),
            ParseResult(label: "UTC时间", value: formatDateUTC(date, format: "yyyy-MM-dd HH:mm:ss")),
            ParseResult(label: "ISO 8601", value: formatDateUTC(date, format: "yyyy-MM-dd'T'HH:mm:ss'Z'")),
            ParseResult(label: "RFC 3339", value: formatDateUTC(date, format: "yyyy-MM-dd'T'HH:mm:ssZ")),
            ParseResult(label: "中文格式", value: formatDate(date, format: "yyyy年MM月dd日 HH时mm分ss秒")),
            ParseResult(label: "星期", value: weekdayString(from: date)),
        ]
    }

    private func formatDate(_ date: Date, format: String) -> String {
        let df = DateFormatter()
        df.dateFormat = format
        df.locale = Locale(identifier: "zh_CN")
        return df.string(from: date)
    }

    private func formatDateUTC(_ date: Date, format: String) -> String {
        let df = DateFormatter()
        df.dateFormat = format
        df.timeZone = TimeZone(abbreviation: "UTC")
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: date)
    }

    private func weekdayString(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        df.locale = Locale(identifier: "zh_CN")
        return df.string(from: date)
    }
}
