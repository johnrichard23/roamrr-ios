import RoamrrDesign
import SwiftUI

/// What opens the join sheet: nothing, or a code from a link to fill in.
struct JoinSeed: Identifiable {
    let id = UUID()
    var code: String?
}

/// T3 and T4: type or paste the code, then see the trip and join it.
struct JoinTripSheet: View {
    let onOpen: (Trip.ID) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var model: JoinTripViewModel
    @FocusState private var codeFocused: Bool

    init(store: TripsStore, seed: JoinSeed, onOpen: @escaping (Trip.ID) -> Void) {
        self.onOpen = onOpen
        _model = State(initialValue: JoinTripViewModel(store: store, code: seed.code))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            header
            if let preview = model.preview {
                confirm(preview)
            } else {
                entry
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .background(theme.background)
        .animation(DesignSystem.Motion.enter, value: model.preview == nil)
        .animation(DesignSystem.Motion.enter, value: model.failure)
        .presentationDragIndicator(.visible)
        .onAppear { codeFocused = model.preview == nil }
    }

    private var header: some View {
        HStack {
            if model.preview == nil {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
            } else {
                Button("Back", systemImage: "chevron.left") { model.backToCode() }
                    .buttonStyle(.dsIcon(.filled))
            }
            Spacer()
            Text(model.preview == nil ? "Join a trip" : "Join trip").textRole(.headline).foregroundStyle(theme.labelPrimary)
            Spacer()
            Color.clear.frame(width: 72, height: 44)
        }
        .frame(minHeight: 44)
    }

    // MARK: T3

    private var entry: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Enter the code a friend shared with you.").stepTitleStyle().foregroundStyle(theme.labelPrimary)
                .accessibilityAddTraits(.isHeader)
            CodeBoxes(code: model.code, isError: model.failure?.isCodeProblem == true, isFocused: codeFocused)
                .overlay {
                    TextField("", text: Binding(get: { model.code }, set: { model.code = $0 }))
                        .focused($codeFocused)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .foregroundStyle(.clear)
                        .tint(.clear)
                        .accessibilityLabel("Trip code")
                }
            if let failure = model.failure {
                notice(failure)
            } else {
                Text("Ask a friend in the trip for the 8-character code.")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
            Button("Paste code", systemImage: "doc.on.clipboard") { paste() }
                .buttonStyle(.ds(.soft, size: .regular, expandsWidth: false))
            Spacer(minLength: 0)
            Button(primaryTitle) { Task { await primaryAction() } }
                .buttonStyle(.ds(.ink))
                .disabled(primaryDisabled)
                .padding(.bottom, theme.spacing.sm)
        }
    }

    private func notice(_ failure: JoinFailure) -> some View {
        let isOffline = failure == .offline
        return Label(failure.message, systemImage: isOffline ? "wifi.slash" : "exclamationmark.circle")
            .textRole(.subheadline)
            .foregroundStyle(isOffline ? theme.labelSecondary : theme.destructive)
            .padding(theme.spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isOffline ? Color.Roamrr.pill : theme.destructive.opacity(0.1),
                in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
            )
            .accessibilityElement(children: .combine)
    }

    /// One next step per problem: fix the letters, or start over with another code.
    private var primaryTitle: String {
        switch model.failure {
        case .notFound: "Try again"
        case .none, .offline: "Continue"
        default: "Enter another code"
        }
    }

    private var primaryDisabled: Bool {
        switch model.failure {
        case .notFound, .expired, .usedUp, .full, .archived, .removed: false
        case .offline: true
        case .none: !model.canContinue
        }
    }

    private func primaryAction() async {
        switch model.failure {
        case .none:
            await model.lookUp()
        case .notFound:
            codeFocused = true
        default:
            model.clear()
            codeFocused = true
        }
    }

    private func paste() {
        guard let text = UIPasteboard.general.string else { return }
        model.code = text
        codeFocused = false
    }

    // MARK: T4

    private func confirm(_ preview: JoinPreview) -> some View {
        let trip = preview.trip
        let people = trip.members.count + (preview.alreadyOn ? 1 : 1)
        return VStack(alignment: .leading, spacing: theme.spacing.md) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    TripCoverCard(trip: trip, subtitle: "\(trip.dates) · \(people) people") {
                        EmptyView()
                    } bottom: {
                        HStack(spacing: theme.spacing.xs) {
                            AvatarStack(trip.members + (preview.alreadyOn ? [] : [store.me]), diameter: 32, ring: Color.Roamrr.panel)
                            Spacer()
                        }
                        HStack(spacing: theme.spacing.xs) {
                            MemberAvatar(preview.invitedBy, diameter: 24)
                            Text("\(preview.invitedBy.name) invited you")
                                .textRole(.subheadline).foregroundStyle(Color.Roamrr.onPanelSecondary)
                        }
                    }
                    if preview.alreadyOn {
                        banner("You’re already on this trip.", systemImage: "checkmark.circle")
                    } else if let name = preview.asPlaceholder {
                        banner(
                            "\(preview.invitedBy.name.split(separator: " ").first.map(String.init) ?? "They") added you as \(name). You’ll take over that spot and its expenses.",
                            systemImage: "person.badge.plus"
                        )
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: theme.spacing.xs) {
                Button(preview.alreadyOn ? "Open trip" : "Join trip") {
                    Task {
                        if let id = await model.join() {
                            dismiss()
                            onOpen(id)
                        }
                    }
                }
                .buttonStyle(.ds(.ink))
                .disabled(model.isWorking)
                if !preview.alreadyOn {
                    Button("Cancel") { dismiss() }.buttonStyle(.ds(.plain))
                }
            }
            .padding(.bottom, theme.spacing.sm)
        }
    }

    private func banner(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .textRole(.subheadline).foregroundStyle(theme.labelPrimary)
            .padding(theme.spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.accentSoft.color, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

/// Eight boxes in two groups of four. The letters come from a field laid over them.
struct CodeBoxes: View {
    let code: String
    let isError: Bool
    let isFocused: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            group(0..<4)
            group(4..<8)
        }
        .accessibilityHidden(true)
    }

    private func group(_ range: Range<Int>) -> some View {
        HStack(spacing: 6) {
            ForEach(range, id: \.self) { index in
                let character = index < code.count ? String(Array(code)[index]) : ""
                let isNext = isFocused && index == min(code.count, 7)
                Text(character)
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(isError ? theme.destructive : theme.labelPrimary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                            .strokeBorder(isError ? theme.destructive : (isNext ? theme.labelPrimary : theme.separator), lineWidth: isNext || isError ? 2 : 1)
                    }
            }
        }
    }
}
