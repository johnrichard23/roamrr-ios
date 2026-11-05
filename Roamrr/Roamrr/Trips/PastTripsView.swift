import RoamrrDesign
import SwiftUI

/// What "See all" on Trips home pushes.
struct PastTripsRoute: Hashable {}

/// Every finished trip, newest first, grouped by year, as full-width cards with where the money stands on each.
struct PastTripsView: View {
    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store

    /// Years, newest first, each with its trips newest first.
    private var years: [(year: Int, trips: [Trip])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.past) { calendar.component(.year, from: $0.end) }
        return grouped.keys.sorted(by: >).map { year in (year, grouped[year, default: []].sorted { $0.end > $1.end }) }
    }

    private var unsettled: Int { store.past.filter { ($0.balance ?? 0) != 0 }.count }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing.lg) {
                if unsettled > 0 {
                    Text("\(unsettled) \(unsettled == 1 ? "trip is" : "trips are") not settled yet.")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
                ForEach(years, id: \.year) { group in
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        Text(String(group.year)).textRole(.title3, emphasized: true).foregroundStyle(theme.labelPrimary)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.trips) { trip in
                            NavigationLink(value: trip.id) { PastTripCard(trip: trip, width: nil, large: true) }
                                .buttonStyle(CardPressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationTitle("Past trips")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
    }
}
