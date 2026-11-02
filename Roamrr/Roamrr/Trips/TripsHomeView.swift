import RoamrrDesign
import SwiftUI

/// T1: your trips. A greeting that says where you are, the trip that matters now, and the ones behind you.
struct TripsHomeView: View {
    /// Called when joining ends on a trip, so the app can show it.
    var openTrip: (Trip.ID) -> Void = { _ in }

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store

    @State private var showCreate = false
    @State private var joinSeed: JoinSeed?
    @State private var page: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xl) {
                toolbar
                greeting
                if store.active.isEmpty { emptyHero } else { hero }
                if !store.past.isEmpty { pastTrips }
                if store.active.isEmpty { emptyActions }
            }
            .padding(.top, theme.spacing.xs)
            .padding(.bottom, theme.spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .sheet(isPresented: $showCreate) { CreateTripSheet(onOpen: openTrip) }
        .sheet(item: $joinSeed) { seed in JoinTripSheet(store: store, seed: seed, onOpen: openTrip) }
    }

    // MARK: Top

    private var toolbar: some View {
        HStack {
            MemberAvatar(store.me, diameter: 44)
            Spacer()
            Button("Join") { joinSeed = JoinSeed() }
                .buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
            Button("Create trip", systemImage: "plus") { showCreate = true }
                .buttonStyle(.dsIcon(.filled))
        }
        .padding(.horizontal, theme.spacing.lg)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
            Text("Hi \(store.me.name.split(separator: " ").first.map(String.init) ?? ""),")
                .textRole(.body)
                .foregroundStyle(theme.labelSecondary)
            Text(store.active.first.map { $0.headline(on: store.today) } ?? "Where to first?")
                .displayTitleStyle()
                .foregroundStyle(theme.labelPrimary)
        }
        .padding(.horizontal, theme.spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: theme.spacing.sm) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: theme.spacing.sm) {
                    ForEach(store.active) { trip in
                        NavigationLink(value: trip.id) {
                            TripHeroCard(trip: trip, today: store.today, me: store.me)
                        }
                        .buttonStyle(.plain)
                        .containerRelativeFrame(.horizontal)
                            .id(trip.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, theme.spacing.lg, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $page)

            if store.active.count > 1 { dots }
        }
    }

    private var dots: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(store.active) { trip in
                Capsule()
                    .fill(trip.id == (page ?? store.active.first?.id) ? theme.labelPrimary : theme.separator)
                    .frame(width: trip.id == (page ?? store.active.first?.id) ? 20 : 6, height: 6)
            }
        }
        .animation(DesignSystem.Motion.enter, value: page)
        .accessibilityHidden(true)
    }

    private var emptyHero: some View {
        VStack(spacing: 0) {
            CoverArt(.hills).frame(maxWidth: .infinity, minHeight: 200)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text("Plan your first trip")
                    .font(.system(.title2, design: .serif, weight: .medium))
                    .foregroundStyle(Color.Roamrr.onPanel)
                Text("Make a trip, invite your friends, and keep every shared cost in one place.")
                    .textRole(.subheadline)
                    .foregroundStyle(Color.Roamrr.onPanelSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.md)
            .background(Color.Roamrr.panel)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .padding(.horizontal, theme.spacing.lg)
    }

    private var emptyActions: some View {
        VStack(spacing: theme.spacing.xs) {
            Button("Create a trip") { showCreate = true }.buttonStyle(.ds(.ink))
            Button("Join with a code") { joinSeed = JoinSeed() }.buttonStyle(.ds(.neutral))
        }
        .padding(.horizontal, theme.spacing.lg)
    }

    // MARK: Past trips

    private var pastTrips: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Text("Past trips").textRole(.title3, emphasized: true).foregroundStyle(theme.labelPrimary)
                Spacer()
                Button("See all") {}
                    .textRole(.subheadline, emphasized: true)
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, theme.spacing.lg)
            ScrollView(.horizontal) {
                LazyHStack(spacing: theme.spacing.sm) {
                    ForEach(store.past) { trip in
                        NavigationLink(value: trip.id) { PastTripCard(trip: trip) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, theme.spacing.lg, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
    }
}


#Preview("Trips") {
    TripsHomeView().environment(TripsStore()).theme(.roamrr)
}

#Preview("Empty") {
    TripsHomeView().environment(TripsStore(trips: [])).theme(.roamrr)
}

#Preview("Dark") {
    TripsHomeView().environment(TripsStore()).theme(.roamrr).preferredColorScheme(.dark)
}
