import RoamrrDesign
import SwiftUI

/// What opens the sheet: a suggested payment to fill it in with, or nothing for a blank one.
struct PaymentSeed: Identifiable {
    let id = UUID()
    let settlement: Settlement?
}

/// D5: record a payment in three steps (who paid who, how much, how), then a "recorded" step.
struct RecordPaymentSheet: View {
    let trip: Trip

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var model: RecordPaymentViewModel
    @State private var confirmDiscard = false

    init(trip: Trip, me: AvatarMember, today: Date, seed: Settlement?) {
        self.trip = trip
        _model = State(initialValue: RecordPaymentViewModel(trip: trip, me: me, today: today, seed: seed))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            if let payment = model.recorded {
                RecordedStep(payment: payment, model: model, balance: store.trip(id: trip.id)?.balance ?? 0)
            } else {
                StepHeader(
                    title: "Record payment", step: model.step, total: RecordPaymentViewModel.stepCount,
                    onBack: model.isFirstStep ? nil : { model.back() },
                    onCancel: { model.hasChanges ? (confirmDiscard = true) : dismiss() }
                )
                StepProgress(step: model.step, total: RecordPaymentViewModel.stepCount)
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
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .background(theme.background)
        .animation(DesignSystem.Motion.enter, value: model.step)
        .animation(DesignSystem.Motion.enter, value: model.recorded)
        .interactiveDismissDisabled(model.hasChanges && model.recorded == nil)
        .confirmationDialog("Discard this payment?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .presentationDragIndicator(.visible)
    }

    private var title: String {
        switch model.step {
        case 1: "Who paid who?"
        case 2: "How much?"
        default: "How was it paid?"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case 1: WhoStep(model: model)
        case 2: PaymentAmountStep(model: model)
        default: HowStep(model: model, trip: trip)
        }
    }

    private var footer: some View {
        VStack(spacing: theme.spacing.xs) {
            if model.isLastStep {
                Label("Roamrr only records this. No money moves through the app.", systemImage: "info.circle")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    .frame(maxWidth: .infinity)
            }
            Button(model.isLastStep ? "Record payment" : "Next") {
                if model.isLastStep {
                    store.record(model.record(), in: trip.id)
                } else {
                    model.next()
                }
            }
            .buttonStyle(.ds(.ink))
            .disabled(model.step == 2 && model.amount == 0)
        }
        .padding(.bottom, theme.spacing.sm)
    }
}

// MARK: - Steps

/// Step 1: who paid and who received, with the pair shown at the top.
private struct WhoStep: View {
    let model: RecordPaymentViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            HStack(spacing: theme.spacing.md) {
                side(model.from, caption: "pays")
                Image(systemName: "arrow.right").font(.system(.title3)).foregroundStyle(theme.labelTertiary)
                side(model.to, caption: "receive")
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacing.md)
            .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
            .accessibilityElement(children: .combine)

            chips("From", selected: model.from, choose: model.choosePayer)
            chips("To", selected: model.to, choose: model.chooseReceiver)
        }
        .sensoryFeedback(.selection, trigger: model.from)
        .sensoryFeedback(.selection, trigger: model.to)
    }

