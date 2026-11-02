import RoamrrDesign
import SwiftUI

/// The top of a step sheet: Cancel on the first step, Back after that, the sheet's name, and "2 of 4".
struct StepHeader: View {
    let title: String
    let step: Int
    let total: Int
    /// Nil on the first step, which shows Cancel instead.
    var onBack: (() -> Void)?
    let onCancel: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            if let onBack {
                Button("Back", systemImage: "chevron.left", action: onBack)
                    .buttonStyle(.dsIcon(.filled))
            } else {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
            }
            Spacer()
            Text(title).textRole(.headline).foregroundStyle(theme.labelPrimary)
            Spacer()
            Text("\(step) of \(total)")
                .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .frame(minHeight: 44)
    }
}

/// One bar per step, filled up to the current one.
struct StepProgress: View {
    let step: Int
    let total: Int

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? theme.labelPrimary : theme.separator)
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A row that shows a date and opens a calendar under it, limited to the trip's dates.
struct TripDateRow: View {
    @Binding var date: Date
    let range: ClosedRange<Date>
    let today: Date

    @Environment(\.theme) private var theme
    @State private var showCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text("Date").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            Button { showCalendar.toggle() } label: {
                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: "calendar").foregroundStyle(theme.labelSecondary)
                    Text(label).textRole(.body).foregroundStyle(theme.labelPrimary)
                    Spacer()
                    Image(systemName: showCalendar ? "chevron.up" : "chevron.right")
                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
                }
                .padding(.horizontal, theme.spacing.md)
                .frame(minHeight: 52)
                .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
            }
            .buttonStyle(.plain)
            if showCalendar {
                DatePicker("Date", selection: $date, in: range, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(theme.spacing.xs)
                    .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
            }
        }
    }

    /// "Today · 4 Nov", or just "2 Nov" for any other day.
    private var label: String {
        Calendar.current.isDate(date, inSameDayAs: today) ? "Today · \(date.dayMonth)" : date.dayMonth
    }
}
