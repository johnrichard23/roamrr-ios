import CoreLocation
import MapKit
import RoamrrDesign
import SwiftUI

/// D9: the trip's map. Find your people: see who is sharing, how far each one is from you, and go to them.
struct TripMapView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store
    @State private var camera: MapCameraPosition = .automatic
    @State private var selectedID: String?
    @State private var sheet: SharingStage?
    @State private var region: MKCoordinateRegion?
    @State private var route: WalkingRoute?
    @State private var chatMember: AvatarMember?
    @State private var meetingSeed: MeetingSeed?
    /// False while the map is still drawing its first tiles, so the blank grid never shows during the zoom in.
    @State private var tilesCovered = true
    /// Moves forward on the same beat as the pins, so freshness is judged against the time now and not a fixed moment.
    @State private var clock = Date()
    /// True once MapKit has downloaded the tiles for the opening view, so the cover can lift on a drawn map.
    @State private var tilesLoaded = false
    @State private var tileSnapshotter: MKMapSnapshotter?
    @Environment(\.displayScale) private var displayScale
    @State private var tracker = LiveTracker(me: CLLocationCoordinate2D(latitude: 9.7960, longitude: 126.1590))

    var body: some View {
        if let trip = store.trip(id: tripID) {
            let _ = clock // read here, so the pins are judged again each time it moves
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private func content(_ trip: Trip) -> some View {
        Map(position: $camera) {
            if let selected = selectedLocation(trip), let spot = tracker.positions[selected.id] {
                ForEach(trailPieces(for: selected.id), id: \.index) { piece in
                    MapPolyline(coordinates: piece.points)
                        .stroke(theme.accent.opacity(piece.opacity * 0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                MapPolyline(coordinates: path(to: selected.id, spot))
                    .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: path(to: selected.id, spot))
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            ForEach(trip.locations) { location in
                if let spot = tracker.positions[location.id] {
                    Annotation(location.member.name, coordinate: spot, anchor: .center) {
                        Pin(
                            member: location.member, isLive: location.isLive(on: store.now),
                            isSelected: selectedID == location.id, isDimmed: selectedID != nil && selectedID != location.id,
                            isYou: false
                        )
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .onTapGesture { select(location.id, trip) }
                        .accessibilityAddTraits(.isButton)
                    }
                    .annotationTitles(.hidden)
                }
            }
            if let selected = selectedLocation(trip), let spot = tracker.positions[selected.id] {
                Annotation("", coordinate: tagSpot(selected.id, spot), anchor: .center) {
                    DistanceTag(distance: walkDistance(selected.id), seconds: route(for: selected.id)?.seconds)
                }
                .annotationTitles(.hidden)
            }
            if let meeting = trip.meetingPoint {
                Annotation(meeting.name, coordinate: meeting.coordinate, anchor: .center) { MeetingFlag() }
                    .annotationTitles(.hidden)
            }
            Annotation("You", coordinate: tracker.me, anchor: .center) {
                if trip.mySharing != nil {
                    Pin(member: store.me, isLive: true, isSelected: false, isDimmed: false, isYou: true)
                } else {
                    YouDot()
                }
            }
            .annotationTitles(.hidden)
        }
        // The same calm style as the tile on the trip home, but with places kept: you use this map to find people and spots.
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .mapControlVisibility(.hidden)
        .overlay {
            if tilesCovered {
                Color.Roamrr.canvas.ignoresSafeArea().allowsHitTesting(false).transition(.opacity)
            }
        }
        .task {
            loadOpeningTiles(trip)
            // Long enough for the zoom to land, then until the tiles for the opening view are in. If they never come,
            // for example offline, the cover lifts after another two seconds and the map shows what it has.
            try? await Task.sleep(for: .milliseconds(450))
            var waited = 0
            while !(tilesLoaded && region != nil), waited < 20 {
                try? await Task.sleep(for: .milliseconds(100))
                waited += 1
            }
            withAnimation(DesignSystem.Motion.enter) { tilesCovered = false }
        }
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                strip(trip)
                if store.isOffline { offlineBanner }
            }
        }
        // An inset, not an overlay, so the controls always sit above the tab bar and are never covered by it.
        .safeAreaInset(edge: .bottom, spacing: 0) { bottom(trip) }
        .navigationTitle(trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .topTrailing) { zoomControls(trip) }
        .toolbar {
            #if DEBUG
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Testing", systemImage: "ladybug") {
                    Toggle("Simulate offline", isOn: Binding(get: { store.forcedOffline }, set: { store.setForcedOffline($0) }))
                }
            }
            #endif
        }
        .onMapCameraChange(frequency: .onEnd) { region = $0.region }
        .onAppear {
            tracker.load(trip.locations, now: store.today)
            fitAll(trip, animated: false)
        }
        .task(id: tripID) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                clock = Date()
                if store.isOffline { continue }
                tracker.tick(following: selectedID, held: store.trip(id: tripID)?.staying ?? [])
            }
        }
        .task(id: selectedID) {
            route = nil
            while let id = selectedID, !Task.isCancelled {
                if !store.isOffline { await loadRoute(to: id) }
                try? await Task.sleep(for: .seconds(8))
            }
        }
        .sheet(item: $sheet) { stage in SharingSheet(trip: trip, stage: stage) }
        .sheet(item: $chatMember) { member in
            ChatSheet(tripID: trip.id, member: member, myCoordinate: tracker.me, theirCoordinate: tracker.positions[member.id])
        }
        .sheet(item: $meetingSeed) { seed in
            MeetingPointSheet(
                tripID: trip.id, recipient: seed.recipient, myCoordinate: tracker.me,
                theirCoordinate: seed.recipient.flatMap { tracker.positions[$0.id] }
            )
        }
    }

    // MARK: Route

    /// The walking route we last asked for, if it is for this person.
    private func route(for id: String) -> WalkingRoute? {
        route?.id == id ? route : nil
    }

    /// The line to draw. It starts at your marker and ends at their marker, with the walking route along the roads in
    /// between, so it always touches both pins even when the road is a few metres away or they have moved since the
    /// route was asked for. (ridecommand does the same by building its line from the same updates as the marker.)
    private func path(to id: String, _ spot: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        guard let roads = route(for: id)?.coordinates, !roads.isEmpty else { return [tracker.me, spot] }
        return [tracker.me] + roads + [spot]
    }

    /// How far to walk: along the route when we have it, as the crow flies until then.
    private func walkDistance(_ id: String) -> Double {
        route(for: id)?.metres ?? tracker.distance(to: id) ?? 0
    }

    /// Where the tag sits: the middle of the route, so it stays on the line.
    private func tagSpot(_ id: String, _ spot: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if let points = route(for: id)?.coordinates, points.count > 2 { return points[points.count / 2] }
        return along(tracker.me, spot, 0.5)
    }

    /// Asks Apple Maps for the walking route from you to where they are now.
    private func loadRoute(to id: String) async {
        guard let spot = tracker.positions[id] else { return }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: tracker.me))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: spot))
        request.transportType = .walking
        guard let found = try? await MKDirections(request: request).calculate().routes.first else { return }
        guard selectedID == id else { return }
        let count = found.polyline.pointCount
        var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: count)
        found.polyline.getCoordinates(&points, range: NSRange(location: 0, length: count))
        if route?.id != id { tracker.snap(id: id, route: points) }
        tracker.setPath(for: id, route: points)
        route = WalkingRoute(id: id, coordinates: points, metres: found.distance, seconds: found.expectedTravelTime)
    }

    private var offlineBanner: some View {
        Label("You’re offline. Showing last known spots.", systemImage: "wifi.slash")
            .textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            .padding(.horizontal, theme.spacing.sm).frame(minHeight: 36)
            .background(Color.Roamrr.pill, in: Capsule())
            .floatingShadow()
            .padding(.horizontal, theme.spacing.lg)
            .accessibilityElement(children: .combine)
    }

    // MARK: Zoom

    /// Zoom in, zoom out, and back to showing everyone (or the two of you while following).
    private func zoomControls(_ trip: Trip) -> some View {
        VStack(spacing: 0) {
            control("plus", "Zoom in") { zoom(by: 0.45) }
            Divider().frame(width: 24)
            control("minus", "Zoom out") { zoom(by: 2.2) }
            Divider().frame(width: 24)
            control("scope", selectedID == nil ? "Show everyone" : "Show both of you") {
                if let id = selectedID, let spot = tracker.positions[id] {
                    frame([tracker.me, spot] + (tracker.trails[id] ?? []))
                } else {
                    fitAll(trip)
                }
            }
        }
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .floatingShadow()
        .padding(.trailing, theme.spacing.md)
        .padding(.top, store.isOffline ? 112 : 64)
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(theme.labelPrimary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }

    /// Zooms in or out (a factor under 1 zooms in). While following someone it stays on the two of you: the view is
    /// centred between you, with room for the card, and never zooms in past the point where one of you would leave it.
    private func zoom(by factor: Double) {
        guard let region else { return }
        var latitude = region.span.latitudeDelta * factor
        var longitude = region.span.longitudeDelta * factor
        var center = region.center
        if let id = selectedID, let spot = tracker.positions[id] {
            // Down to the point where both of you still fit above the card, zoom around the two of you;
            // past that, zoom in on the person.
            let pairLat = abs(spot.latitude - tracker.me.latitude) * 2.5
            let pairLon = abs(spot.longitude - tracker.me.longitude) * 2.5
            let fits = latitude >= pairLat && longitude >= pairLon
            let focus = fits ? along(tracker.me, spot, 0.5) : spot
            center = CLLocationCoordinate2D(latitude: focus.latitude - latitude * 0.14, longitude: focus.longitude)
        }
        let span = MKCoordinateSpan(
            latitudeDelta: min(max(latitude, 0.0006), 40),
            longitudeDelta: min(max(longitude, 0.0006), 40)
        )
        withAnimation(DesignSystem.Motion.camera) { camera = .region(MKCoordinateRegion(center: center, span: span)) }
    }

    // MARK: People strip

    /// Everyone sharing, nearest first, each with how far they are. Tap one to follow them.
    private func strip(_ trip: Trip) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: theme.spacing.xs) {
                ForEach(nearestFirst(trip)) { location in
                    let isOn = selectedID == location.id
                    Button { select(location.id, trip) } label: {
                        HStack(spacing: theme.spacing.xs) {
                            MemberAvatar(location.member, diameter: 32)
                                .opacity(location.isLive(on: store.now) ? 1 : 0.6)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(firstName(location.member)).textRole(.subheadline, emphasized: true)
                                HStack(spacing: 4) {
                                    Text(LiveTracker.label(isOn ? walkDistance(location.id) : (tracker.distance(to: location.id) ?? 0)))
                                        .monospacedDigit()
                                    if location.isLowBattery {
                                        Image(systemName: location.battery <= 10 ? "battery.0percent" : "battery.25percent")
                                            .foregroundStyle(theme.destructive)
                                    }
                                }
                                .textRole(.footnote)
                                    .foregroundStyle(isOn ? Color.Roamrr.onPanelSecondary : theme.labelSecondary)
                            }
                        }
                        .foregroundStyle(isOn ? Color.Roamrr.onPanel : theme.labelPrimary)
                        .padding(.leading, 6)
                        .padding(.trailing, theme.spacing.sm)
                        .frame(minHeight: 44)
                        .background(isOn ? Color.Roamrr.panel : Color.Roamrr.pill, in: Capsule())
                        .floatingShadow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.xs)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    // MARK: Bottom

    private func bottom(_ trip: Trip) -> some View {
        VStack(spacing: theme.spacing.xs) {
            if let session = trip.mySharing {
                SharingBar(session: session) { sheet = .manage } onStop: { store.stopSharing(in: trip.id) }
            }
            if let meeting = trip.meetingPoint {
                MeetingBar(
                    meeting: meeting, status: meeting.status(in: trip, me: store.me),
                    metres: CLLocation(latitude: tracker.me.latitude, longitude: tracker.me.longitude)
                        .distance(from: CLLocation(latitude: meeting.latitude, longitude: meeting.longitude)),
                    onDirections: { openDirections(to: meeting) },
                    onCancel: { store.clearMeetingPoint(in: trip.id) }
                )
            }
            if let selected = selectedLocation(trip) {
                FollowCard(
                    location: selected, tracker: tracker, now: store.now,
                    distance: walkDistance(selected.id), seconds: route(for: selected.id)?.seconds,
                    isHeld: trip.staying.contains(selected.id), isOffline: store.isOffline, onMessage: { chatMember = selected.member },
                    onDirections: { openDirections(to: selected) }, onClose: { selectedID = nil; fitAll(trip) }
                )
            } else {
                summary(trip)
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.bottom, theme.spacing.md)
        .animation(DesignSystem.Motion.enter, value: selectedID)
        .animation(DesignSystem.Motion.enter, value: trip.mySharing != nil)
    }

    /// What shows when nobody is selected: how many are sharing, and your own controls.
    private func summary(_ trip: Trip) -> some View {
        let count = trip.locations.count
        return VStack(alignment: .leading, spacing: theme.spacing.sm) {
            VStack(alignment: .leading, spacing: 0) {
                Text(count == 0 ? "No one is sharing yet" : "\(count) \(count == 1 ? "person" : "people") sharing")
                    .textRole(.title3, emphasized: true).foregroundStyle(theme.labelPrimary)
                Text(count == 0 ? "Share yours so the others can find you." : "Tap someone to see how far they are and go to them.")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
            if !trip.isPast(on: store.today) {
                VStack(spacing: theme.spacing.xs) {
                    if trip.mySharing == nil {
                        Button("Share my location", systemImage: "location.fill") {
                            sheet = UserDefaults.standard.bool(forKey: SharingSheet.seenKey) ? .start : .explainer
                        }
                        .buttonStyle(.ds(.ink))
                    }
                    if trip.meetingPoint == nil {
                        Button("Meeting point", systemImage: "flag") { meetingSeed = MeetingSeed(recipient: nil) }
                            .buttonStyle(.ds(.neutral))
                    }
                }
            }
        }
        .padding(theme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .floatingShadow()
    }

    // MARK: Data

    private func nearestFirst(_ trip: Trip) -> [MemberLocation] {
        trip.locations.sorted { (tracker.distance(to: $0.id) ?? .infinity) < (tracker.distance(to: $1.id) ?? .infinity) }
    }

    private func selectedLocation(_ trip: Trip) -> MemberLocation? {
        trip.locations.first { $0.id == selectedID }
    }

    private func firstName(_ member: AvatarMember) -> String {
        member.name.split(separator: " ").first.map(String.init) ?? member.name
    }

    // MARK: Camera

    private func select(_ id: String, _ trip: Trip) {
        selectedID = selectedID == id ? nil : id
        if let spot = tracker.positions[id], selectedID != nil {
            frame([tracker.me, spot] + (tracker.trails[id] ?? []))
        } else {
            fitAll(trip)
        }
    }

    /// Everyone, you and the meeting point in one view. The view is never tighter than about a kilometre, so one person
    /// alone is shown with their surroundings and not a street corner.
    private func fitAll(_ trip: Trip, animated: Bool = true) {
        frame(
            trip.locations.compactMap { tracker.positions[$0.id] ?? $0.coordinate } + [tracker.me] + (trip.meetingPoint.map { [$0.coordinate] } ?? []),
            minSpan: 0.012, animated: animated
        )
    }

    /// Frames these points with room under them for the card.
    private func frame(_ points: [CLLocationCoordinate2D], minSpan: Double = 0.003, animated: Bool = true) {
        guard let region = framingRegion(points, minSpan: minSpan) else { return }
        if animated {
            withAnimation(DesignSystem.Motion.camera) { camera = .region(region) }
        } else {
            camera = .region(region)
        }
    }

    /// These points with room around them and under them for the card, or nil when there are none.
    private func framingRegion(_ points: [CLLocationCoordinate2D], minSpan: Double) -> MKCoordinateRegion? {
        let lats = points.map(\.latitude), lons = points.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return nil }
        let spanLat = max((maxLat - minLat) * 2.4, minSpan)
        let spanLon = max((maxLon - minLon) * 2.4, minSpan)
        let center = CLLocationCoordinate2D(latitude: (maxLat + minLat) / 2 - spanLat * 0.17, longitude: (maxLon + minLon) / 2)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon))
    }

    /// Asks MapKit for a picture of the opening view. It finishes when the tiles for that view have been downloaded, which
    /// is the nearest thing MapKit gives to "the first tiles are ready", and the live map then draws from the same tiles.
    private func loadOpeningTiles(_ trip: Trip) {
        let points = trip.locations.compactMap { tracker.positions[$0.id] ?? $0.coordinate } + [tracker.me]
            + (trip.meetingPoint.map { [$0.coordinate] } ?? [])
        guard let region = framingRegion(points, minSpan: 0.012) else {
            tilesLoaded = true
            return
        }
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 402, height: 874)
        options.scale = displayScale
        let snapshotter = MKMapSnapshotter(options: options)
        tileSnapshotter = snapshotter
        snapshotter.start { _, _ in
            Task { @MainActor in tilesLoaded = true }
        }
    }

    /// The followed person's trail cut into stretches that get stronger towards where they are now.
    private func trailPieces(for id: String) -> [(index: Int, points: [CLLocationCoordinate2D], opacity: Double)] {
        let trail = tracker.trails[id] ?? []
        guard trail.count > 1 else { return [] }
        let count = min(4, trail.count - 1)
        let size = Double(trail.count - 1) / Double(count)
        return (0..<count).map { piece in
            let from = Int((Double(piece) * size).rounded(.down))
            let to = min(trail.count - 1, Int((Double(piece + 1) * size).rounded(.up)))
            return (piece, Array(trail[from...to]), 0.25 + 0.75 * Double(piece + 1) / Double(count))
        }
    }

    /// The point this far (0 to 1) along the line from `a` to `b`.
    private func along(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ fraction: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * fraction,
            longitude: a.longitude + (b.longitude - a.longitude) * fraction
        )
    }

    /// Walking directions in Apple Maps, to the meeting point.
    private func openDirections(to meeting: MeetingPoint) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: meeting.coordinate))
        item.name = meeting.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    /// Walking directions in Apple Maps, to where they are right now.
    private func openDirections(to location: MemberLocation) {
        guard let spot = tracker.positions[location.id] else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: spot))
        item.name = location.member.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

