import DesignSystem
import SwiftUI

extension ColorToken {
    /// A color that follows the light or dark appearance.
    public var color: Color {
        DesignSystem.color(light: light, dark: dark)
    }
}

extension Color {
    /// The app's colors, for example `Color.Roamrr.canvas`.
    public enum Roamrr {
        public static let canvas = Palette.canvas.color
        public static let ice = Palette.ice.color
        public static let pill = Palette.pill.color
        public static let hairline = Palette.hairline.color
        public static let fieldLine = Palette.fieldLine.color
        public static let ink = Palette.ink.color
        public static let inkSecondary = Palette.inkSecondary.color
        public static let inkMuted = Palette.inkMuted.color
        public static let onInk = Palette.onInk.color
        public static let panel = Palette.panel.color
        public static let onPanel = Palette.onPanel.color
        public static let onPanelSecondary = Palette.onPanelSecondary.color
        public static let accent = Palette.accent.color
        public static let accentSoft = Palette.accentSoft.color
        public static let accentFill = Palette.accentFill.color
        public static let danger = Palette.danger.color
        public static let dangerTint = Palette.dangerTint.color
        public static let onDangerTint = Palette.onDangerTint.color
        public static let wordmarkRR = Palette.wordmarkRR.color
    }
}
