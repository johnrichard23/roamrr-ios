import SwiftUI

extension AvatarMember {
    /// The member's own colour, the one their avatar is filled with.
    public var color: Color {
        Color(hex: Palette.avatars[colorIndex % Palette.avatars.count])
    }
}
