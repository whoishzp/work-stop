import SwiftUI

struct JsonDiffView: View {
    @State private var leftRaw: String = ""
    @State private var rightRaw: String = ""
    @State private var leftFormatted: String = ""
    @State private var rightFormatted: String = ""
    @State private var leftDiffLines: Set<Int> = []
    @State private var rightDiffLines: Set<Int> = []
    @State private var diffCount = 0
    @State private var leftError: String = ""
    @State private var rightError: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack(spacing: 8) {
                if leftError.isEmpty && rightError.isEmpty {
                    if leftFormatted.isEmpty && rightFormatted.isEmpty {
                        Text("直接在下方粘贴或编辑 JSON，自动格式化并对比差异")
                            .font(.caption).foregroundColor(JsonSyntaxHighlighter.lineNumColor)
                    } else if diffCount == 0 {
                        Label("完全相同", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundColor(.green)
                    } else {
                        Label("\(diffCount) 处差异（黄色高亮）", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundColor(.orange)
                    }
                } else {
                    if !leftError.isEmpty {
                        Label("A: \(leftError)", systemImage: "xmark.circle.fill")
                            .font(.caption).foregroundColor(.red)
                    }
                    if !rightError.isEmpty {
                        Label("B: \(rightError)", systemImage: "xmark.circle.fill")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                Spacer()
                if !leftRaw.isEmpty || !rightRaw.isEmpty {
                    Button("清空") {
                        leftRaw = ""; rightRaw = ""
                        leftFormatted = ""; rightFormatted = ""
                        leftDiffLines = []; rightDiffLines = []
                        leftError = ""; rightError = ""
                        diffCount = 0
                    }
                    .font(.caption).buttonStyle(.plain).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Two editable JSON panels side by side
            HStack(spacing: 0) {
                panelView(title: "JSON A", text: $leftFormatted, diffLines: leftDiffLines)
                    .onChange(of: leftFormatted) { _ in processChange(side: .left) }

                Divider().background(Color.gray.opacity(0.4))

                panelView(title: "JSON B", text: $rightFormatted, diffLines: rightDiffLines)
                    .onChange(of: rightFormatted) { _ in processChange(side: .right) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Panel

    private func panelView(title: String, text: Binding<String>, diffLines: Set<Int>) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(JsonSyntaxHighlighter.lineNumColor)
                Spacer()
                Button("格式化") {
                    if title == "JSON A" { autoFormat(side: .left) }
                    else { autoFormat(side: .right) }
                }
                .font(.system(size: 10)).buttonStyle(.plain)
                .foregroundColor(JsonSyntaxHighlighter.lineNumColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(JsonSyntaxHighlighter.bgColor)

            JsonEditorPanel(text: text, diffLineIndices: diffLines)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Processing

    enum Side { case left, right }

    private func processChange(side: Side) {
        // Try to format + update diff
        let raw = side == .left ? leftFormatted : rightFormatted

        // Don't auto-format while typing unless it's valid JSON
        // Just compute diff based on current content
        computeDiff()
    }

    private func autoFormat(side: Side) {
        let raw = side == .left ? leftFormatted : rightFormatted
        if let formatted = tryFormat(raw) {
            if side == .left { leftFormatted = formatted }
            else { rightFormatted = formatted }
        }
    }

    private func tryFormat(_ s: String) -> String? {
        guard !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: formatted, encoding: .utf8)
        else { return nil }
        return str
    }

    private func computeDiff() {
        leftError = ""; rightError = ""
        let la = leftFormatted; let ra = rightFormatted

        guard !la.isEmpty || !ra.isEmpty else {
            leftDiffLines = []; rightDiffLines = []; diffCount = 0; return
        }

        let lLines = la.components(separatedBy: "\n")
        let rLines = ra.components(separatedBy: "\n")
        let maxLen = max(lLines.count, rLines.count)

        var lDiff = Set<Int>(); var rDiff = Set<Int>(); var diffs = 0
        for i in 0..<maxLen {
            let l = i < lLines.count ? lLines[i] : ""
            let r = i < rLines.count ? rLines[i] : ""
            if l != r {
                lDiff.insert(i); rDiff.insert(i); diffs += 1
            }
        }
        leftDiffLines = lDiff; rightDiffLines = rDiff; diffCount = diffs
    }
}
