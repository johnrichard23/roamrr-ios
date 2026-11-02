import RoamrrDesign
import SwiftUI

/// D2: add an expense in four steps, one answer each: amount, who paid, split, what it was for.
struct AddExpenseSheet: View {
    let trip: Trip

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var model: AddExpenseViewModel
    @State private var confirmDiscard = false

    init(trip: Trip, me: AvatarMember, today: Date, from idea: PlanItem? = nil) {
        self.trip = trip
        let model = AddExpenseViewModel(trip: trip, me: me, today: today)
        if let idea { model.prefill(title: idea.title, perPerson: idea.cost, category: idea.category.expenseCategory) }
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            StepHeader(
                title: "Add expense", step: model.step, total: AddExpenseViewModel.stepCount,
                onBack: model.isFirstStep ? nil : { model.back() },
                onCancel: { model.hasChanges ? (confirmDiscard = true) : dismiss() }
            )
            StepProgress(step: model.step, total: AddExpenseViewModel.stepCount)
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                Text(title).stepTitleStyle().foregroundStyle(theme.labelPrimary)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .id(model.step)
            .transition(.opacity)
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .background(theme.background)
        .animation(DesignSystem.Motion.enter, value: model.step)
        .interactiveDismissDisabled(model.hasChanges)
        .confirmationDialog("Discard this expense?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Content

    private var title: String {
        switch model.step {
        case 1: "How much?"
        case 2: "Who paid?"
        case 3: "Split how?"
        default: "What was it for?"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case 1: AmountStep(model: model)
        case 2: PayerStep(model: model)
        case 3: SplitStep(model: model)
        default: DetailsStep(model: model, trip: trip)
        }
    }

    @ViewBuilder
    private var footer: some View {
        Button(model.isLastStep ? "Add expense" : "Next") {
            if model.isLastStep {
                store.add(model.makeExpense(), to: trip.id)
                dismiss()
            } else {
                model.next()
            }
        }
        .buttonStyle(.ds(.ink))
        .disabled(model.isFirstStep ? model.amount == 0 : (model.isLastStep && !model.canFinish))
        .padding(.bottom, theme.spacing.sm)
    }
}
