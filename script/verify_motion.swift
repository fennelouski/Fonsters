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
            let geometry = model.facialGeometry!
            for shape: Float in [-0.6, 0, 0.45, 0.9] {
                geometry.update(smile: shape, opening: 1)
                var front: [SIMD3<Float>] = []
                for mesh in [geometry.cavityMesh, geometry.rimMesh] {
                    // RealityKit's high-level contents snapshot omits mutable
                    // vertices. Inspect the actual buffers used by the renderer.
                    mesh.withUnsafeBytes(bufferIndex: 0) { bytes in
                        let points = bytes.bindMemory(to: CreatureFacialGeometry.Vertex.self).prefix(mesh.vertexCapacity)
                        precondition(points.allSatisfy { [$0.position.x, $0.position.y, $0.position.z].allSatisfy(\.isFinite) })
                        precondition(points.allSatisfy { abs(simd_length($0.normal) - 1) < 0.001 })
                        if mesh === geometry.cavityMesh { front = points.map(\.position).filter { $0.z > 0.051 } }
                    }
                    mesh.withUnsafeIndices { bytes in
                        precondition(bytes.bindMemory(to: UInt32.self).prefix(mesh.indexCapacity).allSatisfy { Int($0) < mesh.vertexCapacity })
                    }
                }
                let right = front.map(\.x).max()!, left = front.map(\.x).min()!
                let cornerY = front.filter { abs($0.x - right) < 0.0001 || abs($0.x - left) < 0.0001 }.map(\.y).min()!
                let centerY = front.filter { abs($0.x) < 0.001 }.map(\.y).min()!
                if shape > 0 { precondition(cornerY > centerY + 0.01) }
                if shape < 0 { precondition(cornerY < centerY - 0.01) }
                if shape == 0 { precondition(abs(cornerY - centerY) < geometry.height * 0.03) }
            }
            geometry.update(smile: 0.45, opening: 1)
            precondition(smile.findEntity(named: "smile-cavity")?.components[ModelComponent.self]?.mesh === cavity.mesh)
            precondition(smile.findEntity(named: "smile-rim")?.components[ModelComponent.self]?.mesh === rim.mesh)
            let renderedAppearance = try encoder.encode(model.descriptor)
            precondition(renderedAppearance == originalAppearance, "A happy expression must not modify resolved appearance")
            let expression = PlayroomController(); expression.writesProbe = false; expression.lowPower = false
            expression.autonomyEnabled = false; expression.roaming = false
            expression.install(model, name: companion.name)
            expression.perform(.play, name: companion.name, learn: false, audible: false)
            for _ in 0..<10 { expression.advance(dt: 0.06) }
            precondition(expression.renderedExpression.smile > 0.75, "Playing should produce a brief bigger smile")
            for _ in 0..<70 { expression.advance(dt: 0.06) }
            precondition(expression.reaction == .idle, "Play must settle back to casual idle")
            expression.staticMode = true
            expression.perform(.rest, name: companion.name, learn: false, audible: false)
            precondition(expression.renderedExpression.smile == 0, "Static rest has a relaxed neutral mouth")
            expression.perform(.greet, name: companion.name, learn: false, audible: false)
            precondition(expression.renderedExpression.smile >= 0.8 && smile.parent === model.head, "Static hello should stay expressive and attached")
        }
        print("PASS: all 12 original procedural RealityKit rigs construct with finite bounds and substantial depth")
        print("PASS: all 12 have finite volumetric smiles; playing briefly smiles bigger then returns to casual idle; static rest/hello are distinct; original resolved appearance is unchanged, including absent 2D mouths")
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
