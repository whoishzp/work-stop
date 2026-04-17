import SwiftUI

struct JsonBeautifyView: View {
    @State private var input: String = ""
    @State private var parsedJson: Any? = nil
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
                    Button("清空") { input = ""; parsedJson = nil; error = "" }
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
                            parsedJson = nil
                            error = ""
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .cornerRadius(6)

            // Right: output panel (tree view)
            VStack(spacing: 0) {
                panelHeader(title: "格式化结果") {
                    if !error.isEmpty {
                        Text(error).font(.caption).foregroundColor(.red).lineLimit(1)
                    } else if !copyFeedback.isEmpty {
                        Text(copyFeedback).font(.caption).foregroundColor(.green)
                    }
                    Button("复制全部") {
                        guard let json = parsedJson else { return }
                        let opts: JSONSerialization.WritingOptions = isCompact
                            ? []
                            : [.prettyPrinted, .sortedKeys]
                        if let data = try? JSONSerialization.data(withJSONObject: json, options: opts),
                           let str = String(data: data, encoding: .utf8) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(str, forType: .string)
                            withAnimation { copyFeedback = "已复制 ✓" }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { copyFeedback = "" }
                            }
                        }
                    }
                    .font(.caption).buttonStyle(.plain)
                    .foregroundColor(parsedJson == nil ? .secondary : .accentColor)
                    .disabled(parsedJson == nil)
                    .contentShape(Rectangle())
                }
                Divider()
                if let json = parsedJson {
                    JsonTreeView(json: json)
                } else {
                    Color(NSColor.textBackgroundColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .cornerRadius(6)
        }
        .padding(16)
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
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1. Try direct parse
        if let data = trimmed.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            parsedJson = deepParseNestedJsonStrings(obj)
            return
        }

        // 2. Input may be a JSON-string-escaped payload (literal \n, \", etc.)
        //    Wrap in quotes and decode as JSON string, then re-parse the result.
        let wrapped = "\"" + trimmed + "\""
        if let wData = wrapped.data(using: .utf8),
           let unescaped = try? JSONSerialization.jsonObject(with: wData) as? String,
           let inner = unescaped.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: inner) {
            parsedJson = deepParseNestedJsonStrings(obj)
            return
        }

        error = "JSON 解析失败"
        parsedJson = nil
    }

    /// Recursively walks the parsed JSON and replaces any string value that is
    /// itself valid JSON with the parsed object, enabling nested tree rendering.
    private func deepParseNestedJsonStrings(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            return dict.mapValues { deepParseNestedJsonStrings($0) }
        }
        if let arr = value as? [Any] {
            return arr.map { deepParseNestedJsonStrings($0) }
        }
        if let str = value as? String {
            let candidate = str.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (candidate.hasPrefix("{") && candidate.hasSuffix("}"))
               || (candidate.hasPrefix("[") && candidate.hasSuffix("]")) else {
                return str
            }
            if let data = candidate.data(using: .utf8),
               let nested = try? JSONSerialization.jsonObject(with: data) {
                return deepParseNestedJsonStrings(nested)
            }
        }
        return value
    }
}
