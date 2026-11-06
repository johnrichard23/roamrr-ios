import RoamrrDesign
import SwiftUI

/// The plan of a solo trip: one list. Each day is a section, and the ideas you have not put on a day wait in a section of their own.
/// There is nobody to vote, so there are no reactions and no Ideas / Days switch.
struct SoloPlanView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(TripsStore.self) private var store
    @State private var showAdd = false
    @State private var showDates = false
    @State private var dayEditing: PlanItem?
    @State private var ideasCollapsed = false

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private func content(_ trip: Trip) -> some View {
        let ideas = trip.plan.filter { $0.day == nil }
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: theme.spacing.xs, pinnedViews: [.sectionHeaders]) {
                    if trip.plan.isEmpty && trip.days.isEmpty {
                        empty(trip)
                    } else {
                        if !trip.datesDecided { setDatesCard }
                        if !ideas.isEmpty || trip.days.isEmpty { ideasSection(trip, ideas) }
                        ForEach(Array(trip.days.enumerated()), id: \.element) { offset, day in
                            daySection(trip, day: day, number: offset + 1, hasIdeas: !ideas.isEmpty)
                        }
                    }
                    if isLandscape, !trip.isPast(on: store.today) { addIdeaBar }
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, theme.spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: ideas.count) { old, new in
                // A new idea lands in the Ideas section: open it and take the person there.
                guard new > old else { return }
                ideasCollapsed = false
                Task {
                    // Wait for the add sheet to finish closing, or the scroll is dropped.
                    try? await Task.sleep(for: .milliseconds(450))
                    withAnimation(DesignSystem.Motion.enter) { proxy.scrollTo(Self.ideasID, anchor: .top) }
                }
            }
            .task {
                // Open on today when the trip is under way.
                guard trip.isNow(on: store.today) else { return }
                try? await Task.sleep(for: .milliseconds(150))
                if let today = trip.days.first(where: { Calendar.current.isDate($0, inSameDayAs: store.today) }) {
                    proxy.scrollTo(today, anchor: .top)
                }
            }
        }
        .background(theme.background)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            if !isLandscape, !trip.isPast(on: store.today) {
                addIdeaBar
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical, theme.spacing.xs)
            }
        }
        .sheet(isPresented: $showAdd) { AddIdeaSheet(trip: trip, editing: nil) }
        .sheet(item: $dayEditing) { AddToDaySheet(trip: trip, item: $0) }
        .sheet(isPresented: $showDates) { SetDatesSheet(tripID: trip.id) }
        .onAppear { ideasCollapsed = trip.isNow(on: store.today) && !trip.days.isEmpty && trip.plan.contains { $0.day != nil } }
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private var addIdeaBar: some View {
        Button("Add idea", systemImage: "plus") { showAdd = true }
            .buttonStyle(.ds(.ink))
    }

    // MARK: Empty

    private func empty(_ trip: Trip) -> some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: "map")
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(Palette.accent.color)
                .frame(width: 72, height: 72).background(Palette.accentSoft.color, in: Circle())
            Text("Start with one place").stepTitleStyle().foregroundStyle(theme.labelPrimary)
            Text("A restaurant, a beach, a sight. Save what you'd like to see, then put it on a day.")
                .textRole(.body).foregroundStyle(theme.labelSecondary).multilineTextAlignment(.center)
            if !trip.datesDecided {
                Button("Set dates") { showDates = true }
                    .buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
                    .padding(.top, theme.spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
    }

    private var setDatesCard: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: "calendar").foregroundStyle(theme.accent)
            Text("No dates yet. Set them to plan day by day.")
                .textRole(.subheadline).foregroundStyle(theme.labelPrimary)
            Spacer(minLength: 0)
            Button("Set dates") { showDates = true }
                .buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
        }
        .padding(theme.spacing.md)
        .background(Palette.accentSoft.color.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Ideas

    private static let ideasID = "ideas"

    private func ideasSection(_ trip: Trip, _ ideas: [PlanItem]) -> some View {
        Section {
            if !ideasCollapsed {
                if ideas.isEmpty {
                    Text("Nothing saved yet. Add a place and it waits here until you give it a day.")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                } else {
                    GroupedRows(data: ideas, dividerInset: theme.spacing.md) { item in
                        NavigationLink(value: PlanRoute(tripID: trip.id, itemID: item.id)) {
                            ideaRow(item, canSchedule: !trip.days.isEmpty && !trip.isPast(on: store.today))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            sectionHeader(
                title: "Ideas", trailing: ideas.isEmpty ? nil : "\(ideas.count)",
                chevron: ideas.isEmpty ? nil : (ideasCollapsed ? "chevron.down" : "chevron.up")
            ) {
                guard !ideas.isEmpty else { return }
                withAnimation(DesignSystem.Motion.enter) { ideasCollapsed.toggle() }
            }
        }
        .id(Self.ideasID)
    }

    private func ideaRow(_ item: PlanItem, canSchedule: Bool) -> some View {
        HStack(spacing: theme.spacing.sm) {
            if IdeaArt(item: item).hasArt {
                IdeaArt(item: item)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: item.category.symbol)
                    .foregroundStyle(theme.accent)
                    .frame(width: 52, height: 52)
                    .background(Palette.accentSoft.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(2)
                Text(item.placeName.isEmpty ? item.category.rawValue : item.placeName)
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary).lineLimit(1)
            }
            Spacer(minLength: theme.spacing.xs)
            if canSchedule {
                Button { dayEditing = item } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3).foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(item.title) to a day")
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: Days

    private func daySection(_ trip: Trip, day: Date, number: Int, hasIdeas: Bool) -> some View {
        let items = trip.planned(on: day)
        let isToday = Calendar.current.isDate(day, inSameDayAs: store.today)
        return Section {
            if items.isEmpty {
                Text(hasIdeas ? "Free. Add one of your ideas with the calendar button." : "Free day.")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    .frame(maxWidth: .infinity).padding(theme.spacing.md)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(theme.separator, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            } else {
                GroupedRows(data: items, dividerInset: theme.spacing.md) { item in
                    NavigationLink(value: PlanRoute(tripID: trip.id, itemID: item.id)) { DayRow(item: item, trip: trip) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Change day or time", systemImage: "calendar") { dayEditing = item }
                            Button("Move back to ideas", systemImage: "arrow.uturn.backward") {
                                store.schedule(item.id, day: nil, minutes: nil, audience: .everyone, in: trip.id)
                            }
                        }
                }
            }
        } header: {
            sectionHeader(
                title: "Day \(number) · \(day.weekdayDayMonth)",
                trailing: isToday ? "Today" : (items.isEmpty ? "Free" : "\(items.count) \(items.count == 1 ? "item" : "items")"),
                emphasizeTrailing: isToday
            )
        }
        .id(day)
    }

    // MARK: Header

    private func sectionHeader(
        title: String, trailing: String?, chevron: String? = nil, emphasizeTrailing: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        let label = HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).textRole(.headline).foregroundStyle(theme.labelPrimary)
            Spacer()
            if let trailing {
                Text(trailing).textRole(.subheadline, emphasized: emphasizeTrailing)
                    .foregroundStyle(emphasizeTrailing ? theme.accent : theme.labelSecondary)
            }
            if let chevron {
                Image(systemName: chevron).font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
            }
        }
        .padding(.top, theme.spacing.sm)
        .padding(.bottom, theme.spacing.xxs)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(theme.background)
        .contentShape(Rectangle())
        return Group {
            if let action {
                Button(action: action) { label }.buttonStyle(.plain)
            } else {
                label
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}
