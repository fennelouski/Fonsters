import Foundation
nonisolated enum FonsterBiography { static func list(from text: String) -> [String] { [] } }

/// Synthetic suspension deliberately ignores task cancellation, as a provider
/// callback or transport can. No SwiftUI host, network, identity or Keychain.
@MainActor final class HeldResponse {
    private var continuation: CheckedContinuation<Int, Error>?
    var entered: Bool { continuation != nil }
    func load() async throws -> Int {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func succeed(_ value: Int) { let pending = continuation; continuation = nil; pending?.resume(returning: value) }
    func fail() { let pending = continuation; continuation = nil; pending?.resume(throwing: FonsterAccountClient.Failure.unavailable) }
}

@main @MainActor struct VerifyForeground {
    static func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition() {
            precondition(ContinuousClock.now < deadline, "Foreground recovery timed out")
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    static func main() async throws {
        let work = FonsterAccountTaskState()
        var values: [Int] = [], errors = 0, requests = 0
        for lateFailure in [false, true] {
            let oldResponse = HeldResponse()
            let oldLoad = Task {
                await work.reload(load: { requests += 1; return try await oldResponse.load() },
                                  apply: { values.append($0) }, failed: { _ in errors += 1 })
            }
            try await waitUntil { oldResponse.entered }
            precondition(work.busy && work.begin() == nil)
            work.invalidate(); oldLoad.cancel()

            // Twenty rapid foreground/background transitions while the old
            // cancellation-slow load still owns the screen. No skipped recovery
            // or parallel request is allowed from any cancelled waiter.
            var waiters: [Task<Void, Never>] = []
            let before = requests
            for _ in 0..<20 {
                let waiter = Task {
                    await work.reload(load: { requests += 1; return -1 },
                                      apply: { values.append($0) }, failed: { _ in errors += 1 })
                }
                await Task.yield()
                work.invalidate(); waiter.cancel(); waiters.append(waiter)
            }
            let recovery = Task {
                await work.reload(load: { requests += 1; return 42 },
                                  apply: { values.append($0) }, failed: { _ in errors += 1 })
            }
            await Task.yield()
            precondition(requests == before && work.busy)
            if lateFailure { oldResponse.fail() } else { oldResponse.succeed(-2) }
            await oldLoad.value
            for waiter in waiters { await waiter.value }
            await recovery.value
            precondition(values.last == 42 && !values.contains(-1) && !values.contains(-2))
            precondition(requests == before + 1 && errors == 0 && !work.busy)
        }

        // Private selections use the same coordinator for save + reload. A
        // cancelled save may have reached the server: keep edits unavailable
        // until it unwinds and the new foreground reload fetches its revision.
        let save = work.begin()!
        work.invalidate()
        precondition(!work.accepts(save) && work.busy)
        var serverRevision = 0, loadedRevision: Int?, selectionWaitStarted = false
        let selectionReload = Task {
            selectionWaitStarted = true
            await work.reload(load: { serverRevision }, apply: { loadedRevision = $0 }, failed: { _ in errors += 1 })
        }
        try await waitUntil { selectionWaitStarted }
        precondition(loadedRevision == nil)
        serverRevision = 1
        work.finish(save)
        await selectionReload.value
        precondition(loadedRevision == 1 && !work.busy)
        let newer = work.begin()!
        work.finish(save) // A late cleanup cannot release a newer operation.
        precondition(work.busy && work.accepts(newer))
        work.finish(newer)

        // A waiter invalidated without task cancellation must not start a load
        // when the previous owner eventually releases its slot.
        let heldOwner = work.begin()!
        let countBeforeWait = values.count
        var invalidatedWaitStarted = false
        let invalidatedWaiter = Task {
            invalidatedWaitStarted = true
            await work.reload(load: { -4 }, apply: { values.append($0) }, failed: { _ in errors += 1 })
        }
        try await waitUntil { invalidatedWaitStarted }
        work.invalidate()
        work.finish(heldOwner)
        await invalidatedWaiter.value
        precondition(values.count == countBeforeWait && !work.busy)

        // Invalidation alone suppresses late data/errors even if the caller's
        // cancellation is delayed. Disappearance cannot publish a new draft.
        for lateFailure in [false, true] {
            let response = HeldResponse()
            let count = values.count
            let disappearing = Task {
                await work.reload(load: { try await response.load() }, apply: { values.append($0) }, failed: { _ in errors += 1 })
            }
            try await waitUntil { response.entered }
            work.invalidate()
            if lateFailure { response.fail() } else { response.succeed(-3) }
            await disappearing.value
            precondition(values.count == count && errors == 0 && !work.busy)
        }
        // An active failure is reported and releases ownership for retry.
        await work.reload(load: { () async throws -> Int in throw FonsterAccountClient.Failure.unavailable },
                          apply: { values.append($0) }, failed: { _ in errors += 1 })
        precondition(errors == 1 && !work.busy)
        print("PASS: 40 rapid foreground transitions; serialized cancellation-slow loads and save recovery; stale success/error suppression; disappearance; owner cleanup; active retry")
    }
}
