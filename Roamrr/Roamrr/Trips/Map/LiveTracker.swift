import CoreLocation
import Foundation
import Observation

/// Where people are right now, and whether each one is getting closer to you.
/// Mock: live members drift a few metres every couple of seconds so the distance can be watched changing.
/// The real version feeds this from the location service and the backend.
@Observable
final class LiveTracker {
    enum Trend { case closer, farther, steady }

    /// Your own position, until the phone's location is wired up.
    private(set) var me: CLLocationCoordinate2D
    private var snappedMe = false
    private(set) var positions: [String: CLLocationCoordinate2D] = [:]
    private(set) var trends: [String: Trend] = [:]
    /// Where each person has just been, oldest first, ending at their current spot. The trail drawn behind them.
    private(set) var trails: [String: [CLLocationCoordinate2D]] = [:]
    private var live: Set<String> = []
    /// The road each followed person walks along: from where they were, to you.
    private var walkingPaths: [String: [CLLocationCoordinate2D]] = [:]
    private static let trailLength = 60

    init(me: CLLocationCoordinate2D) {
        self.me = me
    }

    func load(_ locations: [MemberLocation], now: Date) {
        for location in locations where positions[location.id] == nil {
            positions[location.id] = location.coordinate
            trails[location.id] = [location.coordinate]
        }
        live = Set(locations.filter { $0.isLive(on: now) }.map(\.id))
    }

    /// Metres from you to this person.
    func distance(to id: String) -> Double? {
        guard let spot = positions[id] else { return nil }
        return CLLocation(latitude: me.latitude, longitude: me.longitude)
            .distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
    }

    /// Puts the mock positions onto the road the route starts and ends on, once, so no straight stub is drawn off the road.
    /// Real positions come from the phone and are on the road already.
    func snap(id: String, route: [CLLocationCoordinate2D]) {
        guard let first = route.first, let last = route.last else { return }
        if !snappedMe { me = first; snappedMe = true }
        positions[id] = last
        trails[id] = [last]
    }

    /// Hands over the walking route from you to this person, which they now walk along towards you.
    func setPath(for id: String, route: [CLLocationCoordinate2D]) {
        walkingPaths[id] = Array(route.reversed())
    }

    /// Mock: the person you are following walks along the road towards you, a few metres each time, and their trail
    /// records exactly where they have been. Everyone else stays where they were last seen. Real tracking replaces this
    /// with the position updates, which are on the road because the person was.
    func tick(following id: String?, held: Set<String> = []) {
        guard let id, !held.contains(id), live.contains(id), let from = positions[id], let path = walkingPaths[id], path.count > 1,
              let before = distance(to: id) else { return }
        let here = CLLocation(latitude: from.latitude, longitude: from.longitude)
        var nearest = 0
        var best = Double.infinity
        for (index, point) in path.enumerated() {
            let gap = here.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
            if gap < best { best = gap; nearest = index }
        }
        // Rejoin the road first; then head for the next bend.
        let target = path[best > 8 ? nearest : min(nearest + 1, path.count - 1)]
        let step = Double.random(in: 12...22)
        let remaining = here.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
        guard remaining > 1 else { return }
        let fraction = min(1, step / remaining)
        let next = CLLocationCoordinate2D(
            latitude: from.latitude + (target.latitude - from.latitude) * fraction,
            longitude: from.longitude + (target.longitude - from.longitude) * fraction
        )
        positions[id] = next
        append(next, to: id)
        let after = distance(to: id) ?? before
        trends[id] = abs(after - before) < 3 ? .steady : (after < before ? .closer : .farther)
    }

    /// Adds a point to someone's trail, skipping repeats and keeping only the latest stretch.
    private func append(_ point: CLLocationCoordinate2D, to id: String) {
        var trail = trails[id] ?? []
        if let last = trail.last, last.latitude == point.latitude, last.longitude == point.longitude { return }
        trail.append(point)
        if trail.count > Self.trailLength { trail.removeFirst(trail.count - Self.trailLength) }
        trails[id] = trail
    }

    /// The compass direction from you to this person, in degrees clockwise from north.
    func bearing(to id: String) -> Double? {
        guard let spot = positions[id] else { return nil }
        let a = me.latitude * .pi / 180, b = spot.latitude * .pi / 180
        let d = (spot.longitude - me.longitude) * .pi / 180
        let y = sin(d) * cos(b)
        let x = cos(a) * sin(b) - sin(a) * cos(b) * cos(d)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: Words

    /// "350 m", or "1.2 km" from a kilometre up.
    static func label(_ metres: Double) -> String {
        if metres < 1000 { return "\(max(10, Int((metres / 10).rounded()) * 10)) m" }
        return String(format: "%.1f km", metres / 1000)
    }

    /// "21 min", from a travel time in seconds.
    static func minutes(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    /// "4 min walk", at an easy walking pace.
    static func walk(_ metres: Double) -> String {
        let minutes = Int((metres / 80).rounded(.up))
        return minutes < 1 ? "1 min walk" : minutes < 60 ? "\(minutes) min walk" : "\(minutes / 60) h \(minutes % 60) min walk"
    }
}
