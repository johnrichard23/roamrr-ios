import RoamrrDesign
import SwiftUI

/// A finished trip in the "Past trips" row: its cover, its name, and where the money stands.
struct PastTripCard: View {
    let trip: Trip

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverArt(trip.cover).frame(height: 84)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(trip.title)
                    .textRole(.headline)
                    .foregroundStyle(theme.labelPrimary)
                    .lineLimit(1)
                settled
            }
            .padding(theme.spacing.sm)
        }
        .frame(width: 200, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var settled: some View {
        if let balance = trip.balance, balance != 0 {
            Text("\(Money.peso(abs(balance))) left to settle")
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
                .lineLimit(1)
        } else {
            Label("All settled", systemImage: "checkmark.circle")
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
        }
    }
}

#Preview {
    PastTripCard(trip: MockData.trips[2]).padding().background(Color.Roamrr.canvas).theme(.roamrr)
}
