import RoamrrDesign
import SwiftUI

/// Step 4: what it was, its category and the date.
struct DetailsStep: View {
    @Bindable var model: AddExpenseViewModel
    let trip: Trip

    @Environment(\.theme) private var theme
    @FocusState private var titleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                DSTextField(
                    "What was it?", placeholder: "Surf lessons", text: $model.title, isFocused: $titleFocused,
                    autocapitalization: .sentences
                )
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text("Category").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                    FlowLayout(spacing: theme.spacing.xs) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            chip(category)
                        }
                    }
                }
                TripDateRow(date: $model.date, range: trip.start...trip.end, today: model.today)
                Text("\(Money.peso(model.amount)) · paid by \(model.payer == model.me ? "you" : model.payer.name) · \(model.mode.phrase)")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .sensoryFeedback(.selection, trigger: model.category)
    }

    private func chip(_ category: ExpenseCategory) -> some View {
        let isOn = model.category == category
        return Button { model.category = category } label: {
            Label(category.rawValue, systemImage: category.symbol)
                .textRole(.subheadline, emphasized: isOn)
                .foregroundStyle(isOn ? Palette.accent.color : theme.labelPrimary)
                .padding(.horizontal, theme.spacing.md)
                .frame(minHeight: 40)
                .background(isOn ? Palette.accentSoft.color : Color.Roamrr.pill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
