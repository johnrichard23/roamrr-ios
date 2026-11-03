import RoamrrDesign
import SwiftUI

extension View {
    /// An inline navigation bar with a solid background, so content scrolling under it
    /// never shows through the status bar or collides with the title.
    func solidNavigationBar() -> some View {
        modifier(SolidNavigationBar())
    }
}

private struct SolidNavigationBar: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
