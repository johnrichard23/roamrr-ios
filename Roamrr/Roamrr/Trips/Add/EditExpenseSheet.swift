import RoamrrDesign
import SwiftUI

/// The parts of an expense the review sheet lists, each one opening just its own step.
private enum EditPart: Int, Identifiable {
    case amount = 1, payer, split, details

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .amount: "How much?"
        case .payer: "Who paid?"
        case .split: "Split how?"
        case .details: "What was it for?"
        }
    }
}

/// D3 edit: every answer from the four Add expense steps as a row; tapping one opens only that step.
struct EditExpenseSheet: View {
    let trip: Trip
    let expense: Expense

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var model: AddExpenseViewModel
    @State private var part: EditPart?
    @State private var confirmDiscard = false

    init(trip: Trip, expense: Expense, me: AvatarMember, today: Date) {
        self.trip = trip
        self.expense = expense
        _model = State(initialValue: AddExpenseViewModel(trip: trip, me: me, today: today, editing: expense))
    }

    private var hasEdits: Bool { model.hasEdits(from: expense) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            header
            if let part {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    Text(part.title).stepTitleStyle().foregroundStyle(theme.labelPrimary)
                        .accessibilityAddTraits(.isHeader)
                    stepContent(part)
                }
                .transition(.opacity)
                Spacer(minLength: 0)
                Button("Done") { finish(part) }
                    .buttonStyle(.ds(.ink))
                    .padding(.bottom, theme.spacing.sm)
            } else {
                review
                Spacer(minLength: 0)
                Button("Save changes") {
                    store.update(expense, to: model.edited(from: expense), in: trip.id)
                    dismiss()
                }
                .buttonStyle(.ds(.ink))
                .disabled(!hasEdits)
                .padding(.bottom, theme.spacing.sm)
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .background(theme.background)
        .animation(DesignSystem.Motion.enter, value: part)
        .interactiveDismissDisabled(hasEdits)
        .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            if part == nil {
                Button("Cancel") { hasEdits ? (confirmDiscard = true) : dismiss() }
                    .buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
            } else {
                Button("Back", systemImage: "chevron.left") { part = nil }
                    .buttonStyle(.dsIcon(.filled))
            }
            Spacer()
            Text("Edit expense").textRole(.headline).foregroundStyle(theme.labelPrimary)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .frame(minHeight: 44)
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("Tap what you want to change.").textRole(.body).foregroundStyle(theme.labelSecondary)
            GroupedRows(data: rows, dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { row in
                Button { part = row.part } label: {
                    HStack(spacing: theme.spacing.sm) {
                        Image(systemName: row.symbol)
                            .font(.system(.body))
                            .foregroundStyle(theme.accent)
                            .frame(width: 44, height: 44)
                            .background(Color.Roamrr.ice, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(row.label).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                            Text(row.value).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                        }
                        Spacer(minLength: theme.spacing.xs)
                        Image(systemName: "chevron.right")
                            .font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
                    }
                    .padding(.horizontal, theme.spacing.md)
                    .padding(.vertical, theme.spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("Everyone in the trip sees the change in this expense's history.")
                .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
        }
    }

    private struct Row: Identifiable {
        let part: EditPart
        let symbol: String
        let label: String
        let value: String
        var id: String { label }
    }

    private var rows: [Row] {
        let title = model.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            Row(part: .amount, symbol: "banknote", label: "Amount", value: Money.peso(model.amount)),
            Row(part: .payer, symbol: "person", label: "Paid by", value: model.payer == model.me ? "You" : model.payer.name),
            Row(part: .split, symbol: "arrow.triangle.branch", label: "Split", value: model.splitSummary),
            Row(part: .details, symbol: model.category.symbol, label: "What and category",
                value: title.isEmpty ? model.category.rawValue : "\(title) · \(model.category.rawValue)"),
            Row(part: .details, symbol: "calendar", label: "Date",
                value: Calendar.current.isDate(model.date, inSameDayAs: model.today) ? "Today · \(model.date.dayMonth)" : model.date.dayMonth),
        ]
    }

    @ViewBuilder
    private func stepContent(_ part: EditPart) -> some View {
        switch part {
        case .amount: AmountStep(model: model)
        case .payer: PayerStep(model: model)
        case .split: SplitStep(model: model)
        case .details: DetailsStep(model: model, trip: trip)
        }
    }

    /// Goes back to the review, unless this step's answer isn't usable yet.
    private func finish(_ part: EditPart) {
        switch part {
        case .amount where model.amount == 0: return
        case .split where model.splitProblem != nil:
            model.showSplitProblem = true
            return
        case .details where !model.canFinish: return
        default: break
        }
        model.showSplitProblem = false
        self.part = nil
    }
}