    private func side(_ person: AvatarMember, caption: String) -> some View {
        VStack(spacing: 2) {
            MemberAvatar(person, diameter: 56)
            Text(model.name(person)).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
            Text(person == model.me && caption == "pays" ? "pay" : caption)
                .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func chips(_ label: String, selected: AvatarMember, choose: @escaping (AvatarMember) -> Void) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(label).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            FlowLayout(spacing: theme.spacing.xs) {
                ForEach(model.people) { person in
                    let isOn = person == selected
                    Button { choose(person) } label: {
                        HStack(spacing: theme.spacing.xs) {
                            MemberAvatar(person, diameter: 28)
                            Text(person == model.me ? "You" : person.name)
                                .textRole(.subheadline, emphasized: isOn)
                                .foregroundStyle(isOn ? Palette.accent.color : theme.labelPrimary)
                        }
                        .padding(.leading, 6)
                        .padding(.trailing, theme.spacing.sm)
                        .frame(minHeight: 40)
                        .background(isOn ? Palette.accentSoft.color : Color.Roamrr.pill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}

/// Step 2: the amount, filled with what the suggested payments say.
private struct PaymentAmountStep: View {
    let model: RecordPaymentViewModel

    var body: some View {
        AmountPad(text: Binding(get: { model.amountText }, set: { model.amountText = $0 })) {
            if let hint = model.hint { AmountPill(title: hint, symbol: "checkmark.circle") }
        }
    }
}

/// Step 3: how it was paid, when, and an optional note.
private struct HowStep: View {
    @Bindable var model: RecordPaymentViewModel
    let trip: Trip

    @Environment(\.theme) private var theme
    @FocusState private var noteFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                GroupedRows(data: PaymentMethod.allCases.map(MethodItem.init), dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { item in
                    Button { model.method = item.method } label: {
                        HStack(spacing: theme.spacing.sm) {
                            Image(systemName: item.method.symbol)
                                .font(.system(.body))
                                .foregroundStyle(theme.accent)
                                .frame(width: 44, height: 44)
                                .background(Color.Roamrr.ice, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                            Text(item.method.rawValue)
                                .textRole(.body, emphasized: item.method == model.method)
                                .foregroundStyle(theme.labelPrimary)
                            Spacer()
                            Image(systemName: item.method == model.method ? "largecircle.fill.circle" : "circle")
                                .font(.system(.title3))
                                .foregroundStyle(item.method == model.method ? theme.labelPrimary : theme.border)
                        }
                        .padding(.horizontal, theme.spacing.md)
                        .padding(.vertical, theme.spacing.xs)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item.method == model.method ? .isSelected : [])
                }
                TripDateRow(date: $model.date, range: trip.start...trip.end, today: model.today)
                DSTextField(
                    "Note", placeholder: "For the surf lessons", text: $model.note, isFocused: $noteFocused,
                    autocapitalization: .sentences
                )
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .sensoryFeedback(.selection, trigger: model.method)
    }

    private struct MethodItem: Identifiable {
        let method: PaymentMethod
        var id: PaymentMethod { method }
    }
}

/// The end of the flow, inside the sheet: what changed, your balance now, then Done.
private struct RecordedStep: View {
    let payment: Payment
    let model: RecordPaymentViewModel
    let balance: Decimal

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer(minLength: theme.spacing.lg)
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Palette.accent.color)
                .frame(width: 80, height: 80)
                .background(Palette.accentSoft.color, in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: theme.spacing.xxs) {
                Text("Payment recorded").stepTitleStyle().foregroundStyle(theme.labelPrimary)
                Text(summary).textRole(.body).foregroundStyle(theme.labelSecondary)
            }
            .multilineTextAlignment(.center)
            receipt
            HStack {
                Text("Your balance now").textRole(.body).foregroundStyle(theme.labelSecondary)
                Spacer()
                Text(balance == 0 ? Money.peso(0) : Money.signed(balance))
                    .rowAmountStyle().foregroundStyle(theme.labelPrimary)
            }
            .padding(.horizontal, theme.spacing.xs)
            Spacer(minLength: 0)
            Button("Done") { dismiss() }
                .buttonStyle(.ds(.ink))
                .padding(.bottom, theme.spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.success, trigger: payment.id)
    }

    private var receipt: some View {
        VStack(spacing: theme.spacing.xxs) {
            Text("\(model.name(payment.from)) paid \(payment.to == model.me ? "you" : model.name(payment.to))")
                .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            Text(Money.peso(payment.amount)).heroAmountStyle().foregroundStyle(theme.labelPrimary).minimumScaleFactor(0.5)
            Text("\(payment.method.rawValue) · \(dayText)")
                .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacing.md)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var dayText: String {
        Calendar.current.isDate(payment.date, inSameDayAs: model.today) ? "Today" : payment.date.dayMonth
    }

    /// "Migs is all settled with you", or what the payer still owes.
    private var summary: String {
        let owed = store.trip(id: model.tripID)?.standings.first { $0.member == payment.from }?.amount ?? 0
        let who = model.name(payment.from)
        let verb = payment.from == model.me ? "are" : "is"
        let withWhom = payment.to == model.me ? " with you" : ""
        if owed >= 0 { return "\(who) \(verb) all settled\(withWhom)." }
        return "\(who) still \(payment.from == model.me ? "owe" : "owes") \(Money.peso(-owed))."
    }
}
