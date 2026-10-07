#if os(macOS)
import SwiftUI
import RealityKit
import Observation

@available(macOS 15.0, *)
@MainActor @Observable
final class LocalLobbyController {
    struct Member: Identifiable {
        let companion: PlayroomCompanion
        let controller: PlayroomController
        var id: UUID { companion.id }
    }
    let members: [Member]
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
    private(set) var socialCount = 0
    private(set) var message = "A little wave can start a friendship."
    @ObservationIgnored private(set) var simulation: LocalLobbySimulation
    @ObservationIgnored var containers: [Entity] = []
    @ObservationIgnored var ball: ModelEntity?
    @ObservationIgnored private(set) var frames = 0
    var shouldAnimate: Bool { ready && !paused && !still && !reduceMotion && !backgrounded && !lowPower }
    var selectedMember: Member { members[selected] }
    var names: [String] { members.map { $0.companion.name } }
    var motionStatus: String {
        if backgrounded { return "Paused in background" }; if lowPower { return "Low Power · still" }
        if reduceMotion { return "Reduce Motion · still" }; if still { return "Still mode" }
        return paused ? "Paused" : "Together, at their own pace"
    }
    init() {
        let fixtures = PlayroomCompanion.fixtures
        let memories = PersonalityMemoryStore.localPreview()
        members = [0, 1, 2, 4].map { i in
            let controller = PlayroomController()
            controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false
            controller.enablePersonalityLearning(memories)
            return Member(companion: fixtures[i], controller: controller)
        }
        simulation = .init(names: members.map { $0.companion.name })
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
        userRevision += 1
        dispatch(simulation.act(action.rawValue, actor: index), deliberate: true)
    }
    func waveToFriend() {
        let peer = (selected + 1) % members.count
        greet(actor: selected, peer: peer)
    }
    func greet(actor: Int, peer: Int) {
        userRevision += 1; dispatch(simulation.greet(actor: actor, peer: peer), deliberate: true)
        applyLayout()
    }
    func playTogether() { userRevision += 1; dispatch(simulation.playTogether(), deliberate: true) }
    func gather() { userRevision += 1; simulation.gather(); message = "Everyone comes a little closer." }
    func setWander(_ enabled: Bool) { wander = enabled; userRevision += 1; if !enabled { simulation.freezeGoals() } }
    func execute(_ intent: CreatureCommandIntent) {
        guard let actor = names.firstIndex(of: intent.targetName) else { return }
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
        guard shouldAnimate else { return }
        let events = simulation.step(dt: dt, wander: wander)
        if !events.isEmpty { dispatch(events, deliberate: false) }
        for member in members { member.controller.advance(dt: dt) }
        applyLayout(); frames += 1
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
            member.controller.perform(action, name: member.companion.name, learn: deliberate, audible: deliberate && offset == 0)
        }
        socialCount = simulation.socialEvents
        if let first = events.first {
            if let peer = first.peer { message = "\(names[first.actor]) \(first.action == "hop" ? "starts a hop with" : "waves to") \(names[peer])." }
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
            "still": still, "reduceMotion": reduceMotion, "background": backgrounded, "lowPower": lowPower,
            "socialEvents": socialCount, "localMembers": members.count, "revision": userRevision,
            "learnedInteractions": members.map { $0.controller.personality?.interactionCount ?? 0 },
            "positions": simulation.agents.map { [Double($0.position.x), Double($0.position.y)] }]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: args[i + 1]), options: .atomic)
        }
    }
}
#endif
