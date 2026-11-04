/// A color with a light and a dark value, as 0xRRGGBB.
public struct ColorToken: Sendable, Equatable {
    public let light: UInt32
    public let dark: UInt32

    public init(light: UInt32, dark: UInt32) {
        self.light = light
        self.dark = dark
    }
}

/// Every color in the app (the "Lush" palette). Text and surface pairings are checked in the tests.
public enum Palette {
    // Surfaces
    public static let canvas = ColorToken(light: 0xE8EDED, dark: 0x0E1424)
    public static let ice = ColorToken(light: 0xD4DCDD, dark: 0x1B2640)
    public static let pill = ColorToken(light: 0xF7F9F9, dark: 0x162036)
    public static let hairline = ColorToken(light: 0xC9D2D4, dark: 0x2A3650)
    public static let fieldLine = ColorToken(light: 0x6B7783, dark: 0x7F8FA6)

    // Ink
    public static let ink = ColorToken(light: 0x18233A, dark: 0xE8EDED)
    public static let inkSecondary = ColorToken(light: 0x44516A, dark: 0xB5C0CC)
    public static let inkMuted = ColorToken(light: 0x515D74, dark: 0x97A3B3)
    public static let onInk = ColorToken(light: 0xF7F9F9, dark: 0x0E1424)

    // The solid navy panel under trip covers: the same in both appearances.
    public static let panel = ColorToken(light: 0x18233A, dark: 0x18233A)
    public static let onPanel = ColorToken(light: 0xF7F9F9, dark: 0xF7F9F9)
    public static let onPanelSecondary = ColorToken(light: 0xC9D3E0, dark: 0xC9D3E0)

    // Accent
    public static let accent = ColorToken(light: 0x934414, dark: 0xF0975E)
    public static let accentSoft = ColorToken(light: 0xF1D5C2, dark: 0x3D2819)
    /// Small filled chips such as "4 new" on a cover, with `onInk` text.
    public static let accentFill = ColorToken(light: 0x934414, dark: 0xF0975E)

    // Live: someone sharing their location right now. A steel blue inside the navy family, so the map's pulse is not the
    // accent orange and still never the bright blue of a payment app.
    public static let live = ColorToken(light: 0x4A6FA5, dark: 0x8FB0DC)

    // Status
    public static let danger = ColorToken(light: 0xA81D44, dark: 0xFF8FA3)
    public static let dangerTint = ColorToken(light: 0xF6E1E5, dark: 0x3A1A22)
    public static let onDangerTint = ColorToken(light: 0x8C1236, dark: 0xFFB8C6)

    // Brand: lighter than the interface accent, for large logotype only.
    public static let wordmarkRR = ColorToken(light: 0xC26632, dark: 0xF0975E)

    // Member avatars: the same in light and dark, always with navy initials.
    // Order is the member's fixed color: ice, powder, peach, sand, slate, mist, clay, fog.
    public static let avatars: [UInt32] = [
        0xC1CDCE, 0xB9C6DA, 0xEBCBB4, 0xE2D8C9, 0xB8C5D4, 0xD5DDE7, 0xE4BC9F, 0xCCD5D6,
    ]
    public static let avatarInitials: UInt32 = 0x18233A
}
