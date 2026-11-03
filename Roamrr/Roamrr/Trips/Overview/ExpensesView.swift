import RoamrrDesign
import SwiftUI

/// D1: everything spent on the trip, newest first, with your share of each.
struct ExpensesView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store
    @State private var filter: ExpenseCategory?
    @State private var showAddExpense = false

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
                if trip.expenses.isEmpty {
                    ContentUnavailableView(
                        "No expenses yet", systemImage: "list.bullet.rectangle",
                        description: Text("Add the first shared cost and everyone's balance starts here.")
                    )
                } else {
                    totals(trip)
                    chips(trip)
                    ForEach(days(trip), id: \.day) { group in
                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            PageSectionTitle(title: dayTitle(group.day))
                            GroupedRows(data: group.expenses, dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { expense in
                                NavigationLink(value: ExpenseRoute(tripID: tripID, expenseID: expense.id)) {
                                    ExpenseRow(expense: expense, share: trip.share(of: expense, me: store.me), me: store.me)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationDestination(for: ExpenseRoute.self) { ExpenseDetailView(tripID: $0.tripID, expenseID: $0.expenseID) }
        .navigationTitle("Expenses")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !trip.isPast(on: store.today) {
                Button("Add expense", systemImage: "plus") { showAddExpense = true }
                    .buttonStyle(.ds(.ink))
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical, theme.spacing.xs)
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(trip: trip, me: store.me, today: store.today)
        }
    }

    // MARK: Pieces

    private func totals(_ trip: Trip) -> some View {
        HStack(spacing: theme.spacing.xs) {
            total("Total spent", trip.spent)
            total("Your share", trip.yourShare(me: store.me))
        }
    }

    private func total(_ label: String, _ amount: Decimal?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            Text(Money.peso(amount ?? 0)).textRole(.headline).monospacedDigit().foregroundStyle(theme.labelPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.sm)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.control + 6, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func chips(_ trip: Trip) -> some View {
        let categories = ExpenseCategory.allCases.filter { category in trip.expenses.contains { $0.category == category } }
        return ScrollView(.horizontal) {
            HStack(spacing: theme.spacing.xs) {
                chip("All", isOn: filter == nil) { filter = nil }
                ForEach(categories, id: \.self) { category in
                    chip(category.rawValue, isOn: filter == category) { filter = category }
                }
            }
            .padding(.horizontal, theme.spacing.lg)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -theme.spacing.lg)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .textRole(.subheadline, emphasized: isOn)
                .foregroundStyle(isOn ? Palette.accent.color : theme.labelPrimary)
                .padding(.horizontal, theme.spacing.md)
                .frame(minHeight: 40)
                .background(isOn ? Palette.accentSoft.color : Color.Roamrr.pill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Grouping

    private struct DayGroup {
        let day: Date
        let expenses: [Expense]
    }

    private func days(_ trip: Trip) -> [DayGroup] {
        let calendar = Calendar.current
        let shown = trip.expenses.filter { filter == nil || $0.category == filter }
        return Dictionary(grouping: shown) { calendar.startOfDay(for: $0.date) }
            .map { DayGroup(day: $0.key, expenses: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        let label = day.dayMonth
        if calendar.isDate(day, inSameDayAs: store.today) { return "Today · \(label)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: store.today), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday · \(label)"
        }
        return label
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let share: Decimal
    let me: AvatarMember

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: expense.category.symbol)
                .font(.system(.body))
                .foregroundStyle(theme.accent)
                .frame(width: 44, height: 44)
                .background(Color.Roamrr.ice, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(expense.title).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(1)
                if expense.isPending {
                    Label("Waiting to sync", systemImage: "clock")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                } else {
                    Text(expense.payer == me ? "Paid by you" : "Paid by \(first)")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
            }
            Spacer(minLength: theme.spacing.xs)
            VStack(alignment: .trailing, spacing: 0) {
                Text(Money.peso(expense.amount)).rowAmountStyle().foregroundStyle(theme.labelPrimary)
                Text("you \(Money.peso(share))").textRole(.subheadline).monospacedDigit().foregroundStyle(theme.labelSecondary)
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var first: String {
        expense.payer.name.split(separator: " ").first.map(String.init) ?? expense.payer.name
    }
}
