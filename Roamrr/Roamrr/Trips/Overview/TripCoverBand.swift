import RoamrrDesign
import SwiftUI

/// The short cover at the top of a trip's home: its photo or illustration, with rounded bottom corners.
struct TripCoverBand: View {
    let trip: Trip

    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        Group {
            if let data = trip.coverPhoto, let image = UIImage(data: data) {
                Color.clear.overlay { Image(uiImage: image).resizable().scaledToFill() }.clipped()
            } else {
                CoverArt(trip.cover)
            }
        }
        .frame(maxWidth: .infinity)
        // In landscape the screen is short, so the cover takes less of it.
        .frame(height: verticalSizeClass == .compact ? 110 : 190)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// "Planning", "On the trip": the stage of a trip in a soft pill.
struct StageChip: View {
    let title: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(theme.accent).frame(width: 6, height: 6)
            Text(title).textRole(.footnote, emphasized: true).fixedSize()
        }
        .foregroundStyle(Palette.accent.color)
        .padding(.horizontal, 12).frame(minHeight: 28)
        .background(Palette.accentSoft.color, in: Capsule())
    }
}

/// Picks the screen for a trip's stage and registers everything that screen can push.
struct TripHomeView: View {
    let tripID: Trip.ID

    @Environment(TripsStore.self) private var store
    @Namespace private var mapZoom

    var body: some View {
        Group {
            if let trip = store.trip(id: tripID) {
                if trip.isPlanning {
                    PlanningHomeView(tripID: tripID)
                } else {
                    TripOverviewView(tripID: tripID)
                }
            } else {
                ContentUnavailableView("Trip not found", systemImage: "suitcase")
            }
        }
        .environment(\.mapZoomNamespace, mapZoom)
        .navigationDestination(for: TripSection.self) { section in
            switch section {
            case .balances: BalancesView(tripID: tripID)
            case .expenses: ExpensesView(tripID: tripID)
            case .plan: PlanView(tripID: tripID)
            case .itinerary: PlanView(tripID: tripID, startOnDays: true)
            case .people: PeopleView(tripID: tripID)
            case .map: TripMapView(tripID: tripID).mapZoomDestination(in: mapZoom)
            case .documents: DocumentsView(tripID: tripID)
            case .myDocuments: MyDocumentsView()
            }
        }
        .navigationDestination(for: DocumentRoute.self) { DocumentDetailView(tripID: $0.tripID, documentID: $0.documentID) }
        .navigationDestination(for: PlanRoute.self) { IdeaDetailView(tripID: $0.tripID, itemID: $0.itemID) }
    }
}
