import SwiftUI
import CryptoKit

struct FeHelperView: View {
    enum Tool: String, CaseIterable {
        case jsonBeautify = "JSON美化"
        case jsonDiff     = "JSON比对"
        case encoding     = "信息编码转换"
        case timestamp    = "时间(戳)转换"

        var icon: String {
            switch self {
            case .jsonBeautify: return "doc.text.magnifyingglass"
            case .jsonDiff:     return "arrow.left.arrow.right"
            case .encoding:     return "shuffle"
            case .timestamp:    return "clock.arrow.2.circlepath"
            }
        }
    }

    @State private var selectedTool: Tool = .jsonBeautify

    var body: some View {
        VStack(spacing: 0) {
            toolBar
            Divider()
            toolContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Horizontal Tool Bar

    private var toolBar: some View {
        HStack(spacing: 8) {
            ForEach(Tool.allCases, id: \.self) { tool in
                toolTabButton(tool)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func toolTabButton(_ tool: Tool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) { selectedTool = tool }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tool.icon).font(.system(size: 11, weight: .medium))
                Text(tool.rawValue).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundColor(selectedTool == tool ? .white : .secondary)
        }
        .buttonStyle(GlassTabButtonStyle(isSelected: selectedTool == tool, cornerRadius: 7))
    }

    // MARK: - Tool Content

    @ViewBuilder
    private var toolContent: some View {
        Group {
            switch selectedTool {
            case .jsonBeautify: JsonBeautifyView()
            case .jsonDiff:     JsonDiffView()
            case .encoding:     EncodingView()
            case .timestamp:    TimestampView()
            }
        }
        .id(selectedTool)
        .transition(.identity)
        .animation(.none, value: selectedTool)
    }
}
