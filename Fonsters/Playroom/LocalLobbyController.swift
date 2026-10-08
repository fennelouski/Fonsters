#if os(macOS) || os(iOS) || os(tvOS)
import SwiftUI
import RealityKit
import Observation

@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
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
    var cameraPitch: Float = 0
    var cameraPan: SIMD3<Float> = .zero
    var cameraGestureActive = false
    var cameraGestureOrigin: ControlState?
    var viewportAspect: Float = 1.5
    @ObservationIgnored var viewportHeight: Float = 1
    var visibleStageFraction: Float = 1
    @ObservationIgnored var camera: PerspectiveCamera?
    @ObservationIgnored var sceneCameraDetails: [String] = []
    @ObservationIgnored var fountainDrops: [Entity] = []
    @ObservationIgnored var dragOrbit: Float?
    @ObservationIgnored private(set) var contactID: UUID?
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
    var listening = false
    private(set) var danceMode = FonsterDanceMode.daylight
    @ObservationIgnored var danceScene: LobbyDanceScene?
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
    var continuousGallery = false
    @ObservationIgnored private(set) var presentation = LobbyPresentation()
    private(set) var careFocus: Int?
    var inCare: Bool { careFocus != nil }
    private(set) var searchQuery = ""
    private(set) var searchMatches: [Int] = []
    @ObservationIgnored private var browsingCamera: ControlState?
    @ObservationIgnored private var careReturnCamera: ControlState?
    private var immediatePresentation: Bool { paused || still || reduceMotion || backgrounded || lowPower || reviewingControls }
    var naturalPoses: [LobbyPresentation.Pose] {
        simulation.agents.map { .init(position: [$0.position.x, 0.594 + ($0.seated ? 0.42 : 0), $0.position.y - ($0.seated ? 0.78 : 0)], heading: $0.heading) }
    }
    func search(_ query: String) {
        guard continuousGallery, !inCare else { return }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != searchQuery || presentation.poses.isEmpty else { return }
        takeOwnerControl()
        if presentation.query.isEmpty && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { browsingCamera = controls; resetPresentationCamera() }
        presentation.sideDistance = max(1.5, min(5.5, viewportAspect * 3.3))
        presentation.change(query: query, care: nil, names: names, natural: naturalPoses, immediate: immediatePresentation)
        searchQuery = presentation.query; searchMatches = presentation.matches
        if presentation.query.isEmpty, let state = browsingCamera { restoreCamera(state); browsingCamera = nil }
        applyLayout()
    }
    func openCare(_ index: Int) {
        guard continuousGallery, members.indices.contains(index), ready else { return }
        if inCare && selected == index { return }
        takeOwnerControl()
        if !inCare { careReturnCamera = controls }
        selected = index; careFocus = index; resetPresentationCamera()
        presentation.change(query: searchQuery, care: index, names: names, natural: naturalPoses, immediate: immediatePresentation)
        selectedMember.controller.perform(.greet, name: selectedMember.name, learn: !selectedMember.isVisitor)
        applyLayout()
    }
    func returnToLobby() {
        guard inCare else { return }
        takeOwnerControl(); selectedMember.controller.stopActivity(); careFocus = nil
        presentation.change(query: searchQuery, care: nil, names: names, natural: naturalPoses, immediate: immediatePresentation)
        if let state = careReturnCamera { restoreCamera(state); careReturnCamera = nil }
        applyLayout()
    }
    private func resetPresentationCamera() { cameraOrbit = 0; cameraPitch = 0; cameraPan = .zero; cameraZoom = 1; followSelected = false; focusArea = nil }
    private func restoreCamera(_ state: ControlState) { cameraOrbit = state.orbit; cameraPitch = state.pitch; cameraPan = state.pan; cameraZoom = state.zoom; followSelected = state.follow; focusArea = state.area }
    var selectedSavedID: UUID? { savedIdentities.first(where: { $0.value == selectedMember.id })?.key }
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
        wander = !ProcessInfo.processInfo.arguments.contains("--verify-manual")
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
    /// Private saved IDs are used only to reconcile local views. Portable cards
    /// continue to use independently generated public IDs.
    @ObservationIgnored private var savedIdentities: [UUID: UUID] = [:]
    @ObservationIgnored private var careIdentities: [UUID: UUID] = [:]
    private func careIdentity(for member: Member) -> UUID { careIdentities[member.id] ?? member.id }
    @ObservationIgnored private var savedRoster: [SavedAppearance] = []
    @ObservationIgnored private var savedBiographies: [UUID: FonsterBiography] = [:]
    var selectedBiography: FonsterBiography { selectedMember.visitCard?.biography ?? selectedSavedID.flatMap { savedBiographies[$0] } ?? .init() }
    struct SavedAppearance: Equatable { let id: UUID; let name: String; let seed: String; var biography: FonsterBiography = .init() }
    func showSaved(_ records: [SavedAppearance]) {
        guard records != savedRoster else { return }
        let wasSaved = !savedRoster.isEmpty
        let previous = savedRoster
        savedBiographies = Dictionary(records.map { ($0.id, $0.biography) }, uniquingKeysWith: { first, _ in first })
        savedRoster = records
        guard !records.isEmpty || wasSaved else { return } // Empty libraries can play with the local showcase.
        if records.count == previous.count && zip(records, previous).allSatisfy({ pair in pair.0.id == pair.1.id && pair.0.seed == pair.1.seed }) {
            // Naming/story edits keep the same rigs, camera, paths and care state.
            if records.map(\.name) != previous.map(\.name) {
                takeOwnerControl()
                members = zip(members, records).map { member, record in
                    let name = record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Fonster" : record.name
                    if name == member.name { return member }
                    member.controller.rename(name)
                    return .init(id: member.id, name: name, localCompanion: .init(name: name, seed: record.seed), visitCard: nil, controller: member.controller)
                }
                simulation.rename(names)
                if !searchQuery.isEmpty && !inCare {
                    presentation.change(query: searchQuery, care: nil, names: names, natural: naturalPoses, immediate: immediatePresentation)
                    searchMatches = presentation.matches; applyLayout()
                }
            }
            return
        }
        let selectedRecord = selectedSavedID
        let returningToCare = inCare
        cancelContact(); agent.takeOver(lobby: self); presence.ownerTookOver()
        let memories = PersonalityMemoryStore.localPreview()
        members = records.map { record in
            let name = record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Fonster" : record.name
            let companion = PlayroomCompanion(name: name, seed: record.seed)
            let digest = FonsterVisitCard(publicID: UUID(), name: "Fonster", appearance: companion.descriptor, warmth: 0.5, energy: 0.5, feeling: nil).appearanceDigest
            let publicID = social.identity(for: "saved-" + record.id.uuidString + "-" + digest)
            savedIdentities[record.id] = publicID
            let careID = social.identity(for: "saved-care-" + record.id.uuidString)
            careIdentities[publicID] = careID
            if let existing = members.first(where: { $0.id == publicID && $0.descriptor == companion.descriptor && $0.name == name }) { return existing }
            let controller = PlayroomController(); controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false
            controller.enablePersonalityLearning(memories, identity: careID.uuidString, name: name); controller.setFeeling(social.feeling(for: careID))
            return .init(id: publicID, name: name, localCompanion: companion, visitCard: nil, controller: controller)
        }
        if members.isEmpty {
            members = PlayroomCompanion.fixtures.prefix(4).map { companion in
                let controller = PlayroomController(); controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false; controller.enablePersonalityLearning(memories)
                return .init(id: social.identity(for: companion.name), name: companion.name, localCompanion: companion, visitCard: nil, controller: controller)
            }
        }
        selected = 0; buddy = members.count > 1 ? 1 : 0
        simulation = .init(names: names); presentation = .init(); browsingCamera = nil; careReturnCamera = nil; careFocus = nil; searchQuery = ""; searchMatches = Array(members.indices)
        for (i, member) in members.enumerated() { simulation.setFeeling(member.controller.feeling, actor: i) }
        if returningToCare, let selectedRecord, let publicID = savedIdentities[selectedRecord], let index = members.firstIndex(where: { $0.id == publicID }) {
            selected = index; careFocus = index
            presentation.change(query: "", care: index, names: names, natural: naturalPoses, immediate: true)
        }
        containers = []; camera = nil; ready = false; roomRevision += 1
    }
    struct ControlState: Equatable {
        var selected: Int
        var buddy: Int
        var area: LobbyWorld.Area?
        var follow: Bool
        var zoom: Float
        var orbit: Float
        var pitch: Float
        var pan: SIMD3<Float>
        var paused: Bool
        var still: Bool
        var wander: Bool
        var sounds: Bool
        var feeling: CreatureFeeling
        var careFocus: Int?
        var query: String
        var dance: FonsterDanceMode
    }
    var controls: ControlState {
        .init(selected: selected, buddy: buddy, area: focusArea, follow: followSelected, zoom: cameraZoom, orbit: cameraOrbit, pitch: cameraPitch, pan: cameraPan,
              paused: paused, still: still, wander: wander, sounds: sounds, feeling: selectedMember.controller.feeling, careFocus: careFocus, query: searchQuery, dance: danceMode)
    }
    func restoreControls(_ state: ControlState) {
        guard members.indices.contains(state.selected), members.indices.contains(state.buddy) else { return }
        if continuousGallery {
            if state.careFocus != careFocus || state.query != searchQuery {
                if inCare { returnToLobby() }
                search(state.query)
                if let focus = state.careFocus { openCare(focus) }
            }
        }
        takeOwnerControl(); selected = state.selected; buddy = state.buddy
        focusArea = state.area; followSelected = state.follow; cameraZoom = state.zoom; cameraOrbit = state.orbit; cameraPitch = state.pitch; cameraPan = state.pan
        paused = state.paused; still = state.still; setWander(state.wander); sounds = state.sounds
        if selectedMember.controller.feeling != state.feeling { chooseFeeling(state.feeling) }
        if danceMode != state.dance { setDanceMode(state.dance) }
        message = "Previous controls restored."
        updateCamera(); refreshGates()
    }
    func stopActivity() {
        if continuousGallery && inCare { ownerActed(); selectedMember.controller.stopActivity(); message = selectedMember.controller.message; return }
        interruptPair(); ownerActed()
        for i in members.indices {
            simulation.stopAgentMotion(actor: i); members[i].controller.stopActivity()
        }
        message = "Activity stopped. Shared memories stay with you."
        applyLayout(); writeProbe()
    }

    func card(for member: Member, includeFeeling: Bool, includeBiography: Bool = false) -> FonsterVisitCard {
        let temperament = member.controller.personality
        let displayName = member.visitCard?.name ?? member.name
        let publicName = displayName.contains("@") ? "Fonster" : String(displayName.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }.joined().prefix(24))
        return .init(publicID: member.id, name: publicName.isEmpty ? "Fonster" : publicName, appearance: member.descriptor,
                     warmth: member.controller.agentRituals.warmth(temperament?.greetingWarmth ?? 0.5), energy: member.controller.agentRituals.energy(temperament?.playEnergy ?? 0.5),
                     feeling: includeFeeling ? member.controller.feeling : nil,
                     biography: includeBiography ? member.visitCard?.biography ?? savedIdentities.first(where: { $0.value == member.id }).flatMap { savedBiographies[$0.key] } : nil)
    }
    func chooseFeeling(_ chosen: CreatureFeeling) {
        guard !selectedMember.isVisitor else { return }
        ownerActed(); social.setFeeling(chosen, for: careIdentity(for: selectedMember))
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
        interruptPair(); ownerActed(); focusArea = area; followSelected = false; cameraZoom = 1; cameraOrbit = area == .neighborhood ? -0.5 : 0; cameraPitch = 0; cameraPan = .zero
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
    func showOverview() { focusArea = nil; followSelected = false; cameraZoom = 1; cameraOrbit = 0; cameraPitch = 0; cameraPan = .zero; updateCamera(); writeProbe() }
    func lookAtSelected() { followSelected = true; cameraZoom = 1; cameraPan = .zero; updateCamera(); writeProbe() }
    func rotateCamera(_ angle: Float, vertical: Float = 0) {
        guard angle.isFinite, vertical.isFinite else { return }
        cameraOrbit = (cameraOrbit + angle).remainder(dividingBy: 2 * .pi)
        cameraPitch = min(0.80, max(-0.42, cameraPitch + vertical))
        updateCamera()
    }
    func zoomCamera(_ factor: Float) {
        guard factor.isFinite, factor > 0 else { return }
        cameraZoom = min(2.5, max(0.45, cameraZoom * factor)); updateCamera()
    }
    func panCamera(_ translation: SIMD3<Float>) {
        guard translation.x.isFinite, translation.y.isFinite, translation.z.isFinite else { return }
        cameraPan += translation
        let limit = world.radius * 1.5
        cameraPan.x = min(limit, max(-limit, cameraPan.x)); cameraPan.z = min(limit, max(-limit, cameraPan.z))
        cameraPan.y = min(10, max(-0.25, cameraPan.y)); updateCamera()
    }
    func beginCameraGesture() {
        guard !cameraGestureActive else { return }
        cameraGestureOrigin = controls; cameraGestureActive = true; cancelContact()
    }
    func dragCamera(_ translation: CGSize, pan: Bool, verticalPan: Bool = false) {
        guard let origin = cameraGestureOrigin, translation.width.isFinite, translation.height.isFinite else { return }
        if pan {
            let amount = Float(max(1, world.radius)) * origin.zoom * 0.0025
            let right = SIMD3<Float>(cos(origin.orbit), 0, -sin(origin.orbit))
            let forward = SIMD3<Float>(sin(origin.orbit), 0, cos(origin.orbit))
            cameraPan = origin.pan
            let vertical = verticalPan ? SIMD3<Float>(0, 1, 0) : forward
            panCamera(right * Float(-translation.width) * amount + vertical * Float(-translation.height) * amount)
        } else {
            cameraOrbit = origin.orbit; cameraPitch = origin.pitch
            rotateCamera(Float(-translation.width) * 0.008, vertical: Float(translation.height) * 0.006)
        }
    }
    func endCameraGesture() { cameraGestureActive = false }
    func cameraKey(_ key: KeyEquivalent, modifiers: EventModifiers) -> Bool {
        guard ready, !backgrounded, !modifiers.contains(.command), !modifiers.contains(.control) else { return false }
        let speed: Float = modifiers.contains(.shift) ? 0.6 : 0.2
        let right = SIMD3<Float>(cos(cameraOrbit), 0, -sin(cameraOrbit))
        let forward = SIMD3<Float>(sin(cameraOrbit), 0, cos(cameraOrbit))
        switch key {
        case .leftArrow: rotateCamera(-0.08)
        case .rightArrow: rotateCamera(0.08)
        case .upArrow: rotateCamera(0, vertical: 0.06)
        case .downArrow: rotateCamera(0, vertical: -0.06)
        case "a": panCamera(-right * speed)
        case "d": panCamera(right * speed)
        case "w": panCamera(-forward * speed)
        case "s": panCamera(forward * speed)
        case "q": panCamera([0, -speed, 0])
        case "e": panCamera([0, speed, 0])
        case "-": zoomCamera(1.08)
        case "+", "=": zoomCamera(1 / 1.08)
        case "0": showOverview()
        case "[": rotateCamera(-0.08)
        case "]": rotateCamera(0.08)
        default: return false
        }
        return true
    }
    var cameraDescription: String {
        "Camera angle \(Int(cameraOrbit * 180 / .pi)) degrees, elevation \(Int(cameraPitch * 180 / .pi)) degrees, zoom \(Int(100 / cameraZoom)) percent, position \(String(format: "%.1f, %.1f, %.1f", cameraPan.x, cameraPan.y, cameraPan.z))."
    }
    func updateCamera() {
        guard let camera else { return }
        if continuousGallery && (inCare || !searchQuery.isEmpty) {
            var target: SIMD3<Float> = [0, inCare ? 1.15 : 0.8, 2.7] + cameraPan
            let fit = max(1, 0.62 / max(0.25, viewportAspect))
            let radius: Float = (inCare ? 4.8 : 9.8) * cameraZoom * fit
            if !inCare { target.y -= (1 - min(1, max(0.25, visibleStageFraction))) * radius * tan(Float.pi * 42 / 360) }
            let pitch = min(1.4, max(0.17, (inCare ? 0.22 : 0.40) + cameraPitch))
            let offset: SIMD3<Float> = [sin(cameraOrbit) * radius * cos(pitch), radius * sin(pitch), cos(cameraOrbit) * radius * cos(pitch)]
            camera.look(at: target, from: target + offset, relativeTo: nil); return
        }
        let overview = focusArea == nil && !followSelected
        let target2 = followSelected ? simulation.agents[selected].position : (focusArea?.center ?? SIMD2<Float>(0, -0.25))
        let target: SIMD3<Float> = [target2.x, overview ? 0.10 : 0.50, target2.y] + cameraPan
        let fit = overview ? max(1.25, 1.45 / max(0.35, viewportAspect)) : 1
        let distance = (overview ? world.radius * 1.68 : 5.9) * cameraZoom * fit
        let height = (overview ? world.radius * 1.15 : 4.1) * cameraZoom * fit
        let radius = hypot(distance, height)
        let pitch = min(1.40, max(0.17, atan2(height, distance) + cameraPitch))
        let offset: SIMD3<Float> = [sin(cameraOrbit) * radius * cos(pitch), radius * sin(pitch), cos(cameraOrbit) * radius * cos(pitch)]
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
        if !shouldAnimate { cancelContact(); if continuousGallery { presentation.advance(dt: 0, natural: naturalPoses, immediate: true); applyLayout() } }
        for member in members {
            let c = member.controller
            c.paused = paused || reviewingControls; c.staticMode = still; c.systemReduceMotion = reduceMotion
            c.backgrounded = backgrounded; c.lowPower = lowPower; c.soundEnabled = sounds && !listening; c.listening = listening
            c.refreshStillPose()
        }
        updateDance(); writeProbe()
    }
    func setDanceMode(_ mode: FonsterDanceMode) {
        takeOwnerControl(); danceMode = mode; danceScene?.clearCelebrations()
        for (i, member) in members.enumerated() {
            if mode == .daylight { if member.controller.dancingContinuously { member.controller.stopActivity() } }
            else if !inCare || i == selected {
                member.controller.perform(.play, name: member.name, learn: false, audible: false)
                member.controller.dancingContinuously = true
            }
        }
        updateDance(); writeProbe()
    }
    func celebrate(balloons: Bool) { guard shouldAnimate, danceMode != .daylight else { return }; takeOwnerControl(); danceScene?.celebrate(balloons: balloons, time: activeSeconds) }
    func updateDance() {
        let target = containers.indices.contains(selected) ? containers[selected].position : SIMD3<Float>(0, 0.6, 2.7)
        danceScene?.apply(danceMode, time: activeSeconds, moving: shouldAnimate, target: target)
    }
    func spoken(_ action: CreatureSpokenAction) {
        guard ready, !paused, !backgrounded, !lowPower, !reviewingControls else { return }
        switch action {
        case .wave: perform(.greet); case .dance: if danceMode == .daylight { setDanceMode(.spotlight) }; perform(.play); selectedMember.controller.dancingContinuously = true
        case .sleep: perform(.rest); case .jump: perform(.hop); case .blink: perform(.blink)
        case .spin: perform(.spin); case .stretch: perform(.stretch)
        case .stop: setDanceMode(.daylight); stopActivity()
        }
    }
    func perform(_ action: PlayroomController.Reaction, actor: Int? = nil) {
        let index = actor ?? selected
        guard members.indices.contains(index) else { return }
        if continuousGallery && inCare {
            ownerActed(); members[index].controller.perform(action, name: members[index].name, learn: !members[index].isVisitor)
            message = members[index].controller.message
        } else {
            interruptPair(); ownerActed(); dispatch(simulation.act(action.rawValue, actor: index), deliberate: true)
        }
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
        if !continuousGallery || !presentation.borrowingStage { agent.advance(lobby: self, now: now); presence.advance(lobby: self, now: now) }
        let held = members.firstIndex { $0.id == contactID && $0.controller.touching }
        let events = continuousGallery && presentation.borrowingStage ? [] : simulation.step(dt: dt, wander: wander, heldActor: held)
        if !events.isEmpty && danceMode == .daylight { dispatch(events, deliberate: false) }
        if continuousGallery { presentation.sideDistance = max(1.5, min(5.5, viewportAspect * 3.3)); presentation.advance(dt: dt, natural: naturalPoses) }
        for (i, member) in members.enumerated() {
            member.controller.worldWalking = continuousGallery && presentation.borrowingStage ? presentation.transitioning && presentation.caringFor != i : simulation.agents[i].walking
            if !continuousGallery || !inCare || presentation.transitioning || i == selected { member.controller.advance(dt: dt) }
        }
        LobbyWorldScene.animate(fountainDrops, time: Float(activeSeconds))
        updateDance()
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
    private func ownerActed() { cancelContact(); userRevision += 1; agent.takeOver(lobby: self); presence.ownerTookOver() }
    func beginContact(at point: CGPoint, size: CGSize) -> Bool {
        guard ready, !paused, !backgrounded, !lowPower, !reviewingControls, let camera,
              let ray = CreatureRig.touchRay(at: point, size: size, camera: camera) else { return false }
        let hits = members.enumerated().compactMap { index, member -> (Int, CreatureRig.TouchHit)? in
            guard !continuousGallery || !inCare || index == selected else { return nil }
            if let hit = member.controller.rig?.touchHit(origin: ray.origin, direction: ray.direction) { return (index, hit) }
            if !member.descriptor.supported, containers.indices.contains(index) {
                let container = containers[index], inverse = container.transformMatrix(relativeTo: nil).inverse
                let o = inverse * SIMD4<Float>(ray.origin, 1), d = inverse * SIMD4<Float>(ray.direction, 0)
                guard abs(d.z) > 0.001 else { return nil }
                let t = -o.z / d.z, point = o + d * t
                if t > 0, abs(point.x) <= 0.95, abs(point.y) <= 0.95 { return (index, .init(distance: t, point: [point.x, point.y], zone: .cheek)) }
            }
            return nil
        }
        guard let (index, hit) = hits.min(by: { $0.1.distance < $1.1.distance }) else { return false }
        if continuousGallery && !inCare { openCare(index); return true }
        if !continuousGallery { interruptPair() }
        if selected != index { selected = index } else { ownerActed() }
        if !continuousGallery || !inCare { simulation.stopAgentMotion(actor: index) }
        let member = members[index]
        guard member.controller.beginTouch(hit.sample(at: ProcessInfo.processInfo.systemUptime)) else { return false }
        contactID = member.id; message = member.controller.message
        return true
    }
    func moveContact(at point: CGPoint, size: CGSize) {
        guard let id = contactID, let member = members.first(where: { $0.id == id }),
              !paused, !backgrounded, !lowPower, !reviewingControls, let camera,
              let ray = CreatureRig.touchRay(at: point, size: size, camera: camera),
              let hit = member.controller.rig?.touchHit(origin: ray.origin, direction: ray.direction) else { endContact(); return }
        member.controller.moveTouch(hit.sample(at: ProcessInfo.processInfo.systemUptime))
        message = member.controller.message
    }
    func endContact() {
        guard let id = contactID, let member = members.first(where: { $0.id == id }) else { cancelContact(); return }
        member.controller.endTouch(); message = member.controller.message; contactID = nil
    }
    func cancelContact() {
        for member in members where member.controller.touching { member.controller.cancelTouch() }
        contactID = nil
    }
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
            social.setFeeling(feeling, for: careIdentity(for: members[actor])); simulation.setFeeling(feeling, actor: actor); members[actor].controller.setFeeling(feeling)
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
        let natural = naturalPoses
        for (i, container) in containers.enumerated() where simulation.agents.indices.contains(i) {
            let pose = continuousGallery && presentation.poses.indices.contains(i) ? presentation.poses[i] : natural[i]
            container.position = pose.position; container.scale = .init(repeating: pose.scale)
            container.orientation = simd_quatf(angle: pose.heading, axis: [0, 1, 0])
        }
        ball?.isEnabled = !inCare
        ball?.position = simulation.ballPosition
        updateCamera()
    }
    private func writeProbe() {
        let args = ProcessInfo.processInfo.arguments
        let probePath: String
        if let i = args.firstIndex(of: "--lobby-probe-file"), i + 1 < args.count { probePath = args[i + 1] }
        else if args.contains("--world-camera-diagnostics") { probePath = NSTemporaryDirectory() + "fonsters-world-camera.json" }
        else { return }
        let state: [String: Any] = ["frames": frames, "animating": shouldAnimate, "paused": paused,
            "roomRevision": roomRevision, "care": inCare, "query": searchQuery, "matches": searchMatches.map { names[$0] }, "selectedName": selectedMember.name, "rendererReady": ready, "rendererError": error ?? "",
            "still": still, "reduceMotion": reduceMotion, "background": backgrounded, "lowPower": lowPower,
            "worldRadius": world.radius, "worldAreas": world.areas.map(\.rawValue), "focusArea": focusArea?.rawValue ?? "overview",
            "walking": simulation.agents.map(\.walking), "seated": simulation.agents.map(\.seated),
            "cameraPosition": camera.map { [Double($0.position.x), Double($0.position.y), Double($0.position.z)] } ?? [],
            "viewportAspect": viewportAspect, "cameraAttached": camera?.scene != nil,
            "sceneCameras": sceneCameraDetails,
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
            try? data.write(to: URL(fileURLWithPath: probePath), options: .atomic)
        }
    }
}
#endif