/// A walking route from you to someone, along the roads.
struct WalkingRoute {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let metres: Double
    let seconds: TimeInterval
}

extension MemberLocation {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

// MARK: - Pieces

/// A person on the map, sized like ridecommand's rider marker: a small coloured disc with a thin white border. Whoever you
/// are following is a touch larger with a soft halo and a stronger pulse; everyone else steps back. Anyone sharing live
/// gives off a gentle pulse in the steel-blue live colour, and someone who is not live does not, even when followed. The distance is not repeated here.
private struct Pin: View {
    let member: AvatarMember
    let isLive: Bool
    let isSelected: Bool
    let isDimmed: Bool
    let isYou: Bool

    @Environment(\.theme) private var theme

    private var disc: CGFloat { isSelected ? 34 : (isDimmed ? 24 : 30) }

    /// Live, and either the one being followed or not stepped back behind someone who is.
    private var pulses: Bool { isLive && (isSelected || !isDimmed) }

    var body: some View {
        ZStack {
            if pulses { PulseRing(lineWidth: isSelected ? 6 : 3, color: Palette.live.color) }
            if isSelected { Circle().fill(Palette.live.color.opacity(0.22)).frame(width: 46, height: 46) }
            Circle().fill(.white).frame(width: disc + 4, height: disc + 4)
            MemberAvatar(member, diameter: disc)
                .opacity(isLive || isSelected ? 1 : 0.75)
        }
        .opacity(isDimmed ? 0.6 : 1)
        .markerShadow(softened: isDimmed)
        .animation(DesignSystem.Motion.enter, value: isSelected)
        .animation(DesignSystem.Motion.enter, value: isDimmed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(member.name), \(isLive ? "live" : "last seen")")
    }
}

/// A ring that grows and fades again and again, to say someone is sharing right now. It starts when it appears, and
/// does not move at all under Reduce Motion.
private struct PulseRing: View {
    let lineWidth: CGFloat
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: lineWidth)
            .frame(width: 34, height: 34)
            .scaleEffect(pulse ? 1.7 : 0.8)
            .opacity(pulse ? 0 : 0.8)
            .animation(reduceMotion ? nil : .easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulse)
            .onAppear { pulse = !reduceMotion }
            .onChange(of: reduceMotion) { _, reduce in pulse = !reduce }
            .accessibilityHidden(true)
    }
}

