import RoamrrDesign
import SwiftUI

/// A trip's cover with the navy panel under it: used for the Trips home hero and the "trip created" step.
/// `top` sits over the artwork, `bottom` under the title in the panel.
struct TripCoverCard<Top: View, Bottom: View>: View {
    let trip: Trip
    let subtitle: String
    @ViewBuilder var top: Top
    @ViewBuilder var bottom: Bottom

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            artwork
                .frame(maxWidth: .infinity, minHeight: 176)
                .overlay(alignment: .top) {
                    top
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding([.horizontal, .top], theme.spacing.md)
                }
            panel
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = trip.coverPhoto, let image = UIImage(data: data) {
            Color.clear.overlay { Image(uiImage: image).resizable().scaledToFill() }.clipped()
        } else {
            CoverArt(trip.cover, fit: .abovePanel)
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
            Text(trip.title)
                .font(.system(.title2, design: .serif, weight: .medium))
                .foregroundStyle(Color.Roamrr.onPanel)
            Text(subtitle)
                .textRole(.subheadline)
                .foregroundStyle(Color.Roamrr.onPanelSecondary)
            bottom.padding(.top, theme.spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.md)
        .background(Color.Roamrr.panel)
        .accessibilityElement(children: .contain)
    }
}
