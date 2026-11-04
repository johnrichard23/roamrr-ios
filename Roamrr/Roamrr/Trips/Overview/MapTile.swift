import CoreLocation
import MapKit
import RoamrrDesign
import SwiftUI

/// A small, still map of who is sharing, with a label. Tapping it opens the full map, which grows out of the tile.
struct MapTile: View {
    let trip: Trip

    @Environment(\.theme) private var theme
    @Environment(\.mapZoomNamespace) private var zoomNamespace
    @Environment(TripsStore.self) private var store

    var body: some View {
        ZStack(alignment: .bottom) {
            if trip.locations.isEmpty, trip.meetingPoint == nil {
                Color.Roamrr.pill
                Image(systemName: "map").font(.system(size: 28)).foregroundStyle(theme.labelTertiary).offset(y: -22)
            } else {
                map
            }
            chip
        }
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        // The whole tile is the button, including the part where the map sits, which does not take touches itself.
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .mapZoomSource(in: zoomNamespace)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map, \(label)")
    }

    // MARK: Map

    private var map: some View {
        Map(initialPosition: .region(region), interactionModes: []) {
            // Today's planned places, as small flags that stay behind the people.
            ForEach(plannedToday) { item in
                if let spot = item.coordinate {
                    Annotation("", coordinate: spot, anchor: .center) { PlaceFlag() }.annotationTitles(.hidden)
                }
            }
            if let meeting = trip.meetingPoint {
                Annotation("", coordinate: meeting.coordinate, anchor: .center) { MeetingFlagPin() }.annotationTitles(.hidden)
            }
            ForEach(trip.locations) { location in
                Annotation("", coordinate: location.coordinate, anchor: .center) {
                    TilePin(location: location, isLive: location.isLive(on: store.now))
                }
                .annotationTitles(.hidden)
            }
        }
        // Muted and flat, with no shops or restaurants, so the people and the flags are what you see.
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .allowsHitTesting(false)
        // A flat wash in the palette's own canvas colour, so the map sits in the page and not on top of it.
        .overlay { Color.Roamrr.canvas.opacity(0.1).allowsHitTesting(false) }
    }

    // MARK: Label

    private var chip: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(1)
                    .contentTransition(.numericText())
                Text(detail).textRole(.footnote).foregroundStyle(theme.labelSecondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.Roamrr.pill.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(8)
        .animation(DesignSystem.Motion.enter, value: live)
    }

    private var liveMembers: [AvatarMember] { trip.sharingLive(on: store.now, me: store.me) }

    private var live: Int { liveMembers.count }

    private var label: String { trip.locations.isEmpty ? "Map" : "\(live) sharing live" }

    private var detail: String { trip.locations.isEmpty ? "No one is sharing" : "Tap to find them" }

    /// Today's planned places that have a spot, leaving out any that someone is standing on: the pin says it already.
    private var plannedToday: [PlanItem] {
        trip.planned(on: store.now).filter { item in
            guard let spot = item.coordinate else { return false }
            let here = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            return !trip.locations.contains { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: here) < 120 }
        }
    }

    /// Everyone, plus the meeting point, with room around them. Planned flags never stretch the view.
    private var region: MKCoordinateRegion {
        let points = trip.locations.map(\.coordinate) + (trip.meetingPoint.map { [$0.coordinate] } ?? [])
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

// MARK: Pins

/// A person on the tile: their colour as a ring and a dot while live, faded when their last update is old. Still, so
/// the positions it shows never move for style.
private struct TilePin: View {
    let location: MemberLocation
    let isLive: Bool

    @Environment(\.theme) private var theme
    var body: some View {
        ZStack {
            Circle().fill(.white).frame(width: 34, height: 34)
            Circle().fill(location.member.color).frame(width: 30, height: 30)
            MemberAvatar(location.member, diameter: 24)
            if isLive {
                Circle().fill(Palette.live.color).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: 12, y: 12)
            }
        }
        .opacity(isLive ? 1 : 0.6)
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }

}

/// The group's meeting point: the accent colour, so it stands apart from people.
private struct MeetingFlagPin: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: "flag.fill")
            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(theme.accent, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }
}

/// A place from today's plan: small and quiet, behind the people.
private struct PlaceFlag: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: "flag.fill")
            .font(.system(size: 8, weight: .bold)).foregroundStyle(theme.accent)
            .frame(width: 18, height: 18)
            .background(.white, in: Circle())
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}

// MARK: Press

/// Press feedback for the tile: it dips a little, the way buttons and cards do.
struct MapTilePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            // Under Reduce Motion the dip becomes a light fade: still feedback, no movement.
            .opacity(configuration.isPressed && reduceMotion ? 0.85 : 1)
            .animation(DesignSystem.Motion.press, value: configuration.isPressed)
    }
}

// MARK: Zoom

private struct MapZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Links the tile on a trip's home to the full map it opens, for the zoom transition.
    var mapZoomNamespace: Namespace.ID? {
        get { self[MapZoomNamespaceKey.self] }
        set { self[MapZoomNamespaceKey.self] = newValue }
    }
}

extension View {
    /// The tile is where the full map grows out of. The zoom transition needs iOS 18; earlier versions push as usual.
    @ViewBuilder
    func mapZoomSource(in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            matchedTransitionSource(id: "tripMap", in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func mapZoomDestination(in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: "tripMap", in: namespace))
        } else {
            self
        }
    }
}
