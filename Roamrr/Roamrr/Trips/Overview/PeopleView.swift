import RoamrrDesign
import SwiftUI

/// D6: who is on the trip, when they joined, and the code that lets others in.
struct PeopleView: View {
    let tripID: Trip.ID

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store
    @State private var copied = false

    var body: some View {
        if let trip = store.trip(id: tripID) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase")
        }
    }

    private func content(_ trip: Trip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                PageSectionTitle(title: "\(trip.peopleCount) \(trip.peopleCount == 1 ? "person" : "people")")
                GroupedRows(data: people(trip), dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { person in
                    PersonRow(person: person)
                }
                codePill(trip)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .safeAreaInset(edge: .bottom) {
            if !trip.isPast(on: store.today) {
                ShareLink(item: shareText(trip)) {
                    Label("Invite friends", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.ds(.ink))
                .padding(.horizontal, theme.spacing.lg)
                .padding(.vertical, theme.spacing.xs)
            }
        }
    }

    // MARK: Pieces

    struct Person: Identifiable {
        let member: AvatarMember
        let isMe: Bool
        let detail: String
        let isOwner: Bool

        var id: String { member.id }
    }

    /// The owner first, then you, then everyone else in the order they joined.
    private func people(_ trip: Trip) -> [Person] {
        func person(_ member: AvatarMember, isMe: Bool) -> Person {
            let isOwner = trip.owner.map { $0 == member } ?? isMe
            let detail: String
            if isOwner {
                detail = "Created the trip"
            } else if let date = trip.joined[member.id] {
                detail = "Joined \(date.dayMonth)"
            } else {
                detail = "Joined"
            }
            return Person(member: member, isMe: isMe, detail: detail, isOwner: isOwner)
        }
        let all = [person(store.me, isMe: true)] + trip.members.map { person($0, isMe: false) }
        return all.filter(\.isOwner) + all.filter { !$0.isOwner && $0.isMe } + all.filter { !$0.isOwner && !$0.isMe }
    }

    private func shareText(_ trip: Trip) -> String {
        "Join my trip “\(trip.title)” on Roamrr. Code \(trip.code)\nroamrr://join?code=\(trip.code.replacingOccurrences(of: "-", with: ""))"
    }

    private func codePill(_ trip: Trip) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Trip code").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                Text(trip.code)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(theme.labelPrimary)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = trip.code
                copied = true
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.ds(.neutral, size: .regular, expandsWidth: false))
            .sensoryFeedback(.success, trigger: copied)
        }
        .padding(theme.spacing.md)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
    }
}

private struct PersonRow: View {
    let person: PeopleView.Person

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            MemberAvatar(person.member, diameter: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text(person.isMe ? "You" : person.member.name)
                    .textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                Text(person.detail).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
            Spacer(minLength: theme.spacing.xs)
            if person.isOwner {
                Text("Owner").textRole(.subheadline, emphasized: true).foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
