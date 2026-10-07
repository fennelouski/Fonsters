#if os(macOS) || os(iOS) || os(tvOS)
import Foundation
import Observation

@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
@MainActor @Observable
final class FonsterAgentDirector {
    struct Moment: Identifiable {
        let id = UUID()
        let source: FonsterAgentSource
        let title: String
        let learned: Bool
    }
    private(set) var scopes = Set(FonsterAgentScope.allCases)
    private(set) var reflections: [HumanReflectionField: HumanReflectionRule] = [
        .feeling: .init(cue: .bright), .activity: .init(cue: .focused), .travel: .init(cue: .outAndAbout)
    ]
    private(set) var program: FonsterAgentProgram?
    private(set) var source: FonsterAgentSource = .simulated
    private(set) var running = false
    private(set) var cursor = 0
    private(set) var history: [Moment] = []
    private(set) var message = "Give a little companion agent room to play."
    private(set) var completedPrograms = 0
    @ObservationIgnored private var replayIDs: [UUID] = []
    @ObservationIgnored private var startedAt: Double = 0
    @ObservationIgnored private var nextAt: Double = 0
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var nextWallAt = Date.distantPast
    @ObservationIgnored private var controlID: UUID?
    @ObservationIgnored let memories: AgentRitualMemoryStore
    init(memories: AgentRitualMemoryStore? = nil) { self.memories = memories ?? .localPreview() }
    var title: String { running ? source.title : "You're in control" }
    var nextTitle: String? { program.flatMap { cursor < $0.actions.count ? $0.actions[cursor].title : nil } }

