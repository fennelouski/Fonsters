import Foundation
import Observation

@MainActor @Observable final class ParentActionGate {
    var challenge: ParentChallenge?
    private(set) var purpose = ""
    private var action: (() -> Void)?
    private var approved = false
    func request(_ purpose: String, action: @escaping () -> Void) {
        guard challenge == nil else { return }
        self.purpose = purpose; self.action = action; approved = false; challenge = ParentChallenge()
    }
    func approve(_ answer: String) -> Bool {
        guard challenge?.accepts(answer) == true else { return false }
        approved = true; challenge = nil; return true
    }
    func cancel() { approved = false; action = nil; challenge = nil }
    func finish() {
        let next = approved ? action : nil
        approved = false; action = nil
        next?()
    }
}
