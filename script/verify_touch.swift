import Foundation
import RealityKit
import simd

@main struct VerifyTouch {
    static func sample(_ x: Float, _ y: Float, _ t: Double, _ zone: CreatureTouchDynamics.Zone = .crown) -> CreatureTouchDynamics.Sample {
        .init(point: [x, y], zone: zone, time: t)
    }
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        var soft = CreatureTouchDynamics()
        precondition(soft.begin(sample(-0.3, 0.65, 0)))
        for i in 1...60 { soft.move(sample(-0.3 + Float(i) * 0.006, 0.65, Double(i) / 60)) }
        precondition(soft.response.manner == .softStroke && soft.response.eyes < 0.6 && soft.response.nod < -0.1)
        var quick = CreatureTouchDynamics(); _ = quick.begin(sample(-0.5, 0.5, 0))
        for i in 1...12 { quick.move(sample(-0.5 + Float(i) * 0.07, 0.5, Double(i) / 60)) }
        precondition(quick.response.manner == .lively && quick.response.energy > 0.7 && quick.response.lift > 0)
        var held = CreatureTouchDynamics(); _ = held.begin(sample(0.1, 0.5, 0))
        for i in 1...30 { held.hold(at: Double(i) / 30) }
        precondition(held.response.manner == .cuddle)
        for hz in [30, 120] {
            var verySlow = CreatureTouchDynamics(); _ = verySlow.begin(sample(-0.2, 0.5, 0))
            for i in 1...(hz * 4) { verySlow.move(sample(-0.2 + Float(i) / Float(hz * 4) * 0.48, 0.5, Double(i) / Double(hz))) }
            precondition(verySlow.response.manner == .softStroke, "Very slow movement is still a stroke at either input rate, rather than stationary cuddling")
        }
        var belly = CreatureTouchDynamics(); _ = belly.begin(sample(-0.2, -0.7, 0, .belly))
        for i in 1...80 { belly.move(sample(sin(Float(i) * 0.3) * 0.25, -0.7, Double(i) / 60, .belly)) }
        precondition(belly.response.manner == .tickle && belly.reversals >= 2 && belly.response.smile > 1.2)
        _ = belly.end(at: 80.0 / 60)
        for _ in 0..<60 { belly.settle(dt: 1 / 30) }
        precondition(abs(belly.response.lean) < 0.0001 && belly.response.lift < 0.0001 && abs(belly.response.eyes - 0.94) < 0.0001)
        for (zone, manner) in [(CreatureTouchDynamics.Zone.eye, .blink), (.paw, .highFive)] as [(CreatureTouchDynamics.Zone, CreatureTouchDynamics.Manner)] {
            var model = CreatureTouchDynamics(); _ = model.begin(sample(0, 0, 0, zone))
            precondition(model.response.manner == manner)
        }
        print("PASS: slow strokes relax the eyes and lean; quick swipes give a cheerful recoil; held contact cuddles; reversing belly strokes tickle; eyes blink and paws high-five; release settles")

        func stroke(hz: Int) -> CreatureTouchDynamics.Response {
            var model = CreatureTouchDynamics(); _ = model.begin(sample(-0.3, 0.5, 0))
            for i in 1...hz { model.move(sample(-0.3 + Float(i) / Float(hz) * 0.5, 0.5, Double(i) / Double(hz))) }
            return model.response
        }
        let a = stroke(hz: 30), b = stroke(hz: 120)
        precondition(a.manner == b.manner && abs(a.energy - b.energy) < 0.03 && abs(a.lean - b.lean) < 0.005)
        var hostile = CreatureTouchDynamics()
        precondition(!hostile.begin(sample(.nan, 0, 0)))
        _ = hostile.begin(sample(0, 0, 1)); hostile.move(sample(.infinity, 0, 1.01))
        precondition(hostile.active && hostile.response.energy == 0)
        hostile.move(sample(1, 1, 0.99)); precondition(hostile.response.energy == 0)
        hostile.move(sample(1, 1, 2)); precondition(!hostile.active)
        var maximum = CreatureTouchDynamics(); _ = maximum.begin(sample(0, 0, 0), warmth: .nan, playEnergy: .infinity)
        for i in 1...10_000 {
            maximum.move(sample(i % 2 == 0 ? 100 : -100, -100, Double(i) * 0.01, .belly))
            let r = maximum.response
            precondition(r.energy >= 0 && r.energy <= 1 && abs(r.lean) <= 0.18 && abs(r.squash) < 0.08 && r.lift <= 0.1)
        }
        precondition(maximum.reversals <= 32)
        print("PASS: equivalent 30/120 Hz strokes agree; 10,000 extreme samples stay finite/bounded; invalid time/coordinates are ignored and a delivery gap cancels rather than catching up")

        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        for fixture in PlayroomCompanion.fixtures {
            let before = try encoder.encode(fixture.descriptor)
            let map = CreatureTouchMap(seed: fixture.seed)
            for pixel in fixture.descriptor.silhouette {
                precondition(map.sample(x: (Double(pixel.x) + 0.5) / 32, y: (Double(pixel.y) + 0.5) / 32, time: 0) != nil)
            }
            for y in 0..<32 { for x in 0..<32 where !fixture.descriptor.silhouette.contains(.init(x: x, y: y)) {
                precondition(map.sample(x: (Double(x) + 0.5) / 32, y: (Double(y) + 0.5) / 32, time: 0) == nil)
            } }
            let rig = try CreatureRig(fixture.descriptor, furDetail: .world)
            for eye in rig.eyes {
                let center = eye.position(relativeTo: nil)
                precondition(rig.touchHit(origin: center + [0, 0, 5], direction: [0, 0, -1])?.zone == .eye)
            }
            precondition(rig.touchHit(origin: [9, 9, 6], direction: [0, 0, -1]) == nil)
            let parent = Entity(); parent.scale = [0.55, 0.55, 0.55]; parent.position = [3, 1, -2]
            parent.orientation = simd_quatf(angle: 0.7, axis: [0, 1, 0]); parent.addChild(rig.root)
            let eye = rig.eyes[0], center = eye.position(relativeTo: nil)
            let direction = parent.orientation.act(SIMD3<Float>(0, 0, -1))
            precondition(rig.touchHit(origin: center - direction * 5, direction: direction)?.zone == .eye)
            let after = try encoder.encode(rig.descriptor)
            precondition(after == before)
        }
        print("PASS: all 12 clipped 2D hit masks match resolved silhouettes; native eye volumes follow lobby scale/rotation; empty-space rays miss; resolved appearance remains byte-identical")

