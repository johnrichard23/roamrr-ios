import RoamrrDesign
import SwiftUI

/// One document on a list: its kind icon, title, when it is for, and who added it.
struct DocumentRow: View {
    let document: TripDocument

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            DocumentIconTile(symbol: document.kind.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                meta
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(theme.labelTertiary)
        }
        .padding(.horizontal, theme.spacing.md).padding(.vertical, theme.spacing.xs)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
    }

    /// Who added it, when it is for, and its markers: in a row, or stacked at the largest text sizes.
    private var meta: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            MemberAvatar(document.addedBy, diameter: 22)
            if !document.summary.isEmpty {
                Text(document.summary).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if document.visibility == .onlyMe {
                Image(systemName: "lock.fill").font(.caption).foregroundStyle(theme.labelSecondary)
                    .accessibilityLabel("Only you")
            }
            if document.isPending {
                Image(systemName: "clock").font(.caption).foregroundStyle(theme.labelSecondary)
                    .accessibilityLabel("Waiting to sync")
            }
        }
    }
}
