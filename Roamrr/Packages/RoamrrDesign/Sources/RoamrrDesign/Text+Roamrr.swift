import DesignSystem
import SwiftUI

extension View {
    /// An amount in a list row: semibold body text with digits of equal width,
    /// so a column of amounts lines up.
    public func rowAmountStyle() -> some View {
        textRole(.body, emphasized: true).monospacedDigit()
    }

    /// The one display line at the top of Trips home: New York, regular, 30 pt.
    public func displayTitleStyle() -> some View {
        modifier(DisplayTitleModifier())
    }

    /// The question at the top of a wizard step: New York, regular, 26 pt.
    public func stepTitleStyle() -> some View {
        modifier(StepTitleModifier())
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

private struct DisplayTitleModifier: ViewModifier {
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 30

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .regular, design: .serif))
    }
}

private struct StepTitleModifier: ViewModifier {
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 26

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .regular, design: .serif))
    }
}