        let fixture = PlayroomCompanion.fixtures[0], rig = try CreatureRig(fixture.descriptor)
        let controller = PlayroomController(); controller.writesProbe = false; controller.lowPower = false
        controller.install(rig, name: fixture.name); controller.roaming = false
        let archive = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("touch-memory.json")
        controller.enablePersonalityLearning(.init(url: archive))
        for _ in 0..<100 {
            let now = ProcessInfo.processInfo.systemUptime
            controller.perform(.spin, name: fixture.name, learn: false, audible: false)
            precondition(controller.beginTouch(sample(0, 0.5, now)))
            precondition(controller.reaction == .idle && controller.touching)
            controller.endTouch(at: now + 0.01)
        }
        precondition(controller.personality?.interactionCount == 0)
        let now = ProcessInfo.processInfo.systemUptime
        precondition(controller.beginTouch(sample(-0.3, 0.65, now)))
        for i in 1...60 { controller.moveTouch(sample(-0.3 + Float(i) * 0.006, 0.65, now + Double(i) / 60)) }
        precondition(controller.personality?.interactionCount == 0)
        controller.endTouch(at: now + 1)
        precondition(controller.personality?.interactionCount == 1)
        for gate in ["pause", "still", "reduce", "background", "lowPower"] {
            controller.paused = false; controller.staticMode = false; controller.systemReduceMotion = false; controller.backgrounded = false; controller.lowPower = false
            precondition(controller.beginTouch(sample(0.1, 0.5, ProcessInfo.processInfo.systemUptime)))
            switch gate {
            case "pause": controller.paused = true
            case "still": controller.staticMode = true
            case "reduce": controller.systemReduceMotion = true
            case "background": controller.backgrounded = true
            default: controller.lowPower = true
            }
            controller.refreshStillPose()
            let frames = controller.frameCount
            await controller.animate()
            precondition(!controller.touching && controller.frameCount == frames)
        }
        print("PASS: 100 contacts immediately interrupt spin without a queue or learning; samples never train memory; one completed meaningful stroke learns once; five motion gates cancel contact and hold frames")

        var simulation = LocalLobbySimulation(names: Array(PlayroomCompanion.fixtures.prefix(4)).map(\.name))
        simulation.stopAgentMotion(actor: 0)
        let position = simulation.agents[0].position
        for _ in 0..<1000 {
            let events = simulation.step(dt: 1 / 30, wander: true, heldActor: 0)
            precondition(simulation.agents[0].position == position && !events.contains { $0.actor == 0 || $0.peer == 0 })
        }
        let lobby = LocalLobbyController(); lobby.lowPower = false; lobby.ready = true
        for member in lobby.members { member.controller.install(try CreatureRig(member.descriptor, furDetail: .world), name: member.name) }
        lobby.containers = lobby.members.enumerated().map { index, member in
            let e = Entity(); e.scale = .init(repeating: 0.55); e.addChild(member.controller.rig!.root); return e
        }
        lobby.applyLayout(); let camera = PerspectiveCamera(); camera.camera.fieldOfViewInDegrees = 42
        lobby.camera = camera; lobby.updateCamera(); lobby.refreshGates()
        let size = CGSize(width: 1000, height: 700)
        let center = lobby.members[0].controller.rig!.head.position(relativeTo: nil)
        let local = camera.convert(position: center, from: nil), tangent = tan(Float(42) * .pi / 360)
        let pixel = CGPoint(x: CGFloat((local.x / (-local.z * tangent * Float(size.width / size.height)) + 1) / 2) * size.width,
                            y: CGFloat((1 - local.y / (-local.z * tangent)) / 2) * size.height)
        try lobby.agent.prepareDemo(lobby: lobby); try lobby.agent.start(lobby: lobby)
        precondition(lobby.beginContact(at: pixel, size: size))
        precondition(!lobby.agent.running && lobby.contactID != nil)
        let orbit = lobby.cameraOrbit
        lobby.moveContact(at: pixel, size: size); precondition(lobby.cameraOrbit == orbit)
        lobby.paused = true; lobby.refreshGates(); precondition(lobby.contactID == nil)
        print("PASS: a held world companion cannot wander or receive autonomous social actions; real lobby ray contact takes over an agent immediately, preserves camera angle, and pause cancels the captured contact")
        print("PASS: responsive-touch verification complete")
    }
}
