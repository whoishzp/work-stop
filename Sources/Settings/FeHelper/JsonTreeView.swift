import SwiftUI
import AppKit

// MARK: - JsonTreeView (root container)

struct JsonTreeView: View {
    let json: Any

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                JsonNodeView(key: nil, value: json, depth: 0, isLast: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(JsonSyntaxHighlighter.bgColor)
    }
}

// MARK: - Tree Node View

struct JsonNodeView: View {
    let key: String?
    let value: Any
    let depth: Int
    let isLast: Bool

    @State private var isExpanded = true
    @State private var isHovered  = false
    @State private var didCopy    = false

    init(key: String?, value: Any, depth: Int, isLast: Bool = true) {
        self.key   = key
        self.value = value
        self.depth = depth
        self.isLast = isLast
    }

    // MARK: - Type helpers

    private var asDict: [String: Any]? { value as? [String: Any] }
    private var asArr:  [Any]?         { value as? [Any] }
    private var isContainer: Bool      { asDict != nil || asArr != nil }
    private var childCount: Int        { asDict?.count ?? asArr?.count ?? 0 }
    private var trailingComma: String  { isLast ? "" : "," }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if isExpanded && isContainer {
                childrenRows
            }
        }
    }

    // MARK: - Header row

    private var headerRow: some View {
        HStack(spacing: 0) {
            // Indentation
            Color.clear.frame(width: CGFloat(depth) * 16, height: 1)

            // Expand / collapse triangle
            if isContainer {
                Button { withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() } } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(JsonSyntaxHighlighter.lineNumColor)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 14, height: 1)
            }

            // Key label
            if let k = key {
                Text("\"\(k)\"")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(NSColor(JsonSyntaxHighlighter.keyColor)))
                Text(": ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(NSColor(JsonSyntaxHighlighter.punctColor)))
            }

            // Inline value / summary
            inlineValue

            Spacer(minLength: 4)

            // Hover copy button
            if isHovered {
                Button { copyNode() } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(didCopy ? .green : JsonSyntaxHighlighter.lineNumColor)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 2)
        .padding(.leading, 4)
        .background(isHovered ? Color(NSColor.quaternaryLabelColor).opacity(0.25) : Color.clear)
        .onHover { isHovered = $0 }
    }

    // MARK: - Inline value

    @ViewBuilder
    private var inlineValue: some View {
        if let dict = asDict {
            if isExpanded {
                punctText("{")
            } else {
                HStack(spacing: 2) {
                    punctText("{")
                    Text("...}")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    punctText(trailingComma)
                    commentText("// \(dict.count) \(dict.count == 1 ? "key" : "keys")")
                }
            }
        } else if let arr = asArr {
            if isExpanded {
                punctText("[")
            } else {
                HStack(spacing: 2) {
                    punctText("[")
                    Text("...]")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    punctText(trailingComma)
                    commentText("// \(arr.count) items")
                }
            }
        } else if let str = value as? String {
            Text("\"\(escapeForDisplay(str))\"")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(NSColor(JsonSyntaxHighlighter.stringColor)))
                .textSelection(.enabled)
            if !isLast { punctText(",") }
        } else if let num = value as? NSNumber {
            if isBool(num) {
                Text(num.boolValue ? "true" : "false")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(NSColor(JsonSyntaxHighlighter.boolNullColor)))
                    .textSelection(.enabled)
            } else {
                Text(num.stringValue)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(NSColor(JsonSyntaxHighlighter.numberColor)))
                    .textSelection(.enabled)
            }
            if !isLast { punctText(",") }
        } else if value is NSNull {
            Text("null")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(NSColor(JsonSyntaxHighlighter.boolNullColor)))
                .textSelection(.enabled)
            if !isLast { punctText(",") }
        }
    }

    // MARK: - Children

    @ViewBuilder
    private var childrenRows: some View {
        if let dict = asDict {
            let keys = dict.keys.sorted()
            ForEach(Array(keys.enumerated()), id: \.element) { idx, k in
                JsonNodeView(key: k, value: dict[k]!, depth: depth + 1, isLast: idx == keys.count - 1)
            }
            closingLine("}" + trailingComma)
        } else if let arr = asArr {
            ForEach(Array(arr.enumerated()), id: \.offset) { idx, item in
                JsonNodeView(key: nil, value: item, depth: depth + 1, isLast: idx == arr.count - 1)
            }
            closingLine("]" + trailingComma)
        }
    }

    private func closingLine(_ bracket: String) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: CGFloat(depth) * 16 + 14, height: 1)
            punctText(bracket)
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.leading, 4)
    }

    // MARK: - Helpers

    private func punctText(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(Color(NSColor(JsonSyntaxHighlighter.punctColor)))
    }

    private func commentText(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(Color(NSColor.tertiaryLabelColor))
            .italic()
    }

    private func isBool(_ n: NSNumber) -> Bool {
        CFGetTypeID(n as CFTypeRef) == CFBooleanGetTypeID()
    }

    private func escapeForDisplay(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "\\r")
         .replacingOccurrences(of: "\t", with: "\\t")
    }

    private func copyNode() {
        let str: String
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
            str = s
        } else if let s = value as? String {
            str = s
        } else if let n = value as? NSNumber {
            str = isBool(n) ? (n.boolValue ? "true" : "false") : n.stringValue
        } else if value is NSNull {
            str = "null"
        } else {
            str = "\(value)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        withAnimation { didCopy = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { didCopy = false }
        }
    }
}
