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
    var onSignOut: () -> Void = {}

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
            SettingsHomeView(
                me: store.profile,
                onSaveProfile: { store.updateProfile(name: $0, colorIndex: $1, photo: $2) },
                onSignOut: onSignOut
            )
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .environment(store)
        .environment(\.popToTrips) { path = NavigationPath() }
        .environment(\.signedInMember, store.profile)
        .onAppear { store.startMonitoring() }
    }
}

#Preview {
    MainTabView().theme(.roamrr)
}
