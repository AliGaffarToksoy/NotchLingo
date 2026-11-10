import SwiftUI

/// A small shared vocabulary: system typography, semantic surfaces, one accent.
enum LingoStyle {
    static let accent = Color.teal
    static let page = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor).opacity(0.45)
    static let radius: CGFloat = 16
}

struct QuietIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(hovering ? Color.primary.opacity(0.08) : .clear, in: Circle())
                .contentShape(Circle())
        }.buttonStyle(.plain).onHover { hovering = $0 }.help(label).accessibilityLabel(label)
    }
}

extension View {
    func cardSurface() -> some View {
        padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(LingoStyle.surface, in: RoundedRectangle(cornerRadius: LingoStyle.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: LingoStyle.radius, style: .continuous).strokeBorder(LingoStyle.separator, lineWidth: 0.5))
    }
}
