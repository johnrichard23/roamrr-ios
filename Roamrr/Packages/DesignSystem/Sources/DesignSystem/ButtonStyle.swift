import SwiftUI

/// The single button style. Pick the look with a `ButtonKind`.
public struct RoamrrButtonStyle: ButtonStyle {
    private let kind: ButtonKind
    @Environment(\.isEnabled) private var isEnabled

    public init(_ kind: ButtonKind) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        let colors = kind.colors(isEnabled: isEnabled)
        configuration.label
            .textRole(.headline)
            .foregroundStyle(colors.label.color)
            .padding(.horizontal, Spacing.xl)
            .frame(minHeight: kind.minHeight)
            .background {
                if let fill = colors.fill {
                    Capsule().fill(fill.color)
                }
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == RoamrrButtonStyle {
    /// For example `.buttonStyle(.roamrr(.primary))`.
    public static func roamrr(_ kind: ButtonKind) -> RoamrrButtonStyle {
        RoamrrButtonStyle(kind)
    }
}
