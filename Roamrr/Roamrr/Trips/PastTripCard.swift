import RoamrrDesign
import SwiftUI

/// A finished trip: its cover, its name, and where the money stands. Small in the "Past trips" row on Trips home,
/// large and full width on the Past trips list, where it also shows the dates and who was on it.
struct PastTripCard: View {
    let trip: Trip
    /// A fixed width in the sideways row; nil lets the card fill its place in the list.
    var width: CGFloat? = 200
    /// The list version: a taller cover, and the dates and people under the name.
    var large = false

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverArt(trip.cover).frame(height: large ? 168 : 84)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(trip.title)
                    .textRole(large ? .title3 : .headline, emphasized: large)
                    .foregroundStyle(theme.labelPrimary)
                    .lineLimit(large ? 2 : 1)
                if large {
                    Text("\(trip.dates) · \(trip.peopleCount) \(trip.peopleCount == 1 ? "person" : "people")")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
                settled
                if large, let spent = trip.spent {
                    Text("\(Money.peso(spent)) spent").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
            }
            .padding(large ? theme.spacing.md : theme.spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var settled: some View {
        if let balance = trip.balance, balance != 0 {
            Text("\(Money.peso(abs(balance))) left to settle")
                .textRole(.subheadline, emphasized: large)
                .foregroundStyle(large ? theme.accent : theme.labelSecondary)
                .lineLimit(1)
        } else {
            Label("All settled", systemImage: "checkmark.circle")
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
        }
    }
}

#Preview {
    PastTripCard(trip: MockData.trips[2]).padding().background(Color.Roamrr.canvas).theme(.roamrr).environment(TripsStore())
}
