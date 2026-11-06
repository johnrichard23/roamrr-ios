import RoamrrDesign
import SwiftUI

/// The big card on Trips home for a trip that is happening or coming up.
struct TripHeroCard: View {
    let trip: Trip
    let today: Date
    let me: AvatarMember

    @Environment(\.theme) private var theme

    var body: some View {
        TripCoverCard(trip: trip, subtitle: "\(trip.dates) · \(trip.isSolo ? "Just me" : "\(trip.peopleCount) people")") {
            // The "N new" chip is not shown until there is an activity list for it to open.
            HStack { statusChip; Spacer() }
        } bottom: {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom) {
                    AvatarStack(trip.everyone(with: me), diameter: 32, ring: Color.Roamrr.panel)
                    Spacer()
                    owed(.trailing)
                }
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    AvatarStack(trip.everyone(with: me), diameter: 32, ring: Color.Roamrr.panel)
                    owed(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusChip: some View {
        HStack(spacing: theme.spacing.xs) {
            if trip.isNow(on: today) {
                Circle().fill(theme.accent).frame(width: 8, height: 8)
            }
            Text(trip.status(on: today))
                .textRole(.footnote, emphasized: true)
                .foregroundStyle(theme.labelPrimary)
        }
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.xs)
        .background(Color.Roamrr.pill, in: Capsule())
    }

    @ViewBuilder
    private func owed(_ alignment: HorizontalAlignment) -> some View {
        if trip.isPlanning {
            VStack(alignment: alignment, spacing: 0) {
                Text("Ideas so far")
                    .textRole(.footnote)
                    .foregroundStyle(Color.Roamrr.onPanelSecondary)
                Text("\(trip.plan.count)")
                    .rowAmountStyle()
                    .foregroundStyle(Color.Roamrr.onPanel)
            }
        } else if let balance = trip.balance, balance != 0 {
            VStack(alignment: alignment, spacing: 0) {
                Text(balance > 0 ? "You're owed" : "You owe")
                    .textRole(.footnote)
                    .foregroundStyle(Color.Roamrr.onPanelSecondary)
                Text(Money.peso(abs(balance)))
                    .rowAmountStyle()
                    .foregroundStyle(Color.Roamrr.onPanel)
            }
        }
    }
}

#Preview {
    TripHeroCard(trip: MockData.trips[0], today: MockData.today, me: MockData.you)
        .padding()
        .background(Color.Roamrr.canvas)
        .theme(.roamrr)
}
