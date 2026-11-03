@_exported import DesignSystem
import SwiftUI

extension DesignSystem.Theme {
    /// Roamrr's look: the palette's colors in the shared theme's roles, a serif
    /// display title, capsule buttons and the 20 pt margins.
    ///
    /// Set once at the root with `.theme(.roamrr)`. Success, warning and info
    /// keep the system colors, since the palette has no values for them.
    public static let roamrr = DesignSystem.Theme.system.with {
        $0.accent = Palette.accent.color
        // The primary button is ink, not accent, so nothing draws a pressed accent fill.
        $0.accentPressed = Palette.accent.color
        $0.onAccent = Palette.onInk.color
        $0.background = Palette.canvas.color
        $0.surface = Palette.pill.color
        // Also the fill of a disabled button.
        $0.surfacePressed = Palette.hairline.color
        $0.labelPrimary = Palette.ink.color
        $0.labelSecondary = Palette.inkSecondary.color
        $0.labelTertiary = Palette.inkMuted.color
        $0.border = Palette.fieldLine.color
        $0.separator = Palette.hairline.color
        $0.destructive = Palette.danger.color

        $0.typography = .apple.with {
            $0.largeTitle = .init(
                size: 34, lineHeight: 41, weight: .bold, emphasizedWeight: .bold, design: .serif
            )
            $0.title2 = .init(size: 22, lineHeight: 28, weight: .semibold, emphasizedWeight: .bold)
        }
        $0.spacing = .standard.with {
            $0.screenMarginCompact = 20
            $0.screenMarginRegular = 20
            $0.cardPadding = 20
        }
        $0.radius = .standard.with {
            $0.control = 14
            $0.field = 16
            $0.button = 999
            $0.card = 24
        }
        $0.size = .standard.with { $0.buttonHeight = 52 }
        // Over a map the default shadow is too faint to separate a card from the tiles under it.
        $0.elevation = .standard.with {
            $0.color = .black.opacity(0.15)
            $0.radius = 8
        }
    }
}
