import PhotosUI
import RoamrrDesign
import SwiftUI

/// D11: a trip's settings. The owner changes the facts and runs the group; everyone else sees them and can mute or leave.
struct TripSettingsView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.popToTrips) private var popToTrips
    @Environment(TripsStore.self) private var store
    @State private var showName = false
    @State private var showDates = false
    @State private var showCover = false
    @State private var confirmReopen = false
    @State private var confirmLeave = false
    @State private var removing: AvatarMember?

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            Color.clear.background(theme.background)
        }
    }

    private func isOwner(_ trip: Trip) -> Bool { trip.owner == nil || trip.owner == store.me }

    private func content(_ trip: Trip) -> some View {
        let owner = isOwner(trip)
        let ownerName = trip.owner?.name.split(separator: " ").first.map(String.init) ?? "the owner"
        return ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                if owner { coverRow(trip) }
                section("Trip", foot: owner
                    ? "The home currency is fixed once the first expense is added."
                    : "Only \(ownerName) can change these.") {
                    row("Name", trip.title, tappable: owner) { showName = true }
                    row("Dates", trip.dates, tappable: owner) { showDates = true }
                    row("Home currency", "PHP", locked: true)
                    if !owner { row("Owner", trip.owner?.name ?? "", tappable: false) }
                }
                if owner { stageSection(trip) }
                membersSection(trip, owner: owner)
                section("Notifications", foot: "Turn off to stop hearing about this trip without leaving it.") {
                    Toggle(isOn: Binding(
                        get: { trip.notificationsOn },
                        set: { store.setNotifications($0, in: tripID) }
                    )) {
                        Label("Updates from this trip", systemImage: "bell").textRole(.body).foregroundStyle(theme.labelPrimary)
                    }
                    .tint(theme.labelPrimary)
                    .padding(.horizontal, theme.spacing.md).frame(minHeight: 56)
                }
                leaveSection(trip, owner: owner, ownerName: ownerName)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationTitle("Trip settings")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .sheet(isPresented: $showName) { RenameSheet(tripID: tripID, current: trip.title) }
        .sheet(isPresented: $showDates) {
            SetDatesSheet(tripID: tripID, current: trip.datesDecided ? (trip.start, trip.end) : nil)
        }
        .sheet(isPresented: $showCover) { CoverSheet(tripID: tripID) }
        .confirmationDialog("Reopen planning?", isPresented: $confirmReopen, titleVisibility: .visible) {
            Button("Reopen planning") { store.reopenPlanning(tripID) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The trip goes back to the planning screen. Nothing is deleted.")
        }
        .confirmationDialog(
            removing.map { "Remove \(first($0)) from the trip?" } ?? "",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            if let member = removing {
                Button("Remove \(first(member))", role: .destructive) { store.remove(member, from: tripID) }
            }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: {
            if let member = removing { Text(removeMessage(member, trip)) }
        }
        .confirmationDialog("Leave \(trip.title)?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave trip", role: .destructive) {
                popToTrips()
                store.leave(tripID)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(leaveMessage(trip))
        }
    }

    // MARK: Sections

    private func coverRow(_ trip: Trip) -> some View {
        Button { showCover = true } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let data = trip.coverPhoto, let image = UIImage(data: data) {
                        Color.clear.overlay { Image(uiImage: image).resizable().scaledToFill() }.clipped()
                    } else {
                        CoverArt(trip.cover)
                    }
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
                Label("Change cover", systemImage: "camera")
                    .textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                    .padding(.horizontal, theme.spacing.sm).frame(minHeight: 40)
                    .background(Color.Roamrr.pill, in: Capsule())
                    .padding(theme.spacing.xs)
            }
        }
        .buttonStyle(.plain)
    }

    private func stageSection(_ trip: Trip) -> some View {
        section("Running the trip", foot: trip.isPlanning
            ? "Finalise the itinerary from the planning screen once the dates are set."
            : "Reopening planning keeps everything, and people can still add ideas.") {
            row("Stage", trip.isPlanning ? "Planning" : (trip.isPast(on: store.today) ? "Ended" : "Itinerary final"), tappable: false)
            if !trip.isPlanning && !trip.isPast(on: store.today) {
                Button { confirmReopen = true } label: {
                    HStack {
                        Label("Reopen planning", systemImage: "arrow.uturn.backward").textRole(.body).foregroundStyle(theme.labelPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
                    }
                    .padding(.horizontal, theme.spacing.md).frame(minHeight: 56).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func membersSection(_ trip: Trip, owner: Bool) -> some View {
        let people = [store.me] + trip.members
        return VStack(alignment: .leading, spacing: theme.spacing.xs) {
            PageSectionTitle(title: "Members", note: "\(people.count)")
            GroupedRows(data: people, dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { person in
                HStack(spacing: theme.spacing.sm) {
                    MemberAvatar(person, diameter: 44)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(person == store.me ? "You" : person.name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                        Text(memberDetail(person, trip)).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    }
                    Spacer(minLength: theme.spacing.xs)
                    if owner, person != store.me {
                        Button("Remove") { removing = person }
                            .textRole(.subheadline, emphasized: true).foregroundStyle(theme.destructive)
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, theme.spacing.md).padding(.vertical, theme.spacing.xs)
                .accessibilityElement(children: .combine)
            }
            if owner {
                Text("Removing someone keeps their past expenses and payments, so balances stay right.")
                    .textRole(.footnote).foregroundStyle(theme.labelSecondary).padding(.horizontal, 4)
            }
        }
    }

    private func leaveSection(_ trip: Trip, owner: Bool, ownerName: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Button { confirmLeave = true } label: {
                Label("Leave trip", systemImage: "rectangle.portrait.and.arrow.right")
                    .textRole(.body, emphasized: true)
                    .foregroundStyle(owner ? theme.labelTertiary : theme.destructive)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(owner)
            if owner {
                Text("You’re the owner, so you can’t leave yet. Handing the trip to someone else comes in a later update.")
                    .textRole(.footnote).foregroundStyle(theme.labelSecondary).padding(.horizontal, 4)
            }
        }
    }

    // MARK: Rows

    private func section<Content: View>(_ title: String, foot: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            PageSectionTitle(title: title)
            VStack(spacing: 0, content: content)
                .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
            if let foot { Text(foot).textRole(.footnote).foregroundStyle(theme.labelSecondary).padding(.horizontal, 4) }
        }
    }

    private func row(_ label: String, _ value: String, tappable: Bool = false, locked: Bool = false, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            HStack {
                Text(label).textRole(.body).foregroundStyle(theme.labelPrimary)
                Spacer(minLength: theme.spacing.sm)
                Text(value).textRole(.body).foregroundStyle(theme.labelSecondary).lineLimit(1)
                if locked {
                    Image(systemName: "lock").font(.system(.footnote)).foregroundStyle(theme.labelTertiary)
                } else if tappable {
                    Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
                }
            }
            .padding(.horizontal, theme.spacing.md).frame(minHeight: 56).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(tappable)
    }

    // MARK: Words

    private func first(_ member: AvatarMember) -> String { member.name.split(separator: " ").first.map(String.init) ?? member.name }

    private func memberDetail(_ person: AvatarMember, _ trip: Trip) -> String {
        if person == trip.owner || (trip.owner == nil && person == store.me) { return "Owner" }
        let amount = trip.standings.first { $0.member == person }?.amount ?? 0
        if amount == 0 { return "Settled" }
        return amount > 0 ? "Is owed \(Money.peso(amount))" : "Owes \(Money.peso(-amount))"
    }

    private func removeMessage(_ member: AvatarMember, _ trip: Trip) -> String {
        let amount = trip.standings.first { $0.member == member }?.amount ?? 0
        let money = amount == 0 ? "" : (amount > 0 ? "\(first(member)) is still owed \(Money.peso(amount)). " : "\(first(member)) still owes \(Money.peso(-amount)). ")
        return "\(money)That stays in the balances, and their expenses stay. Their location sharing stops."
    }

    private func leaveMessage(_ trip: Trip) -> String {
        let amount = trip.balance ?? 0
        let money: String
        if amount > 0 { money = "The group owes you \(Money.peso(amount)). That stays in their balances, but you" }
        else if amount < 0 { money = "You owe the group \(Money.peso(-amount)). That stays in their balances, and you" }
        else { money = "You" }
        return "\(money) won’t see the trip or add to it after you leave."
    }
}

// MARK: - Sheets

private struct RenameSheet: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var name: String
    @FocusState private var focused: Bool

    init(tripID: Trip.ID, current: String) {
        self.tripID = tripID
        _name = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                DSTextField("Trip name", placeholder: "Sagada weekend", text: $name, isFocused: $focused, autocapitalization: .words)
                Spacer()
            }
            .padding(.horizontal, theme.spacing.lg)
            .background(theme.background)
            .dsSheetToolbar("Name", cancel: { dismiss() })
            .safeAreaInset(edge: .bottom) {
                Button("Save") {
                    store.rename(tripID, to: name.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .buttonStyle(.ds(.ink))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, theme.spacing.lg).padding(.vertical, theme.spacing.sm)
                .background(theme.background)
            }
        }
        .presentationDetents([.medium])
    }
}

private struct CoverSheet: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                Text("Pick an illustration").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                HStack(spacing: theme.spacing.sm) {
                    ForEach([CoverStyle.sea, .city, .hills], id: \.self) { style in
                        Button {
                            store.setCover(style, photo: nil, in: tripID)
                            dismiss()
                        } label: {
                            CoverArt(style)
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose a photo", systemImage: "photo")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(theme.labelPrimary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.Roamrr.pill, in: Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, theme.spacing.lg)
            .background(theme.background)
            .dsSheetToolbar("Cover", cancel: { dismiss() })
        }
        .presentationDetents([.medium])
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.setCover(store.trip(id: tripID)?.cover ?? .sea, photo: data.compressedPhoto, in: tripID)
                    dismiss()
                }
            }
        }
    }
}
