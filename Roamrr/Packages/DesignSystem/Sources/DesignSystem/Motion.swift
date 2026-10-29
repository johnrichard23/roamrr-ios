import SwiftUI

/// The app's animation vocabulary.
public enum Motion {
    /// Finger-driven moves that settle without bounce.
    public static let settle = Animation.spring(duration: 0.4, bounce: 0)
    /// Appearing bars and success moments.
    public static let pop = Animation.spring(duration: 0.3, bounce: 0.2)
    public static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.12)
    public static let enter = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.25)
    public static let exit = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
}
