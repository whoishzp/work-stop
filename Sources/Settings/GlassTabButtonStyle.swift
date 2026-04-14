import SwiftUI

/// A reusable button style for tab-style buttons.
/// Unselected: transparent; Hover: subtle glass tint; Selected: accent color fill.
struct GlassTabButtonStyle: ButtonStyle {
    let isSelected: Bool
    var cornerRadius: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        GlassBody(
            configuration: configuration,
            isSelected: isSelected,
            cornerRadius: cornerRadius
        )
    }

    private struct GlassBody: View {
        let configuration: ButtonStyleConfiguration
        let isSelected: Bool
        let cornerRadius: CGFloat

        @State private var isHovering = false

        var body: some View {
            configuration.label
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
                .animation(.easeInOut(duration: 0.12), value: isHovering)
                .onHover { isHovering = $0 }
        }

        @ViewBuilder
        private var background: some View {
            if isSelected {
                Color.accentColor
            } else if isHovering {
                Color.primary.opacity(0.08)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                Color.clear
            }
        }
    }
}
