import DesignSystem
import SwiftUI

extension DesignSystem.Motion {
    /// Appearing bars and success moments.
    public static let pop = Animation.spring(duration: 0.3, bounce: 0.2)
    /// The map camera moving from one view to another: something already on screen, so ease in and out.
    public static let camera = Animation.timingCurve(0.77, 0, 0.175, 1, duration: 0.35)
}
