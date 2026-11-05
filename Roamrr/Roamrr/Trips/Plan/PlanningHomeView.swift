import RoamrrDesign
import SwiftUI

/// P0: the home of a trip that is still being planned: the best ideas, who has voted, and the way to finalise.
struct PlanningHomeView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(TripsStore.self) private var store
    @State private var showAdd = false
    @State private var showDates = false
    @State private var showExpense = false
    @State private var confirmFinalise = false
    @State private var showSettings = false
    @State private var showItinerary = false
    @State private var showDocuments = false

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    /// In landscape and at the largest text sizes a pinned bar would cover the page, so it scrolls with the content.
    private var inlineDock: Bool { isLandscape || typeSize.isAccessibilitySize }

    private func isOwner(_ trip: Trip) -> Bool { trip.owner == nil || trip.owner == store.me }

    private func content(_ trip: Trip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                TripCoverBand(trip: trip)
                header(trip)
                topIdeas(trip)
                voted(trip)
                if inlineDock { dock(trip) }
            }
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(edges: .top)
        .background(theme.background)
        .safeAreaInset(edge: .bottom) { if !inlineDock { dock(trip) } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // The places that matter later, kept one tap away instead of crowding the page while the group is still deciding.
                Menu("Trip options", systemImage: "ellipsis") {
                    Button("Itinerary", systemImage: "calendar") { showItinerary = true }
                    Button("Documents", systemImage: "doc.text") { showDocuments = true }
                    Button("Add expense", systemImage: "wallet.pass") { showExpense = true }
                    Divider()
                    Button("Trip settings", systemImage: "gearshape") { showSettings = true }
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) { TripSettingsView(tripID: trip.id) }
        .navigationDestination(isPresented: $showItinerary) { PlanView(tripID: trip.id, startOnDays: true) }
        .navigationDestination(isPresented: $showDocuments) { DocumentsView(tripID: trip.id) }
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
            // One row when it fits, stacked when the text is large, so the page never grows wider than the screen.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.xs) { StageChip(title: "Planning"); dates(trip) }
                VStack(alignment: .leading, spacing: theme.spacing.xs) { StageChip(title: "Planning"); dates(trip) }
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func dates(_ trip: Trip) -> some View {
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
        let info = HStack(spacing: theme.spacing.sm) {
            AvatarStack(split.voted + split.waiting, limit: 3, diameter: 28, ring: Color.Roamrr.pill)
            VStack(alignment: .leading, spacing: 0) {
                Text(alone ? "Just you so far" : "\(split.voted.count) of \(trip.peopleCount) voted").textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                Text(alone ? "Invite friends to add ideas and vote" : (names.isEmpty ? "Everyone has voted" : (names.count > 2 ? "Waiting for \(names.count) people" : "Waiting for \(names.joined(separator: " and "))")))
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
        }
        let invite = ShareLink(item: "Join my trip “\(trip.title)” on Roamrr and vote on ideas. Code \(trip.code)") {
            Label("Invite", systemImage: "person.badge.plus")
                .textRole(.subheadline, emphasized: true)
                .foregroundStyle(theme.labelPrimary)
                .padding(.horizontal, theme.spacing.sm).frame(minHeight: 44)
                .background(theme.background, in: Capsule())
                .fixedSize()
        }
        .buttonStyle(.plain)
        // Side by side when there is room; stacked when the text is large, so the card never grows wider than the screen.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.sm))
            : AnyLayout(HStackLayout(spacing: theme.spacing.sm))
        return layout {
            info.lineLimit(typeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.8)
            if !typeSize.isAccessibilitySize { Spacer(minLength: theme.spacing.xs) }
            invite
        }
        .padding(theme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .padding(.horizontal, theme.spacing.lg)
        .accessibilityElement(children: .combine)
    }

    // MARK: Dock

    private func dock(_ trip: Trip) -> some View {
        VStack(spacing: theme.spacing.xs) {
            if isOwner(trip) {
                HStack(spacing: theme.spacing.xs) {
                    Button("Add idea", systemImage: "plus") { showAdd = true }
                        .labelStyle(.iconOnly).buttonStyle(.dsIcon(.filled))
                    // One clear next step: pick the dates first, then finalise. No greyed-out button with a note above it.
                    if trip.datesDecided {
                        Button("Finalise itinerary", systemImage: "checkmark.circle") { confirmFinalise = true }
                            .buttonStyle(.ds(.ink))
                    } else {
                        Button("Set dates", systemImage: "calendar") { showDates = true }
                            .buttonStyle(.ds(.ink))
                    }
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
        // Solid, so the page never shows through or runs under the bar.
        .background(theme.background)
    }
}

/// An idea in the Top ideas rail: its picture, name, votes, and a bar of how much of the group wants it.
struct IdeaRailCard: View {
    let item: PlanItem
    let people: Int

    @Environment(\.theme) private var theme
    /// Wider as the text grows, so a title wraps on word breaks and not mid-word.
    @ScaledMetric(relativeTo: .body) private var scaledWidth: CGFloat = 156
    private var width: CGFloat { min(scaledWidth, 232) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if IdeaArt(item: item).hasArt {
                    IdeaArt(item: item)
                } else {
                    Palette.accentSoft.color
                }
            }
            .frame(width: width, height: width * 104 / 156).clipped()
            .overlay(alignment: .topTrailing) {
                if item.photos.count > 1 {
                    Label("\(item.photos.count)", systemImage: "photo.on.rectangle.angled")
                        .textRole(.footnote, emphasized: true).foregroundStyle(theme.labelPrimary)
                        .padding(.horizontal, 8).frame(minHeight: 26)
                        .background(Color.Roamrr.pill.opacity(0.95), in: Capsule())
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                    .lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading)
                Text("\(item.count(.must)) must · \(item.count(.want)) want")
                    .textRole(.footnote).foregroundStyle(theme.labelSecondary)
                bar
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 14)
        }
        .frame(width: width, alignment: .leading)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var bar: some View {
        let width = self.width - 24
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
