import DesignSystem
import SwiftUI

/// A person shown as an avatar: a name, the member color they keep everywhere, and an optional photo.
public struct AvatarMember: Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    /// Index into `Palette.avatars`.
    public let colorIndex: Int
    public let photo: Data?
    /// A friend added without the app: drawn with a dashed ring.
    public let isPlaceholder: Bool

    public init(name: String, colorIndex: Int, photo: Data? = nil, isPlaceholder: Bool = false) {
        self.name = name
        self.colorIndex = colorIndex
        self.photo = photo
        self.isPlaceholder = isPlaceholder
    }

    public var initial: String { name.first.map { String($0).uppercased() } ?? "" }
}

/// The person's photo when there is one, otherwise their initial on their member color.
public struct MemberAvatar: View {
    private let member: AvatarMember
    private let diameter: CGFloat
    private let ring: Color?

    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    public init(_ member: AvatarMember, diameter: CGFloat = 40, ring: Color? = nil) {
        self.member = member
        self.diameter = diameter
        self.ring = ring
    }

    public var body: some View {
        let size = diameter * min(textScale, 1.6)
        ZStack {
            Circle().fill(Color(hex: Palette.avatars[member.colorIndex % Palette.avatars.count]))
            if let data = member.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(member.initial)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Color(hex: Palette.avatarInitials))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if member.isPlaceholder {
                Circle().strokeBorder(Color.Roamrr.inkSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .padding(ring == nil ? 0 : 2)
        .background { if let ring { Circle().fill(ring) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(member.name)
        .accessibilityAddTraits(.isImage)
    }
}

/// Overlapping avatars: up to `limit`, then "+n". Each person keeps their own color.
public struct AvatarStack: View {
    private let members: [AvatarMember]
    private let limit: Int
    private let diameter: CGFloat
    private let ring: Color

    public init(_ members: [AvatarMember], limit: Int = 4, diameter: CGFloat = 32, ring: Color) {
        self.members = members
        self.limit = limit
        self.diameter = diameter
        self.ring = ring
    }

    public var body: some View {
        HStack(spacing: -8) {
            ForEach(members.prefix(limit)) { member in
                MemberAvatar(member, diameter: diameter, ring: ring)
            }
            if members.count > limit {
                Text("+\(members.count - limit)")
                    .font(.system(size: diameter * 0.38, weight: .semibold))
                    .foregroundStyle(Color(hex: Palette.avatarInitials))
                    .frame(width: diameter, height: diameter)
                    .background(Circle().fill(Color.Roamrr.pill))
                    .padding(2)
                    .background(Circle().fill(ring))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(members.map(\.name).joined(separator: ", "))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview("Avatars") {
    let people = [
        AvatarMember(name: "Bea", colorIndex: 1), AvatarMember(name: "Ana", colorIndex: 5),
        AvatarMember(name: "Jo", colorIndex: 3), AvatarMember(name: "Migs", colorIndex: 2),
        AvatarMember(name: "Carlo", colorIndex: 4, isPlaceholder: true),
    ]
    return VStack(alignment: .leading, spacing: 16) {
        AvatarStack(people, ring: Color.Roamrr.canvas)
        MemberAvatar(people[4], diameter: 64)
    }
    .padding()
    .background(Color.Roamrr.canvas)
}
