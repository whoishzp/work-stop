import SwiftUI

enum JsonSyntaxHighlighter {
    // Light theme colors (adapts to system appearance)
    static let bgColor       = Color(NSColor.textBackgroundColor)
    static let lineNumColor  = Color(NSColor.tertiaryLabelColor)
    static let keyColor      = Color(red: 0.13, green: 0.37, blue: 0.80)   // blue
    static let stringColor   = Color(red: 0.72, green: 0.24, blue: 0.02)   // dark orange-red
    static let numberColor   = Color(red: 0.06, green: 0.52, blue: 0.26)   // dark green
    static let boolNullColor = Color(red: 0.52, green: 0.10, blue: 0.70)   // dark purple
    static let punctColor    = Color(NSColor.secondaryLabelColor)
    static let defaultColor  = Color(NSColor.labelColor)

    /// Highlight a single JSON line, returning an AttributedString.
    static func highlight(_ line: String) -> AttributedString {
        var result = AttributedString()
        var i = line.startIndex
        let end = line.endIndex

        while i < end {
            let ch = line[i]

            // Whitespace
            if ch.isWhitespace {
                var ws = AttributedString(String(ch))
                ws.foregroundColor = .clear
                result += ws
                i = line.index(after: i)
                continue
            }

            // String token
            if ch == "\"" {
                let (token, next) = readString(line, from: i)
                var attr = AttributedString(token)
                // Determine if this is a key (followed by `:` after whitespace)
                let afterToken = skipWhitespace(line, from: next)
                let isKey = afterToken < end && line[afterToken] == ":"
                attr.foregroundColor = isKey ? NSColor(keyColor) : NSColor(stringColor)
                result += attr
                i = next
                continue
            }

            // Number
            if ch.isNumber || ch == "-" {
                let (token, next) = readNumber(line, from: i)
                var attr = AttributedString(token)
                attr.foregroundColor = NSColor(numberColor)
                result += attr
                i = next
                continue
            }

            // true / false / null
            for kw in ["true", "false", "null"] {
                if line[i...].hasPrefix(kw) {
                    let kwEnd = line.index(i, offsetBy: kw.count)
                    var attr = AttributedString(kw)
                    attr.foregroundColor = NSColor(boolNullColor)
                    result += attr
                    i = kwEnd
                    break
                }
            }
            if i < end && (line[i] == "t" || line[i] == "f" || line[i] == "n") {
                // already handled above, but guard against infinite loop
                var attr = AttributedString(String(line[i]))
                attr.foregroundColor = NSColor(defaultColor)
                result += attr
                i = line.index(after: i)
                continue
            }

            // Punctuation
            var attr = AttributedString(String(ch))
            attr.foregroundColor = NSColor(punctColor)
            result += attr
            i = line.index(after: i)
        }

        return result
    }

    private static func readString(_ s: String, from start: String.Index) -> (String, String.Index) {
        var i = s.index(after: start) // skip opening "
        var escaped = false
        while i < s.endIndex {
            let c = s[i]
            if escaped { escaped = false }
            else if c == "\\" { escaped = true }
            else if c == "\"" {
                let endIdx = s.index(after: i)
                return (String(s[start..<endIdx]), endIdx)
            }
            i = s.index(after: i)
        }
        return (String(s[start...]), s.endIndex)
    }

    private static func readNumber(_ s: String, from start: String.Index) -> (String, String.Index) {
        var i = start
        while i < s.endIndex {
            let c = s[i]
            if c.isNumber || c == "." || c == "-" || c == "e" || c == "E" || c == "+" {
                i = s.index(after: i)
            } else { break }
        }
        return (String(s[start..<i]), i)
    }

    private static func skipWhitespace(_ s: String, from idx: String.Index) -> String.Index {
        var i = idx
        while i < s.endIndex && s[i].isWhitespace { i = s.index(after: i) }
        return i
    }
}

// MARK: - Line-numbered + syntax-highlighted text view

struct CodeLineView: View {
    let lineNumber: Int
    let line: String
    let background: Color
    let onCopy: ((String) -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text("\(lineNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(JsonSyntaxHighlighter.lineNumColor)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 10)

            // Syntax highlighted content
            Text(JsonSyntaxHighlighter.highlight(line))
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Copy button on hover
            if isHovered, let onCopy = onCopy {
                Button {
                    onCopy(extractValue(from: line))
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(JsonSyntaxHighlighter.lineNumColor)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 2)
        .padding(.leading, 4)
        .background(isHovered ? Color.white.opacity(0.05) : background)
        .onHover { isHovered = $0 }
    }

    private func extractValue(from line: String) -> String {
        // Try to extract just the value part after ":"
        if let colonRange = line.range(of: ":") {
            let valueStr = String(line[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ","))
            if !valueStr.isEmpty { return valueStr }
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
