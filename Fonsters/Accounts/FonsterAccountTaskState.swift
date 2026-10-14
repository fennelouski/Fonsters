import Foundation
import Observation

/// UI operations retain ownership until they unwind, even if cancellation is
/// slow. A new foreground load waits for that owner; old results cannot publish
/// after backgrounding or disappearance. This state never accesses credentials.
@MainActor @Observable final class FonsterAccountTaskState {
    struct Ticket: Equatable {
        fileprivate let id = UUID()
        fileprivate let generation: Int
    }
    private var generation = 0
    private var owner: Ticket?
    var busy: Bool { owner != nil }

    func invalidate() { generation += 1 }

    func begin() -> Ticket? {
        guard !busy, !Task.isCancelled else { return nil }
        let ticket = Ticket(generation: generation)
        owner = ticket
        return ticket
    }

    func accepts(_ ticket: Ticket) -> Bool {
        owner == ticket && generation == ticket.generation && !Task.isCancelled
    }

    func finish(_ ticket: Ticket) {
        if owner == ticket { owner = nil }
    }

    /// Used by the actual phase-keyed screen tasks and the headless regressions.
    func reload<Value>(load: () async throws -> Value,
                       apply: (Value) -> Void, failed: (Error) -> Void) async {
        let stamp = generation
        do {
            while busy {
                try Task.checkCancellation()
                guard stamp == generation else { return }
                try await Task.sleep(for: .milliseconds(30))
            }
            try Task.checkCancellation()
            guard stamp == generation, let ticket = begin() else { return }
            defer { finish(ticket) }
            do {
                let value = try await load()
                if accepts(ticket) { apply(value) }
            } catch {
                if accepts(ticket), !(error is CancellationError) { failed(error) }
            }
        } catch { /* A cancelled foreground waiter owns no screen state. */ }
    }
}
