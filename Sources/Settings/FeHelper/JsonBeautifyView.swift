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
                        Text(error).font(.caption).foregroundColor(.red).lineLimit(3)
                            .help(error)
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

        guard let data = trimmed.data(using: .utf8) else {
            error = "输入包含无效字符"
            parsedJson = nil
            return
        }

        // 1. Try direct parse
        var directError: Error?
        if let obj = try? { () throws -> Any in try JSONSerialization.jsonObject(with: data) }() {
            parsedJson = deepParseNestedJsonStrings(obj)
            return
        }
        do { _ = try JSONSerialization.jsonObject(with: data) } catch { directError = error }

        // 2. Input has real " delimiters but literal \n sequences for structural whitespace.
        //    Context-aware scan: replace \n OUTSIDE string values with actual newlines;
        //    leave \n INSIDE strings untouched (they're already valid JSON escapes).
        let structurallyFixed = expandLiteralEscapesOutsideStrings(trimmed)
        if let sfData = structurallyFixed.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: sfData) {
            parsedJson = deepParseNestedJsonStrings(obj)
            return
        }

        // 3. Fully-escaped payload (all " → \", newlines → \n, etc.)
        //    Wrap in quotes → decode as JSON string → re-escape control chars
        //    that ended up bare inside JSON string values → parse as JSON.
        let wrapped = "\"" + trimmed + "\""
        if let wData = wrapped.data(using: .utf8),
           let unescaped = try? JSONSerialization.jsonObject(with: wData) as? String {
            let reEscaped = reEscapeControlCharsInStringValues(unescaped)
            if let inner = reEscaped.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: inner) {
                parsedJson = deepParseNestedJsonStrings(obj)
                return
            }
        }

        error = directError?.localizedDescription ?? "JSON 解析失败"
        parsedJson = nil
    }

    /// Context-aware pass over an input that uses real `"` as string delimiters but
    /// has literal `\n` / `\r` / `\t` sequences where actual whitespace should be.
    /// Replaces those 2-char sequences ONLY when they appear OUTSIDE string values so
    /// the resulting text is structurally valid JSON.  Escape sequences inside strings
    /// (e.g. `\n` meaning newline in a string value) are passed through unchanged.
    private func expandLiteralEscapesOutsideStrings(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var insideString = false
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            let next = text.index(after: i)
            if insideString {
                if ch == "\\" && next < text.endIndex {
                    result.append(ch)
                    result.append(text[next])
                    i = text.index(after: next)
                    continue
                }
                if ch == "\"" { insideString = false }
                result.append(ch)
            } else {
                if ch == "\\" && next < text.endIndex {
                    switch text[next] {
                    case "n":
                        result.append("\n")
                        i = text.index(after: next)
                        continue
                    case "r":
                        result.append("\r")
                        i = text.index(after: next)
                        continue
                    case "t":
                        result.append("\t")
                        i = text.index(after: next)
                        continue
                    default:
                        break
                    }
                }
                if ch == "\"" { insideString = true }
                result.append(ch)
            }
            i = text.index(after: i)
        }
        return result
    }

    /// Scans a JSON text and re-escapes any bare control characters (U+0000–U+001F)
    /// that appear inside JSON string values (e.g., actual LF from a prior unescape step).
    /// Characters outside string values (structural whitespace) are passed through unchanged.
    private func reEscapeControlCharsInStringValues(_ json: String) -> String {
        var result = ""
        result.reserveCapacity(json.count + 64)
        var insideString = false
        var prevWasBackslash = false
        for ch in json {
            if insideString {
                if prevWasBackslash {
                    result.append(ch)
                    prevWasBackslash = false
                } else if ch == "\\" {
                    result.append(ch)
                    prevWasBackslash = true
                } else if ch == "\"" {
                    insideString = false
                    result.append(ch)
                } else if let ascii = ch.asciiValue, ascii < 0x20 {
                    switch ch {
                    case "\n": result += "\\n"
                    case "\r": result += "\\r"
                    case "\t": result += "\\t"
                    default:   result += String(format: "\\u%04X", ascii)
                    }
                } else {
                    result.append(ch)
                }
            } else {
                if ch == "\"" { insideString = true }
                result.append(ch)
            }
        }
        return result
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
