import CoreLocation
import PhotosUI
import RoamrrDesign
import SwiftUI

/// A small chat for finding each other: one-tap signals, short notes, photos of where you are, and meeting points.
struct ChatSheet: View {
    let tripID: Trip.ID
    let member: AvatarMember
    let myCoordinate: CLLocationCoordinate2D
    let theirCoordinate: CLLocationCoordinate2D?

    static let characterLimit = 140

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var text = ""
    @State private var photo: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showMeeting = false
    @FocusState private var focused: Bool

    private var trip: Trip? { store.trip(id: tripID) }
    private var messages: [ChatMessage] { trip?.chats[member.id] ?? [] }
    private var firstName: String { member.name.split(separator: " ").first.map(String.init) ?? member.name }

    var body: some View {
        VStack(spacing: 0) {
            header
            conversation
            composer
        }
        .background(theme.background)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showMeeting) {
            MeetingPointSheet(tripID: tripID, recipient: member, myCoordinate: myCoordinate, theirCoordinate: theirCoordinate)
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { photo = data.compressedPhoto }
                pickerItem = nil
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: theme.spacing.sm) {
            MemberAvatar(member, diameter: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(member.name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                Text(subtitle).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
            Spacer()
            Button("Meeting point", systemImage: "flag") { showMeeting = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.dsIcon(.filled))
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.dsIcon(.filled))
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .padding(.bottom, theme.spacing.xs)
    }

    private var subtitle: String {
        if trip?.staying.contains(member.id) == true { return "Staying put for you" }
        guard let spot = theirCoordinate else { return "" }
        let metres = CLLocation(latitude: myCoordinate.latitude, longitude: myCoordinate.longitude)
            .distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
        return "\(LiveTracker.label(metres)) away"
    }

    // MARK: Messages

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacing.xs) {
                    if messages.isEmpty {
                        VStack(spacing: theme.spacing.xs) {
                            Text("Tell \(firstName) where you are").textRole(.headline).foregroundStyle(theme.labelPrimary)
                            Text("Send a signal, a short note, or a photo of what is around you.")
                                .textRole(.subheadline).foregroundStyle(theme.labelSecondary).multilineTextAlignment(.center)
                        }
                        .padding(.top, theme.spacing.xl)
                    }
                    ForEach(messages) { message in
                        bubble(message).id(message.id)
                    }
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.vertical, theme.spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                withAnimation(DesignSystem.Motion.enter) { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onAppear { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
        }
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        let mine = message.from == store.me
        if message.kind == .meeting, let point = trip?.meetingPoint, point.id == message.meetingID, let trip {
            MeetingCard(point: point, trip: trip, memberForReply: member)
                .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        } else {
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    if let data = message.photo, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(width: 220, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityLabel("Photo from \(mine ? "you" : firstName)")
                    }
                    if !message.text.isEmpty {
                        HStack(spacing: 6) {
                            if message.kind == .signal {
                                Image(systemName: QuickSignal.allCases.first { $0.text == message.text }?.symbol ?? "bolt")
                            }
                            Text(message.text)
                        }
                        .textRole(.body, emphasized: message.kind == .signal)
                        .padding(.horizontal, message.photo == nil ? 0 : 8)
                    }
                }
                .foregroundStyle(mine ? Color.Roamrr.onInk : theme.labelPrimary)
                .padding(message.photo == nil ? EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12) : EdgeInsets(top: 4, leading: 4, bottom: 8, trailing: 4))
                .frame(maxWidth: message.photo == nil ? nil : 236, alignment: .leading)
                .background(background(for: message, mine: mine), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                if message.isPending {
                    Label("Waiting for a connection", systemImage: "clock").textRole(.footnote).foregroundStyle(theme.labelSecondary)
                } else {
                    Text(message.date.clockTime).textRole(.footnote).foregroundStyle(theme.labelTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        }
    }

    private func background(for message: ChatMessage, mine: Bool) -> Color {
        if mine { return Color.Roamrr.ink }
        return message.kind == .signal ? Palette.accentSoft.color : Color.Roamrr.pill
    }

    // MARK: Composer

    private var replies: [String] {
        if let last = messages.last, last.from == member, last.kind == .signal || last.kind == .meeting {
            return ["Okay, got it", "Wait, 5 min", "Can’t, sorry"]
        }
        return []
    }

    private var composer: some View {
        VStack(spacing: theme.spacing.xs) {
            ScrollView(.horizontal) {
                HStack(spacing: theme.spacing.xs) {
                    ForEach(replies, id: \.self) { reply in
                        chip(reply, symbol: nil) { send(text: reply, kind: .text) }
                    }
                    ForEach(QuickSignal.allCases, id: \.self) { signal in
                        chip(signal.text, symbol: signal.symbol) { send(text: signal.text, kind: .signal) }
                    }
                }
                .padding(.horizontal, theme.spacing.lg)
            }
            .scrollIndicators(.hidden)

            if let photo, let image = UIImage(data: photo) {
                HStack {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button("Remove photo", systemImage: "xmark.circle.fill") { self.photo = nil }
                                .labelStyle(.iconOnly).foregroundStyle(.white, .black.opacity(0.6)).offset(x: 6, y: -6)
                        }
                    Spacer()
                }
                .padding(.horizontal, theme.spacing.lg)
            }

            HStack(alignment: .bottom, spacing: theme.spacing.xs) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(theme.labelPrimary)
                        .frame(width: 44, height: 44).background(Color.Roamrr.pill, in: Circle())
                }
                .accessibilityLabel("Add a photo")
                VStack(alignment: .trailing, spacing: 0) {
                    TextField("Message", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focused)
                        .textRole(.body)
                        .onChange(of: text) { _, value in
                            if value.count > Self.characterLimit { text = String(value.prefix(Self.characterLimit)) }
                        }
                    if text.count > 100 {
                        Text("\(text.count)/\(Self.characterLimit)").textRole(.footnote).foregroundStyle(theme.labelTertiary)
                    }
                }
                .padding(.horizontal, theme.spacing.sm)
                .padding(.vertical, 10)
                .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Button("Send", systemImage: "arrow.up") {
                    send(text: text.trimmingCharacters(in: .whitespacesAndNewlines), kind: photo == nil ? .text : .photo)
                }
                .labelStyle(.iconOnly)
                .font(.system(.body, weight: .bold))
                .foregroundStyle(Color.Roamrr.onInk)
                .frame(width: 44, height: 44)
                .background(canSend ? Color.Roamrr.ink : theme.separator, in: Circle())
                .disabled(!canSend)
            }
            .padding(.horizontal, theme.spacing.lg)
        }
        .padding(.top, theme.spacing.xs)
        .padding(.bottom, theme.spacing.sm)
        .background(theme.background)
        .sensoryFeedback(.impact(weight: .light), trigger: messages.count)
    }

    private var canSend: Bool {
        photo != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func chip(_ title: String, symbol: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .textRole(.subheadline, emphasized: true)
            .foregroundStyle(symbol == nil ? theme.labelPrimary : Palette.accent.color)
            .padding(.horizontal, theme.spacing.sm)
            .frame(minHeight: 36)
            .background(symbol == nil ? Color.Roamrr.pill : Palette.accentSoft.color, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func send(text: String, kind: ChatKind) {
        guard !text.isEmpty || photo != nil else { return }
        store.send(
            ChatMessage(id: UUID(), from: store.me, kind: kind, text: text, photo: photo, meetingID: nil, date: store.now),
            to: member, in: tripID
        )
        self.text = ""
        photo = nil
    }
}

/// A meeting point inside the chat, with the buttons to answer it when it is for you.
private struct MeetingCard: View {
    let point: MeetingPoint
    let trip: Trip
    let memberForReply: AvatarMember

    @Environment(\.theme) private var theme
    @Environment(TripsStore.self) private var store

    private var forMe: Bool {
        point.proposedBy != store.me && point.recipients(in: trip, me: store.me).contains(store.me)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Label("Meeting point", systemImage: "flag.fill")
                .textRole(.subheadline, emphasized: true).foregroundStyle(Palette.accent.color)
            Text(point.name).textRole(.headline).foregroundStyle(theme.labelPrimary)
            Text(point.status(in: trip, me: store.me)).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            if forMe, point.responses[store.me.id] == nil {
                HStack(spacing: theme.spacing.xs) {
                    Button("Accept") { store.respond(.accepted, in: trip.id, with: memberForReply) }
                        .buttonStyle(.ds(.ink, size: .regular, expandsWidth: true))
                    Button("Can’t make it") { store.respond(.declined, in: trip.id, with: memberForReply) }
                        .buttonStyle(.ds(.neutral, size: .regular, expandsWidth: true))
                        .minimumScaleFactor(0.8).lineLimit(1)
                }
                .padding(.top, 2)
            }
        }
        .padding(theme.spacing.md)
        .frame(maxWidth: 320, alignment: .leading)
        .background(theme.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(theme.separator, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}
