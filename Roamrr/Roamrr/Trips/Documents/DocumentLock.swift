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
    /// Bumped every time the lock closes, so an authentication that was already under way cannot open it afterwards.
    private var generation = 0

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
        let attempt = generation
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication, localizedReason: "Open your passport and insurance documents"
            )
            // The app was backgrounded or the view left while the person was authenticating: stay locked.
            guard attempt == generation else {
                if state == .unlocking { state = .locked }
                return
            }
            state = success ? .unlocked : .locked
        } catch {
            if attempt == generation || state == .unlocking { state = .locked }
        }
    }

    func lock() {
        generation += 1
        if state == .unlocked || state == .unlocking { state = .locked }
    }
}
