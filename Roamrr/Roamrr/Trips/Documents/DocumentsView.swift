import RoamrrDesign
import SwiftUI

/// What a row on the documents list pushes.
struct DocumentRoute: Hashable {
    let tripID: Trip.ID
    let documentID: TripDocument.ID
}

/// B1: the trip's bookings by kind, and the way into your private documents.
struct DocumentsView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(TripsStore.self) private var store
    @ScaledMetric(relativeTo: .body) private var tileScale: CGFloat = 1
    @State private var showAdd = false

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private func content(_ trip: Trip) -> some View {
        let documents = trip.documents(for: store.me)
        let canAdd = !trip.isPast(on: store.today)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing.md) {
                myDocumentsEntry
                if documents.isEmpty {
                    empty
                } else {
                    ForEach(DocumentKind.allCases, id: \.self) { kind in
                        let group = documents.filter { $0.kind == kind }
                        if !group.isEmpty {
                            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                                PageSectionTitle(title: kind.plural, note: "\(group.count)")
                                GroupedRows(data: group, dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { document in
                                    NavigationLink(value: DocumentRoute(tripID: trip.id, documentID: document.id)) {
                                        DocumentRow(document: document)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                // In landscape and at the largest text sizes a pinned bar would cover the list, so it scrolls with the content.
                if inlineAction, canAdd { addButton }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .safeAreaInset(edge: .bottom) {
            if !inlineAction, canAdd {
                addButton
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical, theme.spacing.xs)
                    .background(theme.background)
            }
        }
        .sheet(isPresented: $showAdd) { AddDocumentSheet(trip: trip) }
    }

    private var inlineAction: Bool { verticalSizeClass == .compact || typeSize.isAccessibilitySize }

    private var addButton: some View {
        Button("Add document", systemImage: "plus") { showAdd = true }
            .buttonStyle(.ds(.ink))
    }

    private var myDocumentsEntry: some View {
        NavigationLink(value: TripSection.myDocuments) {
            HStack(spacing: theme.spacing.sm) {
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "lock.fill")
                        .frame(width: 44 * tileScale, height: 44 * tileScale)
                        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("My documents").textRole(.body, emphasized: true)
                    Text("Passport, insurance. On this phone only.").textRole(.subheadline).opacity(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).opacity(0.6)
            }
            .foregroundStyle(Color.Roamrr.onPanel)
            .padding(theme.spacing.sm)
            .background(Color.Roamrr.panel, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: "doc.text")
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(Palette.accent.color)
                .frame(width: 72, height: 72).background(Palette.accentSoft.color, in: Circle())
            Text("Keep the bookings here").stepTitleStyle().foregroundStyle(theme.labelPrimary)
            Text("Add a flight, a hotel or a tour. Roamrr reads it on your phone and offers to put it on the right day.")
                .textRole(.body).foregroundStyle(theme.labelSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, theme.spacing.xl)
    }
}
