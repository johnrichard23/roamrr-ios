import CoreGraphics

/// The colors a button draws with. A nil fill means a text-only button.
public struct ButtonColors: Sendable, Equatable {
    public let fill: ColorToken?
    public let label: ColorToken
}

/// The kinds of button in the app. One per screen is primary.
public enum ButtonKind: Sendable, CaseIterable {
    case primary
    case secondary
    case neutral
    case tertiary
    case destructive

    public func colors(isEnabled: Bool) -> ButtonColors {
        guard isEnabled else {
            switch self {
            case .primary, .secondary, .neutral:
                return ButtonColors(fill: Palette.hairline, label: Palette.inkSecondary)
            case .tertiary, .destructive:
                return ButtonColors(fill: nil, label: Palette.inkMuted)
            }
        }
        switch self {
        case .primary: return ButtonColors(fill: Palette.ink, label: Palette.onInk)
        case .secondary: return ButtonColors(fill: Palette.accentSoft, label: Palette.ink)
        case .neutral: return ButtonColors(fill: Palette.pill, label: Palette.ink)
        case .tertiary: return ButtonColors(fill: nil, label: Palette.accent)
        case .destructive: return ButtonColors(fill: nil, label: Palette.danger)
        }
    }

    public var minHeight: CGFloat {
        switch self {
        case .primary, .secondary, .neutral: return 52
        case .tertiary, .destructive: return 44
        }
    }
}
