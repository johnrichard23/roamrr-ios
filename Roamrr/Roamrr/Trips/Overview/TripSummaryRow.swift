import RoamrrDesign
import SwiftUI

/// One row of the trip overview: an icon, a label, the key fact in bold, and an optional line under it.
struct TripSummaryRow<Accessory: View>: View {
    let icon: String
    let label: String
    let value: String
    var caption: String?
    @ViewBuilder var accessory: Accessory

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: icon)
                .font(.system(.title3))
                .foregroundStyle(theme.accent)
                .frame(width: 48, height: 48)
                .background(Color.Roamrr.ice, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
                Text(value)
                    .textRole(.body, emphasized: true)
                    .foregroundStyle(theme.labelPrimary)
                if let caption {
                    Text(caption)
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            Spacer(minLength: theme.spacing.xs)
            accessory
            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(theme.labelTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension TripSummaryRow where Accessory == EmptyView {
    init(icon: String, label: String, value: String, caption: String? = nil) {
        self.init(icon: icon, label: label, value: value, caption: caption) { EmptyView() }
    }
}
