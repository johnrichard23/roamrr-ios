import RoamrrDesign
import SwiftUI

/// The big card on Trips home for a trip that is happening or coming up.
struct TripHeroCard: View {
    let trip: Trip
    let today: Date
    let me: AvatarMember

    @Environment(\.theme) private var theme

    var body: some View {
        TripCoverCard(trip: trip, subtitle: "\(trip.dates) · \(trip.peopleCount) people") {
            HStack {
                statusChip
                Spacer()
                if trip.newCount > 0 { newChip }
            }
        } bottom: {
            HStack(alignment: .bottom) {
                AvatarStack(trip.everyone(with: me), diameter: 32, ring: Color.Roamrr.panel)
                Spacer()
                owed
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

    private var newChip: some View {
        Text("\(trip.newCount) new")
            .textRole(.footnote, emphasized: true)
            .foregroundStyle(Palette.onInk.color)
            .padding(.horizontal, theme.spacing.sm)
            .padding(.vertical, theme.spacing.xs)
            .background(Color.Roamrr.accentFill, in: Capsule())
    }

    @ViewBuilder
    private var owed: some View {
        if trip.isPlanning {
            VStack(alignment: .trailing, spacing: 0) {
                Text("ideas so far")
                    .textRole(.footnote)
                    .foregroundStyle(Color.Roamrr.onPanelSecondary)
                Text("\(trip.plan.count)")
                    .rowAmountStyle()
                    .foregroundStyle(Color.Roamrr.onPanel)
            }
        } else if let balance = trip.balance, balance != 0 {
            VStack(alignment: .trailing, spacing: 0) {
                Text(balance > 0 ? "you're owed" : "you owe")
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
