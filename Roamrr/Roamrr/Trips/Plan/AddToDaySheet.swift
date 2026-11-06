import RoamrrDesign
import SwiftUI

/// P4: put an idea on a day, with an optional time, for everyone or only those who want to.
struct AddToDaySheet: View {
    let trip: Trip
    let item: PlanItem

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var day: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var audience: PlanAudience

    init(trip: Trip, item: PlanItem) {
        self.trip = trip
        self.item = item
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: MockData.today)
        let first = trip.days.first { $0 >= today } ?? trip.days.first ?? today
        _day = State(initialValue: item.day ?? first)
        _hasTime = State(initialValue: item.minutes != nil)
        let minutes = item.minutes ?? 9 * 60
        _time = State(initialValue: calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date())
        _audience = State(initialValue: item.audience)
    }

    private var dayNumber: Int { (trip.days.firstIndex { Calendar.current.isDate($0, inSameDayAs: day) } ?? 0) + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
                Spacer()
                Text("Add to a day").textRole(.headline).foregroundStyle(theme.labelPrimary)
                Spacer()
                Color.clear.frame(width: 72, height: 44)
            }
            .frame(minHeight: 44)
            Text(item.title).textRole(.body).foregroundStyle(theme.labelSecondary)
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Which day?").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                        GroupedRows(data: trip.days.map(DayOption.init), dividerInset: theme.spacing.md) { option in
                            Button { day = option.day } label: { dayRow(option.day) }.buttonStyle(.plain)
                                .accessibilityAddTraits(isSelected(option.day) ? .isSelected : [])
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $hasTime) {
                            Text("Set a time").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                        }
                        .tint(theme.labelPrimary)
                        if hasTime {
                            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                        }
                    }
                    if !trip.isSolo {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Who is it for?").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                            Picker("Who is it for", selection: $audience) {
                                Text("Everyone").tag(PlanAudience.everyone)
                                Text("Only those who want to").tag(PlanAudience.interested)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            Button("Add to Day \(dayNumber)") { save() }
                .buttonStyle(.ds(.ink))
                .padding(.bottom, theme.spacing.sm)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .background(theme.background)
        .presentationDragIndicator(.visible)
    }

    private struct DayOption: Identifiable {
        let day: Date
        var id: Date { day }
    }

    private func isSelected(_ other: Date) -> Bool { Calendar.current.isDate(other, inSameDayAs: day) }

    private func dayRow(_ other: Date) -> some View {
        let number = (trip.days.firstIndex { Calendar.current.isDate($0, inSameDayAs: other) } ?? 0) + 1
        let count = trip.planned(on: other).count
        let on = isSelected(other)
        return HStack {
            Text("Day \(number) · \(other.weekdayDayMonth)").textRole(.body, emphasized: on).foregroundStyle(theme.labelPrimary)
            Spacer()
            Text(count == 0 ? "Free" : "\(count) \(count == 1 ? "item" : "items")").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            Image(systemName: on ? "largecircle.fill.circle" : "circle").font(.system(.title3))
                .foregroundStyle(on ? theme.labelPrimary : theme.border)
        }
        .padding(.horizontal, theme.spacing.md).frame(minHeight: 52).contentShape(Rectangle())
    }

    private func save() {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        let minutes = hasTime ? (parts.hour ?? 0) * 60 + (parts.minute ?? 0) : nil
        store.schedule(item.id, day: calendar.startOfDay(for: day), minutes: minutes, audience: audience, in: trip.id)
        dismiss()
    }
}
