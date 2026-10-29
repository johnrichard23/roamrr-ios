import SwiftUI

#if canImport(UIKit)
import UIKit

extension ColorToken {
    /// A color that follows the light or dark appearance.
    public var color: Color {
        let light = self.light
        let dark = self.dark
        return Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

extension Color {
    /// The app's colors, for example `Color.Roamrr.canvas`.
    public enum Roamrr {
        public static let canvas = Palette.canvas.color
        public static let blush = Palette.blush.color
        public static let pill = Palette.pill.color
        public static let hairline = Palette.hairline.color
        public static let fieldLine = Palette.fieldLine.color
        public static let ink = Palette.ink.color
        public static let inkSecondary = Palette.inkSecondary.color
        public static let inkMuted = Palette.inkMuted.color
        public static let onInk = Palette.onInk.color
        public static let accent = Palette.accent.color
        public static let accentSoft = Palette.accentSoft.color
        public static let danger = Palette.danger.color
        public static let dangerTint = Palette.dangerTint.color
        public static let onDangerTint = Palette.onDangerTint.color
        public static let wordmarkRR = Palette.wordmarkRR.color
    }
}
