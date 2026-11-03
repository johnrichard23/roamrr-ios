import RoamrrDesign
import SwiftUI

/// The two tabs of a signed-in app: Trips and Settings.
private struct PopToTripsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Goes back to the Trips list from anywhere inside a trip.
    var popToTrips: () -> Void {
        get { self[PopToTripsKey.self] }
        set { self[PopToTripsKey.self] = newValue }
    }
}

struct MainTabView: View {
    @State private var store = TripsStore()
    @State private var path = NavigationPath()

    var body: some View {
        TabView {
            NavigationStack(path: $path) {
                TripsHomeView(openTrip: { path.append($0) })
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Trip.ID.self) { TripHomeView(tripID: $0) }
            }
            .tabItem { Label("Trips", systemImage: "suitcase") }
            SettingsPlaceholder()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .environment(store)
        .environment(\.popToTrips) { path = NavigationPath() }
        .onAppear { store.startMonitoring() }
    }
}

private struct SettingsPlaceholder: View {
    var body: some View {
        ContentUnavailableView("Settings", systemImage: "slider.horizontal.3", description: Text("Coming after Trips."))
    }
}

#Preview {
    MainTabView().theme(.roamrr)
}
