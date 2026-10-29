import SwiftUI

/// The text roles. Fonts are system fonts, so they already carry the platform's tracking
/// and scale with Dynamic Type; the extra line spacing and tracking here are small
/// adjustments, in points at the default size.
public enum TextRole: Sendable, CaseIterable {
    case display
    case title
    case headline
    case body
    case rowAmount
    case subheadline
    case footnote
    case caption

    public var font: Font {
        switch self {
        case .display: return .system(.largeTitle, design: .serif, weight: .bold)
        case .title: return Font.title2.weight(.semibold)
        case .headline: return .headline
        case .body: return .body
        case .rowAmount: return Font.body.weight(.semibold).monospacedDigit()
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption
        }
    }

    /// The Dynamic Type style the spacing scales with.
    var relativeTo: Font.TextStyle {
        switch self {
        case .display: return .largeTitle
        case .title: return .title2
        case .headline: return .headline
        case .body, .rowAmount: return .body
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption
        }
    }

    /// Extra space between lines, for text that wraps.
    public var lineSpacing: CGFloat {
        switch self {
        case .display, .title, .headline, .rowAmount: return 0
        case .body, .subheadline, .footnote: return 2
        case .caption: return 1
        }
    }

    public var tracking: CGFloat { 0 }
}

/// Text styles. All of them scale with Dynamic Type.
public enum Typography {
    /// One per screen: trip name and welcome line.
    public static let display = TextRole.display.font
    public static let title = TextRole.title.font
    public static let headline = TextRole.headline.font
    public static let body = TextRole.body.font
    public static let rowAmount = TextRole.rowAmount.font
    public static let subheadline = TextRole.subheadline.font
    public static let footnote = TextRole.footnote.font
    public static let caption = TextRole.caption.font
}

private struct TextRoleModifier: ViewModifier {
    private let role: TextRole
    @ScaledMetric private var lineSpacing: CGFloat

    init(_ role: TextRole) {
        self.role = role
        _lineSpacing = ScaledMetric(wrappedValue: role.lineSpacing, relativeTo: role.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(role.font)
            .lineSpacing(lineSpacing)
            .tracking(role.tracking)
    }
}

private struct HeroAmountModifier: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 44

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .semibold).monospacedDigit())
    }
}

extension View {
    /// Font, line spacing, and tracking for a text role.
    public func textRole(_ role: TextRole) -> some View {
        modifier(TextRoleModifier(role))
    }

    /// The large amount at the top of the balances and add-expense screens.
    public func heroAmountStyle() -> some View {
        modifier(HeroAmountModifier())
    }
}
