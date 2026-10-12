import Foundation

/// A private hosted account is separate from the creature library and iCloud.
/// Production remains compile-time protected. Fixtures can exercise the full
/// lifecycle only through an injected transport and credential store.
actor FonsterAccountClient {
    enum Failure: Error, Equatable {
        case protectedExperience, invalidResponse, signedOut, unavailable, reauthenticate, conflict, superseded
    }
    struct Session: Codable, Sendable, Equatable {
        let token: String
        let expiresAt: Double // backend Unix milliseconds
        let account: Account
    }
    struct Account: Codable, Sendable, Equatable {
        let id: UUID
        let experience: String
        let revision: Int
        let publicSocial: Bool
    }
    struct Selection: Codable, Sendable, Hashable { let id: UUID; let category: String }
    struct Archive: Codable, Sendable {
        let version: Int; let account: Account; let createdAt: Double; let selections: [Selection]
    }
    struct Challenge: Decodable, Sendable { let challengeID: UUID; let nonce: String; let expiresAt: Double }
    struct Credential: Sendable { let identityToken: String; let authorizationCode: String }
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    typealias Identity = @Sendable (String) async throws -> Credential
    private let endpoint: URL
    private let store: any FonsterAccountSessionStore
    private let transport: Transport
    private let enabled: Bool
    private let now: @Sendable () -> Date
    private var generation = 0
    private var busy = false

    init(endpoint: URL, store: any FonsterAccountSessionStore) throws {
        try Self.validate(endpoint)
        guard store.endpoint == endpoint else { throw Failure.invalidResponse }
        self.endpoint = endpoint; self.store = store
        transport = { try await Self.ephemeralTransport($0) }
        enabled = ProtectedPlayPolicy.allowsAccounts && ProtectedPlayPolicy.allowsThirdPartyRequests
            && FonsterAccountReleaseConfiguration.approvedEndpoint == endpoint
        now = { Date() }
        if enabled && !store.claimExclusiveOwner() { throw Failure.superseded }
    }
    /// Internal fixture composition; never called from the shipped view.
    init(fixtureEndpoint: URL, store: any FonsterAccountSessionStore, now: @escaping @Sendable () -> Date,
         transport: @escaping Transport) throws {
        try Self.validate(fixtureEndpoint)
        guard store.endpoint == fixtureEndpoint else { throw Failure.invalidResponse }
        guard fixtureEndpoint.host == "synthetic.invalid" else { throw Failure.protectedExperience }
        endpoint = fixtureEndpoint; self.store = store; self.now = now; self.transport = transport; enabled = true
        guard store.claimExclusiveOwner() else { throw Failure.superseded }
    }
    private static func validate(_ url: URL) throws {
        guard url.scheme == "https", url.host != nil, url.port == nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, url.path == "/api/accounts" else { throw Failure.invalidResponse }
    }
    private func gate() throws { guard enabled else { throw Failure.protectedExperience }; try Task.checkCancellation() }
    private func check(_ stamp: Int) throws {
        try Task.checkCancellation()
        guard stamp == generation else { throw Failure.superseded }
    }
    func sessionToken() async throws -> String? {
        try gate(); let stamp = generation
        let stored = try store.read()
        try check(stamp)
        guard let value = stored else { return nil }
        guard Self.valid(value, at: now()) else { try store.clear(); return nil }
        return value.token
    }
    func privateInterestResolver() async throws -> FonsterPrivateInterestResolver {
        try gate()
        let url = endpoint.deletingLastPathComponent().appendingPathComponent("private-interests/search")
        return try await MainActor.run { try FonsterPrivateInterestResolver(endpoint: url, session: { try await self.sessionToken() }) }
    }
    func currentAccount() async throws -> Account? {
        try gate()
        guard try await sessionToken() != nil else { return nil }
        let stamp = generation
        let data = try await request("me", method: "GET", body: nil, authenticated: true)
        try check(stamp)
        struct Response: Decodable { let account: Account }
        let account = try JSONDecoder().decode(Response.self, from: data).account
        try Self.validate(account)
        guard let session = try store.read(), session.account.id == account.id else { throw Failure.signedOut }
        try check(stamp)
        return account
    }
    func signIn(identity: Identity) async throws {
        try gate()
        guard !busy else { throw Failure.superseded }
        busy = true; generation += 1; let stamp = generation
        defer { busy = false }
        // A fresh challenge/code is required after cancellation or failure.
        try store.clear()
        let challenge = try JSONDecoder().decode(Challenge.self, from: await request("challenge", method: "POST", body: Data("{}".utf8), authenticated: false))
        try check(stamp)
        guard challenge.expiresAt > now().timeIntervalSince1970 * 1000,
              challenge.expiresAt <= now().timeIntervalSince1970 * 1000 + 300_000, Self.opaque(challenge.nonce) else { throw Failure.invalidResponse }
        let credential = try await identity(challenge.nonce)
        try check(stamp)
        guard !credential.identityToken.isEmpty, credential.identityToken.utf8.count <= 8192,
              !credential.authorizationCode.isEmpty, credential.authorizationCode.utf8.count <= 8192 else { throw Failure.invalidResponse }
        struct Login: Encodable { let challengeID: UUID; let identityToken: String; let authorizationCode: String }
        let body = try JSONEncoder().encode(Login(challengeID: challenge.challengeID, identityToken: credential.identityToken, authorizationCode: credential.authorizationCode))
        let data = try await request("login", method: "POST", body: body, authenticated: false)
        try check(stamp)
        let session = try JSONDecoder().decode(Session.self, from: data)
        guard Self.valid(session, at: now()) else { throw Failure.invalidResponse }
        try store.write(session)
        // Synchronous bounded storage cannot re-enter the session owner;
        // cancellation still discards a just-written session.
        do { try check(stamp) } catch { try store.clear(); throw error }
    }
    func signOut() async throws {
        try gate(); generation += 1
        let session = try store.read()
        try store.clear() // local removal wins even if server is unavailable
        guard let session, Self.valid(session, at: now()) else { return }
        _ = try await request("logout", method: "POST", body: Data("{}".utf8), token: session.token, authenticated: false)
    }
    func exportAccount() async throws -> Data {
        try gate(); let stamp = generation
        let data = try await request("export", method: "POST", body: Data("{}".utf8), authenticated: true)
        try check(stamp)
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        try Self.validate(archive.account)
        guard archive.version == 1, archive.createdAt.isFinite, archive.createdAt > 0,
              archive.createdAt <= now().timeIntervalSince1970 * 1000 + 30_000, archive.selections.count <= 32,
              archive.selections.allSatisfy({ Self.categories.contains($0.category) }),
              Set(archive.selections).count == archive.selections.count,
              let session = try store.read(), session.account.id == archive.account.id else { throw Failure.invalidResponse }
        try check(stamp)
        // Re-encode finite fields: never export arbitrary server extras or tokens.
        return try JSONEncoder().encode(archive)
    }
    func deleteAccount() async throws -> Bool {
        try gate(); let stamp = generation
        let data = try await request("delete", method: "POST", body: Data("{}".utf8), authenticated: true)
        try check(stamp)
        struct Result: Decodable { let state: String; let retryRequired: Bool }
        let result = try JSONDecoder().decode(Result.self, from: data)
        guard (result.state == "deleted" && !result.retryRequired) || (result.state == "deleting" && result.retryRequired) else { throw Failure.invalidResponse }
        generation += 1; try store.clear()
        return result.retryRequired
    }
    func saveSelections(_ selections: [Selection], revision: Int) async throws -> Int {
        try gate(); let stamp = generation
        guard revision >= 0, revision < Int.max, selections.count <= 32, Set(selections).count == selections.count, selections.allSatisfy({Self.categories.contains($0.category)}) else { throw Failure.invalidResponse }
        struct Write: Encodable { let revision: Int; let selections: [Selection] }
        struct Result: Decodable { let revision: Int; let selections: [Selection]; let publicSocial: Bool }
        let body = try JSONEncoder().encode(Write(revision: revision, selections: selections))
        let result = try JSONDecoder().decode(Result.self, from: await request("interests", method: "PUT", body: body, authenticated: true))
        try check(stamp)
        guard result.revision == revision + 1, !result.publicSocial, result.selections.count <= 32, Set(result.selections).count == result.selections.count,
              Set(result.selections) == Set(selections) else { throw Failure.invalidResponse }
        return result.revision
    }
    private func request(_ route: String, method: String, body: Data?, token: String? = nil, authenticated: Bool) async throws -> Data {
        try gate(); let stamp = generation
        let bearer: String?
        if authenticated { bearer = try await sessionToken(); guard bearer != nil else { throw Failure.signedOut } }
        else { bearer = token }
        try check(stamp)
        let url = endpoint.appendingPathComponent(route)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = method; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await transport(request)
        try check(stamp)
        if authenticated { guard try await sessionToken() == bearer else { throw Failure.signedOut } }
        try check(stamp)
        guard data.count <= 262_144, let response = response as? HTTPURLResponse, response.url == url else { throw Failure.invalidResponse }
        if response.statusCode == 401 { generation += 1; try store.clear(); throw Failure.signedOut }
        if response.statusCode == 403 {
            struct Denial: Decodable { let error: String }
            if (try? JSONDecoder().decode(Denial.self, from: data).error) == "reauthentication_required" { throw Failure.reauthenticate }
            throw Failure.protectedExperience
        }
        if response.statusCode == 409 { throw Failure.conflict }
        guard response.statusCode == 200 else { throw Failure.unavailable }
        return data
    }
    private static let categories: Set<String> = ["likes", "dislikes", "movies", "shows", "creators", "celebrities", "music", "places"]
    private static func opaque(_ value: String) -> Bool { value.count == 43 && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") } }
    private static func validate(_ account: Account) throws {
        guard account.revision >= 0, account.experience == "protected", !account.publicSocial else { throw Failure.invalidResponse }
    }
    private static func valid(_ session: Session, at date: Date) -> Bool {
        opaque(session.token) && session.expiresAt.isFinite && session.expiresAt > date.timeIntervalSince1970 * 1000 &&
        session.expiresAt <= date.timeIntervalSince1970 * 1000 + 900_000 && (try? validate(session.account)) != nil
    }
    private static func ephemeralTransport(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil; config.httpShouldSetCookies = false
        let session = URLSession(configuration: config, delegate: FonsterAccountRedirectGuard(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        return try await session.data(for: request)
    }
}

/// One lifecycle owner per namespace for the process lifetime. Bounded synchronous
/// mutations avoid actor reentrancy and a second client cannot mutate its session.
nonisolated protocol FonsterAccountSessionStore: Sendable {
    var endpoint: URL { get }
    func claimExclusiveOwner() -> Bool
    func read() throws -> FonsterAccountClient.Session?
    func write(_ session: FonsterAccountClient.Session) throws
    func clear() throws
}

/// Reviewed production endpoint must be pinned in source, never a preference,
/// remote feature flag, deep link or client-provided host. No endpoint is approved.
nonisolated enum FonsterAccountReleaseConfiguration {
    static let approvedEndpoint: URL? = nil
}
