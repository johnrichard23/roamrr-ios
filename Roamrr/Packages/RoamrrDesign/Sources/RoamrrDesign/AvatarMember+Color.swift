import SwiftUI

extension AvatarMember {
    /// The member's own colour, the one their avatar is filled with.
    public var color: Color {
        Color(hex: Palette.avatars[colorIndex % Palette.avatars.count])
    }
}

extension Palette {
    /// The member color at `index`, for pickers that show every choice.
    public static func avatarColor(_ index: Int) -> Color {
        Color(hex: avatars[index % avatars.count])
    }
}
