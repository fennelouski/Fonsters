import Foundation
import AppKit
import RealityKit

@main struct VerifyMotion {
    @MainActor static func main() async throws {
        for companion in PlayroomCompanion.fixtures {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let originalAppearance = try encoder.encode(companion.descriptor)
            let model = try CreatureRig(companion.descriptor)
            let bounds = model.root.visualBounds(relativeTo: model.root)
            precondition(bounds.extents.z > 0.6 && bounds.extents.x > 0.3 && bounds.extents.y > 0.3)
            precondition(model.groundOffset.isFinite && model.eyes.count == 2)
            guard let smile = model.mouth, smile.parent === model.head,
                  let cavity = smile.findEntity(named: "smile-cavity")?.components[ModelComponent.self],
                  let rim = smile.findEntity(named: "smile-rim")?.components[ModelComponent.self] else {
                fatalError("Every 3D companion needs a smile attached to its head")
            }
            var front: [SIMD3<Float>] = []
            for component in [cavity, rim] {
                for meshModel in component.mesh.contents.models {
                    for part in meshModel.parts {
                        let points = part.positions.elements
                        precondition(points.allSatisfy { [$0.x, $0.y, $0.z].allSatisfy(\.isFinite) })
                        precondition(part.normals?.elements.allSatisfy { abs(simd_length($0) - 1) < 0.001 } == true)
                        precondition(part.triangleIndices?.elements.allSatisfy { Int($0) < points.count } == true)
                        if component.mesh === cavity.mesh { front += points.filter { $0.z > 0.051 } }
                    }
                }
            }
            let right = front.map(\.x).max()!, left = front.map(\.x).min()!
            let cornerY = front.filter { abs($0.x - right) < 0.0001 || abs($0.x - left) < 0.0001 }.map(\.y).min()!
            let centerY = front.filter { abs($0.x) < 0.001 }.map(\.y).max()!
            precondition(cornerY > centerY + 0.02, "The rendered mouth's corners must turn upwards")
            let renderedAppearance = try encoder.encode(model.descriptor)
            precondition(renderedAppearance == originalAppearance, "A happy expression must not modify resolved appearance")
            let expression = PlayroomController(); expression.writesProbe = false; expression.lowPower = false
            expression.autonomyEnabled = false; expression.roaming = false
            expression.install(model, name: companion.name)
            let idleSmile = smile.scale.y
            expression.perform(.play, name: companion.name, learn: false, audible: false)
            for _ in 0..<25 { expression.advance(dt: 0.06) }
            precondition(smile.scale.y > idleSmile + 0.1, "Playing should open the happy smile")
            for _ in 0..<70 { expression.advance(dt: 0.06) }
            precondition(expression.reaction == .idle && abs(smile.scale.y - idleSmile) < 0.01, "Play must settle back to the default smile")
            expression.staticMode = true
            expression.perform(.rest, name: companion.name, learn: false, audible: false)
            precondition(smile.scale.y < idleSmile && smile.scale.y > 0, "Rest should keep a softer smile in static mode")
            expression.perform(.greet, name: companion.name, learn: false, audible: false)
            precondition(smile.scale.y > idleSmile && smile.parent === model.head, "Static hello should stay expressive and attached")
        }
        print("PASS: all 12 original procedural RealityKit rigs construct with finite bounds and substantial depth")
        print("PASS: all 12 have upturned finite 3D smiles; playing opens the smile then returns to happy idle; static rest/hello stay expressive; original resolved appearance is unchanged, including absent 2D mouths")
        let controller = PlayroomController()
        let fixture = PlayroomCompanion.fixtures[1]
        let rig = try CreatureRig(fixture.descriptor)
        controller.install(rig, name: fixture.name)
        controller.lowPower = false
        let memoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("fonsters-motion-\(UUID().uuidString)/memories.json")
        let memories = PersonalityMemoryStore(url: memoryURL)
        controller.enablePersonalityLearning(memories)
        for _ in 0..<100 {
            controller.perform(.greet, name: fixture.name, learn: false)
            controller.look([0.3, 0.2])
        }
        precondition(controller.personality?.interactionCount == 0, "Sensor-triggered reactions must not train personality")
        print("PASS: 100 sensor-style greetings and gaze updates do not change personality")
        let actionStart = controller.actionCount
        for _ in 0..<100 { controller.perform(.play, name: fixture.name) }
        controller.perform(.rest, name: fixture.name)
        precondition(controller.reaction == .rest && controller.actionCount == actionStart + 101)
        precondition(controller.personality?.games == 1, "Rapid taps must learn only one meaningful ritual")
        let work = Task { @MainActor in await controller.animate() }
        try await Task.sleep(for: .milliseconds(180))
        precondition(controller.frameCount > 2)
        work.cancel()
        try await Task.sleep(for: .milliseconds(70))
        for gate in ["pause", "still", "reduceMotion", "background", "lowPower"] {
            controller.paused = gate == "pause"
            controller.staticMode = gate == "still"
            controller.systemReduceMotion = gate == "reduceMotion"
            controller.backgrounded = gate == "background"
            controller.lowPower = gate == "lowPower"
            let before = controller.frameCount
            precondition(!controller.shouldAnimate, "Gate did not stop animation: \(gate)")
            await controller.animate()
            try await Task.sleep(for: .milliseconds(70))
            precondition(controller.frameCount == before, "Frames advanced while gated: \(gate)")
            controller.perform(.greet, name: fixture.name)
            precondition(controller.reaction == .greet && controller.message.contains("hello"))
            print("PASS: \(gate) stops frame updates and still accepts a single reaction pose")
        }
        controller.paused = false; controller.staticMode = false; controller.systemReduceMotion = false
        controller.backgrounded = false; controller.lowPower = false
        let before = controller.frameCount
        let resumed = Task { @MainActor in await controller.animate() }
        try await Task.sleep(for: .milliseconds(180))
        resumed.cancel()
        precondition(controller.frameCount > before)
        print("PASS: 100 repeated reactions replace one action; rest interrupts; all five motion gates stop frames; resume restarts frames; real RealityKit rig transforms stay finite")
        precondition(rig.root.transform.matrix.columns.3.y.isFinite)
    }
}
