import RoamrrDesign
import SwiftUI

/// B4: one document: the file, what was read from it, and where it sits in the plan.
struct DocumentDetailView: View {
    let tripID: Trip.ID
    let documentID: TripDocument.ID

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var confirmDelete = false

    var body: some View {
        if let trip = store.trip(id: tripID), let document = trip.documents.first(where: { $0.id == documentID }) {
            content(trip, document)
        } else {
            Color.clear.background(theme.background)
        }
    }

    private func content(_ trip: Trip, _ document: TripDocument) -> some View {
        let canChange = document.addedBy == store.me || trip.owner == nil || trip.owner == store.me
        return ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                VStack(spacing: theme.spacing.xs) {
                    Image(systemName: document.kind.symbol).font(.system(size: 34, weight: .regular)).foregroundStyle(theme.accent)
                    Text(document.fileName).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
                .accessibilityElement(children: .combine)
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.kind.rawValue.uppercased()).textRole(.footnote, emphasized: true).foregroundStyle(theme.accent)
                    Text(document.title).displayTitleStyle().foregroundStyle(theme.labelPrimary)
                }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
                facts(document)
                planStatus(trip, document)
                if canChange {
                    Button { confirmDelete = true } label: {
                        Label("Delete document", systemImage: "trash")
                            .textRole(.body, emphasized: true).foregroundStyle(theme.destructive)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Only \(document.addedBy.name.split(separator: " ").first.map(String.init) ?? document.addedBy.name) or the trip owner can change this.")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary).frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationTitle("Document")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .confirmationDialog("Delete this document?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete document", role: .destructive) {
                store.deleteDocument(document.id, in: tripID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is removed for everyone. Anything already on the plan stays there.")
        }
    }

    private func facts(_ document: TripDocument) -> some View {
        var rows: [(String, String)] = []
        if !document.place.isEmpty { rows.append(("Place", document.place)) }
        if let start = document.start {
            rows.append((document.kind == .stay ? "Check-in" : "When", [start.weekdayDayMonth, document.minutes.map(PlanItem.clockText)].compactMap { $0 }.joined(separator: " · ")))
        }
        if let end = document.end { rows.append(("Check-out", end.weekdayDayMonth)) }
        if !document.confirmation.isEmpty { rows.append(("Confirmation", document.confirmation)) }
        rows.append(("Added by", document.addedBy == store.me ? "You" : document.addedBy.name))
        rows.append(("Who can see it", document.visibility == .trip ? "The whole trip" : "Only \(document.addedBy == store.me ? "you" : document.addedBy.name)"))
        let items = rows.map { Fact(label: $0.0, value: $0.1) }
        return GroupedRows(data: items, dividerInset: theme.spacing.md) { fact in
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sm) {
                Text(fact.label).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                Spacer(minLength: theme.spacing.sm)
                Text(fact.value).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary).multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, theme.spacing.md).padding(.vertical, theme.spacing.xs).frame(minHeight: 48)
            .accessibilityElement(children: .combine)
        }
    }

    private struct Fact: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    @ViewBuilder
    private func planStatus(_ trip: Trip, _ document: TripDocument) -> some View {
        if let itemID = document.planItemID, let item = trip.plan.first(where: { $0.id == itemID }), let day = item.day {
            NavigationLink(value: PlanRoute(tripID: trip.id, itemID: item.id)) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("On the plan").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                        Text(day.weekdayDayMonth).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(theme.labelTertiary)
                }
                .padding(theme.spacing.md)
                .background(Palette.accentSoft.color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
