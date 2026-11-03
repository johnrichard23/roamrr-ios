import RoamrrDesign
import SwiftUI

/// The soft square behind a document's icon. It grows with the text size, and goes away at the largest
/// sizes so the title gets the width.
struct DocumentIconTile: View {
    let symbol: String
    var base: CGFloat = 44

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        if !typeSize.isAccessibilitySize {
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold)).foregroundStyle(theme.accent)
                .frame(width: base * scale, height: base * scale)
                .background(Palette.accentSoft.color, in: RoundedRectangle(cornerRadius: base * 0.32, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}
