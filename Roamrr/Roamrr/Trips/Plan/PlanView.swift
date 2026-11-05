import RoamrrDesign
import SwiftUI

/// What a card or row on the plan pushes.
struct PlanRoute: Hashable {
    let tripID: Trip.ID
    let itemID: PlanItem.ID
}

/// P1: the trip plan. Ideas anyone adds and votes on, and the days they are put on.
struct PlanView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(TripsStore.self) private var store
    @State private var tab: Tab
    @State private var filter: PlanCategory?
    @State private var showAdd = false
    @State private var dayEditing: PlanItem?
    @State private var showDates = false

    enum Tab: String, CaseIterable { case ideas = "Ideas", days = "Days" }

    init(tripID: Trip.ID, startOnDays: Bool = false) {
        self.tripID = tripID
        _tab = State(initialValue: startOnDays ? .days : .ideas)
    }

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private func content(_ trip: Trip) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing.sm) {
                Picker("View", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if trip.plan.isEmpty {
                    empty
                } else if tab == .ideas {
                    chips(trip)
                    ForEach(trip.ideas(in: filter)) { item in
                        NavigationLink(value: PlanRoute(tripID: trip.id, itemID: item.id)) {
                            IdeaCard(item: item, me: store.me, onReact: { react($0, item) })
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    days(trip)
                }
                // In landscape a pinned bar would cover a third of the screen, so it scrolls with the content.
                if isLandscape, !trip.isPast(on: store.today) { addIdeaBar }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .toolbar {
            if !trip.isPast(on: store.today) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add idea", systemImage: "plus") { showAdd = true }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isLandscape, !trip.isPast(on: store.today) {
                addIdeaBar
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical, theme.spacing.xs)
            }
        }
        .sheet(isPresented: $showAdd) { AddIdeaSheet(trip: trip, editing: nil) }
        .sheet(item: $dayEditing) { item in AddToDaySheet(trip: trip, item: item) }
        .sheet(isPresented: $showDates) { SetDatesSheet(tripID: trip.id) }
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private var addIdeaBar: some View {
        Button("Add idea", systemImage: "plus") { showAdd = true }
            .buttonStyle(.ds(.ink))
    }

    private func react(_ reaction: PlanReaction, _ item: PlanItem) {
        store.react(reaction, on: item.id, in: tripID)
    }

    // MARK: Ideas

    private var empty: some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: "calendar")
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(Palette.accent.color)
                .frame(width: 72, height: 72).background(Palette.accentSoft.color, in: Circle())
            Text("Add the first idea").stepTitleStyle().foregroundStyle(theme.labelPrimary)
            Text("A restaurant, an activity, a sight. Anyone on the trip can add, and everyone votes.")
                .textRole(.body).foregroundStyle(theme.labelSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func chips(_ trip: Trip) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: theme.spacing.xs) {
                chip("All", isOn: filter == nil) { filter = nil }
                ForEach(PlanCategory.allCases, id: \.self) { category in
                    chip(category.rawValue, isOn: filter == category) { filter = category }
                }
            }
            .padding(.horizontal, theme.spacing.lg)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -theme.spacing.lg)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .textRole(.subheadline, emphasized: isOn)
                .foregroundStyle(isOn ? Palette.accent.color : theme.labelPrimary)
                .padding(.horizontal, theme.spacing.md).frame(minHeight: 40)
                .background(isOn ? Palette.accentSoft.color : Color.Roamrr.pill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Days

    @ViewBuilder
    private func days(_ trip: Trip) -> some View {
        if trip.days.isEmpty {
            VStack(spacing: theme.spacing.sm) {
                Text("Dates not decided yet").textRole(.headline).foregroundStyle(theme.labelPrimary)
                Text("Once the dates are set, each day of the trip shows up here.")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary).multilineTextAlignment(.center)
                if trip.owner == nil || trip.owner == store.me {
                    Button("Set dates") { showDates = true }.buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
                }
            }
            .frame(maxWidth: .infinity).padding(theme.spacing.lg)
            .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        }
        ForEach(Array(trip.days.enumerated()), id: \.element) { offset, day in
            let items = trip.planned(on: day)
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Day \(offset + 1) · \(day.weekdayDayMonth)").textRole(.headline).foregroundStyle(theme.labelPrimary)
                    Spacer()
                    if Calendar.current.isDate(day, inSameDayAs: store.today) {
                        Text("Today").textRole(.subheadline, emphasized: true).foregroundStyle(theme.accent)
                    } else {
                        Text(items.isEmpty ? "Free" : "\(items.count) \(items.count == 1 ? "item" : "items")")
                            .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    }
                }
                .padding(.top, theme.spacing.xs)
                if items.isEmpty {
                    Text("Nothing planned yet. Add from your ideas.")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                        .frame(maxWidth: .infinity).padding(theme.spacing.md)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(theme.separator, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                } else {
                    GroupedRows(data: items, dividerInset: theme.spacing.md) { item in
                        NavigationLink(value: PlanRoute(tripID: trip.id, itemID: item.id)) { DayRow(item: item, trip: trip) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Change day or time", systemImage: "calendar") { dayEditing = item }
                                Button("Remove from this day", systemImage: "minus.circle") {
                                    store.schedule(item.id, day: nil, minutes: nil, audience: .everyone, in: trip.id)
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Pieces

/// The picture for an idea: a real photo when there is one, otherwise the mock tile.
struct IdeaArt: View {
    let item: PlanItem

    var body: some View {
        if let data = item.photos.first, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let tile = item.tile {
            LinearGradient(colors: Self.colors(tile), startPoint: .top, endPoint: .bottom)
        } else {
            Color.clear
        }
    }

    static func colors(_ tile: PlanTile) -> [Color] {
        switch tile {
        case .sunrise: [Color(tileHex: 0xF1B58C), Color(tileHex: 0xE8897A), Color(tileHex: 0x6F86A8), Color(tileHex: 0x324A6E)]
        case .food: [Color(tileHex: 0xE7C9A0), Color(tileHex: 0xC9835A)]
        case .lagoon: [Color(tileHex: 0x9BD0DC), Color(tileHex: 0x4C9DB0), Color(tileHex: 0x2E6E86)]
        case .rocks: [Color(tileHex: 0xB9C4C2), Color(tileHex: 0x6E7F85)]
        }
    }

    var hasArt: Bool { !item.photos.isEmpty || item.tile != nil }
}

/// One idea in the list: picture, category, title, place, link, the four reactions, and who added it.
struct IdeaCard: View {
    let item: PlanItem
    let me: AvatarMember
    let onReact: (PlanReaction) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack(alignment: .top, spacing: theme.spacing.sm) {
                if IdeaArt(item: item).hasArt {
                    IdeaArt(item: item)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Label(item.category.rawValue, systemImage: item.category.symbol)
                        .textRole(.footnote, emphasized: true).foregroundStyle(theme.accent)
                    Text(item.title).textRole(.headline).foregroundStyle(theme.labelPrimary)
                    if !item.placeName.isEmpty {
                        Text(item.placeName).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if let link = item.link { LinkCard(link: link) }
            ReactionRow(item: item, me: me, onReact: onReact)
            HStack(spacing: 8) {
                MemberAvatar(item.addedBy, diameter: 22)
                Text("Added by \(item.addedBy == me ? "you" : (item.addedBy.name.split(separator: " ").first.map(String.init) ?? item.addedBy.name))")
                    .textRole(.footnote).foregroundStyle(theme.labelSecondary)
                if let cost = item.cost {
                    Text("· \(Money.peso(cost)) each").textRole(.footnote, emphasized: true).foregroundStyle(theme.labelSecondary)
                }
                Spacer()
                if item.isPending {
                    Label("Waiting to sync", systemImage: "clock").textRole(.footnote).foregroundStyle(theme.labelSecondary)
                }
            }
        }
        .padding(theme.spacing.md)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }
}

/// Must-do, Want, Maybe, Skip with how many chose each; yours is filled in.
struct ReactionRow: View {
    let item: PlanItem
    let me: AvatarMember
    let onReact: (PlanReaction) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PlanReaction.allCases, id: \.self) { reaction in
                let isMine = item.reactions[me.id] == reaction
                Button { onReact(reaction) } label: {
                    HStack(spacing: 4) {
                        Text(reaction.rawValue)
                        Text("\(item.count(reaction))").monospacedDigit().fontWeight(.regular)
                    }
                    .textRole(.footnote, emphasized: true)
                    .foregroundStyle(isMine ? Color.Roamrr.onPanel : theme.labelSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(isMine ? Color.Roamrr.panel : theme.background, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(reaction.rawValue), \(item.count(reaction))")
                .accessibilityAddTraits(isMine ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: item.reactions[me.id])
    }
}

/// A link: its label and site. Tapping opens it in the browser. Nothing is loaded.
struct LinkCard: View {
    let link: PlanLink

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button { openURL(link.url) } label: {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(theme.accent)
                    .frame(width: 32, height: 32).background(Color.Roamrr.ice, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(link.label).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(1)
                    Text(link.site).textRole(.footnote).foregroundStyle(theme.labelSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
            }
            .padding(10)
            .background(theme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(link.label), opens \(link.site) in your browser")
    }
}

/// One planned item on the Days tab.
private struct DayRow: View {
    let item: PlanItem
    let trip: Trip

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(item.timeText.map { $0.replacingOccurrences(of: " ", with: "\n") } ?? "Any\ntime")
                .textRole(.footnote, emphasized: item.minutes != nil)
                .foregroundStyle(item.minutes != nil ? theme.labelSecondary : theme.labelTertiary)
                .multilineTextAlignment(.leading)
                .frame(width: 46, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(2)
                Text(subtitle).textRole(.subheadline).foregroundStyle(theme.labelSecondary).lineLimit(1)
            }
            Spacer(minLength: theme.spacing.xs)
            if item.audience == .interested {
                AvatarStack(([trip.members] + [[]]).flatMap { $0 }.filter { item.going.contains($0.id) }, limit: 3, diameter: 22, ring: Color.Roamrr.pill)
            }
            Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        guard item.audience == .interested else { return "Everyone" }
        return "Optional · \(item.going.count) in"
    }
}

private extension Color {
    /// For the mock artwork only.
    init(tileHex hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
