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
    let agent = FonsterAgentDirector()
    let presence: FonsterSocialDirector
    var activeTime: Double { activeSeconds }
    @ObservationIgnored private var worldMemory: LobbyWorldMemory
    var focusArea: LobbyWorld.Area?
    var followSelected = false
    var cameraZoom: Float = 1
    var cameraOrbit: Float = 0
    @ObservationIgnored var camera: PerspectiveCamera?
    @ObservationIgnored var fountainDrops: [Entity] = []
    @ObservationIgnored var dragOrbit: Float?
    var world: LobbyWorld { LobbyWorld(population: members.count) }
    var worldTemporaryReason: String? { worldMemory.temporaryReason }
    var availableCompanions: [PlayroomCompanion] {
        PlayroomCompanion.fixtures.filter { fixture in
            !worldMemory.names.contains(fixture.name) && !members.contains { $0.name.caseInsensitiveCompare(fixture.name) == .orderedSame }
        }
    }
    var growthDescription: String {
        if let next = world.nextArea { return "\(members.count) Fonsters · \(next.title) at \(next.population)" }
        return "\(members.count) Fonsters · A whole little neighborhood"
    }
    var buddy = 1 { didSet { if oldValue != buddy { ownerActed() } } }
    var selected = 0 { didSet { if oldValue != selected { ownerActed(); if followSelected { updateCamera() } } } }
    var paused = false
    var still = false
    var reduceMotion = false
    var backgrounded = false
    var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    var wander = true
    var sounds = false
    var ready = false
    var reviewingControls = false
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
    var shouldAnimate: Bool { ready && !paused && !still && !reduceMotion && !backgrounded && !lowPower && !reviewingControls }
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
    init(presenceStore: FonsterSocialStore? = nil) {
        presence = FonsterSocialDirector(store: presenceStore)
        let social = FriendshipMemoryStore.localPreview(); self.social = social
        let memory = LobbyWorldMemory(); worldMemory = memory
        let fixtures = PlayroomCompanion.fixtures
        let memories = PersonalityMemoryStore.localPreview()
        let newMembers = memory.names.compactMap { name -> Member? in
            guard let i = fixtures.firstIndex(where: { $0.name == name }) else { return nil }
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
        for member in members {
            member.controller.agentRituals = agent.memories.profile(member.id)
            try? social.register(card(for: member, includeFeeling: false))
        }
        if ProcessInfo.processInfo.arguments.contains("--presence-preview") {
            for member in members where !member.isVisitor {
                if let profile = try? presence.store.create(id: member.id, name: member.name, owned: true),
                   let introduction = profile.posts.first(where: { $0.event.kind == .introduction && $0.state == .draft }) {
                    try? FonsterLocalFeedAdapter().publish(introduction.id, profileID: member.id, store: presence.store)
                }
            }
        }
        let launchArgs = ProcessInfo.processInfo.arguments
        if let i = launchArgs.firstIndex(of: "--world-area"), i + 1 < launchArgs.count, let area = LobbyWorld.Area(rawValue: launchArgs[i + 1]), world.areas.contains(area) { focusArea = area; cameraOrbit = area == .neighborhood ? -0.5 : 0; simulation.travel(to: area, actor: selected, peer: peerIndex, instant: true) }
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
                     warmth: member.controller.agentRituals.warmth(temperament?.greetingWarmth ?? 0.5), energy: member.controller.agentRituals.energy(temperament?.playEnergy ?? 0.5),
                     feeling: includeFeeling ? member.controller.feeling : nil)
    }
    func chooseFeeling(_ chosen: CreatureFeeling) {
        guard !selectedMember.isVisitor else { return }
        ownerActed(); social.setFeeling(chosen, for: selectedMember.id)
        selectedMember.controller.setFeeling(chosen); simulation.setFeeling(chosen, actor: selected)
        message = "\(selectedMember.name) wears the feeling you chose: \(chosen.title.lowercased())."
    }
    func invite(_ card: FonsterVisitCard) throws {
        try card.validate()
        let slot = min(3, members.count - 1)
        guard !members.enumerated().contains(where: { $0.offset != slot && $0.element.id == card.publicID }),
              members[slot].id != card.publicID || members[slot].isVisitor else { throw VisitCardError.alreadyHere }
        try social.register(card)
        invalidateRoom()
        let controller = PlayroomController()
        controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false
        controller.useVisitorTemperament(card)
        let knownName = PlayroomCompanion.fixtures.contains { $0.name == card.name }
        let collision = members.enumerated().contains { $0.offset != slot && $0.element.name.caseInsensitiveCompare(card.name) == .orderedSame }
        let alias = knownName && !collision ? card.name : "Visitor"
        members[slot] = .init(id: card.publicID, name: alias, localCompanion: nil, visitCard: card, controller: controller)
        rebuildSimulation(); buddy = slot; message = "\(card.name) is visiting from a shared snapshot."
    }
    func endVisit() {
        guard hasVisitor else { return }
        invalidateRoom()
        let slot = members.firstIndex(where: \.isVisitor)!
        let fixture = PlayroomCompanion.fixtures.first { $0.name == worldMemory.names[slot] }!, id = social.identity(for: fixture.name)
        let controller = PlayroomController()
        controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false
        controller.enablePersonalityLearning(PersonalityMemoryStore.localPreview()); controller.setFeeling(social.feeling(for: id)); controller.agentRituals = agent.memories.profile(id)
        members[slot] = .init(id: id, name: fixture.name, localCompanion: fixture, visitCard: nil, controller: controller)
        rebuildSimulation(); message = "The visit ended. Shared memories stay on this Mac."
    }
    private func invalidateRoom() {
        ready = false; roomRevision += 1; ownerActed()
        containers = []; ball = nil; camera = nil; fountainDrops = []; error = nil
        for member in members { member.controller.silence(); member.controller.rig = nil; member.controller.rendererReady = false }
    }
    private func rebuildSimulation() {
        simulation = .init(names: names)
        for (i, member) in members.enumerated() { simulation.setFeeling(member.controller.feeling, actor: i) }
    }
    func addCompanion(_ fixture: PlayroomCompanion) {
        guard members.count < 12, availableCompanions.contains(where: { $0.name == fixture.name }) else { return }
        invalidateRoom()
        let controller = PlayroomController()
        controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false
        controller.enablePersonalityLearning(PersonalityMemoryStore.localPreview())
        let id = social.identity(for: fixture.name); controller.setFeeling(social.feeling(for: id)); controller.agentRituals = agent.memories.profile(id)
        let member = Member(id: id, name: fixture.name, localCompanion: fixture, visitCard: nil, controller: controller)
        members.append(member); worldMemory.enroll(fixture.name)
        try? social.register(card(for: member, includeFeeling: false))
        rebuildSimulation()
        message = "\(fixture.name) joins the world. \(growthDescription)."
    }
    func explore(_ area: LobbyWorld.Area) {
        guard world.areas.contains(area), ready, !paused, !backgrounded, !lowPower else { return }
        interruptPair(); ownerActed(); focusArea = area; followSelected = false; cameraZoom = 1; cameraOrbit = area == .neighborhood ? -0.5 : 0
        simulation.travel(to: area, actor: selected, peer: peerIndex, instant: still || reduceMotion)
        for i in [selected, peerIndex] { members[i].controller.perform(.idle, name: names[i], learn: false, audible: false) }
        message = "\(selectedMember.name) and \(names[peerIndex]) explore \(area.title.lowercased())."
        if !selectedMember.isVisitor { presence.store.record(.init(kind: .explore, area: area.rawValue, source: .ownerAction), id: selectedMember.id) }
        applyLayout(); writeProbe()
    }
    func sitOnBench() {
        guard ready, !world.benches.isEmpty, !paused, !backgrounded, !lowPower else { return }
        interruptPair(); ownerActed()
        simulation.sit(actor: selected, instant: still || reduceMotion)
        selectedMember.controller.perform(still || reduceMotion ? .rest : .idle, name: selectedMember.name, learn: false, audible: false)
        message = "\(selectedMember.name) finds a soft afternoon on the bench."
        applyLayout(); writeProbe()
    }
    func showOverview() { focusArea = nil; followSelected = false; cameraZoom = 1; cameraOrbit = 0; updateCamera(); writeProbe() }
    func lookAtSelected() { followSelected = true; cameraZoom = 1; updateCamera(); writeProbe() }
    func rotateCamera(_ angle: Float) { cameraOrbit += angle; updateCamera() }
    func zoomCamera(_ factor: Float) { cameraZoom = min(1.7, max(0.65, cameraZoom * factor)); updateCamera() }
    func updateCamera() {
        guard let camera else { return }
        let overview = focusArea == nil && !followSelected
        let target2 = followSelected ? simulation.agents[selected].position : (focusArea?.center ?? SIMD2<Float>(0, -0.25))
        let target: SIMD3<Float> = [target2.x, overview ? 0.10 : 0.50, target2.y]
        let distance = (overview ? world.radius * 1.68 : 5.9) * cameraZoom
        let height = (overview ? world.radius * 1.15 : 4.1) * cameraZoom
        let offset: SIMD3<Float> = [sin(cameraOrbit) * distance, height, cos(cameraOrbit) * distance]
        camera.look(at: target, from: target + offset, relativeTo: nil)
    }
    func walk(at point: CGPoint, size: CGSize) {
        guard let camera, ready, !paused, !backgrounded, !lowPower, size.width > 0, size.height > 0 else { return }
        let x = Float(point.x / size.width * 2 - 1), y = Float(1 - point.y / size.height * 2)
        let tangent = tan(Float(camera.camera.fieldOfViewInDegrees) * .pi / 360)
        let local: SIMD3<Float> = [x * Float(size.width / size.height) * tangent, y * tangent, -1]
        let ray = camera.orientation.act(simd_normalize(local))
        guard ray.y < -0.001 else { return }
        let intersection = camera.position + ray * (-camera.position.y / ray.y)
        // Clicking beyond the world doesn't draw a long unintended route.
        guard simd_length(SIMD2<Float>(intersection.x, intersection.z)) <= world.radius else { return }
        walk(to: [intersection.x, intersection.z])
    }
    func walk(to destination: SIMD2<Float>) {
        guard destination.x.isFinite, destination.y.isFinite, ready, !paused, !backgrounded, !lowPower else { return }
        interruptPair(); ownerActed()
        simulation.walk(to: destination, actor: selected, instant: still || reduceMotion)
        selectedMember.controller.perform(.idle, name: selectedMember.name, learn: false, audible: false)
        message = "\(selectedMember.name) takes a little walk."
        applyLayout(); writeProbe()
    }
    func refreshGates() {
        for member in members {
            let c = member.controller
            c.paused = paused || reviewingControls; c.staticMode = still; c.systemReduceMotion = reduceMotion
            c.backgrounded = backgrounded; c.lowPower = lowPower; c.soundEnabled = sounds
            c.refreshStillPose()
        }
        writeProbe()
    }
    func perform(_ action: PlayroomController.Reaction, actor: Int? = nil) {
        let index = actor ?? selected
        guard members.indices.contains(index) else { return }
        interruptPair()
        ownerActed()
        dispatch(simulation.act(action.rawValue, actor: index), deliberate: true)
        if !members[index].isVisitor { presence.ownerMoment(reaction: action.rawValue, id: members[index].id) }
    }
    func waveToFriend() {
        greet(actor: selected, peer: peerIndex)
    }
    func greet(actor: Int, peer: Int) {
        interruptPair(); ownerActed(); dispatch(simulation.greet(actor: actor, peer: peer), deliberate: true)
        if members.indices.contains(actor), !members[actor].isVisitor { presence.ownerMoment(reaction: "greet", id: members[actor].id) }
        applyLayout()
    }
    func playTogether() { interruptPair(); ownerActed(); dispatch(simulation.playTogether(), deliberate: true) }
    func gather() { interruptPair(); ownerActed(); simulation.gather(); message = "Everyone comes a little closer." }
    func pair(quiet: Bool) {
        interruptPair(); ownerActed()
        let peer = peerIndex
        dispatch(simulation.together(actor: selected, peer: peer, quiet: quiet), deliberate: true)
        if !selectedMember.isVisitor { presence.ownerMoment(reaction: quiet ? "rest" : "play", id: selectedMember.id) }
        message = quiet ? "\(names[selected]) and \(names[peer]) share a quiet moment. No need to cheer up." : "\(names[selected]) and \(names[peer]) pass the ball back and forth."
        applyLayout()
    }
    private func interruptPair() {
        guard let game = simulation.pairGame else { return }
        for i in [game.actor, game.peer] { members[i].controller.perform(.idle, name: names[i], learn: false, audible: false) }
        simulation.interruptGame()
    }
    func setWander(_ enabled: Bool) { wander = enabled; ownerActed(); if !enabled { simulation.freezeGoals() } }
    func execute(_ intent: CreatureCommandIntent) {
        guard let actor = names.firstIndex(of: intent.targetName) else { return }
        interruptPair()
        if intent.action == .greetFriend, let peerName = intent.peerName, let peer = names.firstIndex(of: peerName) {
            greet(actor: actor, peer: peer); return
        }
        if intent.action == .roam { wander = true; ownerActed(); simulation.setWandering(true, actor: actor); members[actor].controller.followingPointer = false; members[actor].controller.perform(.idle, name: names[actor]); return }
        if intent.action == .stop { ownerActed(); simulation.setWandering(false, actor: actor); members[actor].controller.stopMoving(); message = "\(names[actor]) stays beside you."; return }
        if intent.action == .follow { if !members[actor].controller.followingPointer { members[actor].controller.followPointer() }; ownerActed(); message = "\(names[actor]) follows your pointer."; return }
        let actions: [CreatureCommandIntent.Action: PlayroomController.Reaction] = [.hello: .greet, .dance: .play, .rest: .rest, .blink: .blink, .look: .look, .hop: .hop, .spin: .spin, .stretch: .stretch, .highFive: .highFive, .rub: .rub, .fetch: .fetch]
        if let action = actions[intent.action] { perform(action, actor: actor) }
    }
    func advance(dt: Float, now: Date = .now) {
        guard shouldAnimate, dt.isFinite, dt > 0 else { return }
        activeSeconds += Double(min(0.06, dt))
        if ProcessInfo.processInfo.arguments.contains("--agent-demo"), frames == 20 {
            try? agent.prepareDemo(lobby: self, now: now); try? agent.start(lobby: self, now: now)
        }
        if ProcessInfo.processInfo.arguments.contains("--presence-demo"), frames == 20 {
            _ = try? presence.store.create(id: selectedMember.id, name: selectedMember.name, owned: !selectedMember.isVisitor, now: now)
            try? presence.start(lobby: self, now: now)
        }
        agent.advance(lobby: self, now: now)
        presence.advance(lobby: self, now: now)
        let events = simulation.step(dt: dt, wander: wander)
        if !events.isEmpty { dispatch(events, deliberate: false) }
        for (i, member) in members.enumerated() { member.controller.worldWalking = simulation.agents[i].walking; member.controller.advance(dt: dt) }
        LobbyWorldScene.animate(fountainDrops, time: Float(activeSeconds))
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
    private func dispatch(_ events: [LocalLobbySimulation.Event], deliberate: Bool, agentDriven: Bool = false) {
        for (offset, event) in events.enumerated() {
            guard let action = PlayroomController.Reaction(rawValue: event.action) else { continue }
            let member = members[event.actor]
            member.controller.perform(action, name: member.name, learn: deliberate && !member.isVisitor, audible: (deliberate || agentDriven) && offset == 0)
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
    func takeOwnerControl() { ownerActed() }
    private func ownerActed() { userRevision += 1; agent.takeOver(lobby: self); presence.ownerTookOver() }
    func cancelAgentMotion(id: UUID) {
        guard let actor = members.firstIndex(where: { $0.id == id }) else { return }
        interruptPair()
        simulation.stopAgentMotion(actor: actor)
        members[actor].controller.perform(.idle, name: names[actor], learn: false, audible: false)
        members[actor].controller.silence(); applyLayout()
    }
    func applyAgent(_ action: FonsterAgentAction, id: UUID, reflection: HumanReflectionRule?) throws {
        guard let actor = members.firstIndex(where: { $0.id == id }), !members[actor].isVisitor else { throw FonsterAgentError.unavailable }
        let peer = action.peerID.flatMap { id in members.firstIndex(where: { $0.id == id }) }
        interruptPair()
        switch action.kind {
        case .feeling:
            guard let feeling = action.feeling else { throw FonsterAgentError.invalid }
            social.setFeeling(feeling, for: id); simulation.setFeeling(feeling, actor: actor); members[actor].controller.setFeeling(feeling)
        case .explore:
            guard let raw = action.area, let area = LobbyWorld.Area(rawValue: raw) else { throw FonsterAgentError.invalid }
            simulation.travel(to: area, actor: actor, instant: still || reduceMotion)
            members[actor].controller.perform(.idle, name: names[actor], learn: false, audible: false)
        case .bench:
            simulation.sit(actor: actor, instant: still || reduceMotion)
            members[actor].controller.perform(still || reduceMotion ? .rest : .idle, name: names[actor], learn: false, audible: false)
        case .react:
            dispatch(simulation.act(action.reaction!, actor: actor), deliberate: false, agentDriven: true)
        case .greet:
            guard let peer else { throw FonsterAgentError.noPeer }
            dispatch(simulation.greet(actor: actor, peer: peer), deliberate: false, agentDriven: true)
        case .playTogether, .quietTogether:
            guard let peer else { throw FonsterAgentError.noPeer }
            dispatch(simulation.together(actor: actor, peer: peer, quiet: action.kind == .quietTogether), deliberate: false, agentDriven: true)
        case .reflect:
            // A transient pose from an owner-chosen coarse cue. Never changes
            // saved feelings, visit files, appearance, or private personality.
            guard let cue = action.cue, let reflection, reflection.enabled, reflection.cue == cue else { throw FonsterAgentError.reflectionDenied }
            if reflection.audience == .localCompanions {
                guard let peer else { throw FonsterAgentError.noPeer }
                dispatch(simulation.together(actor: actor, peer: peer, quiet: cue.reaction == "rest"), deliberate: false, agentDriven: true)
            } else { dispatch(simulation.act(cue.reaction, actor: actor), deliberate: false, agentDriven: true) }
        }
        applyLayout(); writeProbe()
    }
    func applyLayout() {
        for (i, container) in containers.enumerated() where simulation.agents.indices.contains(i) {
            let agent = simulation.agents[i]
            container.position = [agent.position.x, 0.594 + (agent.seated ? 0.42 : 0), agent.position.y - (agent.seated ? 0.78 : 0)]
            container.orientation = simd_quatf(angle: agent.heading, axis: [0, 1, 0])
        }
        ball?.position = simulation.ballPosition
        updateCamera()
    }
    private func writeProbe() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--lobby-probe-file"), i + 1 < args.count else { return }
        let state: [String: Any] = ["frames": frames, "animating": shouldAnimate, "paused": paused,
            "rendererReady": ready, "rendererError": error ?? "",
            "still": still, "reduceMotion": reduceMotion, "background": backgrounded, "lowPower": lowPower,
            "worldRadius": world.radius, "worldAreas": world.areas.map(\.rawValue), "focusArea": focusArea?.rawValue ?? "overview",
            "walking": simulation.agents.map(\.walking), "seated": simulation.agents.map(\.seated),
            "cameraPosition": camera.map { [Double($0.position.x), Double($0.position.y), Double($0.position.z)] } ?? [],
            "agentRunning": agent.running, "agentSource": agent.source.rawValue, "agentCursor": agent.cursor, "agentHistory": agent.history.map { $0.title }, "agentRituals": members.map { $0.controller.agentRituals.total },
            "humanReflectionEnabled": HumanReflectionField.allCases.filter { agent.reflections[$0]?.enabled == true }.map(\.rawValue),
            "profileAgentRunning": presence.running, "profileCount": presence.store.profiles.count,
            "profileDrafts": presence.store.profiles.reduce(0) { $0 + $1.posts.filter { $0.state == .draft }.count },
            "localFeedPosts": presence.store.profiles.reduce(0) { $0 + $1.posts.filter { $0.state == .localFeed }.count },
            "reviewingControls": reviewingControls,
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
