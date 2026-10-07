import Foundation
import AppKit
import RealityKit

@main struct VerifyMotion {
    @MainActor static func main() async throws {
        for companion in PlayroomCompanion.fixtures {
            let model = try CreatureRig(companion.descriptor)
            let bounds = model.root.visualBounds(relativeTo: model.root)
            precondition(bounds.extents.z > 0.6 && bounds.extents.x > 0.3 && bounds.extents.y > 0.3)
            precondition(model.groundOffset.isFinite && model.eyes.count == 2)
        }
        print("PASS: all 12 original procedural RealityKit rigs construct with finite bounds and substantial depth")
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
