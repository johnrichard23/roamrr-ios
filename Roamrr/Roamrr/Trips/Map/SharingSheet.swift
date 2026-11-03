import RoamrrDesign
import SwiftUI

/// Where the location sheet starts.
enum SharingStage: Identifiable {
    case explainer, start, manage

    var id: Self { self }
}

/// X6, D10 and "Your location": what is shared, for how long, and stopping. One sheet that moves between them.
struct SharingSheet: View {
    static let seenKey = "roamrr.seenLocationExplainer"

    let trip: Trip

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var stage: SharingStage
    @State private var hours = 12

    init(trip: Trip, stage: SharingStage) {
        self.trip = trip
        _stage = State(initialValue: stage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            header
            Group {
                switch stage {
                case .explainer: explainer
                case .start: start
                case .manage: manage
                }
            }
            .id(stage)
            .transition(.opacity)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .background(theme.background)
        .animation(DesignSystem.Motion.enter, value: stage)
        .presentationDragIndicator(.visible)
        .presentationDetents(stage == .manage ? [.medium] : [.large])
    }

    private var others: [AvatarMember] { trip.members }

    private var names: String {
        let first = others.map { $0.name.split(separator: " ").first.map(String.init) ?? $0.name }
        guard first.count > 1 else { return first.first ?? "everyone" }
        return first.dropLast().joined(separator: ", ") + " and " + (first.last ?? "")
    }

    private var header: some View {
        HStack {
            switch stage {
            case .explainer: Color.clear.frame(width: 72, height: 44)
            case .start: Button("Cancel") { dismiss() }.buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
            case .manage: Color.clear.frame(width: 72, height: 44)
            }
            Spacer()
            Text(stage == .start ? "Share my location" : stage == .manage ? "Your location" : "Location")
                .textRole(.headline).foregroundStyle(theme.labelPrimary)
            Spacer()
            if stage == .manage {
                Button("Done") { dismiss() }.buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
            } else {
                Color.clear.frame(width: 72, height: 44)
            }
        }
        .frame(minHeight: 44)
    }

    // MARK: X6

    private var explainer: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            VStack(spacing: theme.spacing.sm) {
                Image(systemName: "location.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Palette.accent.color)
                    .frame(width: 72, height: 72)
                    .background(Palette.accentSoft.color, in: Circle())
                Text("Share your location with the trip").stepTitleStyle().foregroundStyle(theme.labelPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            GroupedRows(data: facts, dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { fact in
                HStack(spacing: theme.spacing.sm) {
                    Image(systemName: fact.symbol)
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Color.Roamrr.ice, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(fact.title).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                        Text(fact.detail).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.xs)
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
            Text("Next, your iPhone asks for permission. Choose “While Using the App”.")
                .textRole(.subheadline).foregroundStyle(theme.labelSecondary).frame(maxWidth: .infinity)
            VStack(spacing: theme.spacing.xs) {
                Button("Continue") {
                    UserDefaults.standard.set(true, forKey: Self.seenKey)
                    stage = .start
                }
                .buttonStyle(.ds(.ink))
                Button("Not now") { dismiss() }.buttonStyle(.ds(.plain))
            }
            .padding(.bottom, theme.spacing.sm)
        }
    }

    private struct Fact: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    private var facts: [Fact] {
        [
            Fact(symbol: "person.2", title: "Only this trip", detail: "\(names) see your pin. No one else."),
            Fact(symbol: "clock", title: "It stops on its own", detail: "You pick how long, from 1 hour to 3 days."),
            Fact(symbol: "lock", title: "No history", detail: "Only your latest spot is kept, and it’s cleared when you stop."),
        ]
    }

    // MARK: D10 start

    private var start: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text("For how long?").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                        GroupedRows(data: Self.durations, dividerInset: theme.spacing.md) { option in
                            Button { hours = option.hours } label: { durationRow(option) }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(hours == option.hours ? .isSelected : [])
                        }
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text("Who can see you").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                        HStack(spacing: theme.spacing.sm) {
                            AvatarStack(others, limit: 4, diameter: 36, ring: Color.Roamrr.pill)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Everyone on this trip").textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                                Text(names).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(theme.spacing.md)
                        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            Label("Only your latest spot is kept. It’s cleared when sharing ends.", systemImage: "lock")
                .textRole(.subheadline).foregroundStyle(theme.labelSecondary).frame(maxWidth: .infinity)
            Button("Start sharing", systemImage: "location.fill") {
                store.startSharing(hours: hours, in: trip.id)
                dismiss()
            }
            .buttonStyle(.ds(.ink))
            .padding(.bottom, theme.spacing.sm)
        }
        .sensoryFeedback(.selection, trigger: hours)
    }

    struct Duration: Identifiable {
        let hours: Int
        let title: String
        var id: Int { hours }
    }

    static let durations = [
        Duration(hours: 1, title: "1 hour"), Duration(hours: 4, title: "4 hours"), Duration(hours: 12, title: "12 hours"),
        Duration(hours: 24, title: "24 hours"), Duration(hours: 72, title: "3 days"),
    ]

    private func durationRow(_ option: Duration) -> some View {
        let isOn = hours == option.hours
        let end = store.today.addingTimeInterval(Double(option.hours) * 3600)
        return HStack(spacing: theme.spacing.sm) {
            Text(option.title).textRole(.body, emphasized: isOn).foregroundStyle(theme.labelPrimary)
            if option.hours == 12 {
                Text("Default").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
            Spacer()
            Text(end.untilText(from: store.today)).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                .font(.system(.title3)).foregroundStyle(isOn ? theme.labelPrimary : theme.border)
        }
        .padding(.horizontal, theme.spacing.md)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: Your location

    private var manage: some View {
        let session = trip.mySharing
        return VStack(alignment: .leading, spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text("You’re sharing for").textRole(.body).foregroundStyle(Color.Roamrr.onPanelSecondary)
                Text(session?.remaining(from: store.today) ?? "—").heroAmountStyle().foregroundStyle(Color.Roamrr.onPanel)
                Text("\(session?.end.untilText(from: store.today) ?? "") · started \(session?.start.clockTime ?? "")")
                    .textRole(.subheadline).foregroundStyle(Color.Roamrr.onPanelSecondary)
                ProgressView(value: session?.fractionLeft(from: store.today) ?? 0)
                    .tint(theme.accent)
                    .padding(.top, theme.spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.lg)
            .background(Color.Roamrr.panel, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
            .accessibilityElement(children: .combine)
            HStack(spacing: theme.spacing.sm) {
                AvatarStack(others, limit: 4, diameter: 32, ring: Color.Roamrr.pill)
                Text("The whole trip sees you live").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Button("Stop sharing") {
                store.stopSharing(in: trip.id)
                dismiss()
            }
            .buttonStyle(.ds(.destructive))
            Button("Change how long", systemImage: "clock") { stage = .start }
                .buttonStyle(.ds(.plain))
                .padding(.bottom, theme.spacing.sm)
        }
    }
}
