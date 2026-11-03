import RoamrrDesign
import SwiftUI

/// P3: one idea: its picture, link, note, everyone's reactions, and what to do with it.
struct IdeaDetailView: View {
    let tripID: Trip.ID
    let itemID: PlanItem.ID

    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var showDay = false
    @State private var showEdit = false
    @State private var showExpense = false
    @State private var confirmDelete = false
    @State private var meetingSet = false

    var body: some View {
        if let trip = store.trip(id: tripID), let item = trip.plan.first(where: { $0.id == itemID }) {
            content(trip, item)
        } else {
            Color.clear.background(theme.background)
        }
    }

    private func content(_ trip: Trip, _ item: PlanItem) -> some View {
        let canChange = item.addedBy == store.me || trip.owner == nil || trip.owner == store.me
        return ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                if IdeaArt(item: item).hasArt {
                    IdeaArt(item: item)
                        .frame(maxWidth: .infinity).frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
                        .accessibilityHidden(true)
                }
                header(item)
                if let link = item.link { LinkCard(link: link) }
                if !item.note.isEmpty {
                    Text(item.note).textRole(.body).foregroundStyle(theme.labelPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(theme.spacing.md)
                        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                if item.day != nil { schedule(item) }
                ReactionRow(item: item, me: store.me) { store.react($0, on: item.id, in: tripID) }
                actions(trip, item)
                who(trip, item)
                if canChange {
                    Button { confirmDelete = true } label: {
                        Label("Delete idea", systemImage: "trash")
                            .textRole(.body, emphasized: true).foregroundStyle(theme.destructive)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Only \(item.addedBy.name.split(separator: " ").first.map(String.init) ?? item.addedBy.name) or the trip owner can change this.")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary).frame(maxWidth: .infinity)
                }
                // In landscape a pinned bar would cover a third of the screen, so it scrolls with the content.
                if isLandscape, canSchedule(trip) { dayButton(trip, item) }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationTitle("Idea")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .toolbar {
            if canChange && !trip.isPast(on: store.today) {
                ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isLandscape, canSchedule(trip) {
                dayButton(trip, item)
                    .padding(.horizontal, theme.spacing.lg).padding(.vertical, theme.spacing.xs)
            }
        }
        .sheet(isPresented: $showDay) { AddToDaySheet(trip: trip, item: item) }
        .sheet(isPresented: $showEdit) { AddIdeaSheet(trip: trip, editing: item) }
        .sheet(isPresented: $showExpense) { AddExpenseSheet(trip: trip, me: store.me, today: store.today, from: item) }
        .confirmationDialog("Delete this idea?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete idea", role: .destructive) {
                store.deleteIdea(item.id, in: tripID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It's removed for everyone, along with its votes.")
        }
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private func canSchedule(_ trip: Trip) -> Bool { !trip.isPast(on: store.today) && !trip.days.isEmpty }

    private func dayButton(_ trip: Trip, _ item: PlanItem) -> some View {
        Button(item.day == nil ? "Add to a day" : "Change day or time", systemImage: "calendar") { showDay = true }
            .buttonStyle(.ds(.ink))
    }

    // MARK: Pieces

    private func header(_ item: PlanItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(item.category.rawValue, systemImage: item.category.symbol)
                .textRole(.subheadline, emphasized: true).foregroundStyle(theme.accent)
            Text(item.title).displayTitleStyle().foregroundStyle(theme.labelPrimary)
            HStack(spacing: 8) {
                MemberAvatar(item.addedBy, diameter: 22)
                Text(byLine(item)).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
            if let cost = item.cost {
                Text("About \(Money.peso(cost)) each").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func byLine(_ item: PlanItem) -> String {
        let name = item.addedBy == store.me ? "you" : (item.addedBy.name.split(separator: " ").first.map(String.init) ?? item.addedBy.name)
        return item.placeName.isEmpty ? "Added by \(name)" : "Added by \(name) · \(item.placeName)"
    }

    /// Where it sits in the plan, and for optional items, whether you are in.
    private func schedule(_ item: PlanItem) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Label("\(item.day?.weekdayDayMonth ?? "")\(item.timeText.map { " · \($0)" } ?? "")", systemImage: "calendar")
                .textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
            if item.audience == .interested {
                let isIn = item.going.contains(store.me.id)
                HStack {
                    Text("Optional · \(item.going.count) in").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    Spacer()
                    Button(isIn ? "I'm in" : "Count me in", systemImage: isIn ? "checkmark" : "plus") {
                        store.setGoing(!isIn, on: item.id, in: tripID)
                    }
                    .buttonStyle(.ds(isIn ? .soft : .neutral, size: .regular, expandsWidth: false))
                }
            } else {
                Text("Everyone").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
        }
        .padding(theme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accentSoft.color.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sensoryFeedback(.selection, trigger: item.going.count)
    }

    private func actions(_ trip: Trip, _ item: PlanItem) -> some View {
        HStack(spacing: theme.spacing.xs) {
            if item.coordinate != nil, !trip.isPast(on: store.today) {
                Button(meetingSet ? "Meeting point set" : "Meet here", systemImage: meetingSet ? "checkmark" : "mappin.and.ellipse") {
                    guard let spot = item.coordinate else { return }
                    store.propose(
                        MeetingPoint(
                            id: UUID(), name: item.placeName.isEmpty ? item.title : item.placeName,
                            latitude: spot.latitude, longitude: spot.longitude, proposedBy: store.me, audience: []
                        ),
                        in: tripID
                    )
                    meetingSet = true
                }
                .buttonStyle(.ds(.neutral))
                .disabled(meetingSet)
            }
            if item.cost != nil, !trip.isPast(on: store.today) {
                Button("Add expense", systemImage: "wallet.pass") { showExpense = true }
                    .buttonStyle(.ds(.neutral))
            }
        }
    }

    private func who(_ trip: Trip, _ item: PlanItem) -> some View {
        let people = [store.me] + trip.members
        let summary = [PlanReaction.must, .want].map { "\(item.count($0)) \($0.rawValue.lowercased())" }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: theme.spacing.xs) {
            PageSectionTitle(title: "Who is in", note: summary)
            GroupedRows(data: people, dividerInset: theme.spacing.md + 36 + theme.spacing.sm) { person in
                HStack(spacing: theme.spacing.sm) {
                    MemberAvatar(person, diameter: 36)
                    Text(person == store.me ? "You" : person.name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                    Spacer()
                    if let reaction = item.reactions[person.id] {
                        Text(reaction.rawValue).textRole(.subheadline, emphasized: true).foregroundStyle(theme.accent)
                    } else {
                        Text("No answer").textRole(.subheadline).foregroundStyle(theme.labelTertiary)
                    }
                }
                .padding(.horizontal, theme.spacing.md).padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
