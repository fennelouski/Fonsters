import Foundation
import Combine

@main struct VerifyProtectedPlay {
    @MainActor static func main() async {
        func check(_ value: Bool, _ label: String) { precondition(value, label); print("PASS " + label) }
        check(!ProtectedPlayPolicy.allowsAccounts && !ProtectedPlayPolicy.allowsExternalAgents && !ProtectedPlayPolicy.allowsPublicSocialProfiles, "accounts, external agents and public social capabilities stay closed")
        check(!ProtectedPlayPolicy.allowsThirdPartyRequests, "protected play forbids external requests")
        for age in [0, 5, 12] { check(ProtectedPlayPolicy.boundary(age: age, country: "US") == .protectedPlay, "US age \(age) keeps protected play") }
        check(ProtectedPlayPolicy.boundary(age: 13, country: "US") == .requiresAccountReleaseReview, "13th birthday does not enable an account")
        for age in [nil, -1, 121] { check(ProtectedPlayPolicy.boundary(age: age, country: "US") == .protectedPlay, "unknown or invalid age stays protected") }
        for country in [nil, "GB", "NL", "DE", "XX"] { check(ProtectedPlayPolicy.boundary(age: 18, country: country) == .requiresCountryReview, "unreviewed country never grants signup") }
        let challenge = ParentChallenge(first: 17, second: 8)
        check(!challenge.accepts("") && !challenge.accepts("135") && !challenge.accepts("136x") && challenge.accepts(" 136 "), "adult task requires exact numeric answer")
        let gate = ParentActionGate(); var actions = 0
        gate.request("share") { actions += 1 }
        check(!gate.approve("wrong") && actions == 0 && gate.challenge != nil, "wrong answer cannot run action")
        gate.cancel(); gate.finish(); check(actions == 0, "cancel drops action")
        gate.request("share") { actions += 1 }
        let right = gate.challenge.map { String($0.first * $0.second) }!
        check(gate.approve(right) && actions == 0, "approval waits for sheet dismissal")
        gate.finish(); gate.finish(); check(actions == 1, "approved action executes once")
        gate.request("camera") { actions += 1 }; gate.challenge = nil; gate.finish()
        check(actions == 1, "swipe dismissal cannot grant parent access")
        gate.request("microphone") { actions += 1 }
        let second = gate.challenge.map { String($0.first * $0.second) }!
        check(gate.approve(second), "second action needs a fresh challenge")
        gate.cancel(); gate.finish(); check(actions == 1, "background cancellation invalidates a queued approval")
        // Real entry points, with a protocol trap: if a regression opens a
        // request, the trap fails immediately before contacting any server.
        URLProtocol.registerClass(NetworkTrap.self)
        RandomTextFallbacks.registerDefaults()
        for source in ["quote", "words", "uuid", "lorem"] {
            let result = await fetchRandomTextWithFallback(source: source)
            check(result.0?.isEmpty == false && result.1, "\(source) generates locally")
        }
        let remote = HTTPFeatureFlagRemoteProvider(url: URL(string: "https://protected-play.invalid/flags")!)
        let overrides = await remote.fetchOverrides()
        check(overrides.isEmpty, "HTTP flag provider stays closed")
        check(FeatureFlagBackendConfiguration.backendURL() == nil, "backend configuration exposes no endpoint")
        let spy = FlagSpy(); let store = FeatureFlagStore(remoteProvider: spy)
        store.refreshFromRemote()
        try? await Task.sleep(for: .milliseconds(100))
        let calls = await spy.calls
        check(calls == 0, "store never invokes even an injected remote provider")
        URLProtocol.unregisterClass(NetworkTrap.self)
    }
}
final class NetworkTrap: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { fatalError("Protected play attempted an external request") }
    override func stopLoading() {}
}
actor FlagSpy: FeatureFlagRemoteProviding {
    private(set) var calls = 0
    func fetchOverrides() async -> [String: Bool] { calls += 1; return [:] }
}
