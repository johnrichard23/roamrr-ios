import RoamrrDesign
import SwiftUI

/// P0: the home of a trip that is still being planned: the best ideas, who has voted, and the way to finalise.
struct PlanningHomeView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(TripsStore.self) private var store
    @State private var showAdd = false
    @State private var showDates = false
    @State private var showExpense = false
    @State private var confirmFinalise = false
    @State private var showSettings = false

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private func isOwner(_ trip: Trip) -> Bool { trip.owner == nil || trip.owner == store.me }

    private func content(_ trip: Trip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                TripCoverBand(trip: trip)
                header(trip)
                topIdeas(trip)
                voted(trip)
                chips(trip)
                // In landscape a pinned bar would cover a third of the screen, so it scrolls with the content.
                if isLandscape { dock(trip) }
            }
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(edges: .top)
        .background(theme.background)
        .safeAreaInset(edge: .bottom) { if !isLandscape { dock(trip) } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Trip options", systemImage: "ellipsis") {
                    Button("Trip settings", systemImage: "gearshape") { showSettings = true }
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) { TripSettingsView(tripID: trip.id) }
        .sheet(isPresented: $showAdd) { AddIdeaSheet(trip: trip, editing: nil) }
        .sheet(isPresented: $showDates) { SetDatesSheet(tripID: trip.id) }
        .sheet(isPresented: $showExpense) { AddExpenseSheet(trip: trip, me: store.me, today: store.today) }
        .confirmationDialog("Finalise the itinerary?", isPresented: $confirmFinalise, titleVisibility: .visible) {
            Button("Finalise itinerary") { withAnimation(DesignSystem.Motion.enter) { store.finalise(trip.id) } }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text("Everyone is told. People can still add ideas afterwards.")
        }
    }

    // MARK: Pieces

    private func header(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(trip.title).displayTitleStyle().foregroundStyle(theme.labelPrimary)
            HStack(spacing: theme.spacing.xs) {
                StageChip(title: "Planning")
                if !trip.datesDecided && isOwner(trip) {
                    Button { showDates = true } label: {
                        HStack(spacing: 4) {
                            Text("Dates not decided yet")
                            Image(systemName: "chevron.right").font(.system(.caption, weight: .semibold))
                        }
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(trip.dates).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    private func topIdeas(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Top ideas").textRole(.headline).foregroundStyle(theme.labelPrimary)
                Spacer()
                if !trip.plan.isEmpty {
                    NavigationLink(value: TripSection.plan) {
                        Text("See all \(trip.plan.count)").textRole(.subheadline, emphasized: true).foregroundStyle(theme.accent)
                    }
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            if trip.plan.isEmpty {
                VStack(spacing: theme.spacing.xs) {
                    Text("Add the first idea").textRole(.headline).foregroundStyle(theme.labelPrimary)
                    Text("A restaurant, an activity, a sight. Everyone votes.")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
                .frame(maxWidth: .infinity).padding(theme.spacing.lg)
                .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
                .padding(.horizontal, theme.spacing.lg)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: theme.spacing.sm) {
                        ForEach(trip.ideas(in: nil).prefix(6)) { item in
                            NavigationLink(value: PlanRoute(tripID: trip.id, itemID: item.id)) {
                                IdeaRailCard(item: item, people: trip.peopleCount)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, theme.spacing.lg)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func voters(_ trip: Trip) -> (voted: [AvatarMember], waiting: [AvatarMember]) {
        let people = [store.me] + trip.members
        let ids = Set(trip.plan.flatMap { $0.reactions.keys })
        return (people.filter { ids.contains($0.id) }, people.filter { !ids.contains($0.id) })
    }

    private func voted(_ trip: Trip) -> some View {
        let split = voters(trip)
        let names = split.waiting.map { $0 == store.me ? "you" : ($0.name.split(separator: " ").first.map(String.init) ?? $0.name) }
        let alone = trip.members.isEmpty
        return HStack(spacing: theme.spacing.sm) {
            AvatarStack(split.voted + split.waiting, limit: 3, diameter: 28, ring: Color.Roamrr.pill)
            VStack(alignment: .leading, spacing: 0) {
                Text(alone ? "Just you so far" : "\(split.voted.count) of \(trip.peopleCount) voted").textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(1).minimumScaleFactor(0.75)
                Text(alone ? "Invite friends to add ideas and vote" : (names.isEmpty ? "Everyone has voted" : (names.count > 2 ? "Waiting for \(names.count) people" : "Waiting for \(names.joined(separator: " and "))")))
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: theme.spacing.xs)
            ShareLink(item: "Join my trip “\(trip.title)” on Roamrr and vote on ideas. Code \(trip.code)") {
                Label("Invite", systemImage: "person.badge.plus")
                    .textRole(.subheadline, emphasized: true)
                    .foregroundStyle(theme.labelPrimary)
                    .padding(.horizontal, theme.spacing.sm).frame(minHeight: 44)
                    .background(theme.background, in: Capsule())
                    .fixedSize()
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacing.md)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .padding(.horizontal, theme.spacing.lg)
        .accessibilityElement(children: .combine)
    }

    private func chips(_ trip: Trip) -> some View {
        HStack(spacing: theme.spacing.xs) {
            NavigationLink(value: TripSection.itinerary) {
                chip("calendar", "Itinerary", trip.plannedDayCount == 0 ? "Draft" : "\(trip.plannedDayCount) \(trip.plannedDayCount == 1 ? "day" : "days")")
            }
            Button { showExpense = true } label: {
                chip("wallet.pass", "Expense", trip.expenses.isEmpty ? "None" : Money.compact(trip.spent ?? 0))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, theme.spacing.lg)
    }

    private func chip(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(theme.accent)
            Text(title).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            Text(detail).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
        }
        .lineLimit(1)
        .padding(.horizontal, theme.spacing.sm).frame(minHeight: 44)
        .background(Color.Roamrr.pill, in: Capsule())
    }

    // MARK: Dock

    private func dock(_ trip: Trip) -> some View {
        VStack(spacing: theme.spacing.xs) {
            if isOwner(trip) {
                if !trip.datesDecided {
                    Text("Set the dates to finalise the itinerary.").textRole(.footnote).foregroundStyle(theme.labelSecondary)
                }
                HStack(spacing: theme.spacing.xs) {
                    Button("Add idea", systemImage: "plus") { showAdd = true }
                        .labelStyle(.iconOnly).buttonStyle(.dsIcon(.filled))
                    Button("Finalise itinerary", systemImage: "checkmark.circle") { confirmFinalise = true }
                        .buttonStyle(.ds(.ink))
                        .disabled(!trip.datesDecided)
                }
            } else {
                HStack(spacing: theme.spacing.xs) {
                    Button("Add idea", systemImage: "plus") { showAdd = true }
                        .labelStyle(.iconOnly).buttonStyle(.dsIcon(.filled))
                    Text("Waiting for \(trip.owner?.name.split(separator: " ").first.map(String.init) ?? "the owner") to finalise")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.Roamrr.pill, in: Capsule())
                }
            }
        }
        .padding(.horizontal, theme.spacing.lg).padding(.vertical, theme.spacing.xs)
        .background(.ultraThinMaterial.opacity(0.0))
    }
}

/// An idea in the Top ideas rail: its picture, name, votes, and a bar of how much of the group wants it.
struct IdeaRailCard: View {
    let item: PlanItem
    let people: Int

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if IdeaArt(item: item).hasArt {
                    IdeaArt(item: item)
                } else {
                    Palette.accentSoft.color
                }
            }
            .frame(width: 156, height: 104).clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                    .lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading)
                Text("\(item.count(.must)) must · \(item.count(.want)) want")
                    .textRole(.footnote).foregroundStyle(theme.labelSecondary)
                bar
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 14)
        }
        .frame(width: 156, alignment: .leading)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var bar: some View {
        let width: CGFloat = 132
        let total = CGFloat(max(people, 1))
        let must = width * CGFloat(item.count(.must)) / total
        let want = width * CGFloat(item.count(.want)) / total
        return ZStack(alignment: .leading) {
            Capsule().fill(theme.separator).frame(width: width, height: 6)
            HStack(spacing: 0) {
                Rectangle().fill(theme.accent).frame(width: must, height: 6)
                Rectangle().fill(theme.accent.opacity(0.45)).frame(width: want, height: 6)
            }
            .clipShape(Capsule())
        }
        .padding(.top, 6)
    }
}
