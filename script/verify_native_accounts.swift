import Foundation
nonisolated enum FonsterBiography { static func list(from text: String) -> [String] { [] } }
nonisolated final class MemoryStore: FonsterAccountSessionStore, @unchecked Sendable {
    let endpoint = URL(string:"https://synthetic.invalid/api/accounts")!
    private let lock = NSLock()
    private var value: FonsterAccountClient.Session?
    private var readCount = 0
    private var claimed = false
    func claimExclusiveOwner() -> Bool { lock.withLock { if claimed { return false }; claimed = true; return true } }
    var hasOwner: Bool { lock.withLock { claimed } }
    var reads: Int { lock.withLock { readCount } }
    func read() -> FonsterAccountClient.Session? { lock.withLock { readCount += 1; return value } }
    func write(_ session: FonsterAccountClient.Session) { lock.withLock { value = session } }
    func clear() { lock.withLock { value = nil } }
}
actor Fixture {
    var calls = 0
    private var loginNumber = 0
    var status = 200
    var extra = false
    var deletePending = false
    var suspended = false
    var suspendedRoute: String?
    var continuation: CheckedContinuation<Void, Never>?
    func configure(status: Int = 200, extra: Bool = false, deletePending: Bool = false, suspended: Bool = false, suspendedRoute: String? = nil) {
        self.status = status; self.extra = extra; self.deletePending = deletePending; self.suspended = suspended; self.suspendedRoute = suspendedRoute
    }
    func pauseIdentity() async { await withCheckedContinuation { continuation = $0 } }
    func release() { continuation?.resume(); continuation = nil }
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        calls += 1
        let route = request.url!.lastPathComponent
        var body: [String: Any]
        let account: [String: Any] = ["id":"00000000-0000-4000-8000-000000000001", "experience":"protected", "revision":0, "publicSocial":false]
        switch route {
        case "challenge": body = ["challengeID":"00000000-0000-4000-8000-000000000002", "nonce":String(repeating:"n", count:43), "expiresAt":1_700_000_300_000.0]
        case "login":
            loginNumber += 1
            let suffix = String(loginNumber)
            body = ["token":String(repeating:"t", count:43 - suffix.count) + suffix, "expiresAt":1_700_000_900_000.0, "account":account]
        case "me": body = ["account":account]
        case "export": body = ["version":1, "account":account, "createdAt":1_700_000_000_000.0, "selections":[], "token":"must-never-export"]
        case "delete": body = ["state":deletePending ? "deleting" : "deleted", "retryRequired":deletePending]
        case "interests": body = ["revision":1,"selections":[],"publicSocial":false]
        default: body = ["signedOut":true]
        }
        if status == 403 { body = ["error":"reauthentication_required"] }
        if extra { body["account"] = ["id":"00000000-0000-4000-8000-000000000099", "experience":"protected", "revision":0, "publicSocial":false] }
        // Capture the response before suspension: changing fixture configuration
        // for a newer request must not turn an old 401 into a newer 200.
        let response = (try JSONSerialization.data(withJSONObject: body), HTTPURLResponse(url:request.url!, statusCode:status, httpVersion:nil, headerFields:nil)!)
        if (suspended && route == "export") || route == suspendedRoute {
            precondition(continuation == nil, "Only one held response per fixture")
            await withCheckedContinuation { continuation = $0 }
        }
        return response
    }
}
@main struct Verify {
    static func waitForResponse(_ fixture: Fixture) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while await fixture.continuation == nil {
            precondition(ContinuousClock.now < deadline, "Timed out waiting for a synthetic request")
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    static func main() async throws {
        let now = Date(timeIntervalSince1970:1_700_000_000)
        let store = MemoryStore(), fixture = Fixture()
        let url = URL(string:"https://synthetic.invalid/api/accounts")!
        do { _ = try FonsterAccountClient(endpoint:URL(string:"https://other.invalid/api/accounts")!,store:store); fatalError("Credential scope mismatch accepted") } catch FonsterAccountClient.Failure.invalidResponse {}
        let closed = try FonsterAccountClient(endpoint:url,store:store)
        do { try await closed.signIn { _ in fatalError("Protected identity called") }; fatalError("Protected gate opened") } catch FonsterAccountClient.Failure.protectedExperience {}
        do { _ = try await closed.exportAccount(); fatalError("Protected export") } catch FonsterAccountClient.Failure.protectedExperience {}
        do { _ = try await closed.currentAccount(); fatalError("Protected load") } catch FonsterAccountClient.Failure.protectedExperience {}
        do { _ = try await closed.sessionToken(); fatalError("Protected session") } catch FonsterAccountClient.Failure.protectedExperience {}
        do { try await closed.signOut(); fatalError("Protected logout") } catch FonsterAccountClient.Failure.protectedExperience {}
        do { _ = try await closed.deleteAccount(); fatalError("Protected deletion") } catch FonsterAccountClient.Failure.protectedExperience {}
        do { _ = try await closed.saveSelections([], revision: 0); fatalError("Protected save") } catch FonsterAccountClient.Failure.protectedExperience {}
        do { _ = try await closed.privateInterestResolver(); fatalError("Protected search") } catch FonsterAccountClient.Failure.protectedExperience {}
        let reads = store.reads; precondition(reads == 0 && !store.hasOwner)
        let client = try FonsterAccountClient(fixtureEndpoint:url,store:store,now:{now},transport:{try await fixture.send($0)})
        do { _ = try FonsterAccountClient(fixtureEndpoint:url,store:store,now:{now},transport:{try await fixture.send($0)}); fatalError("Multiple lifecycle owners accepted") } catch FonsterAccountClient.Failure.superseded {}
        let identity: FonsterAccountClient.Identity = { nonce in precondition(nonce.count == 43); return .init(identityToken:"synthetic-token",authorizationCode:"synthetic-code") }
        try await client.signIn(identity:identity)
        let token = try await client.sessionToken(); precondition(token?.count == 43)
        let account = try await client.currentAccount(); precondition(account?.publicSocial == false)
        let archive = try await client.exportAccount(); precondition(!String(decoding:archive,as:UTF8.self).contains("must-never-export"))
        await fixture.configure(extra:true)
        do { _ = try await client.exportAccount(); fatalError("Cross-account export") } catch FonsterAccountClient.Failure.invalidResponse {}
        await fixture.configure(status:403)
        do { _ = try await client.deleteAccount(); fatalError("Old auth deletion") } catch FonsterAccountClient.Failure.reauthenticate {}
        let retained = try await client.sessionToken(); precondition(retained != nil)
        await fixture.configure(status:409)
        do { _ = try await client.saveSelections([],revision:0); fatalError("Conflict ignored") } catch FonsterAccountClient.Failure.conflict {}
        await fixture.configure()
        let revision = try await client.saveSelections([],revision:0); precondition(revision == 1)
        let selection = FonsterAccountClient.Selection(id: UUID(uuidString:"00000000-0000-4000-8000-000000000003")!, category:"movies")
        do { _ = try await client.saveSelections([selection],revision:0); fatalError("Dropped selection accepted") } catch FonsterAccountClient.Failure.invalidResponse {}
        do { _ = try await client.saveSelections([selection,selection],revision:0); fatalError("Duplicate selection accepted") } catch FonsterAccountClient.Failure.invalidResponse {}
        await fixture.configure(deletePending:true)
        let pending = try await client.deleteAccount(); precondition(pending)
        let deleted = try await client.sessionToken(); precondition(deleted == nil)
        await fixture.configure()
        try await client.signIn(identity:identity)
        await fixture.configure(suspended:true)
        let exportTask = Task { try await client.exportAccount() }
        try await waitForResponse(fixture)
        try await client.signOut()
        await fixture.release()
        do { _ = try await exportTask.value; fatalError("Stale export escaped logout") } catch FonsterAccountClient.Failure.superseded {}
        await fixture.configure()
        try await client.signIn(identity:identity)
        await fixture.configure(status:503)
        do { try await client.signOut(); fatalError("Outage ignored") } catch FonsterAccountClient.Failure.unavailable {}
        let loggedOut = try await client.sessionToken(); precondition(loggedOut == nil)
        await fixture.configure()
        try await client.signIn(identity:identity)
        await fixture.configure(status:401)
        do { _ = try await client.currentAccount(); fatalError("401 ignored") } catch FonsterAccountClient.Failure.signedOut {}
        let expired = try await client.sessionToken(); precondition(expired == nil)
        store.write(.init(token:String(repeating:"t", count:43), expiresAt:now.timeIntervalSince1970 * 1000, account:.init(id:UUID(),experience:"protected",revision:0,publicSocial:false)))
        let restoredExpired = try await client.sessionToken(); precondition(restoredExpired == nil && store.read() == nil)
        await fixture.configure()
        let delayedLogin = Task { try await client.signIn { _ in
            await fixture.pauseIdentity()
            return .init(identityToken:"synthetic-token",authorizationCode:"synthetic-code")
        } }
        try await waitForResponse(fixture)
        let before = await fixture.calls
        try await client.signOut()
        await fixture.release()
        do { try await delayedLogin.value; fatalError("Late identity restored logout") } catch FonsterAccountClient.Failure.superseded {}
        let after = await fixture.calls; precondition(after == before && store.read() == nil)
        let delayedCancel = Task { try await client.signIn { _ in
            await fixture.pauseIdentity()
            return .init(identityToken:"synthetic-token",authorizationCode:"synthetic-code")
        } }
        try await waitForResponse(fixture)
        delayedCancel.cancel(); await fixture.release()
        do { try await delayedCancel.value; fatalError("Late cancelled identity committed") } catch is CancellationError {}
        precondition(store.read() == nil)
        // Requests from a prior session cannot clear or mutate a replacement.
        // Each held response keeps its original status despite a new login.
        for route in ["me", "export", "delete", "interests"] {
            await fixture.configure()
            try await client.signIn(identity: identity)
            await fixture.configure(status: 401, suspendedRoute: route)
            let stale = Task {
                switch route {
                case "me": _ = try await client.currentAccount()
                case "export": _ = try await client.exportAccount()
                case "delete": _ = try await client.deleteAccount()
                default: _ = try await client.saveSelections([], revision: 0)
                }
            }
            try await waitForResponse(fixture)
            await fixture.configure()
            try await client.signIn(identity: identity)
            let replacement = store.read()
            await fixture.release()
            do { try await stale.value; fatalError("Old response accepted for " + route) }
            catch FonsterAccountClient.Failure.superseded {}
            precondition(store.read() == replacement && replacement != nil)
        }
        await fixture.configure(status: 503, suspendedRoute: "logout")
        let oldLogout = Task { try await client.signOut() }
        try await waitForResponse(fixture)
        precondition(store.read() == nil)
        await fixture.configure()
        try await client.signIn(identity: identity)
        let replacement = store.read()
        await fixture.release()
        do { try await oldLogout.value; fatalError("Stale logout accepted") }
        catch FonsterAccountClient.Failure.superseded {}
        precondition(store.read() == replacement && replacement != nil)

        // A transport that ignores cancellation still cannot publish a login,
        // load, export, save or delete result, or erase credentials on late 401.
        for route in ["me", "export", "delete", "interests", "login"] {
            await fixture.configure()
            try await client.signIn(identity: identity)
            await fixture.configure(status: route == "login" ? 200 : 401, suspendedRoute: route)
            let cancelled = Task {
                switch route {
                case "me": _ = try await client.currentAccount()
                case "export": _ = try await client.exportAccount()
                case "delete": _ = try await client.deleteAccount()
                case "login": try await client.signIn(identity: identity)
                default: _ = try await client.saveSelections([], revision: 0)
                }
            }
            try await waitForResponse(fixture)
            let beforeCancel = store.read()
            cancelled.cancel()
            await fixture.release()
            do { try await cancelled.value; fatalError("Cancelled result accepted for " + route) }
            catch is CancellationError {}
            precondition(store.read() == beforeCancel)
        }
        let cancellation = Task { try Task.checkCancellation(); try await client.signIn(identity:identity) }
        cancellation.cancel()
        do { try await cancellation.value; fatalError("Cancelled login committed") } catch is CancellationError {}
        print("PASS: protected zero-storage gate; exclusive lifecycle owner; login/current account; finite own export; cross-account rejection; recent-auth deletion; revision conflicts; missing/duplicate selections; pending deletion clears session; stale export after signout; logout outage clears session; 401 revocation; restored expiry; late identity after logout/cancel; late 401/logout versus replacement; cancellation-slow login/load/export/save/delete; cancellation")
    }
}
