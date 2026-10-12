import Foundation

/// Unreleased account-provider seam. No preview key, default endpoint, age flag,
/// parent challenge or imported interest can enable network requests. The native
/// release policy must be reviewed separately before choosing this resolver.
actor FonsterPrivateInterestResolver: FonsterInterestResolving {
    enum Failure: Error { case protectedExperience, invalidConfiguration, signedOut, unavailable, invalidResponse }
    typealias SessionProvider = @Sendable () async throws -> String?
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private let endpoint: URL
    private let session: SessionProvider
    private let transport: Transport
    private var generations: [FonsterInterestCategory: Int] = [:]

    init(endpoint: URL, session: @escaping SessionProvider,
         transport: @escaping Transport = { try await FonsterPrivateInterestResolver.ephemeralTransport($0) }) throws {
        guard endpoint.scheme == "https", endpoint.host != nil, endpoint.port == nil, endpoint.user == nil, endpoint.password == nil,
              endpoint.query == nil, endpoint.fragment == nil, endpoint.path == "/api/private-interests/search" else {
            throw Failure.invalidConfiguration
        }
        self.endpoint = endpoint; self.session = session; self.transport = transport
    }
    func resolve(_ query: String, category: FonsterInterestCategory) async throws -> [FonsterInterestEntity] {
        guard ProtectedPlayPolicy.allowsAccounts && ProtectedPlayPolicy.allowsThirdPartyRequests else {
            throw Failure.protectedExperience
        }
        try Task.checkCancellation()
        let generation = (generations[category] ?? 0) + 1
        generations[category] = generation
        guard let token = try await session(), token.count == 43,
              token.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else {
            throw Failure.signedOut
        }
        try Task.checkCancellation()
        guard generations[category] == generation else { throw CancellationError() }
        let normalized = query.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...128).contains(normalized.utf16.count) else { throw Failure.invalidResponse }
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Search(query: normalized, category: category.rawValue))
        let (data, response) = try await transport(request)
        try Task.checkCancellation()
        guard generations[category] == generation else { throw CancellationError() }
        // Sign-out/expiry while awaiting a provider response wins. Never write
        // remote matches into the protected editorial/share catalogue.
        guard try await session() == token else { throw Failure.signedOut }
        try Task.checkCancellation()
        guard generations[category] == generation else { throw CancellationError() }
        guard let response = response as? HTTPURLResponse, Self.responseMatches(response, endpoint: endpoint) else { throw Failure.invalidResponse }
        if response.statusCode == 401 { throw Failure.signedOut }
        if response.statusCode == 403 { throw Failure.protectedExperience }
        guard response.statusCode == 200 else { throw Failure.unavailable }
        return try Self.entities(data, category: category, now: Date())
    }
    nonisolated static func entities(_ data: Data, category: FonsterInterestCategory, now: Date) throws -> [FonsterInterestEntity] {
        guard data.count <= 262_144 else { throw Failure.invalidResponse }
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        guard result.version == 1, result.records.count <= 32, Set(result.records.map(\.id)).count == result.records.count else { throw Failure.invalidResponse }
        return try result.records.map { record in
            guard UUID(uuidString: record.id) != nil, record.verification.method == "provider-api",
                  record.approval == "unreviewed",
                  let checkedAt = Self.checkedDate(record.verification.checkedAt),
                  now.timeIntervalSince(checkedAt) >= -30, now.timeIntervalSince(checkedAt) < 3600,
                  !record.sourceID.isEmpty, record.sourceID.utf16.count <= 512, let host = Self.hosts[record.source],
                  record.url.utf16.count <= 2048, let url = URL(string: record.url), url.scheme == "https", url.host == host,
                  url.user == nil, url.password == nil, url.port == nil,
                  !record.title.isEmpty, record.title.utf16.count <= 128,
                  !(record.title + (record.detail ?? "")).unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  (record.detail ?? "").utf16.count <= 240 else { throw Failure.invalidResponse }
            return FonsterInterestEntity(id: record.id, group: record.source + ":" + record.sourceID,
                title: record.title, source: record.source, symbol: Self.symbols[record.source] ?? "globe",
                category: category, summary: record.detail ?? "", url: url, aliases: [])
        }
    }
    nonisolated static func responseMatches(_ response: HTTPURLResponse, endpoint: URL) -> Bool {
        response.url == endpoint
    }
    nonisolated private static func checkedDate(_ value: String) -> Date? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: value) { return date }
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: value)
    }
    nonisolated private static func ephemeralTransport(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration, delegate: FonsterAccountRedirectGuard(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        return try await session.data(for: request)
    }
    nonisolated private static let hosts = ["wikipedia": "en.wikipedia.org", "youtube": "www.youtube.com",
                                "apple-music": "music.apple.com", "apple-maps": "maps.apple.com"]
    nonisolated private static let symbols = ["wikipedia": "book.closed", "youtube": "play.rectangle",
                                  "apple-music": "music.note", "apple-maps": "mappin.and.ellipse"]
    nonisolated private struct Search: Encodable { let query: String; let category: String }
    nonisolated private struct SearchResult: Decodable { let version: Int; let records: [Record] }
    nonisolated private struct Record: Decodable {
        let id: String; let source: String; let sourceID: String; let title: String
        let url: String; let detail: String?; let approval: String; let verification: Verification
    }
    nonisolated private struct Verification: Decodable { let method: String; let checkedAt: String }
}

/// Never forward an account bearer token to a redirected URL, including same-host
/// redirects. The approved endpoint must be the response endpoint exactly.
nonisolated final class FonsterAccountRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
