import RoamrrDesign
import SwiftUI

/// Step 2: who paid. You are the default.
struct PayerStep: View {
    let model: AddExpenseViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        GroupedRows(data: model.people, dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { person in
            Button { model.payer = person } label: {
                HStack(spacing: theme.spacing.sm) {
                    MemberAvatar(person, diameter: 44)
                    Text(person == model.me ? "You" : person.name)
                        .textRole(.body, emphasized: person == model.payer)
                        .foregroundStyle(theme.labelPrimary)
                    Spacer()
                    Image(systemName: person == model.payer ? "largecircle.fill.circle" : "circle")
                        .font(.system(.title3))
                        .foregroundStyle(person == model.payer ? theme.labelPrimary : theme.border)
                }
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.xs)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(person == model.payer ? .isSelected : [])
        }
        .sensoryFeedback(.selection, trigger: model.payer)
    }
}
