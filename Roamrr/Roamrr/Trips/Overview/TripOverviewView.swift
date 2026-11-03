import CoreLocation
import MapKit
import RoamrrDesign
import SwiftUI

/// The pages a trip home can open.
enum TripSection: Hashable {
    case balances, expenses, plan, itinerary, map, people, documents, myDocuments

    var title: String {
        switch self {
        case .balances: "Balances"
        case .expenses: "Expenses"
        case .plan: "Plan"
        case .itinerary: "Itinerary"
        case .map: "Map"
        case .people: "People"
        case .documents: "Documents"
        case .myDocuments: "My documents"
        }
    }
}

/// D0: the home of a trip whose itinerary is final. What is next, who is where, and where the money stands.
struct TripOverviewView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(TripsStore.self) private var store
    @State private var showAddExpense = false
    @State private var confirmReopen = false
    @State private var meetingSetFor: PlanItem.ID?
    @State private var showSettings = false

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private func content(_ trip: Trip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                TripCoverBand(trip: trip)
                header(trip)
                if trip.isPast(on: store.today) {
                    settleCard(trip)
                } else {
                    nextUp(trip)
                }
                tiles(trip)
                chips(trip)
                // In landscape a pinned bar would cover a third of the screen, so it scrolls with the content.
                if isLandscape, !trip.isPast(on: store.today) { addExpenseBar }
            }
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(edges: .top)
        .background(theme.background)
        .safeAreaInset(edge: .bottom) {
            if !isLandscape, !trip.isPast(on: store.today) {
                addExpenseBar
                    .padding(.vertical, theme.spacing.xs)
                    .frame(maxWidth: .infinity)
                    .background(theme.background)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Trip options", systemImage: "ellipsis") {
                    Button("Trip settings", systemImage: "gearshape") { showSettings = true }
                    if trip.owner == nil || trip.owner == store.me, !trip.isPast(on: store.today) {
                        Button("Reopen planning", systemImage: "arrow.uturn.backward") { confirmReopen = true }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) { TripSettingsView(tripID: trip.id) }
        .sheet(isPresented: $showAddExpense) { AddExpenseSheet(trip: trip, me: store.me, today: store.today) }
        .confirmationDialog("Reopen planning?", isPresented: $confirmReopen, titleVisibility: .visible) {
            Button("Reopen planning") { withAnimation(DesignSystem.Motion.enter) { store.reopenPlanning(trip.id) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The trip goes back to the planning screen. Nothing is deleted.")
        }
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private var addExpenseBar: some View {
        Button("Add expense", systemImage: "plus") { showAddExpense = true }
            .buttonStyle(.ds(.ink))
            .padding(.horizontal, theme.spacing.lg)
    }

    // MARK: Header

    private func header(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(trip.title).displayTitleStyle().foregroundStyle(theme.labelPrimary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.xs) {
                    StageChip(title: stageTitle(trip))
                    Text(trip.overviewSubtitle(on: store.today)).textRole(.subheadline).foregroundStyle(theme.labelSecondary).lineLimit(1)
                }
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    StageChip(title: stageTitle(trip))
                    Text(trip.overviewSubtitle(on: store.today)).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func stageTitle(_ trip: Trip) -> String {
        if trip.isPast(on: store.today) { return "Ended" }
        return trip.isNow(on: store.today) ? "On the trip" : "Itinerary final"
    }

    // MARK: Next up

    @ViewBuilder
    private func nextUp(_ trip: Trip) -> some View {
        if let item = trip.nextItem(after: store.now) {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                NavigationLink(value: PlanRoute(tripID: trip.id, itemID: item.id)) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("NEXT UP").textRole(.footnote, emphasized: true).foregroundStyle(Color(red: 0.89, green: 0.65, blue: 0.49))
                            Spacer()
                            Text(timeLeft(item)).textRole(.subheadline).foregroundStyle(Color.Roamrr.onPanelSecondary)
                        }
                        Text(item.title).stepTitleStyle().foregroundStyle(Color.Roamrr.onPanel).multilineTextAlignment(.leading)
                        Text(nextSubtitle(item)).textRole(.subheadline).foregroundStyle(Color.Roamrr.onPanelSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if item.coordinate != nil {
                    HStack(spacing: theme.spacing.xs) {
                        panelButton("Directions", "mappin.and.ellipse", filled: true) { openDirections(item) }
                        panelButton(meetingSetFor == item.id ? "Meeting point set" : "Meet here", meetingSetFor == item.id ? "checkmark" : "flag", filled: false) {
                            meet(item, in: trip)
                        }
                        .disabled(meetingSetFor == item.id)
                    }
                }
            }
            .padding(theme.spacing.md)
            .modifier(PanelCard())
            .padding(.horizontal, theme.spacing.lg)
        } else {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                Text("NEXT UP").textRole(.footnote, emphasized: true).foregroundStyle(Color(red: 0.89, green: 0.65, blue: 0.49))
                Text("Nothing planned").stepTitleStyle().foregroundStyle(Color.Roamrr.onPanel)
                NavigationLink(value: TripSection.itinerary) {
                    Text("Add from your ideas").textRole(.subheadline, emphasized: true)
                        .foregroundStyle(Color.Roamrr.onPanel)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.md)
            .modifier(PanelCard())
            .padding(.horizontal, theme.spacing.lg)
        }
    }

    private func panelButton(_ title: String, _ symbol: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .textRole(.subheadline, emphasized: true)
                .foregroundStyle(filled ? Color.Roamrr.panel : Color.Roamrr.onPanel)
                .lineLimit(1).minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(filled ? Color.white : Color.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func timeLeft(_ item: PlanItem) -> String {
        let calendar = Calendar.current
        guard let day = item.day else { return "" }
        if calendar.isDate(day, inSameDayAs: store.now) {
            guard let minutes = item.minutes else { return "Today" }
            let now = Int(store.now.timeIntervalSince(calendar.startOfDay(for: store.now)) / 60)
            let left = max(0, minutes - now)
            if left < 60 { return "in \(left) min" }
            return left % 60 == 0 ? "in \(left / 60) h" : "in \(left / 60) h \(left % 60) min"
        }
        return day.weekdayDayMonth
    }

    private func nextSubtitle(_ item: PlanItem) -> String {
        [item.timeText, item.placeName.isEmpty ? nil : item.placeName].compactMap { $0 }.joined(separator: " · ")
    }

    private func openDirections(_ item: PlanItem) {
        guard let spot = item.coordinate else { return }
        let target = MKMapItem(placemark: MKPlacemark(coordinate: spot))
        target.name = item.placeName.isEmpty ? item.title : item.placeName
        target.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private func meet(_ item: PlanItem, in trip: Trip) {
        guard let spot = item.coordinate else { return }
        store.propose(
            MeetingPoint(
                id: UUID(), name: item.placeName.isEmpty ? item.title : item.placeName,
                latitude: spot.latitude, longitude: spot.longitude, proposedBy: store.me, audience: []
            ),
            in: trip.id
        )
        meetingSetFor = item.id
    }

    // MARK: Ended

    private func settleCard(_ trip: Trip) -> some View {
        let balance = trip.balance ?? 0
        return NavigationLink(value: TripSection.balances) {
            VStack(alignment: .leading, spacing: 6) {
                Text(balance == 0 ? "ALL SETTLED" : "SETTLE UP").textRole(.footnote, emphasized: true).foregroundStyle(Color(red: 0.89, green: 0.65, blue: 0.49))
                Text(balance == 0 ? "Nothing left to pay" : Money.peso(abs(balance))).stepTitleStyle().foregroundStyle(Color.Roamrr.onPanel)
                Text(balance == 0 ? "Everyone is square." : (balance > 0 ? "The group still owes you" : "You still owe the group"))
                    .textRole(.subheadline).foregroundStyle(Color.Roamrr.onPanelSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.md)
            .modifier(PanelCard())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, theme.spacing.lg)
    }

    // MARK: Tiles

    private func tiles(_ trip: Trip) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.xs) {
            if !trip.isPast(on: store.today) {
                NavigationLink(value: TripSection.map) { MapTile(trip: trip) }.buttonStyle(.plain)
            }
            VStack(spacing: theme.spacing.xs) {
                if !trip.isPast(on: store.today) {
                    NavigationLink(value: TripSection.balances) { owedTile(trip) }.buttonStyle(.plain)
                }
                NavigationLink(value: TripSection.expenses) { spentTile(trip) }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacing.lg)
    }

    private func tile(_ symbol: String, _ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: symbol).textRole(.subheadline).foregroundStyle(theme.labelSecondary).labelStyle(.titleAndIcon)
            Text(value).font(.system(.title2, weight: .semibold)).monospacedDigit().foregroundStyle(theme.labelPrimary)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(detail).textRole(.footnote).foregroundStyle(theme.labelSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func owedTile(_ trip: Trip) -> some View {
        let balance = trip.balance ?? 0
        if trip.spent == nil { return tile("arrow.left.arrow.right", "Balances", "—", "No expenses yet") }
        if balance == 0 { return tile("arrow.left.arrow.right", "Balances", "Settled", "Nothing to pay") }
        return tile("arrow.left.arrow.right", balance > 0 ? "You're owed" : "You owe", Money.compact(balance), "Tap to settle up")
    }

    private func spentTile(_ trip: Trip) -> some View {
        guard let spent = trip.spent else { return tile("list.bullet.rectangle", "Spent", "—", "Add the first one") }
        let share = trip.yourShare(me: store.me).map { "your share \(Money.peso($0))" } ?? ""
        return tile("list.bullet.rectangle", "Spent", Money.compact(spent), share)
    }

    // MARK: Chips

    private func chips(_ trip: Trip) -> some View {
        FlowLayout(spacing: theme.spacing.xs) {
            NavigationLink(value: TripSection.itinerary) {
                chip("calendar", "Itinerary", itineraryDetail(trip))
            }
            NavigationLink(value: TripSection.people) {
                compactChip("person.2", "People", "\(trip.peopleCount)")
            }
            NavigationLink(value: TripSection.documents) {
                compactChip("doc.text", "Documents", "\(trip.documents(for: store.me).count)")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, theme.spacing.lg)
    }

    private func itineraryDetail(_ trip: Trip) -> String {
        if trip.isPast(on: store.today) { return trip.plan.isEmpty ? "None" : "\(trip.plan.count) \(trip.plan.count == 1 ? "item" : "items")" }
        let today = trip.planned(on: store.today).count
        if today > 0 { return "\(today) today" }
        let days = trip.plannedDayCount
        return days == 0 ? "Draft" : "\(days) \(days == 1 ? "day" : "days")"
    }

    private func chip(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(theme.accent)
            Text(title).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            Text(detail).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
        }
        .lineLimit(1)
        .padding(.horizontal, theme.spacing.sm).frame(minHeight: 44)
        .background(Color.Roamrr.pill, in: Capsule())
    }

    /// A chip that shows only its icon and a count, so three of them fit on one row. VoiceOver still hears the name.
    private func compactChip(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(theme.accent)
            Text(value).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
        }
        .lineLimit(1)
        .padding(.horizontal, theme.spacing.sm).frame(minHeight: 44)
        .background(Color.Roamrr.pill, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}

/// A small, still map of who is sharing, with a label. Tapping it opens the full map.
private struct MapTile: View {
    let trip: Trip

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store

    var body: some View {
        ZStack(alignment: .bottom) {
            if trip.locations.isEmpty {
                Color.Roamrr.pill
                Image(systemName: "map").font(.system(size: 28)).foregroundStyle(theme.labelTertiary).offset(y: -22)
            } else {
                Map(initialPosition: .region(region), interactionModes: []) {
                    ForEach(trip.locations) { location in
                        Annotation("", coordinate: location.coordinate, anchor: .center) {
                            MemberAvatar(location.member, diameter: 28, ring: .white).shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        }
                    }
                }
                .mapControlVisibility(.hidden)
                .allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(label).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(1)
                Text(detail).textRole(.footnote).foregroundStyle(theme.labelSecondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.Roamrr.pill.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(8)
        }
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map, \(label)")
    }

    private var live: Int { trip.sharingLive(on: store.now, me: store.me).count }

    private var label: String { trip.locations.isEmpty ? "Map" : "\(live) sharing live" }

    private var detail: String { trip.locations.isEmpty ? "No one is sharing" : "Tap to find them" }

    private var region: MKCoordinateRegion {
        let points = trip.locations.map(\.coordinate)
        let lats = points.map(\.latitude), lons = points.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else {
            return MKCoordinateRegion()
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 + 0.002, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 2.2, 0.02), longitudeDelta: max((maxLon - minLon) * 2.2, 0.02))
        )
    }
}

/// The navy card on a trip's home. In dark mode it gets a hairline edge: the panel colour is almost the tile colour there.
private struct PanelCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        content
            .background(Color.Roamrr.panel, in: shape)
            .overlay { if scheme == .dark { shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1) } }
    }
}
