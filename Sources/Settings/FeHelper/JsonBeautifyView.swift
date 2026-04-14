import SwiftUI

struct JsonBeautifyView: View {
    @State private var input: String = ""
    @State private var formattedLines: [String] = []
    @State private var error: String = ""
    @State private var isCompact = false
    @State private var copyFeedback: String = ""

    var body: some View {
        HStack(spacing: 10) {
            // Left: input panel
            VStack(spacing: 0) {
                panelHeader(title: "输入 JSON") {
                    Toggle("压缩", isOn: $isCompact)
                        .font(.caption)
                        .toggleStyle(.checkbox)
                        .onChange(of: isCompact) { _ in formatJSON() }
                    Button("清空") { input = ""; formattedLines = []; error = "" }
                        .font(.caption).buttonStyle(.plain).foregroundColor(.secondary)
                        .contentShape(Rectangle())
                    Button("粘贴") {
                        input = NSPasteboard.general.string(forType: .string) ?? ""
                    }
                    .font(.caption).buttonStyle(.plain).foregroundColor(.accentColor)
                    .contentShape(Rectangle())
                }
                Divider()
                TextEditor(text: $input)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: input) { _ in
                        if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            formatJSON()
                        } else {
                            formattedLines = []
                            error = ""
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .cornerRadius(6)

            // Right: output panel
            VStack(spacing: 0) {
                panelHeader(title: "格式化结果") {
                    if !error.isEmpty {
                        Text(error).font(.caption).foregroundColor(.red).lineLimit(1)
                    } else if !copyFeedback.isEmpty {
                        Text(copyFeedback).font(.caption).foregroundColor(.green)
                    }
                    Button("复制全部") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(formattedLines.joined(separator: "\n"), forType: .string)
                        withAnimation { copyFeedback = "已复制 ✓" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { copyFeedback = "" }
                        }
                    }
                    .font(.caption).buttonStyle(.plain)
                    .foregroundColor(formattedLines.isEmpty ? .secondary : .accentColor)
                    .disabled(formattedLines.isEmpty)
                    .contentShape(Rectangle())
                }
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(formattedLines.enumerated()), id: \.0) { idx, line in
                            CodeLineView(
                                lineNumber: idx + 1,
                                line: line,
                                background: .clear,
                                onCopy: { value in
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(value, forType: .string)
                                    withAnimation { copyFeedback = "已复制 ✓" }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation { copyFeedback = "" }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(JsonSyntaxHighlighter.bgColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .cornerRadius(6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func panelHeader<Trailing: View>(title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func formatJSON() {
        error = ""
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let data = input.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            error = "JSON 解析失败"
            formattedLines = []
            return
        }
        let opts: JSONSerialization.WritingOptions = isCompact ? [] : [.prettyPrinted, .sortedKeys]
        if let formatted = try? JSONSerialization.data(withJSONObject: obj, options: opts),
           let str = String(data: formatted, encoding: .utf8) {
            formattedLines = str.components(separatedBy: "\n")
        }
    }
}
