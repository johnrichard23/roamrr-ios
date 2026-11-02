import RoamrrDesign
import SwiftUI

/// Pick the trip's dates once the group has agreed on them.
struct SetDatesSheet: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var start: Date?
    @State private var end: Date?

    init(tripID: Trip.ID, current: (start: Date, end: Date)? = nil) {
        self.tripID = tripID
        _start = State(initialValue: current?.start)
        _end = State(initialValue: current?.end)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                CalendarCard(start: $start, end: $end, today: store.today)
                    .padding(.horizontal, theme.spacing.lg)
            }
            .background(theme.background)
            .dsSheetToolbar("Trip dates", cancel: { dismiss() })
            .safeAreaInset(edge: .bottom) {
                Button("Save dates") {
                    if let start { store.setDates(start: start, end: end ?? start, in: tripID) }
                    dismiss()
                }
                .buttonStyle(.ds(.ink))
                .disabled(start == nil)
                .padding(.horizontal, theme.spacing.lg).padding(.vertical, theme.spacing.sm)
                .background(theme.background)
            }
        }
    }
}
