import CoreLocation
import MapKit
import SwiftUI

/// A place Apple Maps found: a name, a short address line, and where it is.
struct PlaceResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let detail: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Looks places up with Apple Maps. Free, native, and needs a connection; saved places work without one.
enum PlaceSearch {
    /// Up to six matches for what was typed, near `around` when we know where the trip is.
    static func find(_ text: String, around: CLLocationCoordinate2D?, hint: String = "") async -> [PlaceResult] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        let request = MKLocalSearch.Request()
        // With no position to go on, the trip's place name keeps results to the right part of the world.
        let area = hint.trimmingCharacters(in: .whitespaces)
        request.naturalLanguageQuery = (area.isEmpty || query.localizedCaseInsensitiveContains(area)) ? query : "\(query) \(area)"
        request.resultTypes = [.pointOfInterest, .address]
        if let around {
            request.region = MKCoordinateRegion(center: around, span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0))
        }
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.prefix(6).map { item in
            let placemark = item.placemark
            let detail = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea]
                .compactMap { $0 }.joined(separator: ", ")
            return PlaceResult(name: item.name ?? query, detail: detail, coordinate: placemark.coordinate)
        }
    }
}

extension PlaceSearch {
    /// Finds roughly where a trip is from its place name, once, so searches are about that area.
    static func locate(_ name: String) async -> CLLocationCoordinate2D? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let marks = try? await CLGeocoder().geocodeAddressString(trimmed)
        return marks?.first?.location?.coordinate
    }
}

extension Trip {
    /// Where the trip roughly is, from anything on it that has a position, to focus the search.
    var searchCenter: CLLocationCoordinate2D? {
        let points = locations.map(\.coordinate) + plan.compactMap(\.coordinate)
        guard !points.isEmpty else { return nil }
        return CLLocationCoordinate2D(
            latitude: points.map(\.latitude).reduce(0, +) / Double(points.count),
            longitude: points.map(\.longitude).reduce(0, +) / Double(points.count)
        )
    }
}
