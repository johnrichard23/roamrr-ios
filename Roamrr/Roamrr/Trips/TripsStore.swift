import Foundation
import Network
import Observation
import RoamrrDesign

/// The trips on this phone. Mock data until the data layer is connected.
@Observable
final class TripsStore {
    private(set) var trips: [Trip]
    let today: Date
    let me: AvatarMember
    private let created = Date()
    private(set) var networkDown = false
    private(set) var forcedOffline = false
    private let monitor = NWPathMonitor()
    private var monitoring = false

    /// No usable connection, or the tester has switched it off.
    var isOffline: Bool { networkDown || forcedOffline }

    init(trips: [Trip] = MockData.trips, today: Date = MockData.today, me: AvatarMember = MockData.you) {
        self.trips = trips
        self.today = today
        self.me = me
    }

    /// Trips that are happening or still to come, soonest first.
    var active: [Trip] {
        trips.filter { !$0.isPast(on: today) }.sorted { ($0.datesDecided ? $0.start : .distantFuture) < ($1.datesDecided ? $1.start : .distantFuture) }
    }

    /// Finished trips, most recent first.
    var past: [Trip] {
        trips.filter { $0.isPast(on: today) }.sorted { $0.end > $1.end }
    }

    func trip(id: Trip.ID) -> Trip? {
        trips.first { $0.id == id }
    }

