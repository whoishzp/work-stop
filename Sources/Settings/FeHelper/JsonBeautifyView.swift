import SwiftUI

struct JsonBeautifyView: View {
    @State private var input: String = ""
    @State private var formattedLines: [String] = []
    @State private var error: String = ""
    @State private var isCompact = false
    @State private var copyFeedback: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // Left: input
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("输入 JSON")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Toggle("压缩", isOn: $isCompact)
                        .font(.caption)
                        .toggleStyle(.checkbox)
                        .onChange(of: isCompact) { _ in formatJSON() }
                    Button("清空") { input = ""; formattedLines = []; error = "" }
                        .font(.caption).buttonStyle(.plain).foregroundColor(.secondary)
                    Button("粘贴") {
                        input = NSPasteboard.general.string(forType: .string) ?? ""
                    }
                    .font(.caption).buttonStyle(.plain).foregroundColor(.accentColor)
                }
                TextEditor(text: $input)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    .onChange(of: input) { _ in
                        if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            formatJSON()
                        } else {
                            formattedLines = []
                            error = ""
                        }
                    }
            }
            .padding(12)

            // Divider with status
            VStack(spacing: 6) {
                if !error.isEmpty {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                } else if !formattedLines.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                }
            }
            .frame(width: 24)

            // Right: syntax highlighted output
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("格式化结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !error.isEmpty {
                        Text(error).font(.caption).foregroundColor(.red).lineLimit(1)
                    } else if !copyFeedback.isEmpty {
                        Text(copyFeedback).font(.caption).foregroundColor(.green).transition(.opacity)
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
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

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
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            }
            .cornerRadius(6)
            .padding(.leading, 4)
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
