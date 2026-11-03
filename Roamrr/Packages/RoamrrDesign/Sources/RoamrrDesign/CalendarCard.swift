import DesignSystem
import SwiftUI

/// An inline month calendar for picking a trip's dates: tap the first day, then the last, and the days between fill in.
/// The footer says what was picked or what to tap next.
public struct CalendarCard: View {
    @Binding private var start: Date?
    @Binding private var end: Date?
    private let today: Date
    private let calendar: Calendar

    @State private var month: Date
    @Environment(\.theme) private var theme

    public init(start: Binding<Date?>, end: Binding<Date?>, today: Date = .now, calendar: Calendar = .current) {
        _start = start
        _end = end
        self.today = today
        self.calendar = calendar
        _month = State(initialValue: calendar.dateInterval(of: .month, for: start.wrappedValue ?? today)?.start ?? today)
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            weekdays
            grid
            Divider().overlay(theme.separator)
            footer
        }
        .padding(.top, theme.spacing.xs)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .textRole(.headline)
                .foregroundStyle(theme.labelPrimary)
            Spacer()
            Button("Previous month", systemImage: "chevron.left") { step(-1) }
            Button("Next month", systemImage: "chevron.right") { step(1) }
        }
        .buttonStyle(.dsIcon())
        .padding(.horizontal, theme.spacing.md)
    }

    private func step(_ value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: month) {
            withAnimation(DesignSystem.Motion.enter) { month = next }
        }
    }

    private var weekdays: some View {
        HStack(spacing: 0) {
            ForEach(Array(orderedWeekdays.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(theme.labelTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, theme.spacing.xs)
        .accessibilityHidden(true)
    }

    private var orderedWeekdays: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    // MARK: Grid

    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let offset = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let dates = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: offset) + dates
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                if let date {
                    dayCell(date, column: index % 7)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, theme.spacing.xs)
    }

    private func dayCell(_ date: Date, column: Int) -> some View {
        let role = role(of: date)
        return Button { select(date) } label: {
            Text(date.formatted(.dateTime.day()))
                .font(.system(.body, weight: role.isEnd || calendar.isDate(date, inSameDayAs: today) ? .semibold : .regular))
                .foregroundStyle(foreground(role, date))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background { if role.isEnd { Circle().fill(theme.labelPrimary).frame(width: 40, height: 40) } }
                .background { band(role, column: column) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityAddTraits(role == .none ? [] : .isSelected)
    }

    private enum DayRole: Equatable {
        case none, first, last, only, middle
        var isEnd: Bool { self == .first || self == .last || self == .only }
    }

    private func role(of date: Date) -> DayRole {
        guard let start else { return .none }
        guard let end else { return calendar.isDate(date, inSameDayAs: start) ? .only : .none }
        if calendar.isDate(start, inSameDayAs: end) { return calendar.isDate(date, inSameDayAs: start) ? .only : .none }
        if calendar.isDate(date, inSameDayAs: start) { return .first }
        if calendar.isDate(date, inSameDayAs: end) { return .last }
        return date > start && date < end ? .middle : .none
    }

    private func foreground(_ role: DayRole, _ date: Date) -> Color {
        if role.isEnd { return Palette.onInk.color }
        if calendar.isDate(date, inSameDayAs: today) { return theme.accent }
        return theme.labelPrimary
    }

    /// The soft band behind the range: full cells in the middle, half cells at the ends, rounded at the row edges.
    @ViewBuilder
    private func band(_ role: DayRole, column: Int) -> some View {
        let soft = Palette.accentSoft.color
        switch role {
        case .middle:
            UnevenRoundedRectangle(
                topLeadingRadius: column == 0 ? 22 : 0, bottomLeadingRadius: column == 0 ? 22 : 0,
                bottomTrailingRadius: column == 6 ? 22 : 0, topTrailingRadius: column == 6 ? 22 : 0
            )
            .fill(soft).frame(height: 40)
        case .first:
            HStack(spacing: 0) {
                Color.clear
                UnevenRoundedRectangle(bottomTrailingRadius: column == 6 ? 22 : 0, topTrailingRadius: column == 6 ? 22 : 0)
                    .fill(soft)
            }
            .frame(height: 40)
        case .last:
            HStack(spacing: 0) {
                UnevenRoundedRectangle(topLeadingRadius: column == 0 ? 22 : 0, bottomLeadingRadius: column == 0 ? 22 : 0)
                    .fill(soft)
                Color.clear
            }
            .frame(height: 40)
        case .only, .none:
            EmptyView()
        }
    }

    private func select(_ date: Date) {
        if let current = start, end == nil, date >= current {
            end = date
        } else {
            start = date
            end = nil
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if let start, let end {
                let days = DateRangeText.dayCount(start, end, calendar: calendar)
                Text("\(DateRangeText.short(start, end, calendar: calendar)) · \(days) \(days == 1 ? "day" : "days")")
                    .textRole(.subheadline, emphasized: true)
                    .foregroundStyle(theme.labelPrimary)
            } else if start != nil {
                Text("Now tap the last day").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            } else {
                Text("Tap the first and last day").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
            Spacer()
            if start != nil {
                Button("Clear") {
                    start = nil
                    end = nil
                }
                .textRole(.subheadline, emphasized: true)
                .foregroundStyle(theme.accent)
                .minTapTarget()
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .frame(minHeight: 48)
    }
}

#Preview("Calendar") {
    struct Demo: View {
        @State var start: Date? = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 20))
        @State var end: Date? = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 22))
        var body: some View {
            CalendarCard(
                start: $start, end: $end,
                today: Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 4)) ?? .now
            )
            .padding()
            .background(Color.Roamrr.ice)
        }
    }
    return Demo().theme(.roamrr)
}
