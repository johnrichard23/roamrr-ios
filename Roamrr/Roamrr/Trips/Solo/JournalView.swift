import RoamrrDesign
import SwiftUI

/// J1: the trip's journal, one row per day so far, newest first. Days without an entry stay quiet.
struct JournalView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store
    @State private var writing: WriteDay?
    @State private var showDates = false

    var body: some View {
        if let trip = store.trip(id: tripID) {
            let days = trip.daysSoFar(on: store.today)
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(days.isEmpty ? "Only you can see this" : "Written \(days.filter { trip.entry(on: $0) != nil }.count) of \(days.count) days · only you can see this")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                        .padding(.bottom, theme.spacing.xs)
                    ForEach(days, id: \.self) { day in
                        Button { writing = WriteDay(day: day) } label: { row(trip, day: day) }
                            .buttonStyle(CardPressStyle())
                    }
                }
                // Without a full-width frame the page shrinks to its text when there are no rows.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, theme.spacing.lg)
                .padding(.vertical, theme.spacing.sm)
            }
            .background(theme.background)
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $writing) { WriteEntrySheet(tripID: trip.id, day: $0.day) }
            .sheet(isPresented: $showDates) { SetDatesSheet(tripID: trip.id) }
            .overlay {
                if days.isEmpty { emptyState(trip) }
            }
        }
    }

    /// No days to write yet: either the dates are not set (so say how to fix that) or the trip has not started.
    @ViewBuilder
    private func emptyState(_ trip: Trip) -> some View {
        if trip.datesDecided {
            ContentUnavailableView(
                "Your journal opens soon", systemImage: "book.closed",
                description: Text("It opens on \(trip.start.weekdayDayMonth), the first day of the trip.")
            )
        } else {
            ContentUnavailableView {
                Label("Set your dates first", systemImage: "book.closed")
            } description: {
                Text("The journal has one page for each day of the trip.")
            } actions: {
                Button("Set dates") { showDates = true }.buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
            }
        }
    }

    private func row(_ trip: Trip, day: Date) -> some View {
        let entry = trip.entry(on: day)
        return HStack(alignment: .top, spacing: theme.spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Day \(trip.dayNumber(on: day) ?? 0)").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                    Text(day.weekdayDayMonth).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    if let mood = entry?.mood {
                        Image(systemName: mood.symbol).symbolRenderingMode(.hierarchical).foregroundStyle(theme.accent)
                            .accessibilityLabel(mood.title)
                    }
                }
                if let entry, !entry.text.isEmpty {
                    Text(entry.text).textRole(.body).foregroundStyle(theme.labelPrimary).lineLimit(3).multilineTextAlignment(.leading)
                } else {
                    Label(entry == nil ? "Add a line about this day" : "No words yet", systemImage: "plus")
                        .textRole(.subheadline).foregroundStyle(theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let data = entry?.photos.first, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
            }
        }
        .padding(theme.spacing.md)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(Rectangle())
    }
}
