import Foundation

/// WCAG contrast ratio between two colors given as 0xRRGGBB.
public enum Contrast {
    public static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let (lighter, darker) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((hex >> shift) & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}
