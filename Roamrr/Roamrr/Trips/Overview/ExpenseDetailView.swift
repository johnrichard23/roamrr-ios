import RoamrrDesign
import SwiftUI

/// What a row on the Expenses page pushes. A type of its own, because trip ids and expense ids are both
/// `UUID` and navigation destinations are matched by type.
struct ExpenseRoute: Hashable {
    let tripID: Trip.ID
    let expenseID: Expense.ID
}

/// D3: one expense: what it was, who paid, your part, how it was split and what has changed since.
struct ExpenseDetailView: View {
    let tripID: Trip.ID
    let expenseID: Expense.ID

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var showEdit = false
    @State private var confirmDelete = false

    var body: some View {
        if let trip = store.trip(id: tripID), let expense = trip.expenses.first(where: { $0.id == expenseID }) {
            content(trip, expense)
        } else {
            Color.clear.background(theme.background)
        }
    }

    private func content(_ trip: Trip, _ expense: Expense) -> some View {
        let canChange = trip.canChange(expense, me: store.me)
        return ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                hero(expense)
                yourShare(trip, expense)
                split(trip, expense)
                history(expense)
                if canChange {
                    Button { confirmDelete = true } label: {
                        Label("Delete expense", systemImage: "trash")
                            .textRole(.body, emphasized: true)
                            .foregroundStyle(theme.destructive)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(lockedNote(trip, expense))
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationTitle("Expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canChange && !trip.isPast(on: store.today) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEdit = true }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditExpenseSheet(trip: trip, expense: expense, me: store.me, today: store.today)
        }
        .confirmationDialog("Delete this expense?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete expense", role: .destructive) {
                store.delete(expense, in: tripID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It's removed for everyone and balances update. This can't be undone.")
        }
    }

    // MARK: Pieces

    private func hero(_ expense: Expense) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack {
                Label(expense.category.rawValue, systemImage: expense.category.symbol)
                    .textRole(.subheadline, emphasized: true)
                    .foregroundStyle(Color.Roamrr.onPanel)
                    .padding(.horizontal, theme.spacing.sm)
                    .frame(minHeight: 32)
                    .background(Color.white.opacity(0.14), in: Capsule())
                Spacer()
                if expense.isPending {
                    Label("Waiting to sync", systemImage: "clock")
                        .textRole(.subheadline).foregroundStyle(Color.Roamrr.onPanelSecondary)
                }
            }
            Text(expense.title).stepTitleStyle().foregroundStyle(Color.Roamrr.onPanel)
            Text(Money.peso(expense.amount)).heroAmountStyle().foregroundStyle(Color.Roamrr.onPanel)
                .minimumScaleFactor(0.5).lineLimit(1)
            Text("\(payerLine(expense)) · \(dayText(expense.date))")
                .textRole(.body).foregroundStyle(Color.Roamrr.onPanelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.lg)
        .background(Color.Roamrr.panel, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func yourShare(_ trip: Trip, _ expense: Expense) -> some View {
        let share = trip.share(of: expense, me: store.me)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your share").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                Text(Money.peso(share)).textRole(.title3, emphasized: true).monospacedDigit().foregroundStyle(theme.labelPrimary)
            }
            Spacer()
            Text(shareNote(expense, share: share))
                .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(theme.spacing.md)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func split(_ trip: Trip, _ expense: Expense) -> some View {
        let shares = expense.split.isEmpty
            ? ([store.me] + trip.members).map { ExpenseShare(member: $0, amount: expense.amount / Decimal(trip.peopleCount)) }
            : expense.split
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            PageSectionTitle(
                title: expense.isEqualSplit ? "Split equally" : "Split by amounts",
                note: "\(shares.count) \(shares.count == 1 ? "person" : "people")"
            )
            if expense.isEqualSplit {
                HStack {
                    AvatarStack(shares.map(\.member), limit: 5, diameter: 36, ring: Color.Roamrr.pill)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(Money.peso(shares.first?.amount ?? 0)) each").textRole(.body, emphasized: true).monospacedDigit()
                            .foregroundStyle(theme.labelPrimary)
                        Text("\(expense.payer == store.me ? "You" : firstName(expense.payer)) paid \(Money.peso(expense.amount))")
                            .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    }
                }
                .padding(theme.spacing.md)
                .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
                .accessibilityElement(children: .combine)
            } else {
                GroupedRows(data: shares.map(ShareItem.init), dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { item in
                    HStack(spacing: theme.spacing.sm) {
                        MemberAvatar(item.share.member, diameter: 44)
                        Text(item.share.member == store.me ? "You" : item.share.member.name)
                            .textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                        Spacer()
                        Text(Money.peso(item.share.amount)).rowAmountStyle().foregroundStyle(theme.labelPrimary)
                    }
                    .padding(.horizontal, theme.spacing.md)
                    .padding(.vertical, theme.spacing.xs)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private struct ShareItem: Identifiable {
        let share: ExpenseShare
        var id: String { share.member.id }
    }

    private func history(_ expense: Expense) -> some View {
        let added = ExpenseChange(
            id: expense.id, who: expense.payer, title: "\(expense.payer == store.me ? "You" : firstName(expense.payer)) added this",
            detail: expense.isPending && expense.history.isEmpty ? "\(dayText(expense.date)) · saved on this phone" : dayText(expense.date),
            date: expense.date
        )
        return VStack(alignment: .leading, spacing: theme.spacing.xs) {
            PageSectionTitle(title: "History")
            GroupedRows(data: expense.history + [added], dividerInset: theme.spacing.md + 12 + theme.spacing.sm) { change in
                HStack(alignment: .top, spacing: theme.spacing.sm) {
                    Circle().fill(theme.accent).frame(width: 8, height: 8).padding(.top, 8).padding(.horizontal, 2)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(change.title).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                        Text(change.detail).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Words

    private func firstName(_ member: AvatarMember) -> String {
        member.name.split(separator: " ").first.map(String.init) ?? member.name
    }

    private func payerLine(_ expense: Expense) -> String {
        expense.payer == store.me ? "Paid by you" : "Paid by \(firstName(expense.payer))"
    }

    private func dayText(_ date: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: store.today) ? "Today · \(date.dayMonth)" : date.dayMonth
    }

    private func shareNote(_ expense: Expense, share: Decimal) -> String {
        if expense.payer == store.me { return "The others owe you \(Money.peso(max(expense.amount - share, 0)))" }
        if share == 0 { return "You're not part of this one" }
        return "You owe \(firstName(expense.payer)) this part"
    }

    /// "Only Jo or the trip owner can change this.", or just "Only Bea can change this." when the payer owns the trip.
    private func lockedNote(_ trip: Trip, _ expense: Expense) -> String {
        let payer = firstName(expense.payer)
        return trip.owner == expense.payer ? "Only \(payer) can change this." : "Only \(payer) or the trip owner can change this."
    }
}
