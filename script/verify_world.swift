import Foundation
import SwiftUI
import RealityKit
import simd

@main struct VerifyWorld {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        let stream = LobbyWorldStream()
        stream.update(center: .zero)
        let homeNames = Set(stream.root.children.map(\.name))
        precondition(homeNames.count == 9)
        for step in 0..<100 { stream.update(center: [Float(step) * 97, 0, Float(step) * -51]); precondition(stream.root.children.count == 9) }
        stream.update(center: .zero)
        precondition(Set(stream.root.children.map(\.name)) == homeNames)
        print("PASS: 100 streamed neighborhoods retain nine tiles; Home regenerates the same deterministic terrain")
        let mapData = try Data(contentsOf: URL(fileURLWithPath: "Fonsters/Playroom/Resources/MappedWorldDemo.json"))
        let map = try LobbyMappedWorld.load(data: mapData)
        stream.mappedWorld = map
        var rendered: Set<String> = []
        for feature in map.features {
            let p = map.center(feature); stream.update(center: [p.x, 0, p.y])
            precondition(stream.root.children.count == 9)
            for tile in stream.root.children { for entity in tile.children where entity.name.hasPrefix("osm:") { rendered.insert(entity.name) } }
        }
        precondition(rendered.count == 52, "Every mapped object must render in its visible neighborhood")
        stream.mappedWorld = nil; stream.update(center: .zero)
        precondition(stream.root.children.count == 9 && Set(stream.root.children.map(\.name)) == homeNames)
        print("PASS: actual RealityKit geometry renders all 52 mapped objects with nine-tile bounds; generated home restores without mapped leftovers")
        if CommandLine.arguments.contains("--camera-only") {
            let lobby = LocalLobbyController(), camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 42; lobby.camera = camera
            let tangent = tan(Float.pi * 42 / 360)
            for aspect: Float in [0.6, 0.9, 1.5, 2.8] {
                lobby.viewportAspect = aspect; lobby.showOverview()
                for i in 0..<128 {
                    let a = Float(i) / 128 * 2 * Float.pi
                    let point: SIMD3<Float> = [sin(a) * lobby.world.radius, 0, cos(a) * lobby.world.radius]
                    let local = camera.convert(position: point, from: nil)
                    precondition(local.z < 0)
                    precondition(abs(local.x / -local.z / tangent / aspect) < 1)
                    precondition(abs(local.y / -local.z / tangent) < 1)
                }
            }
            print("PASS: complete playable terrain fits portrait phone, tablet, Mac and TV overview cameras")
            lobby.ready = true; lobby.lowPower = false
            lobby.reviewingControls = true
            let modalView = lobby.controls
            precondition(!lobby.cameraKey("w", modifiers: [], held: true))
            precondition(!lobby.cameraKey(.leftArrow, modifiers: []))
            precondition(!lobby.cameraNavigationActive && lobby.controls == modalView)
            lobby.reviewingControls = false
            for key: KeyEquivalent in [.leftArrow, .rightArrow, .upArrow, .downArrow, "a", "d", "w", "s", "q", "e", "+", "-"] {
                lobby.showOverview(); let before = camera.transform
                precondition(lobby.cameraKey(key, modifiers: []))
                precondition(camera.transform != before, "camera key did not navigate")
                precondition([camera.position.x, camera.position.y, camera.position.z].allSatisfy(\.isFinite))
            }
            lobby.showOverview(); let before = lobby.controls
            lobby.beginCameraGesture(); lobby.dragCamera(CGSize(width: 100, height: 80), pan: false)
            precondition(lobby.cameraOrbit != before.orbit && lobby.cameraPitch != before.pitch)
            lobby.endCameraGesture(); var history = FonsterControlHistory<LocalLobbyController.ControlState>()
            history.record(old: before, new: lobby.controls); lobby.restoreControls(history.undo()!)
            precondition(lobby.controls == before && !history.canUndo)
            lobby.beginCameraGesture(); lobby.dragCamera(CGSize(width: 100, height: 80), pan: true); lobby.endCameraGesture()
            precondition(lobby.cameraPan.x != 0 && lobby.cameraPan.z != 0)
            lobby.showOverview(); lobby.beginCameraGesture()
            lobby.dragCamera(CGSize(width: 40, height: -80), pan: true, verticalPan: true); lobby.endCameraGesture()
            precondition(lobby.cameraPan.x != 0 && lobby.cameraPan.y > 0 && lobby.cameraPan.z == 0)
            for _ in 0..<1000 {
                lobby.rotateCamera(20, vertical: 20); lobby.panCamera([100, 100, -100]); lobby.zoomCamera(0.5)
            }
            precondition(lobby.cameraZoom == 0.45 && lobby.cameraPitch == 0.80)
            precondition([camera.position.x, camera.position.y, camera.position.z].allSatisfy(\.isFinite))
            let bounded = lobby.controls
            lobby.rotateCamera(.nan, vertical: .infinity); lobby.panCamera([.nan, 0, 0]); lobby.zoomCamera(.nan)
            precondition(lobby.controls == bounded)
            precondition(!lobby.cameraKey("w", modifiers: .command) && lobby.controls == bounded)
            lobby.showOverview(); precondition(lobby.cameraPan == .zero && lobby.cameraPitch == 0 && lobby.cameraOrbit == 0 && lobby.cameraZoom == 1)
            lobby.perform(.rest); lobby.stopActivity()
            precondition(lobby.simulation.agents.allSatisfy { $0.reaction == "idle" && $0.remaining == 0 && !$0.walking && $0.route.isEmpty && !$0.seated })
            precondition(lobby.members.allSatisfy { $0.controller.reaction == .idle })
            for _ in 0..<90 { lobby.advance(dt: 1.0 / 30) }
            precondition(lobby.simulation.agents.allSatisfy { $0.reaction == "idle" && !$0.walking })
            print("PASS: Stop clears held rests, walks and games without an immediate autonomous restart")
            lobby.backgrounded = true; precondition(!lobby.cameraKey("w", modifiers: []))
            print("PASS: twelve keyboard directions, horizontal/vertical orbit, planar drag, vertical translation, whole-gesture Undo, reset and extreme/invalid input bounds")
            lobby.backgrounded = false; lobby.continuousGallery = true; lobby.ready = true; lobby.lowPower = false
            lobby.search(""); let revision = lobby.roomRevision
            let memberIDs = lobby.members.map(\.id), appearances = lobby.members.map(\.descriptor)
            let originalPositions = lobby.simulation.agents.map(\.position), originalGoals = lobby.simulation.agents.map(\.goal)
            lobby.search("Moss"); precondition(lobby.searchMatches.map { lobby.names[$0] } == ["Moss"])
            for _ in 0..<30 { lobby.advance(dt: 1.0 / 30) }
            lobby.openCare(lobby.searchMatches[0])
            for _ in 0..<30 { lobby.advance(dt: 1.0 / 30) }
            for _ in 0..<100 { lobby.perform(.play); lobby.perform(.rest) }
            precondition(lobby.inCare && lobby.roomRevision == revision)
            precondition(lobby.simulation.agents.map(\.position) == originalPositions && lobby.simulation.agents.map(\.goal) == originalGoals)
            lobby.returnToLobby(); lobby.search("")
            for _ in 0..<29 { lobby.advance(dt: 1.0 / 30) }
            precondition(!lobby.inCare && lobby.members.map(\.id) == memberIDs && lobby.members.map(\.descriptor) == appearances)
            precondition(lobby.simulation.agents.map(\.position) == originalPositions)
            lobby.reduceMotion = true; lobby.refreshGates(); lobby.openCare(0)
            precondition(lobby.presentation.poses[0].scale == 0.93 && !lobby.presentation.transitioning)
            lobby.returnToLobby(); precondition(lobby.presentation.poses == lobby.naturalPoses)
            lobby.reduceMotion = false; lobby.wander = false; lobby.refreshGates(); lobby.openCare(0)
            let focusControls = lobby.controls, positionsBeforeExploration = lobby.simulation.agents.map(\.position)
            precondition(!lobby.walk(to: [0, 2]), "solo care must not silently queue a hidden walk")
            lobby.toggleExploration()
            precondition(lobby.exploring && lobby.inCare && lobby.followSelected)
            for _ in 0..<300 { lobby.advance(dt: 1.0 / 30) }
            precondition(!lobby.presentation.borrowingStage)
            let origin = lobby.simulation.agents[lobby.selected].position
            precondition(lobby.walk(to: [0, 2.7]))
            let accepted = lobby.simulation.agents[lobby.selected].goal
            precondition(lobby.walkDestination == accepted)
            for invalid in [SIMD2<Float>(10000, 0), [.nan, 0], lobby.world.trees[0], [0, -1.65]] {
                let goal = lobby.simulation.agents[lobby.selected].goal
                precondition(!lobby.walk(to: invalid))
                precondition(lobby.simulation.agents[lobby.selected].goal == goal)
            }
            for _ in 0..<120 {
                lobby.advance(dt: 1.0 / 30)
                precondition(lobby.world.walkable(lobby.simulation.agents[lobby.selected].position, clearance: 0.43))
            }
            precondition(simd_distance(lobby.simulation.agents[lobby.selected].position, origin) > 0.1)
            precondition(simd_distance(lobby.simulation.agents[lobby.selected].position, accepted) < simd_distance(origin, accepted))
            for gate in 0..<4 {
                lobby.paused = gate == 0; lobby.backgrounded = gate == 1; lobby.lowPower = gate == 2; lobby.reviewingControls = gate == 3
                precondition(!lobby.walk(to: [0, 2.3]))
            }
            lobby.paused = false; lobby.backgrounded = false; lobby.lowPower = false; lobby.reviewingControls = false
            lobby.reduceMotion = true; lobby.refreshGates()
            precondition(lobby.walk(to: [0, 2.7]))
            precondition(lobby.simulation.agents[lobby.selected].route.isEmpty && lobby.walkDestination == nil)
            lobby.restoreControls(focusControls)
            precondition(lobby.inCare && !lobby.exploring && lobby.presentation.poses[lobby.selected].scale == 0.93)
            lobby.returnToLobby(); lobby.search("")
            precondition(lobby.members.map(\.id) == memberIDs && lobby.members.map(\.descriptor) == appearances)
            precondition(lobby.simulation.agents.dropFirst().map(\.position) == Array(positionsBeforeExploration.dropFirst()))
            print("PASS: exploration unfreezes routed walking; bounds/obstacles/invalid taps preserve accepted goals; motion gates reject walks; Reduce Motion places statically; care Undo and other companions are preserved")
            let savedID = UUID(); lobby.showSaved([.init(id: savedID, name: "My Moss", seed: "little-fonster-138")])
            let publicID = lobby.selectedMember.id
            lobby.perform(.greet); lobby.chooseFeeling(.cozy)
            let learned = lobby.selectedMember.controller.personality!
            precondition(learned.hellos == 1)
            precondition(publicID != savedID && lobby.selectedSavedID == savedID)
            lobby.ready = true; lobby.openCare(0)
            let sameRoom = lobby.roomRevision, sameController = lobby.selectedMember.controller
            let learnedBeforeRename = sameController.personality
            let samePositions = lobby.simulation.agents.map(\.position), sameGoals = lobby.simulation.agents.map(\.goal)
            lobby.showSaved([.init(id: savedID, name: "My Moss renamed", seed: "little-fonster-138", biography: .init(background: "A tiny moon traveler.", likes: ["Comets"]))])
            precondition(lobby.selectedMember.id == publicID && lobby.selectedMember.name == "My Moss renamed")
            precondition(lobby.roomRevision == sameRoom && lobby.selectedMember.controller === sameController && lobby.inCare)
            precondition(lobby.simulation.agents.map(\.position) == samePositions && lobby.simulation.agents.map(\.goal) == sameGoals)
            precondition(lobby.selectedMember.controller.personality == learnedBeforeRename && lobby.selectedMember.controller.feeling == .cozy)
            precondition(lobby.selectedBiography.likes == ["Comets"])
            let included = lobby.card(for: lobby.selectedMember, includeFeeling: false, includeBiography: true)
            precondition(included.biography == nil && included.interests == nil && included.version == 1)
            let includedBytes = try included.encoded()
            precondition(!String(data: includedBytes, encoding: .utf8)!.contains("A tiny moon traveler."))
            let updatedLearned = lobby.selectedMember.controller.personality!
            lobby.showSaved([.init(id: savedID, name: "My Moss renamed", seed: "little-fonster-233")])
            precondition(lobby.selectedMember.id != publicID && lobby.selectedMember.controller.personality == updatedLearned && lobby.selectedMember.controller.feeling == .cozy)
            lobby.showSaved([.init(id: savedID, name: "My Moss renamed", seed: "little-fonster-138")])
            precondition(lobby.selectedMember.id == publicID && lobby.selectedMember.controller.personality == updatedLearned && lobby.selectedMember.controller.feeling == .cozy)
            let card = try lobby.card(for: lobby.selectedMember, includeFeeling: false).encoded()
            let text = String(data: card, encoding: .utf8)!
            precondition(!text.contains(savedID.uuidString) && !text.contains("little-fonster-138"))
            print("PASS: same scene revision, IDs and descriptors through search/care/back; routes and positions held across 200 care reactions; immediate Reduce Motion; saved-record reconciliation uses stable random public IDs and keeps private IDs/seeds out of exports; renaming and appearance changes preserve learned care memory while appearance public identities remain stable")
            return
        }
        let fixtures = PlayroomCompanion.fixtures
        var lastRadius: Float = 0
        var routes = 0
        for count in 2...12 {
            let world = LobbyWorld(population: count)
            precondition(world.radius >= lastRadius); lastRadius = world.radius
            precondition(world.areas.allSatisfy { $0.population <= count })
            for i in 0..<count {
                let home = world.home(i)
                precondition(world.walkable(home), "unwalkable spawn \(count)/\(i)")
                for area in world.areas {
                    let goal = world.destination(in: area, slot: i)
                    let path = world.route(from: home, to: goal)
                    precondition(!path.isEmpty, "missing route \(count)/\(i)/\(area)")
                    var start = home
                    for point in path { precondition(world.segmentClear(start, point)); start = point }
                    precondition(simd_distance(start, goal) < 0.001); routes += 1
                }
            }
        }
        print("PASS: populations 2–12 grow monotonically; \(routes) routes reach every unlocked area with swept obstacle clearance")
        if !CommandLine.arguments.contains("--skip-endurance") {
        for count in [4, 8, 12] {
            var sim = LocalLobbySimulation(names: Array(fixtures.prefix(count)).map(\.name))
            let initial = sim.agents.map(\.position)
            var expressions = Set<String>()
            for _ in 0..<9000 {
                expressions.formUnion(sim.step(dt: 1.0 / 30, wander: true).map(\.action))
                for i in sim.agents.indices {
                    precondition(sim.world.walkable(sim.agents[i].position))
                    for j in sim.agents.indices where j > i { precondition(simd_distance(sim.agents[i].position, sim.agents[j].position) >= 0.899) }
                }
            }
            precondition(initial != sim.agents.map(\.position))
            precondition(sim.agents.reduce(0) { $0 + $1.discoveries } > 0, "Exploration should lead to a visible discovery reaction")
            precondition(expressions.contains("stretch") && expressions.contains("greet"))
            print("PASS: \(count) companions discover \(sim.agents.map { $0.exploredAreas.count }) areas with reactions \(expressions.sorted())")
            _ = sim.act("rest", actor: 0); let rest = sim.agents[0].position
            for _ in 0..<1000 { _ = sim.step(dt: 1.0 / 30, wander: true) }
            precondition(sim.agents[0].position == rest)
        }
        print("PASS: 27,000 autonomous world steps keep 4/8/12 companions separated, inside the world and outside scenery; rest stays put")
        }
        let corner = LobbyWorld(population: 12)
        let before: SIMD2<Float> = [-5.96, 1.70], after: SIMD2<Float> = [-5.66, 1.95]
        precondition(corner.walkable(before) && corner.walkable(after) && !corner.segmentClear(before, after))
        print("PASS: a thin picnic-area corner crossing between otherwise clear endpoints is rejected")
        var traveler = LocalLobbySimulation(names: ["Coral", "Moss"], population: 12)
        for area in traveler.world.areas {
            traveler.travel(to: area, actor: 0)
            let destination = traveler.agents[0].goal
            print("CHECK: traveling to \(area) from \(traveler.agents[0].position), path \(traveler.agents[0].route)")
            for _ in 0..<1800 { _ = traveler.step(dt: 1.0 / 30, wander: false) }
            precondition(simd_distance(traveler.agents[0].position, destination) < 0.08, "didn't arrive at \(area): \(traveler.agents[0].position), goal \(destination)")
        }
        traveler.sit(actor: 0)
        for _ in 0..<1500 { _ = traveler.step(dt: 1.0 / 30, wander: false) }
        precondition(traveler.agents[0].seated && traveler.agents[0].reaction == "rest")
        traveler.walk(to: [0, 1.6], actor: 0)
        precondition(!traveler.agents[0].seated && !traveler.agents[0].seatRequested)
        traveler.travel(to: .park, actor: 0, peer: 1, instant: true)
        precondition(traveler.agents.allSatisfy { $0.route.isEmpty && traveler.world.walkable($0.position) })
        precondition(simd_distance(traveler.agents[0].position, traveler.agents[1].position) >= 0.90)
        print("PASS: deliberate walking reaches all five areas; bench rest arrives, can be interrupted, and static navigation stays separated")
        var protected = LocalLobbySimulation(names: ["Coral", "Moss"], population: 12)
        protected.travel(to: .park, actor: 0)
        let requested = protected.agents[0].goal
        for _ in 0..<600 {
            _ = protected.step(dt: 1.0 / 30, wander: true)
            precondition(protected.agents[0].goal == requested && protected.agents[0].reaction == "idle")
        }
        protected.sit(actor: 0); protected.freezeGoals(); _ = protected.step(dt: 1.0 / 30, wander: false)
        precondition(!protected.agents[0].seatRequested && !protected.agents[0].seated)
        print("PASS: deliberate travel keeps priority over autonomous greetings; stopping a bench approach doesn't seat a creature on the path")
        let archive = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("preserved-world.json")
        let invalid = Data("{\"version\":99,\"names\":[\"future\"]}".utf8)
        let actualArchive = archive.appendingPathExtension("world.json")
        try invalid.write(to: actualArchive)
        var memory = LobbyWorldMemory(arguments: ["test", "--personality-file", archive.path])
        memory.enroll("Tide")
        let preserved = try Data(contentsOf: actualArchive)
        precondition(preserved == invalid)
        precondition(memory.temporaryReason != nil)
        print("PASS: newer world archives are preserved, temporary enrollment is explicit and no records are deleted")
        let lobby = LocalLobbyController(); lobby.lowPower = false
        let original = lobby.members.map(\.id)
        while let next = lobby.availableCompanions.first { lobby.addCompanion(next) }
        precondition(lobby.members.count == 12 && lobby.world.areas.count == 5)
        precondition(Array(lobby.members.prefix(4).map(\.id)) == original)
        let rebuilt = LocalLobbyController()
        precondition(rebuilt.members.map(\.name) == lobby.members.map(\.name))
        precondition(rebuilt.members.map(\.id) == lobby.members.map(\.id))
        print("PASS: adding gallery companions persists membership and stable random public identities; reopening retains the neighborhood")
        let guestFixture = fixtures[3]
        let guest = FonsterVisitCard(publicID: UUID(), name: guestFixture.name, appearance: guestFixture.descriptor, warmth: 0.5, energy: 0.5)
        try lobby.invite(guest)
        precondition(Set(lobby.names).count == lobby.names.count && lobby.members[3].name == "Visitor")
        lobby.endVisit()
        precondition(lobby.members[3].name == "Orbit" && lobby.members.count == 12)
        print("PASS: a guest in the expanded world keeps a unique command alias and ending the visit restores Orbit without shrinking membership")
        let scene = try LobbyWorldScene.make(lobby.world)
        let bounds = scene.root.visualBounds(relativeTo: scene.root)
        precondition(bounds.extents.x.isFinite && scene.fountainDrops.count == 16)
        let camera = PerspectiveCamera(); camera.camera.fieldOfViewInDegrees = 42; lobby.camera = camera
        for member in lobby.members {
            let rig = try CreatureRig(member.descriptor, furDetail: .world)
            precondition(rig.furStrands < 6000 && rig.mouth != nil)
            member.controller.install(rig, name: member.name)
            let container = Entity(); container.addChild(rig.root); lobby.containers.append(container)
        }
        lobby.fountainDrops = scene.fountainDrops; lobby.ready = true; lobby.refreshGates(); lobby.applyLayout()
        for area in lobby.world.areas { lobby.explore(area); for _ in 0..<20 { lobby.advance(dt: 1.0 / 30) } }
        for _ in 0..<100 { lobby.walk(to: [-1, 2]); lobby.pair(quiet: false); lobby.explore(.park) }
        precondition(lobby.simulation.pairGame == nil)
        let learning = lobby.members.map { $0.controller.personality!.interactionCount }
        for gate in ["pause", "still", "reduceMotion", "background", "lowPower"] {
            lobby.paused = gate == "pause"; lobby.still = gate == "still"; lobby.reduceMotion = gate == "reduceMotion"
            lobby.backgrounded = gate == "background"; lobby.lowPower = gate == "lowPower"; lobby.refreshGates()
            let positions = lobby.simulation.agents.map(\.position), drops = scene.fountainDrops.map(\.position), cam = camera.transform, frames = lobby.frames
            for _ in 0..<90 { lobby.advance(dt: 1.0 / 30) }
            precondition(lobby.frames == frames && lobby.simulation.agents.map(\.position) == positions)
            precondition(scene.fountainDrops.map(\.position) == drops && camera.transform == cam)
            if gate == "still" || gate == "reduceMotion" {
                lobby.explore(.garden)
                precondition(lobby.simulation.agents[lobby.selected].route.isEmpty)
            }
        }
        lobby.paused = false; lobby.still = false; lobby.reduceMotion = false; lobby.backgrounded = false; lobby.lowPower = false
        lobby.refreshGates(); lobby.advance(dt: 1.0 / 30)
        precondition(lobby.shouldAnimate && lobby.members.map { $0.controller.personality!.interactionCount } == learning)
        lobby.cameraZoom = 1; lobby.showOverview()
        lobby.walk(at: CGPoint(x: 640, y: 450), size: CGSize(width: 1280, height: 900))
        precondition(lobby.simulation.world.walkable(lobby.simulation.agents[lobby.selected].goal))
        for _ in 0..<100 { lobby.zoomCamera(0.5); lobby.rotateCamera(0.3) }
        precondition(lobby.cameraZoom == 0.45 && camera.position.x.isFinite)
        for _ in 0..<100 { lobby.zoomCamera(2) }
        precondition(lobby.cameraZoom == 2.5)
        print("PASS: actual 12 native furry rigs and world scenery construct; 100 replacement interactions, camera controls, all five motion gates and resume preserve geometry and learning")
        print("PASS: native ray-to-ground navigation and bounded camera zoom accept finite destinations")
    }
}
