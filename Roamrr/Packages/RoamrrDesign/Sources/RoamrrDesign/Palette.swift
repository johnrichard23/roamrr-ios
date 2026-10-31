/// A color with a light and a dark value, as 0xRRGGBB.
public struct ColorToken: Sendable, Equatable {
    public let light: UInt32
    public let dark: UInt32

    public init(light: UInt32, dark: UInt32) {
        self.light = light
        self.dark = dark
    }
}

/// Every color in the app. Text and surface pairings are checked in the tests.
public enum Palette {
    // Surfaces
    public static let canvas = ColorToken(light: 0xEAF0F4, dark: 0x12171C)
    public static let blush = ColorToken(light: 0xFBEBE2, dark: 0x2A211D)
    public static let pill = ColorToken(light: 0xFFFFFF, dark: 0x1E252B)
    public static let hairline = ColorToken(light: 0xE4DCD0, dark: 0x2F3A42)
    public static let fieldLine = ColorToken(light: 0x8F8778, dark: 0x8A857C)

    // Ink
    public static let ink = ColorToken(light: 0x1D1C19, dark: 0xF4EFEA)
    public static let inkSecondary = ColorToken(light: 0x5A564E, dark: 0xB9B4A9)
    public static let inkMuted = ColorToken(light: 0x6A655B, dark: 0x9A958B)
    public static let onInk = ColorToken(light: 0xFFFFFF, dark: 0x12171C)

    // Accent
    public static let accent = ColorToken(light: 0xB8451F, dark: 0xFF9A6B)
    public static let accentSoft = ColorToken(light: 0xF6C9AE, dark: 0x4A2F22)

    // Status
    public static let danger = ColorToken(light: 0xA81D44, dark: 0xFF8FA3)
    public static let dangerTint = ColorToken(light: 0xF9E1E7, dark: 0x3A1A22)
    public static let onDangerTint = ColorToken(light: 0x8C1236, dark: 0xFFB8C6)

    // Brand
    public static let wordmarkRR = ColorToken(light: 0xD9602E, dark: 0xFF9A6B)

    // Member avatars: the same in light and dark, always with dark initials.
    public static let avatars: [UInt32] = [
        0xF6C9AE, 0xC9DCEB, 0xD9E6C8, 0xE3D5F0, 0xF6E3A1, 0xF3C4CF, 0xCBE8DC, 0xE5D9C3,
    ]
    public static let avatarInitials: UInt32 = 0x1D1C19
}
