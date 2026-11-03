import RoamrrDesign
import SwiftUI

/// Rows in one rounded card with a hairline between them, as the trip pages list people and expenses.
struct GroupedRows<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    let data: Data
    /// How far the hairline is pulled in from the left, to start under the text.
    var dividerInset: CGFloat = 0
    @ViewBuilder var row: (Data.Element) -> Row

    @Environment(\.theme) private var theme

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(data) { item in
                row(item)
                if item.id != data.last?.id {
                    Rectangle().fill(theme.separator).frame(height: 1).padding(.leading, dividerInset)
                }
            }
        }
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
    }
}

/// A section title on a trip page, with an optional note on the right.
struct PageSectionTitle: View {
    let title: String
    var note: String?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).textRole(.headline).foregroundStyle(theme.labelPrimary)
            Spacer()
            if let note {
                Text(note).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Stands in for a flow that is built later.
struct PlaceholderSheet: View {
    let title: String
    let message: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer", description: Text(message))
                .dsSheetToolbar(title, cancel: { dismiss() })
        }
    }
}