/// You, before you share: a plain blue-dot style marker.
private struct YouDot: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Circle().fill(Color.Roamrr.panel)
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .background(Circle().fill(Color.Roamrr.panel.opacity(0.2)).frame(width: 44, height: 44))
            .markerShadow()
            .accessibilityLabel("You")
    }
}

/// The label in the middle of the route line: how far, and how long on foot.
private struct DistanceTag: View {
    let distance: Double
    let seconds: TimeInterval?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Text(LiveTracker.label(distance)).monospacedDigit()
            Text("·").foregroundStyle(Color.Roamrr.onPanelSecondary)
            Text(seconds.map(LiveTracker.minutes) ?? LiveTracker.walk(distance).replacingOccurrences(of: " walk", with: ""))
        }
        .textRole(.footnote, emphasized: true)
        .foregroundStyle(Color.Roamrr.onPanel)
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(Color.Roamrr.panel, in: Capsule())
        .markerShadow()
        .accessibilityLabel("\(LiveTracker.label(distance)), \(seconds.map(LiveTracker.minutes) ?? LiveTracker.walk(distance))")
    }
}

/// The person you are following: how far, how long on foot, whether you are getting closer, and a way to go to them.
private struct FollowCard: View {
    let location: MemberLocation
    let tracker: LiveTracker
    let now: Date
    let distance: Double
    let seconds: TimeInterval?
    let isHeld: Bool
    let isOffline: Bool
    let onMessage: () -> Void
    let onDirections: () -> Void
    let onClose: () -> Void

