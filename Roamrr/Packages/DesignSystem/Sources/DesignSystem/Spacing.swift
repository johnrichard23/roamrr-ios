import CoreGraphics

/// Spacing on a 4 pt grid.
public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48

    public static let scale: [CGFloat] = [xxs, xs, sm, md, lg, xl, xxl, xxxl]

    public static let screenMargin: CGFloat = lg
    public static let sectionGap: CGFloat = xxl
    public static let cardPadding: CGFloat = lg
    public static let rowMinHeight: CGFloat = 60
}

/// Corner radii. Buttons, chips, and pills are capsules and have no radius here.
public enum Radius {
    public static let card: CGFloat = 24
    public static let field: CGFloat = 16
    public static let pin: CGFloat = 14
}
