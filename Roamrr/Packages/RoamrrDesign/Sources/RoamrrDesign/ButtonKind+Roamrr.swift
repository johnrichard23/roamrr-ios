import DesignSystem
import SwiftUI

extension DesignSystem.ButtonKind {
    /// The screen's main action: ink fill. One per screen.
    public static let ink = DesignSystem.ButtonKind { theme in
        .init(
            fill: theme.labelPrimary,
            pressedFill: theme.labelPrimary.opacity(0.85),
            foreground: Palette.onInk.color
        )
    }

    /// A softer action: the soft accent fill with ink text.
    public static let soft = DesignSystem.ButtonKind { theme in
        .init(
            fill: Palette.accentSoft.color,
            pressedFill: Palette.accentSoft.color.opacity(0.8),
            foreground: theme.labelPrimary
        )
    }

    /// A neutral action: a white pill on the canvas.
    public static let neutral = DesignSystem.ButtonKind { theme in
        .init(fill: theme.surface, pressedFill: theme.surfacePressed, foreground: theme.labelPrimary)
    }

    /// A destructive action drawn as text, so it never competes with `ink`.
    public static let dangerText = DesignSystem.ButtonKind { theme in
        .init(
            fill: .clear,
            pressedFill: theme.surfacePressed,
            foreground: theme.destructive,
            disabledFill: .clear
        )
    }
}
