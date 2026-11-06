import RoamrrDesign
import SwiftUI

/// The day being written, for the Write entry sheet.
struct WriteDay: Identifiable {
    let day: Date
    var id: Date { day }
}

/// The home of a solo trip: which day it is, what is next, today's money, and the trip's pages.
/// Votes, balances, people and live sharing are left out: there is nobody to share them with.
struct SoloTripHomeView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store
    @State private var showAddExpense = false
    @State private var writing: WriteDay?
    @State private var showSettings = false

    /// The trip's pages, listed in the order the phase of the trip makes useful.
    private enum Page: Hashable, Identifiable {
        case plan, journal, bookings
        var id: Self { self }
    }

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private func content(_ trip: Trip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                TripCoverBand(trip: trip)
                header(trip)
                todayCard(trip)
                moneyTile(trip)
                pages(trip)
            }
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(edges: .top)
        .background(theme.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Trip options", systemImage: "ellipsis") {
                    Button("Trip settings", systemImage: "gearshape") { showSettings = true }
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) { TripSettingsView(tripID: trip.id) }
        .sheet(isPresented: $showAddExpense) { AddExpenseSheet(trip: trip, me: store.me, today: store.today) }
        .sheet(item: $writing) { WriteEntrySheet(tripID: trip.id, day: $0.day) }
    }

    // MARK: Header

    private func header(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(trip.title).displayTitleStyle().foregroundStyle(theme.labelPrimary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.xs) {
                    StageChip(title: "Just me")
                    Text(trip.overviewSubtitle(on: store.today)).textRole(.subheadline).foregroundStyle(theme.labelSecondary).lineLimit(1)
                }
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    StageChip(title: "Just me")
                    Text(trip.overviewSubtitle(on: store.today)).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
            }
            if let today = trip.dayNumber(on: store.today) {
                DayTicks(count: trip.dayCount, today: today)
                    .padding(.top, theme.spacing.xs)
            }
        }
        .padding(.horizontal, theme.spacing.lg)
    }

    // MARK: Lead card

    /// During the trip: what is next, and today's entry. Before it: when it starts and a way into the plan. After it: the journal.
    @ViewBuilder
    private func todayCard(_ trip: Trip) -> some View {
        if trip.isNow(on: store.today) {
            duringCard(trip)
        } else if trip.isPast(on: store.today) {
            otherCard(title: "Read it back", subtitle: "Your trip has ended.", button: "Open your journal", symbol: "book.closed", to: .journal)
        } else {
            otherCard(
                title: trip.datesDecided ? trip.status(on: store.today) : "Start your plan",
                subtitle: trip.datesDecided ? "\(trip.dayCount) \(trip.dayCount == 1 ? "day" : "days") to plan." : "Add places and ideas now. Set dates when you know.",
                button: "Plan your days", symbol: "calendar", to: .itinerary
            )
        }
    }

    private func otherCard(title: String, subtitle: String, button: String, symbol: String, to section: TripSection) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).stepTitleStyle().foregroundStyle(Color.Roamrr.onPanel)
                Text(subtitle).textRole(.subheadline).foregroundStyle(Color.Roamrr.onPanelSecondary)
            }
            NavigationLink(value: section) { panelButton(button, symbol) }
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .modifier(PanelCard())
        .padding(.horizontal, theme.spacing.lg)
    }

    private func duringCard(_ trip: Trip) -> some View {
        let written = trip.entry(on: store.today) != nil
        return VStack(alignment: .leading, spacing: theme.spacing.sm) {
            if let next = trip.nextItem(after: store.now) {
                NavigationLink(value: PlanRoute(tripID: trip.id, itemID: next.id)) {
                    HStack(spacing: theme.spacing.xs) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next: \(next.title)").stepTitleStyle().foregroundStyle(Color.Roamrr.onPanel).multilineTextAlignment(.leading)
                            Text([next.timeText, next.placeName.isEmpty ? nil : next.placeName].compactMap { $0 }.joined(separator: " · "))
                                .textRole(.subheadline).foregroundStyle(Color.Roamrr.onPanelSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(Color.Roamrr.onPanelSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text("Nothing else planned today").stepTitleStyle().foregroundStyle(Color.Roamrr.onPanel)
            }
            Button { writing = WriteDay(day: store.today) } label: {
                panelButton(written ? "Keep writing today" : "Write today", written ? "checkmark" : "square.and.pencil")
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacing.md)
        .modifier(PanelCard())
        .padding(.horizontal, theme.spacing.lg)
    }

    private func panelButton(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .textRole(.subheadline, emphasized: true)
            .foregroundStyle(Color.Roamrr.panel)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.white, in: Capsule())
    }

    // MARK: Money

    /// Always there while the trip can still take expenses: the tile opens them, the plus adds one.
    private func moneyTile(_ trip: Trip) -> some View {
        let past = trip.isPast(on: store.today)
        return HStack(spacing: 0) {
            NavigationLink(value: TripSection.expenses) { moneyDetail(trip) }
                .buttonStyle(.plain)
            if !past {
                Button { showAddExpense = true } label: {
                    Image(systemName: "plus")
                        .font(.system(.title3, weight: .semibold)).foregroundStyle(theme.accent)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add expense")
            }
        }
        .padding(.leading, 16).padding(.trailing, past ? 16 : 4).padding(.vertical, 8)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, theme.spacing.lg)
    }

    @ViewBuilder
    private func moneyDetail(_ trip: Trip) -> some View {
        if let daily = trip.dailyBudget, trip.isNow(on: store.today) {
            let spentToday = trip.dailySpent(on: store.today)
            let left = daily - spentToday
            let over = left < 0
            VStack(alignment: .leading, spacing: 6) {
                Label(over ? "Over today's budget" : "Left today", systemImage: "banknote")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                Text(Money.whole(abs(left)))
                    .font(.system(.title, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(over ? Color.Roamrr.danger : theme.labelPrimary)
                    .contentTransition(.numericText())
                ProgressView(value: daily > 0 ? min(1, NSDecimalNumber(decimal: spentToday / daily).doubleValue) : 0)
                    .tint(over ? Color.Roamrr.danger : theme.accent)
                    .accessibilityHidden(true)
                Text("\(Money.whole(spentToday)) of \(Money.whole(daily)) a day")
                    .textRole(.footnote).foregroundStyle(theme.labelSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens your expenses")
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("Expenses", systemImage: "banknote").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                Text(trip.spent.map { "\(Money.whole($0)) spent" } ?? "None yet")
                    .textRole(.headline).monospacedDigit().foregroundStyle(theme.labelPrimary)
                if let daily = trip.dailyBudget {
                    Text("Budget \(Money.whole(daily)) a day").textRole(.footnote).foregroundStyle(theme.labelSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens your expenses")
        }
    }

    // MARK: Pages

    private func pages(_ trip: Trip) -> some View {
        GroupedRows(data: pageOrder(trip), dividerInset: theme.spacing.md + 28 + theme.spacing.sm) { page in
            NavigationLink(value: section(page)) { pageRow(page, trip) }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacing.lg)
    }

    /// Before the trip the plan and the bookings come first, during it the journal sits next to the plan, after it the journal leads.
    private func pageOrder(_ trip: Trip) -> [Page] {
        if trip.isPast(on: store.today) { return [.journal, .plan, .bookings] }
        return trip.isNow(on: store.today) ? [.plan, .journal, .bookings] : [.plan, .bookings, .journal]
    }

    private func section(_ page: Page) -> TripSection {
        switch page {
        case .plan: .itinerary
        case .journal: .journal
        case .bookings: .documents
        }
    }

    private func pageRow(_ page: Page, _ trip: Trip) -> some View {
        let (title, symbol, detail) = rowContent(page, trip)
        return HStack(spacing: theme.spacing.sm) {
            Image(systemName: symbol).font(.system(.body, weight: .medium)).foregroundStyle(theme.accent).frame(width: 28)
            Text(title).textRole(.body).foregroundStyle(theme.labelPrimary)
            Spacer(minLength: theme.spacing.xs)
            Text(detail).textRole(.subheadline).foregroundStyle(theme.labelSecondary).lineLimit(1)
            Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
        }
        .padding(.horizontal, theme.spacing.md)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func rowContent(_ page: Page, _ trip: Trip) -> (title: String, symbol: String, detail: String) {
        switch page {
        case .plan:
            if trip.isNow(on: store.today) { return ("Plan", "calendar", "\(trip.planned(on: store.today).count) today") }
            let days = trip.plannedDayCount
            return ("Plan", "calendar", days == 0 ? "Empty" : "\(days) \(days == 1 ? "day" : "days")")
        case .journal:
            let days = trip.daysSoFar(on: store.today)
            if days.isEmpty { return ("Journal", "book.closed", trip.datesDecided ? "Opens \(trip.start.dayMonth)" : "Set dates") }
            return ("Journal", "book.closed", "\(days.filter { trip.entry(on: $0) != nil }.count) of \(days.count) days")
        case .bookings:
            let count = trip.documents(for: store.me).count
            return ("Bookings", "doc.text", count == 0 ? "Add one" : "\(count) \(count == 1 ? "booking" : "bookings")")
        }
    }
}

/// One mark per day of the trip: past days soft, today full, days to come empty.
struct DayTicks: View {
    let count: Int
    /// 1-based.
    let today: Int

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...max(count, 1), id: \.self) { day in
                Capsule()
                    .fill(day == today ? theme.accent : day < today ? theme.accent.opacity(0.35) : Color.Roamrr.pill)
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}