    @Environment(\.theme) private var theme

    private var isLive: Bool { location.isLive(on: now) }

    var body: some View {
        VStack(spacing: theme.spacing.sm) {
            HStack(spacing: theme.spacing.sm) {
                MemberAvatar(location.member, diameter: 52)
                VStack(alignment: .leading, spacing: 0) {
                    Text(location.member.name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                    Text(isLive ? "Live · \(location.place)" : "Last seen \(location.lastSeen(on: now)) · \(location.place)")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary).lineLimit(1)
                }
                Spacer(minLength: theme.spacing.xs)
                Button("Close", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.dsIcon(.filled))
            }
            statusRow
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(LiveTracker.label(distance)).heroAmountStyle().foregroundStyle(theme.labelPrimary)
                        .contentTransition(.numericText())
                    Text(isLive ? (seconds.map { "\(LiveTracker.minutes($0)) walk" } ?? LiveTracker.walk(distance)) : "from where they were last seen")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
                Spacer()
                if isOffline, let bearing = tracker.bearing(to: location.id) {
                    CompassArrow(bearing: bearing)
                } else if isLive {
                    trend
                }
            }
            HStack(spacing: theme.spacing.xs) {
                Button("Message", systemImage: "bubble.left", action: onMessage)
                    .buttonStyle(.ds(.neutral))
                Button("Directions", systemImage: "figure.walk", action: onDirections)
                    .buttonStyle(.ds(.ink))
            }
        }
        .padding(theme.spacing.md)
        .background(theme.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .floatingShadow()
        .animation(DesignSystem.Motion.enter, value: distance.rounded())
        .accessibilityElement(children: .contain)
    }

