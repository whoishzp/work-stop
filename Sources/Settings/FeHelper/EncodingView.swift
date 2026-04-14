import SwiftUI
import CryptoKit
import Compression

struct EncodingView: View {
    enum Operation: String, CaseIterable, Identifiable {
        // Encode
        case unicodeEncode  = "Unicode编码"
        case urlEncode      = "URL编码(%开头)"
        case utf16Encode    = "UTF16编码(\\x开头)"
        case base64Encode   = "Base64编码"
        case md5            = "MD5计算"
        case hexEncode      = "十六进制编码"
        case sha1           = "Sha1加密"
        case htmlBasic      = "HTML普通编码"
        case htmlFull       = "HTML深度编码"
        // Decode
        case unicodeDecode  = "Unicode解码(\\u开头)"
        case urlDecode      = "URL解码(%开头)"
        case utf16Decode    = "UTF16解码(\\x开头)"
        case base64Decode   = "Base64解码"
        case hexDecode      = "十六进制解码"
        case htmlDecode     = "HTML实体解码"
        case urlParams      = "URL参数解析"
        case jwtDecode      = "JWT解码"
        case cookieParse    = "Cookie格式化"

        var id: String { rawValue }

        var isEncode: Bool {
            switch self {
            case .unicodeEncode, .urlEncode, .utf16Encode, .base64Encode,
                 .md5, .hexEncode, .sha1, .htmlBasic, .htmlFull:
                return true
            default:
                return false
            }
        }
    }

    static let encodeOps: [Operation] = [
        .unicodeEncode, .urlEncode, .utf16Encode, .base64Encode,
        .md5, .hexEncode, .sha1, .htmlBasic, .htmlFull
    ]
    static let decodeOps: [Operation] = [
        .unicodeDecode, .urlDecode, .utf16Decode, .base64Decode,
        .hexDecode, .htmlDecode, .urlParams, .jwtDecode, .cookieParse
    ]

    @State private var input: String = ""
    @State private var output: String = ""
    @State private var selectedOp: Operation = .unicodeEncode

