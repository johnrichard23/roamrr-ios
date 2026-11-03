import RoamrrDesign
import SwiftUI

/// Step 3: how it is divided. Equally, by exact amounts, by percent, or by shares, with a live check that it adds up.
struct SplitStep: View {
    @Bindable var model: AddExpenseViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("\(Money.peso(model.amount)) between \(model.people.count) people")
                .textRole(.body).foregroundStyle(theme.labelSecondary)
                .padding(.top, -theme.spacing.xs)
            Picker("Split", selection: $model.mode) {
                ForEach(SplitMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            ScrollView {
                GroupedRows(data: model.people, dividerInset: theme.spacing.md) { person in
                    row(person)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            status
        }
        .sensoryFeedback(.error, trigger: model.showSplitProblem) { _, new in new }
    }

    @ViewBuilder
    private func row(_ person: AvatarMember) -> some View {
        let name = person == model.me ? "You" : person.name
        HStack(spacing: theme.spacing.sm) {
            switch model.mode {
            case .equally:
                Button { toggle(person) } label: {
                    HStack(spacing: theme.spacing.sm) {
                        Image(systemName: model.included.contains(person.id) ? "checkmark.circle" : "circle")
                            .font(.system(.title3))
                            .foregroundStyle(model.included.contains(person.id) ? theme.labelPrimary : theme.border)
                        Text(name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                        Spacer()
                        amountLabel(person)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.included.contains(person.id) ? .isSelected : [])
            case .amounts:
                Text(name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                Spacer()
                field("0.00", text: binding(\.exactText, person), prefix: "₱")
            case .percent:
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                    amountLabel(person)
                }
                Spacer()
                field("0", text: binding(\.percentText, person), suffix: "%")
            case .shares:
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                    amountLabel(person)
                }
                Spacer()
                Stepper(
                    "\(model.shareCounts[person.id] ?? 0) shares",
                    value: Binding(get: { model.shareCounts[person.id] ?? 0 }, set: { model.shareCounts[person.id] = $0 }),
                    in: 0...20
                )
                .fixedSize()
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }

    private func amountLabel(_ person: AvatarMember) -> some View {
        Text(model.share(for: person).map { Money.peso($0) } ?? "—")
            .textRole(.body, emphasized: model.mode == .equally).monospacedDigit()
            .foregroundStyle(model.share(for: person) == nil ? theme.labelTertiary : theme.labelPrimary)
    }

    private func field(_ placeholder: String, text: Binding<String>, prefix: String = "", suffix: String = "") -> some View {
        HStack(spacing: 2) {
            if !prefix.isEmpty { Text(prefix).foregroundStyle(theme.labelSecondary) }
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 84)
            if !suffix.isEmpty { Text(suffix).foregroundStyle(theme.labelSecondary) }
        }
        .textRole(.body)
        .padding(.horizontal, theme.spacing.sm)
        .frame(minHeight: 40)
        .background(theme.background, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
    }

    private var status: some View {
        let problem = model.splitProblem
        let showing = problem != nil && model.showSplitProblem
        return Label(problem ?? "Adds up", systemImage: problem == nil ? "checkmark.circle" : "exclamationmark.circle")
            .textRole(.subheadline, emphasized: true)
            .foregroundStyle(showing ? theme.destructive : theme.labelSecondary)
            .animation(DesignSystem.Motion.enter, value: showing)
    }

    private func toggle(_ person: AvatarMember) {
        if model.included.contains(person.id) {
            model.included.remove(person.id)
        } else {
            model.included.insert(person.id)
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<AddExpenseViewModel, [String: String]>, _ person: AvatarMember) -> Binding<String> {
        Binding(
            get: { model[keyPath: keyPath][person.id] ?? "" },
            set: { model[keyPath: keyPath][person.id] = $0 }
        )
    }
}