    /// How fresh the position is and how much battery their phone has left.
    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: theme.spacing.xs) {
                Label("\(location.battery)%", systemImage: batterySymbol)
                    .textRole(.footnote, emphasized: true)
                    .foregroundStyle(location.isLowBattery ? theme.destructive : theme.labelPrimary)
                    .padding(.horizontal, 10).frame(minHeight: 26)
                    .background(location.isLowBattery ? theme.destructive.opacity(0.12) : Color.Roamrr.pill, in: Capsule())
                Text(isOffline ? "Last known \(location.lastSeen(on: now))" : (isLive ? "Updated just now" : "Last seen \(location.lastSeen(on: now))"))
                    .textRole(.footnote).foregroundStyle(theme.labelSecondary)
            }
            if location.isLowBattery {
                Text("Low battery. Their location may stop updating soon.")
                    .textRole(.footnote).foregroundStyle(theme.destructive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var batterySymbol: String {
        switch location.battery {
        case ...10: "battery.0percent"
        case ...35: "battery.25percent"
        case ...65: "battery.50percent"
        case ...90: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private var trend: some View {
        let state = isHeld ? LiveTracker.Trend.steady : (tracker.trends[location.id] ?? .steady)
        let title: String
        let symbol: String
        if isHeld {
            (title, symbol) = ("Staying put", "hand.raised")
        } else {
            switch state {
            case .closer: (title, symbol) = ("Getting closer", "arrow.down.right")
            case .farther: (title, symbol) = ("Moving away", "arrow.up.right")
            case .steady: (title, symbol) = ("Staying put", "equal")
            }
        }
        return Label(title, systemImage: symbol)
            .textRole(.subheadline, emphasized: true)
            .foregroundStyle(state == .closer ? Palette.accent.color : theme.labelSecondary)
            .padding(.horizontal, theme.spacing.sm)
            .frame(minHeight: 32)
            .background(state == .closer ? Palette.accentSoft.color : Color.Roamrr.pill, in: Capsule())
            .animation(DesignSystem.Motion.enter, value: state)
    }
}

/// The bar that stays up while you share: when it ends, and Stop. Tapping it opens the details.
private struct SharingBar: View {
    let session: SharingSession
    let onOpen: () -> Void
    let onStop: () -> Void

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Button(action: onOpen) {
                HStack(spacing: theme.spacing.sm) {
                    Circle().fill(theme.accent).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("You’re sharing").textRole(.body, emphasized: true).foregroundStyle(Color.Roamrr.onPanel)
                        Text(session.end.untilText(from: store.today))
                            .textRole(.subheadline).foregroundStyle(Color.Roamrr.onPanelSecondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button("Stop", action: onStop)
                .buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
        }
        .padding(.leading, theme.spacing.md)
        .padding(.trailing, theme.spacing.xs)
        .padding(.vertical, theme.spacing.xs)
        .background(Color.Roamrr.panel, in: Capsule())
        .floatingShadow()
    }
}

/// The flag that marks where the group meets.
private struct MeetingFlag: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: "flag.fill")
            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(theme.accent, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .markerShadow()
            .accessibilityLabel("Meeting point")
    }
}

/// The meeting point, how far it is, who has accepted, and a way to walk there.
private struct MeetingBar: View {
    let meeting: MeetingPoint
    let status: String
    let metres: Double
    let onDirections: () -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            MeetingFlag()
            VStack(alignment: .leading, spacing: 0) {
                Text(meeting.name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(1)
                Text("\(LiveTracker.label(metres)) · \(status)")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary).lineLimit(1)
            }
            Spacer(minLength: theme.spacing.xs)
            Button("Directions", systemImage: "figure.walk", action: onDirections)
                .labelStyle(.iconOnly).buttonStyle(.dsIcon(.filled))
            if meeting.proposedBy == store.me {
                Button("Remove meeting point", systemImage: "xmark", action: onCancel)
                    .labelStyle(.iconOnly).buttonStyle(.dsIcon(.filled))
            }
        }
        .padding(theme.spacing.xs)
        .padding(.leading, theme.spacing.xs)
        .background(theme.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .floatingShadow()
    }
}

/// An arrow that points towards where someone was last seen. It needs no internet: only your own position and theirs.
/// North is up until the phone's compass heading is connected.
private struct CompassArrow: View {
    let bearing: Double

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(direction).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                Text("north is up").textRole(.footnote).foregroundStyle(theme.labelSecondary)
            }
            Image(systemName: "location.north.fill")
                .font(.system(size: 22, weight: .bold)).foregroundStyle(Color.Roamrr.onPanel)
                .rotationEffect(.degrees(bearing))
                .frame(width: 52, height: 52)
                .background(Color.Roamrr.panel, in: Circle())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Head \(direction)")
    }

    private var direction: String {
        let names = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
        return names[Int((bearing + 22.5) / 45) % 8]
    }
}
