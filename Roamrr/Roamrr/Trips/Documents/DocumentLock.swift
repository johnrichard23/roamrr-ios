import LocalAuthentication
import Observation

/// Keeps My documents behind Face ID, Touch ID or the phone's passcode. It locks again when the app leaves the
/// screen, so a phone handed over mid-trip does not show a passport.
@Observable
final class DocumentLock {
    enum State: Equatable {
        case locked
        case unlocking
        case unlocked
        /// The phone has no passcode, so there is nothing to protect the documents with.
        case unavailable
    }

    private(set) var state = State.locked

    var isUnlocked: Bool { state == .unlocked }

    func unlock() async {
        guard state == .locked || state == .unavailable else { return }
        let context = LAContext()
        var problem: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &problem) else {
            state = .unavailable
            return
        }
        state = .unlocking
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication, localizedReason: "Open your passport and insurance documents"
            )
            state = success ? .unlocked : .locked
        } catch {
            state = .locked
        }
    }

    func lock() {
        if state == .unlocked { state = .locked }
    }
}
