import RoamrrDesign
import SwiftUI

/// The rules of typing an amount on the keypad: digits, one point, two decimals, up to nine digits.
enum AmountInput {
    static func press(_ key: String, on text: inout String) {
        switch key {
        case "⌫":
            if !text.isEmpty { text.removeLast() }
        case ".":
            guard !text.contains(".") else { return }
            text += text.isEmpty ? "0." : "."
        default:
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count > 1 {
                guard parts[1].count < 2 else { return }
            } else {
                guard text.count < 9 else { return }
            }
            text = text == "0" ? key : text + key
        }
    }

    /// "₱2,400" while typing, keeping a trailing point or typed decimals as they are.
    static func display(_ text: String) -> String {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Decimal(string: String(parts.first ?? "")) ?? 0
        var result = whole.formatted(.number.grouping(.automatic).precision(.fractionLength(0)).locale(Locale(identifier: "en_PH")))
        if parts.count > 1 { result += "." + parts[1] }
        return "₱" + result
    }
}

/// The big amount and a number pad that is already open. `note` sits under the amount: a currency or a hint.
struct AmountPad<Note: View>: View {
    @Binding var text: String
    @ViewBuilder var note: Note

    @Environment(\.theme) private var theme

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            VStack(spacing: theme.spacing.xs) {
                Text(text.isEmpty ? "₱0" : AmountInput.display(text))
                    .heroAmountStyle()
                    .foregroundStyle(text.isEmpty ? theme.labelTertiary : theme.labelPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                note
            }
            .frame(maxWidth: .infinity)
            .padding(.top, theme.spacing.lg)
            .accessibilityElement(children: .combine)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacing.xs), count: 3), spacing: theme.spacing.xs) {
                ForEach(keys, id: \.self) { key in
                    Button { AmountInput.press(key, on: &text) } label: {
                        Group {
                            if key == "⌫" { Image(systemName: "delete.left") } else { Text(key) }
                        }
                        .font(.system(.title2, weight: .medium))
                        .foregroundStyle(theme.labelPrimary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(key == "⌫" ? "Delete" : key == "." ? "Decimal point" : key)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: text)
    }
}

/// A small pill under the amount: "PHP", or "Settles Migs with you".
struct AmountPill: View {
    let title: String
    var symbol: String?

    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
        }
        .textRole(.subheadline, emphasized: true)
        .foregroundStyle(theme.labelPrimary)
        .padding(.horizontal, theme.spacing.md)
        .frame(minHeight: 36)
        .background(Color.Roamrr.pill, in: Capsule())
    }
}
