import DesignSystem
import SwiftUI

extension View {
    /// An amount in a list row: semibold body text with digits of equal width,
    /// so a column of amounts lines up.
    public func rowAmountStyle() -> some View {
        textRole(.body, emphasized: true).monospacedDigit()
    }

    /// The large amount at the top of the balances and add-expense screens.
    public func heroAmountStyle() -> some View {
        modifier(HeroAmountModifier())
    }
}

private struct HeroAmountModifier: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 44

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .semibold).monospacedDigit())
    }
}