    func setScope(_ scope: FonsterAgentScope, enabled: Bool, lobby: LocalLobbyController) {
        takeOver(lobby: lobby, reason: "Influence changed. Prepare a fresh plan.")
        if enabled { scopes.insert(scope) } else { scopes.remove(scope) }
        program = nil
    }
    func setReflection(_ field: HumanReflectionField, rule: HumanReflectionRule, lobby: LocalLobbyController) {
        guard rule.cue.field == field else { return }
        takeOver(lobby: lobby, reason: rule.enabled ? "Reflection choices changed. Prepare a fresh plan." : "\(field.title) reflection revoked.")
        reflections[field] = rule; program = nil
    }
    func revoke(lobby: LocalLobbyController) {
        takeOver(lobby: lobby, reason: "Agent control revoked. You're in control.")
        program = nil
        for field in HumanReflectionField.allCases { reflections[field]?.enabled = false }
    }
    func takeOver(lobby: LocalLobbyController, reason: String = "You took over. The agent plan has stopped.") {
        running = false
        if let id = controlID { controlID = nil; lobby.cancelAgentMotion(id: id); message = reason }
    }
    func prepare(_ plan: FonsterAgentProgram, source: FonsterAgentSource, lobby: LocalLobbyController, now: Date = .now) throws {
        try plan.validate(now: now)
        try validateTarget(plan, lobby: lobby)
        guard !replayIDs.contains(plan.programID) else { throw FonsterAgentError.replay }
        // Review every action first: one denied action prevents the entire plan.
        for action in plan.actions { try validateAction(action, lobby: lobby) }
        takeOver(lobby: lobby)
        program = plan; self.source = source; cursor = 0
        message = "\(source.title) · \(plan.actions.count) actions ready to review."
    }
    func prepareDemo(lobby: LocalLobbyController, now: Date = .now, includeReflections: Bool = true) throws {
        let member = lobby.selectedMember, peer = lobby.members[lobby.peerIndex]
        let area = lobby.world.areas.contains(.park) ? "park" : "garden"
        var actions: [FonsterAgentAction] = [
            .init(kind: .feeling, feeling: .curious), .init(kind: .greet, peerID: peer.id),
            .init(kind: .explore, area: area), .init(kind: .react, reaction: "look"),
            .init(kind: .playTogether, peerID: peer.id), .init(kind: .react, reaction: "spin"),
            .init(kind: .quietTogether, peerID: peer.id), .init(kind: .bench)
        ]
        if lobby.world.benches.isEmpty { actions.removeLast() }
        for field in HumanReflectionField.allCases {
            if includeReflections, let rule = reflections[field], rule.enabled { actions.append(.init(kind: .reflect, peerID: rule.audience == .localCompanions ? peer.id : nil, reflectionField: field, cue: rule.cue)) }
        }
        let filtered = actions.filter { (try? validateAction($0, lobby: lobby)) != nil }
        guard !filtered.isEmpty else { throw FonsterAgentError.denied }
        try prepare(.init(fonsterID: member.id, actions: filtered, now: now), source: .simulated, lobby: lobby, now: now)
    }
    func start(lobby: LocalLobbyController, now: Date = .now) throws {
        guard let program else { throw FonsterAgentError.invalid }
        try program.validate(now: now); try validateTarget(program, lobby: lobby)
        guard lobby.ready, !lobby.paused, !lobby.backgrounded, !lobby.lowPower else { throw FonsterAgentError.unavailable }
        guard !replayIDs.contains(program.programID) else { throw FonsterAgentError.replay }
        for action in program.actions { try validateAction(action, lobby: lobby) }
        replayIDs.append(program.programID)
        if replayIDs.count > 128 { replayIDs.removeFirst() }
        revision = lobby.roomRevision; startedAt = lobby.activeTime; nextAt = lobby.activeTime + 0.7
        cursor = 0; running = true; controlID = program.fonsterID
        message = "\(source.title) is guiding \(lobby.selectedMember.name). Touch any creature control to take over."
    }
    func advance(lobby: LocalLobbyController, now: Date = .now) {
        guard running, lobby.shouldAnimate, lobby.activeTime >= nextAt, now >= nextWallAt else { return }
        do { try performNext(lobby: lobby, now: now) }
        catch { takeOver(lobby: lobby, reason: error.localizedDescription) }
    }
    func performNext(lobby: LocalLobbyController, now: Date = .now, manual: Bool = false) throws {
        guard running, let program, cursor < program.actions.count else { throw FonsterAgentError.unavailable }
        guard revision == lobby.roomRevision, lobby.ready, !lobby.paused, !lobby.backgrounded, !lobby.lowPower,
              lobby.activeTime - startedAt <= 120 else { throw FonsterAgentError.unavailable }
        guard now < program.expiresAt else { throw FonsterAgentError.expired }
        // Manual static steps also respect the rate limit; no tap-generated queue.
        guard now >= nextWallAt, manual ? (lobby.still || lobby.reduceMotion) : lobby.activeTime >= nextAt else { throw FonsterAgentError.rateLimited }
        try validateTarget(program, lobby: lobby)
        let action = program.actions[cursor]; try validateAction(action, lobby: lobby)
        try lobby.applyAgent(action, id: program.fonsterID, reflection: action.reflectionField.flatMap { reflections[$0] })
        lobby.presence.observe(action, id: program.fonsterID, source: source, now: now)
        var learned = false
        if scopes.contains(.learning), let ritual = action.ritual {
            learned = memories.learn(ritual, id: program.fonsterID, source: source, now: now)
            if let member = lobby.members.first(where: { $0.id == program.fonsterID }) { member.controller.agentRituals = memories.profile(member.id) }
        }
        history.insert(.init(source: source, title: action.title, learned: learned), at: 0)
        if history.count > 48 { history.removeLast() }
        cursor += 1
        let interval: Double = action.kind == .explore ? 18 : 8
        nextAt = lobby.activeTime + interval; nextWallAt = now.addingTimeInterval(interval)
        message = "\(source.title) · \(action.title).\(learned ? " A small ritual is becoming familiar." : "")"
        if cursor == program.actions.count { running = false; completedPrograms += 1; message = "This little plan is complete. You're in control." }
    }
    private func validateTarget(_ plan: FonsterAgentProgram, lobby: LocalLobbyController) throws {
        guard let member = lobby.members.first(where: { $0.id == plan.fonsterID }), !member.isVisitor,
              lobby.selectedMember.id == member.id else { throw FonsterAgentError.unavailable }
    }
    private func validateAction(_ action: FonsterAgentAction, lobby: LocalLobbyController) throws {
        try action.validate()
        let scope: FonsterAgentScope
        switch action.kind {
        case .explore, .bench: scope = .movement
        case .react, .reflect: scope = .reactions
        case .feeling: scope = .feelings
        case .greet, .playTogether, .quietTogether: scope = .friendships
        }
        guard scopes.contains(scope), action.reaction != "fetch" || scopes.contains(.movement) else { throw FonsterAgentError.denied }
        if let peer = action.peerID { guard peer != lobby.selectedMember.id, lobby.members.contains(where: { $0.id == peer }) else { throw FonsterAgentError.noPeer } }
        if let area = action.area, !lobby.world.areas.contains(where: { $0.rawValue == area }) { throw FonsterAgentError.noArea }
        if action.kind == .bench && lobby.world.benches.isEmpty { throw FonsterAgentError.noArea }
        if action.kind == .reflect {
            guard let field = action.reflectionField, let rule = reflections[field], rule.enabled, rule.cue == action.cue,
                  rule.audience == .localCompanions ? (action.peerID != nil && scopes.contains(.friendships)) : action.peerID == nil else { throw FonsterAgentError.reflectionDenied }
        }
    }
}
#endif