    var body: some View {
        VStack(spacing: 0) {
            // Input area
            TextEditor(text: $input)
                .font(.system(size: 13, design: .monospaced))
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                .padding(16)

            Divider()

            // Operation selection
            VStack(alignment: .leading, spacing: 8) {
                opRow(label: "加密：", ops: Self.encodeOps)
                opRow(label: "解密：", ops: Self.decodeOps)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Buttons
            HStack {
                Spacer()
                Button("清空") {
                    input = ""; output = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                Button("转换") { convert() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            // Output area
            VStack(alignment: .leading, spacing: 6) {
                Text("当前数据解析结果如下：")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextEditor(text: $output)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Op Row

    private func opRow(label: String, ops: [Operation]) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 46, alignment: .trailing)
            FlowLayout(spacing: 4) {
                ForEach(ops) { op in
                    opButton(op)
                }
            }
        }
    }

    private func opButton(_ op: Operation) -> some View {
        Button {
            selectedOp = op
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(selectedOp == op ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                Text(op.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(selectedOp == op ? .accentColor : .secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.0001))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Conversion

    private func convert() {
        let src = input
        switch selectedOp {
        case .unicodeEncode:
            output = src.unicodeScalars.map { scalar in
                if scalar.value < 128 { return "\\u00\(String(format: "%02x", scalar.value))" }
                return "\\u\(String(format: "%04x", scalar.value))"
            }.joined()
        case .urlEncode:
            output = src.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? src
        case .utf16Encode:
            output = src.utf16.map { "\\x\(String(format: "%04x", $0))" }.joined()
        case .base64Encode:
            output = Data(src.utf8).base64EncodedString()
        case .md5:
            let digest = Insecure.MD5.hash(data: Data(src.utf8))
            output = digest.map { String(format: "%02hhx", $0) }.joined()
        case .hexEncode:
            output = Data(src.utf8).map { String(format: "%02x", $0) }.joined()
        case .sha1:
            let digest = Insecure.SHA1.hash(data: Data(src.utf8))
            output = digest.map { String(format: "%02hhx", $0) }.joined()
        case .htmlBasic:
            output = src
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#x27;")
        case .htmlFull:
            output = src.unicodeScalars.map { scalar in
                if scalar.value < 128 && scalar.value > 31 { return String(scalar) }
                return "&#\(scalar.value);"
            }.joined()
        case .unicodeDecode:
            output = decodeUnicode(src)
        case .urlDecode:
            output = src.removingPercentEncoding ?? src
        case .utf16Decode:
            output = decodeUTF16(src)
        case .base64Decode:
            if let data = Data(base64Encoded: src), let str = String(data: data, encoding: .utf8) {
                output = str
            } else { output = "Base64 解码失败" }
        case .hexDecode:
            output = decodeHex(src)
        case .htmlDecode:
            output = decodeHTMLEntities(src)
        case .urlParams:
            output = parseURLParams(src)
        case .jwtDecode:
            output = decodeJWT(src)
        case .cookieParse:
            output = parseCookie(src)
        }
    }

    // MARK: - Decode Helpers

    private func decodeUnicode(_ s: String) -> String {
        var result = s
        let pattern = "\\\\u([0-9a-fA-F]{4})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return s }
        let nsStr = s as NSString
        let matches = regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed()
        for match in matches {
            if let hexRange = Range(match.range(at: 1), in: s),
               let codePoint = UInt32(s[hexRange], radix: 16),
               let scalar = Unicode.Scalar(codePoint) {
                let char = String(scalar)
                let fullRange = Range(match.range, in: s)!
                result = result.replacingCharacters(in: fullRange, with: char)
            }
            _ = nsStr
        }
        return result
    }

    private func decodeUTF16(_ s: String) -> String {
        var codes: [UInt16] = []
        let parts = s.components(separatedBy: "\\x").filter { !$0.isEmpty }
        for part in parts {
            let hexPart = String(part.prefix(4))
            if let code = UInt16(hexPart, radix: 16) {
                codes.append(code)
            }
        }
        return String(decoding: codes, as: UTF16.self)
    }

    private func decodeHex(_ s: String) -> String {
        let clean = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "0x", with: "")
        var bytes: [UInt8] = []
        var i = clean.startIndex
        while i < clean.endIndex {
            let next = clean.index(i, offsetBy: 2, limitedBy: clean.endIndex) ?? clean.endIndex
            if let byte = UInt8(clean[i..<next], radix: 16) { bytes.append(byte) }
            i = next
        }
        return String(bytes: bytes, encoding: .utf8) ?? "十六进制解码失败"
    }

    private func decodeHTMLEntities(_ s: String) -> String {
        var result = s
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#x27;", "'"), ("&apos;", "'"),
            ("&nbsp;", " "), ("&copy;", "©"), ("&reg;", "®")
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        // &#DECIMAL;
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
            for match in matches {
                if let range = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[range]),
                   let scalar = Unicode.Scalar(code) {
                    let fullRange = Range(match.range, in: result)!
                    result = result.replacingCharacters(in: fullRange, with: String(scalar))
                }
            }
        }
        return result
    }

    private func parseURLParams(_ s: String) -> String {
        let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: String
        if let url = URL(string: cleaned), let q = url.query { query = q }
        else if cleaned.contains("=") { query = cleaned }
        else { return "无法解析 URL 参数" }
        let pairs = query.components(separatedBy: "&")
        return pairs.map { pair in
            let kv = pair.components(separatedBy: "=")
            let k = kv[0].removingPercentEncoding ?? kv[0]
            let v = (kv.count > 1 ? kv[1...].joined(separator: "=") : "").removingPercentEncoding ?? ""
            return "\(k) = \(v)"
        }.joined(separator: "\n")
    }

    private func decodeJWT(_ s: String) -> String {
        let parts = s.components(separatedBy: ".")
        guard parts.count >= 2 else { return "不是有效的 JWT 格式（期望 3 段，用.分隔）" }
        var result = ""
        for (i, part) in parts.prefix(2).enumerated() {
            // JWT base64url padding
            var padded = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            while padded.count % 4 != 0 { padded += "=" }
            if let data = Data(base64Encoded: padded),
               let json = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
               let str = String(data: pretty, encoding: .utf8) {
                result += (i == 0 ? "【Header】\n" : "\n【Payload】\n") + str + "\n"
            }
        }
        return result.isEmpty ? "JWT 解码失败" : result
    }

    private func parseCookie(_ s: String) -> String {
        let pairs = s.components(separatedBy: ";")
        return pairs.map { pair in
            let kv = pair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
            let k = kv[0].trimmingCharacters(in: .whitespaces)
            let v = (kv.count > 1 ? kv[1...].joined(separator: "=") : "").removingPercentEncoding ?? ""
            return "\(k) = \(v)"
        }.joined(separator: "\n")
    }
}

// MARK: - Simple FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowHeight + spacing; x = 0; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing; x = bounds.minX; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
