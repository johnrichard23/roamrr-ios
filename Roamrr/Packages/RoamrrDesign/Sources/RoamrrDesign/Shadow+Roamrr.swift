import DesignSystem
import SwiftUI

extension View {
    /// The one shadow for cards, chips and buttons that float over the map: the theme's elevation.
    public func floatingShadow() -> some View {
        modifier(FloatingShadow())
    }

    /// A tighter, darker shadow for pins and small markers that sit on the map.
    /// `softened` is for a marker that steps back, like a pin that is not the one being followed.
    public func markerShadow(softened: Bool = false) -> some View {
        shadow(color: .black.opacity(softened ? 0.15 : 0.25), radius: 3, y: 1.5)
    }
}

private struct FloatingShadow: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.shadow(
            color: theme.elevation.color,
            radius: theme.elevation.radius,
            y: theme.elevation.offsetY
        )
    }
}