    /// Records an expense on a trip and brings its balances up to date.
    func add(_ expense: Expense, to tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].add(expense, me: me)
    }

    /// Saves an edited expense and brings the trip's balances up to date.
    func update(_ old: Expense, to new: Expense, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].replace(old, with: new, me: me)
    }

    /// Deletes an expense and brings the trip's balances up to date.
    func delete(_ expense: Expense, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].remove(expense, me: me)
    }

    /// Starts (or changes) your location sharing on a trip, for this many hours.
    func startSharing(hours: Int, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].mySharing = SharingSession(start: today, end: today.addingTimeInterval(Double(hours) * 3600))
    }

    /// Stops sharing; the pin disappears for everyone else.
    func stopSharing(in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].mySharing = nil
    }

    /// Records a payment on a trip and brings its balances up to date.
    func record(_ payment: Payment, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].record(payment, me: me)
    }

    func add(_ trip: Trip) {
        trips.append(trip)
    }

    // MARK: Connection

    /// Starts watching the phone's connection. Messages written offline are sent when it comes back.
    func startMonitoring() {
        guard !monitoring else { return }
        monitoring = true
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.setNetworkDown(path.status != .satisfied) }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    func setNetworkDown(_ down: Bool) {
        let wasOffline = isOffline
        networkDown = down
        if wasOffline && !isOffline { flushPending() }
    }

    /// For testing without turning the simulator's network off.
    func setForcedOffline(_ offline: Bool) {
        let wasOffline = isOffline
        forcedOffline = offline
        if wasOffline && !isOffline { flushPending() }
    }

    /// Sends what was written offline, oldest first.
    private func flushPending() {
        for index in trips.indices {
            for at in trips[index].plan.indices { trips[index].plan[at].isPending = false }
        }
        for index in trips.indices {
            for (key, list) in trips[index].chats {
                guard let member = trips[index].members.first(where: { $0.id == key }) else { continue }
                for position in list.indices where list[position].isPending {
                    trips[index].chats[key]?[position].isPending = false
                    mockReply(to: list[position], from: member, in: trips[index].id)
                }
            }
        }
    }

    // MARK: Trip stage

    /// The owner locks in the itinerary. Anyone can still add ideas afterwards.
    func finalise(_ tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].stage = .final
    }

    /// Back to planning, if the group wants to start over.
    func reopenPlanning(_ tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].stage = .planning
    }

    func setDates(start: Date, end: Date, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].start = start
        trips[index].end = end
        trips[index].datesDecided = true
    }

    // MARK: Trip settings

    func rename(_ tripID: Trip.ID, to name: String) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].title = name
    }

    func setCover(_ style: CoverStyle, photo: Data?, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].cover = style
        trips[index].coverPhoto = photo
    }

    func setNotifications(_ on: Bool, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].notificationsOn = on
    }

    /// The owner takes someone off the trip. Their expenses and payments stay, so balances stay right; their sharing stops.
    func remove(_ member: AvatarMember, from tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].members.removeAll { $0 == member }
        trips[index].locations.removeAll { $0.member == member }
        trips[index].staying.remove(member.id)
        trips[index].chats[member.id] = nil
        if trips[index].meetingPoint?.proposedBy == member { trips[index].meetingPoint = nil }
    }

    /// You leave a trip you don't own. Mock: it just goes from this phone; the real app keeps it under Past trips.
    func leave(_ tripID: Trip.ID) {
        trips.removeAll { $0.id == tripID }
    }

    // MARK: Trip plan

    func addIdea(_ item: PlanItem, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        var saved = item
        saved.isPending = isOffline
        trips[index].plan.append(saved)
    }

    func updateIdea(_ item: PlanItem, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }),
              let at = trips[index].plan.firstIndex(where: { $0.id == item.id }) else { return }
        var saved = item
        saved.isPending = isOffline
        trips[index].plan[at] = saved
    }

    func deleteIdea(_ id: PlanItem.ID, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].plan.removeAll { $0.id == id }
    }

    /// Sets your reaction to an idea. Choosing the one you already have clears it.
    func react(_ reaction: PlanReaction, on id: PlanItem.ID, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }),
              let at = trips[index].plan.firstIndex(where: { $0.id == id }) else { return }
        if trips[index].plan[at].reactions[me.id] == reaction {
            trips[index].plan[at].reactions[me.id] = nil
        } else {
            trips[index].plan[at].reactions[me.id] = reaction
        }
        trips[index].plan[at].isPending = isOffline
    }

    /// Puts an idea on a day, or takes it off one when `day` is nil.
    func schedule(_ id: PlanItem.ID, day: Date?, minutes: Int?, audience: PlanAudience, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }),
              let at = trips[index].plan.firstIndex(where: { $0.id == id }) else { return }
        trips[index].plan[at].day = day
        trips[index].plan[at].minutes = day == nil ? nil : minutes
        trips[index].plan[at].audience = audience
        trips[index].plan[at].order = (trips[index].plan.map(\.order).max() ?? 0) + 1
        if audience == .interested, day != nil { trips[index].plan[at].going.insert(me.id) }
        if day == nil { trips[index].plan[at].going = [] }
        trips[index].plan[at].isPending = isOffline
    }

    func setGoing(_ going: Bool, on id: PlanItem.ID, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }),
              let at = trips[index].plan.firstIndex(where: { $0.id == id }) else { return }
        if going { trips[index].plan[at].going.insert(me.id) } else { trips[index].plan[at].going.remove(me.id) }
    }

    // MARK: Finding each other

    /// The mock clock: 9:41 AM on the day the drafts use, moving on as the app runs.
    var now: Date { today.addingTimeInterval(Date().timeIntervalSince(created)) }

    /// Sends a message to someone on a trip. The mock person answers a moment later.
    func send(_ message: ChatMessage, to member: AvatarMember, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        var sent = message
        sent.isPending = isOffline && message.from == me
        trips[index].chats[member.id, default: []].append(sent)
        guard message.from == me, !sent.isPending else { return }
        mockReply(to: message, from: member, in: tripID)
    }

    /// Proposes a meeting point and tells the people it is for.
    func propose(_ point: MeetingPoint, in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].meetingPoint = point
        let people = point.recipients(in: trips[index], me: me).filter { $0 != point.proposedBy }
        let others = point.proposedBy == me ? people : [point.proposedBy]
        for person in others {
            trips[index].chats[person.id, default: []].append(
                ChatMessage(id: UUID(), from: point.proposedBy, kind: .meeting, text: point.name, photo: nil, meetingID: point.id, date: now)
            )
        }
        guard point.proposedBy == me else { return }
        for person in people { mockMeetingAnswer(from: person, in: tripID) }
    }

    /// Answers a meeting point from your side.
    func respond(_ response: MeetingResponse, in tripID: Trip.ID, with member: AvatarMember) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }), trips[index].meetingPoint != nil else { return }
        trips[index].meetingPoint?.responses[me.id] = response
        let text = response == .declined ? "I can’t make it there." : "I’ll be there."
        trips[index].chats[member.id, default: []].append(
            ChatMessage(id: UUID(), from: me, kind: .text, text: text, photo: nil, meetingID: nil, date: now)
        )
    }

    /// Takes the meeting point off the map.
    func clearMeetingPoint(in tripID: Trip.ID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].meetingPoint = nil
    }

    // MARK: Mock people

    private func mockReply(to message: ChatMessage, from member: AvatarMember, in tripID: Trip.ID) {
        let text = message.text.lowercased()
        var answer = "Okay, got it."
        var holds = false
        var proposes = false
        switch message.kind {
        case .signal:
            if text.contains("stay put") { answer = "Okay, I’ll stay right here."; holds = true }
            else if text.contains("on my way") { answer = "Great, I’ll wait here." }
            else if text.contains("i’m here") { answer = "Nice, I can see you now." }
            else { answer = "I’m near the boardwalk, look for the blue sign." }
        case .photo:
            answer = "Got it, I can see where you are."
        case .text, .meeting:
            if text.contains("meet") { answer = "How about the boardwalk?"; proposes = true }
            else if text.contains("stay") || text.contains("wait") { answer = "Okay, I’ll stay here."; holds = true }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard let self, let index = self.trips.firstIndex(where: { $0.id == tripID }) else { return }
            self.trips[index].chats[member.id, default: []].append(
                ChatMessage(id: UUID(), from: member, kind: .text, text: answer, photo: nil, meetingID: nil, date: self.now)
            )
            if holds {
                self.trips[index].staying.insert(member.id)
                try? await Task.sleep(for: .seconds(120))
                self.trips[index].staying.remove(member.id)
            }
            if proposes, let spot = self.trips[index].locations.first(where: { $0.member == member }) {
                try? await Task.sleep(for: .seconds(0.8))
                self.propose(
                    MeetingPoint(
                        id: UUID(), name: spot.place, latitude: spot.latitude, longitude: spot.longitude,
                        proposedBy: member, audience: [self.me]
                    ),
                    in: tripID
                )
            }
        }
    }

    private func mockMeetingAnswer(from member: AvatarMember, in tripID: Trip.ID) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self, let index = self.trips.firstIndex(where: { $0.id == tripID }), let point = self.trips[index].meetingPoint else { return }
            self.trips[index].meetingPoint?.responses[member.id] = .accepted
            self.trips[index].chats[member.id, default: []].append(
                ChatMessage(id: UUID(), from: member, kind: .text, text: "Okay, see you at \(point.name).", photo: nil, meetingID: nil, date: self.now)
            )
        }
    }
}
