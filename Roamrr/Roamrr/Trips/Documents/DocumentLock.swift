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
    /// The prompt that is on screen, kept so leaving the screen can close it. Without this the Face ID sheet stays
    /// up over whatever screen comes next.
    private var context: LAContext?

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
        self.context = context
        let attempt = generation
        defer { if attempt == generation { self.context = nil } }
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
        // Closes the Face ID or passcode prompt if it is still showing; its pending call then ends with an error.
        context?.invalidate()
        context = nil
        if state == .unlocked || state == .unlocking { state = .locked }
    }
}
