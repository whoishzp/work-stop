import SwiftUI
import AppKit

// MARK: - Auto-formatting NSTextView subclass

final class AutoFormatJsonTextView: NSTextView {
    override func paste(_ sender: Any?) {
        super.paste(sender)
        autoFormatIfJson()
    }

    override func pasteAsPlainText(_ sender: Any?) {
        super.pasteAsPlainText(sender)
        autoFormatIfJson()
    }

    private func autoFormatIfJson() {
        let current = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty,
              let data = current.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: obj,
                    options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: formatted, encoding: .utf8),
              str != string
        else { return }
        let range = NSRange(location: 0, length: (string as NSString).length)
        insertText(str, replacementRange: range)
    }
}

/// Editable NSTextView panel with JSON syntax highlighting and diff-line background support.
struct JsonEditorPanel: NSViewRepresentable {
    @Binding var text: String
    var diffLineIndices: Set<Int>

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = AutoFormatJsonTextView()
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        scrollView.documentView = textView

        guard let textView = scrollView.documentView as? AutoFormatJsonTextView else { return scrollView }

        textView.isEditable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = context.coordinator
        textView.allowsUndo = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? AutoFormatJsonTextView else { return }
        guard !context.coordinator.isEditing else { return }

        context.coordinator.isUpdating = true
        defer { context.coordinator.isUpdating = false }

        let storage = textView.textStorage!
        let attributed = buildAttributedString(text, diffIndices: diffLineIndices)
        storage.setAttributedString(attributed)
    }

    private func buildAttributedString(_ text: String, diffIndices: Set<Int>) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let defaultAttrs: [NSAttributedString.Key: Any] = [.font: font]
        let lines = text.components(separatedBy: "\n")
        let result = NSMutableAttributedString()

        for (i, line) in lines.enumerated() {
            // Syntax highlight the line
            let highlightedLine = attributedLine(line, font: font)

            // Apply diff background if needed
            if diffIndices.contains(i) {
                let bg = NSColor.yellow.withAlphaComponent(0.18)
                highlightedLine.addAttribute(.backgroundColor, value: bg,
                                             range: NSRange(location: 0, length: highlightedLine.length))
            }

            // Append newline (no special bg)
            if i < lines.count - 1 {
                let nl = NSMutableAttributedString(string: "\n", attributes: defaultAttrs)
                highlightedLine.append(nl)
            }
            result.append(highlightedLine)
        }
        return result
    }

    private func attributedLine(_ line: String, font: NSFont) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        var i = line.startIndex
        let end = line.endIndex

        func append(_ substr: Substring, color: NSColor) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            result.append(NSAttributedString(string: String(substr), attributes: attrs))
        }

        while i < end {
            let ch = line[i]
            // Whitespace
            if ch.isWhitespace {
                append(line[i...i], color: .clear)
                i = line.index(after: i)
                continue
            }
            // String
            if ch == "\"" {
                let (token, next) = readString(line, from: i)
                let afterToken = skipWS(line, from: next)
                let isKey = afterToken < end && line[afterToken] == ":"
                let color = isKey ? NSColor(JsonSyntaxHighlighter.keyColor) : NSColor(JsonSyntaxHighlighter.stringColor)
                append(token[token.startIndex...], color: color)
                i = next
                continue
            }
            // Number
            if ch.isNumber || ch == "-" {
                let (token, next) = readNumber(line, from: i)
                append(token[token.startIndex...], color: NSColor(JsonSyntaxHighlighter.numberColor))
                i = next
                continue
            }
            // true/false/null
            var matched = false
            for kw in ["true", "false", "null"] {
                if line[i...].hasPrefix(kw) {
                    let kwEnd = line.index(i, offsetBy: kw.count, limitedBy: end) ?? end
                    let range = i..<kwEnd
                    append(line[range], color: NSColor(JsonSyntaxHighlighter.boolNullColor))
                    i = kwEnd
                    matched = true
                    break
                }
            }
            if matched { continue }
            // Punctuation
            append(line[i...i], color: NSColor(JsonSyntaxHighlighter.punctColor))
            i = line.index(after: i)
        }
        return result
    }

    private func readString(_ s: String, from start: String.Index) -> (Substring, String.Index) {
        var i = s.index(after: start)
        var esc = false
        while i < s.endIndex {
            let c = s[i]
            if esc { esc = false }
            else if c == "\\" { esc = true }
            else if c == "\"" { return (s[start...i], s.index(after: i)) }
            i = s.index(after: i)
        }
        return (s[start...], s.endIndex)
    }

    private func readNumber(_ s: String, from start: String.Index) -> (Substring, String.Index) {
        var i = start
        while i < s.endIndex {
            let c = s[i]
            if c.isNumber || c == "." || c == "-" || c == "e" || c == "E" || c == "+" { i = s.index(after: i) }
            else { break }
        }
        return (s[start..<i], i)
    }

    private func skipWS(_ s: String, from idx: String.Index) -> String.Index {
        var i = idx
        while i < s.endIndex && s[i].isWhitespace { i = s.index(after: i) }
        return i
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JsonEditorPanel
        var isUpdating = false
        var isEditing = false

        init(_ parent: JsonEditorPanel) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }
            isEditing = true
            let newText = textView.string
            if parent.text != newText {
                parent.text = newText
            }
            isEditing = false
        }
    }
}
