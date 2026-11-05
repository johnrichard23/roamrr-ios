import RoamrrDesign
import SwiftUI

/// D4: where you stand, the payments that would settle the trip, and everyone's balance.
struct BalancesView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(TripsStore.self) private var store
    @State private var paymentSeed: PaymentSeed?

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private func content(_ trip: Trip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                hero(trip)
                if !trip.settlements.isEmpty { suggested(trip) }
                if !trip.standings.isEmpty { everyone(trip) }
                // In landscape a pinned bar would cover a third of the screen, so it scrolls with the content.
                if isLandscape, !trip.isPast(on: store.today) { recordPaymentButton }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationTitle("Balances")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .safeAreaInset(edge: .bottom) {
            if !isLandscape, !trip.isPast(on: store.today) {
                recordPaymentButton
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical, theme.spacing.xs)
            }
        }
        .sheet(item: $paymentSeed) { seed in
            RecordPaymentSheet(trip: trip, me: store.me, today: store.today, seed: seed.settlement)
        }
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private var recordPaymentButton: some View {
        Button("Record payment", systemImage: "wallet.pass") { paymentSeed = PaymentSeed(settlement: nil) }
            .buttonStyle(.ds(.ink))
    }

    // MARK: Pieces

    private func hero(_ trip: Trip) -> some View {
        let balance = trip.balance ?? 0
        return VStack(alignment: .leading, spacing: theme.spacing.xxs) {
            Text("Your balance").textRole(.body).foregroundStyle(Color.Roamrr.onPanelSecondary)
            if balance == 0 {
                Text("All settled").heroAmountStyle().foregroundStyle(Color.Roamrr.onPanel)
            } else {
                Text(Money.signed(balance)).heroAmountStyle().foregroundStyle(Color.Roamrr.onPanel)
                    .minimumScaleFactor(0.6)
                Text(balance > 0 ? "Owed to you" : "You owe")
                    .textRole(.body).foregroundStyle(Color.Roamrr.onPanelSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.lg)
        .background(Color.Roamrr.panel, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func suggested(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            PageSectionTitle(title: "Suggested payments", note: "\(trip.settlements.count) settle everything")
            GroupedRows(data: trip.settlements) { settlement in
                Button { paymentSeed = PaymentSeed(settlement: settlement) } label: {
                    SettlementRow(settlement: settlement, me: store.me)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func everyone(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            PageSectionTitle(title: "Everyone")
            GroupedRows(data: trip.standings, dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { standing in
                StandingRow(standing: standing, me: store.me)
            }
        }
    }
}

private struct SettlementRow: View {
    let settlement: Settlement
    let me: AvatarMember

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            HStack(spacing: -10) {
                MemberAvatar(settlement.from, diameter: 36, ring: Color.Roamrr.pill)
                MemberAvatar(settlement.to, diameter: 36, ring: Color.Roamrr.pill)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(headline).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                Text(involvesMe ? "Record when it's paid" : "Between them")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
            Spacer(minLength: theme.spacing.xs)
            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var involvesMe: Bool { settlement.from == me || settlement.to == me }

    private var headline: String {
        let amount = Money.peso(settlement.amount)
        if settlement.from == me { return "You pay \(first(settlement.to)) \(amount)" }
        if settlement.to == me { return "\(first(settlement.from)) pays you \(amount)" }
        return "\(first(settlement.from)) pays \(first(settlement.to)) \(amount)"
    }

    private func first(_ member: AvatarMember) -> String {
        member.name.split(separator: " ").first.map(String.init) ?? member.name
    }
}

private struct StandingRow: View {
    let standing: Standing
    let me: AvatarMember

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            MemberAvatar(standing.member, diameter: 44)
            Text(standing.member == me ? "You" : standing.member.name)
                .textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
            Spacer(minLength: theme.spacing.xs)
            VStack(alignment: .trailing, spacing: 0) {
                Text(standing.amount == 0 ? Money.peso(0) : Money.signed(standing.amount))
                    .rowAmountStyle().foregroundStyle(theme.labelPrimary)
                Text(caption)
                    .textRole(.subheadline)
                    .foregroundStyle(standing.amount > 0 ? theme.accent : theme.labelSecondary)
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        if standing.amount == 0 { return "Settled" }
        if standing.amount > 0 { return standing.member == me ? "Owed to you" : "Is owed" }
        return standing.member == me ? "You owe" : "Owes"
    }
}
