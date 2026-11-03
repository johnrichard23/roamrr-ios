import CoreLocation
import MapKit
import RoamrrDesign
import SwiftUI

/// What opens the meeting point sheet: for one person, or for everyone.
struct MeetingSeed: Identifiable {
    let id = UUID()
    var recipient: AvatarMember?
}

/// Picks a place to meet: move the map under the pin, name it, say who it is for.
struct MeetingPointSheet: View {
    let tripID: Trip.ID
    let recipient: AvatarMember?
    let myCoordinate: CLLocationCoordinate2D
    let theirCoordinate: CLLocationCoordinate2D?

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var camera: MapCameraPosition
    @State private var center: CLLocationCoordinate2D
    @State private var name = "Meeting point"
    @State private var everyone: Bool
    @FocusState private var nameFocused: Bool

    init(tripID: Trip.ID, recipient: AvatarMember?, myCoordinate: CLLocationCoordinate2D, theirCoordinate: CLLocationCoordinate2D?) {
        self.tripID = tripID
        self.recipient = recipient
        self.myCoordinate = myCoordinate
        self.theirCoordinate = theirCoordinate
        let start = Self.middle(myCoordinate, theirCoordinate)
        _camera = State(initialValue: .region(MKCoordinateRegion(center: start, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))))
        _center = State(initialValue: start)
        _everyone = State(initialValue: recipient == nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
                Spacer()
                Text("Meeting point").textRole(.headline).foregroundStyle(theme.labelPrimary)
                Spacer()
                Color.clear.frame(width: 72, height: 44)
            }
            .frame(minHeight: 44)

            Text("Where should we meet?").stepTitleStyle().foregroundStyle(theme.labelPrimary)

            Map(position: $camera)
                .mapControlVisibility(.hidden)
                .onMapCameraChange(frequency: .continuous) { center = $0.region.center }
                .overlay {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(theme.accent, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .markerShadow()
                        .offset(y: -19)
                        .allowsHitTesting(false)
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            ScrollView(.horizontal) {
                HStack(spacing: theme.spacing.xs) {
                    shortcut("Between us", "arrow.left.and.right") { move(to: Self.middle(myCoordinate, theirCoordinate)) }
                    shortcut("My spot", "location.fill") { move(to: myCoordinate) }
                    if let theirCoordinate {
                        shortcut("\(firstName)’s spot", "person.fill") { move(to: theirCoordinate) }
                    }
                }
            }
            .scrollIndicators(.hidden)

            DSTextField("Name it", placeholder: "Cloud 9 boardwalk", text: $name, isFocused: $nameFocused, autocapitalization: .words)

            if let recipient {
                Picker("Who is it for", selection: $everyone) {
                    Text("Just \(firstName(of: recipient))").tag(false)
                    Text("Everyone").tag(true)
                }
                .pickerStyle(.segmented)
            }

            Spacer(minLength: 0)
            Button("Propose meeting point", systemImage: "flag.fill") { propose() }
                .buttonStyle(.ds(.ink))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.bottom, theme.spacing.sm)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .background(theme.background)
        .scrollDismissesKeyboard(.interactively)
        .presentationDragIndicator(.visible)
    }

    private var firstName: String { recipient.map(firstName(of:)) ?? "" }

    private func firstName(of member: AvatarMember) -> String {
        member.name.split(separator: " ").first.map(String.init) ?? member.name
    }

    private func shortcut(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                .padding(.horizontal, theme.spacing.sm).frame(minHeight: 36)
                .background(Color.Roamrr.pill, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func move(to spot: CLLocationCoordinate2D) {
        withAnimation(DesignSystem.Motion.camera) { camera = .region(MKCoordinateRegion(center: spot, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))) }
    }

    private func propose() {
        let audience: [AvatarMember] = (recipient != nil && !everyone) ? [recipient].compactMap { $0 } : []
        store.propose(
            MeetingPoint(
                id: UUID(), name: name.trimmingCharacters(in: .whitespaces), latitude: center.latitude, longitude: center.longitude,
                proposedBy: store.me, audience: audience
            ),
            in: tripID
        )
        dismiss()
    }

    private static func middle(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D?) -> CLLocationCoordinate2D {
        guard let b else { return a }
        return CLLocationCoordinate2D(latitude: (a.latitude + b.latitude) / 2, longitude: (a.longitude + b.longitude) / 2)
    }
}
