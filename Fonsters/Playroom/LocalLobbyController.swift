#if os(macOS)
import SwiftUI
import RealityKit
import Observation

@available(macOS 15.0, *)
@MainActor @Observable
final class LocalLobbyController {
    @MainActor struct Member: Identifiable {
        let id: UUID
        let name: String
        let localCompanion: PlayroomCompanion?
        let visitCard: FonsterVisitCard?
        let controller: PlayroomController
        var descriptor: CreatureAppearanceDescriptor { localCompanion?.descriptor ?? visitCard!.appearance }
        var isVisitor: Bool { visitCard != nil }
        var feelingLabel: String { isVisitor && visitCard?.feeling == nil ? "Feeling not shared" : controller.feeling.title }
    }
    private(set) var members: [Member]
    let social: FriendshipMemoryStore
    var buddy = 1
    var selected = 0 { didSet { if oldValue != selected { userRevision += 1 } } }
    var paused = false
    var still = false
    var reduceMotion = false
    var backgrounded = false
    var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    var wander = true
    var sounds = false
    var ready = false
    var error: String?
    private(set) var userRevision = 0
    private(set) var roomRevision = 0
    private(set) var socialCount = 0
    private(set) var message = "A little wave can start a friendship."
    @ObservationIgnored private(set) var simulation: LocalLobbySimulation
    @ObservationIgnored var containers: [Entity] = []
    @ObservationIgnored var ball: ModelEntity?
    @ObservationIgnored private(set) var frames = 0
    @ObservationIgnored private var activeSeconds: Double = 0
    @ObservationIgnored private let session = UUID()
    var shouldAnimate: Bool { ready && !paused && !still && !reduceMotion && !backgrounded && !lowPower }
    var selectedMember: Member { members[selected] }
    var names: [String] { members.map(\.name) }
    var peerIndex: Int { buddy != selected && members.indices.contains(buddy) ? buddy : (selected + 1) % members.count }
    var selectedFriendship: CreatureFriendship { social.friendship(selectedMember.id, members[peerIndex].id) }
    var hasVisitor: Bool { members.contains(where: \.isVisitor) }
    var motionStatus: String {
        if backgrounded { return "Paused in background" }; if lowPower { return "Low Power · still" }
        if reduceMotion { return "Reduce Motion · still" }; if still { return "Still mode" }
        return paused ? "Paused" : "Together, at their own pace"
    }
    init() {
        let social = FriendshipMemoryStore.localPreview(); self.social = social
        let fixtures = PlayroomCompanion.fixtures
        let memories = PersonalityMemoryStore.localPreview()
        let newMembers = [0, 1, 2, 4].map { i in
            let controller = PlayroomController()
            controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false
            controller.enablePersonalityLearning(memories)
            let id = social.identity(for: fixtures[i].name)
            controller.setFeeling(social.feeling(for: id))
            return Member(id: id, name: fixtures[i].name, localCompanion: fixtures[i], visitCard: nil, controller: controller)
        }
        members = newMembers
        simulation = .init(names: newMembers.map(\.name))
        for (i, member) in members.enumerated() { simulation.setFeeling(member.controller.feeling, actor: i) }
        for member in members { try? social.register(card(for: member, includeFeeling: false)) }
        if ProcessInfo.processInfo.arguments.contains("--social-demo") {
            let fixture = fixtures[3]
            let sample = FonsterVisitCard(publicID: social.identity(for: "SyntheticTideVisitor"), name: fixture.name, appearance: fixture.descriptor,
                                         warmth: 0.45, energy: 0.3, feeling: .cozy)
            if let data = try? sample.encoded(), let decoded = try? FonsterVisitCard.decode(data) {
                try? invite(decoded)
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "--sample-visit-file"), i + 1 < args.count {
                    try? data.write(to: URL(fileURLWithPath: args[i + 1]), options: .atomic)
                }
            }
        }
    }
    func card(for member: Member, includeFeeling: Bool) -> FonsterVisitCard {
        let temperament = member.controller.personality
        return .init(publicID: member.id, name: member.visitCard?.name ?? member.name, appearance: member.descriptor,
                     warmth: temperament?.greetingWarmth ?? 0.5, energy: temperament?.playEnergy ?? 0.5,
                     feeling: includeFeeling ? member.controller.feeling : nil)
    }
    func chooseFeeling(_ chosen: CreatureFeeling) {
        guard !selectedMember.isVisitor else { return }
        userRevision += 1; social.setFeeling(chosen, for: selectedMember.id)
        selectedMember.controller.setFeeling(chosen); simulation.setFeeling(chosen, actor: selected)
        message = "\(selectedMember.name) wears the feeling you chose: \(chosen.title.lowercased())."
    }
    func invite(_ card: FonsterVisitCard) throws {
        try card.validate()
        guard !members.prefix(3).contains(where: { $0.id == card.publicID }),
              members[3].id != card.publicID || members[3].isVisitor else { throw VisitCardError.alreadyHere }
        try social.register(card)
        invalidateRoom()
        let controller = PlayroomController()
        controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false
        controller.useVisitorTemperament(card)
        let knownName = PlayroomCompanion.fixtures.contains { $0.name == card.name }
        let collision = members.prefix(3).contains { $0.name.caseInsensitiveCompare(card.name) == .orderedSame }
        let alias = knownName && !collision ? card.name : "Visitor"
        members[3] = .init(id: card.publicID, name: alias, localCompanion: nil, visitCard: card, controller: controller)
        rebuildSimulation(); buddy = 3; message = "\(card.name) is visiting from a shared snapshot."
    }
    func endVisit() {
        guard hasVisitor else { return }
        invalidateRoom()
        let fixture = PlayroomCompanion.fixtures[4], id = social.identity(for: "Orbit")
        let controller = PlayroomController()
        controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false
        controller.enablePersonalityLearning(PersonalityMemoryStore.localPreview()); controller.setFeeling(social.feeling(for: id))
        members[3] = .init(id: id, name: fixture.name, localCompanion: fixture, visitCard: nil, controller: controller)
        rebuildSimulation(); message = "The visit ended. Shared memories stay on this Mac."
    }
    private func invalidateRoom() {
        ready = false; roomRevision += 1; userRevision += 1
        containers = []; ball = nil
        for member in members { member.controller.silence(); member.controller.rig = nil; member.controller.rendererReady = false }
    }
    private func rebuildSimulation() {
        simulation = .init(names: names)
        for (i, member) in members.enumerated() { simulation.setFeeling(member.controller.feeling, actor: i) }
    }
    func refreshGates() {
        for member in members {
            let c = member.controller
            c.paused = paused; c.staticMode = still; c.systemReduceMotion = reduceMotion
            c.backgrounded = backgrounded; c.lowPower = lowPower; c.soundEnabled = sounds
            c.refreshStillPose()
        }
        writeProbe()
    }
    func perform(_ action: PlayroomController.Reaction, actor: Int? = nil) {
        let index = actor ?? selected
        guard members.indices.contains(index) else { return }
        interruptPair()
        userRevision += 1
        dispatch(simulation.act(action.rawValue, actor: index), deliberate: true)
    }
    func waveToFriend() {
        greet(actor: selected, peer: peerIndex)
    }
    func greet(actor: Int, peer: Int) {
        interruptPair(); userRevision += 1; dispatch(simulation.greet(actor: actor, peer: peer), deliberate: true)
        applyLayout()
    }
    func playTogether() { interruptPair(); userRevision += 1; dispatch(simulation.playTogether(), deliberate: true) }
    func gather() { interruptPair(); userRevision += 1; simulation.gather(); message = "Everyone comes a little closer." }
    func pair(quiet: Bool) {
        interruptPair(); userRevision += 1
        let peer = peerIndex
        dispatch(simulation.together(actor: selected, peer: peer, quiet: quiet), deliberate: true)
        message = quiet ? "\(names[selected]) and \(names[peer]) share a quiet moment. No need to cheer up." : "\(names[selected]) and \(names[peer]) pass the ball back and forth."
        applyLayout()
    }
    private func interruptPair() {
        guard let game = simulation.pairGame else { return }
        for i in [game.actor, game.peer] { members[i].controller.perform(.idle, name: names[i], learn: false, audible: false) }
        simulation.interruptGame()
    }
    func setWander(_ enabled: Bool) { wander = enabled; userRevision += 1; if !enabled { simulation.freezeGoals() } }
    func execute(_ intent: CreatureCommandIntent) {
        guard let actor = names.firstIndex(of: intent.targetName) else { return }
        interruptPair()
        if intent.action == .greetFriend, let peerName = intent.peerName, let peer = names.firstIndex(of: peerName) {
            greet(actor: actor, peer: peer); return
        }
        if intent.action == .roam { wander = true; userRevision += 1; simulation.setWandering(true, actor: actor); members[actor].controller.followingPointer = false; members[actor].controller.perform(.idle, name: names[actor]); return }
        if intent.action == .stop { userRevision += 1; simulation.setWandering(false, actor: actor); members[actor].controller.stopMoving(); message = "\(names[actor]) stays beside you."; return }
        if intent.action == .follow { if !members[actor].controller.followingPointer { members[actor].controller.followPointer() }; userRevision += 1; message = "\(names[actor]) follows your pointer."; return }
        let actions: [CreatureCommandIntent.Action: PlayroomController.Reaction] = [.hello: .greet, .dance: .play, .rest: .rest, .blink: .blink, .look: .look, .hop: .hop, .spin: .spin, .stretch: .stretch, .highFive: .highFive, .rub: .rub, .fetch: .fetch]
        if let action = actions[intent.action] { perform(action, actor: actor) }
    }
    func advance(dt: Float) {
        guard shouldAnimate, dt.isFinite, dt > 0 else { return }
        activeSeconds += Double(min(0.06, dt))
        let events = simulation.step(dt: dt, wander: wander)
        if !events.isEmpty { dispatch(events, deliberate: false) }
        for member in members { member.controller.advance(dt: dt) }
        applyLayout(); frames += 1
        if ProcessInfo.processInfo.arguments.contains("--social-demo") {
            if frames == 20 { selected = 0; buddy = 3; chooseFeeling(.cozy); pair(quiet: false) }
            if frames == 215 { pair(quiet: true) }
        }
        if frames % 15 == 0 { writeProbe() }
    }
    func animate() async {
        refreshGates()
        var last = Date()
        while !Task.isCancelled && shouldAnimate {
            let now = Date(), dt = min(0.06, Float(now.timeIntervalSince(last)))
            last = now; advance(dt: dt)
            do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
        }
    }
    private func dispatch(_ events: [LocalLobbySimulation.Event], deliberate: Bool) {
        for (offset, event) in events.enumerated() {
            guard let action = PlayroomController.Reaction(rawValue: event.action) else { continue }
            let member = members[event.actor]
            member.controller.perform(action, name: member.name, learn: deliberate && !member.isVisitor, audible: deliberate && offset == 0)
        }
        if let first = events.first, let peer = first.peer, members.indices.contains(peer), !paused && !backgrounded && !lowPower {
            let kind = first.action == "rub" ? "quiet" : (["hop", "highFive", "play"].contains(first.action) ? "game" : "hello")
            social.record(kind, members[first.actor].id, members[peer].id, activeSeconds: activeSeconds, autonomous: !deliberate, session: session)
        }
        socialCount = simulation.socialEvents
        if let first = events.first {
            if let peer = first.peer { message = "\(names[first.actor]) \(first.action == "rub" ? "keeps quiet company with" : first.action == "hop" ? "starts a hop with" : "waves to") \(names[peer])." }
            else { message = members[first.actor].controller.message }
        }
        writeProbe()
    }
    func applyLayout() {
        for (i, container) in containers.enumerated() where simulation.agents.indices.contains(i) {
            let agent = simulation.agents[i]
            container.position = [agent.position.x, 0.594, agent.position.y]
            container.orientation = simd_quatf(angle: agent.heading, axis: [0, 1, 0])
        }
        ball?.position = simulation.ballPosition
    }
    private func writeProbe() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--lobby-probe-file"), i + 1 < args.count else { return }
        let state: [String: Any] = ["frames": frames, "animating": shouldAnimate, "paused": paused,
            "rendererReady": ready, "rendererError": error ?? "",
            "still": still, "reduceMotion": reduceMotion, "background": backgrounded, "lowPower": lowPower,
            "socialEvents": socialCount, "localMembers": members.count, "revision": userRevision,
            "visitors": members.filter(\.isVisitor).count, "pairGame": simulation.pairGame != nil,
            "chosenFeelings": members.map { $0.feelingLabel }, "selectedFriendshipMoments": selectedFriendship.meaningfulMoments,
            "learnedInteractions": members.map { $0.controller.personality?.interactionCount ?? 0 },
            "positions": simulation.agents.map { [Double($0.position.x), Double($0.position.y)] }]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: args[i + 1]), options: .atomic)
        }
    }
}
#endif
