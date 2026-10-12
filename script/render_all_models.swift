import Foundation
import RealityKit
import AppKit

@main struct RenderAllModels {
    @MainActor static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var selected: [String: CreatureAppearanceDescriptor] = [:]
        for i in 0..<1500 {
            let appearance = CreatureAppearanceDescriptor.resolve(seed: "little-fonster-\(i)")
            if let volume = appearance.volume {
                let config = resolveConfig(seed:"little-fonster-\(i)")
                let name: String
                if volume.family == "creature" { name = config.complexityTier < 4 ? "low-tier" : (config.upsideDown ? "inverted" : (config.symmetryAxis == .horizontal ? "horizontal" : "asymmetric")) }
                else { name = volume.anatomy!.variant }
                if selected[name] == nil { selected[name] = appearance }
            }
        }
        selected["articulated"] = PlayroomCompanion.fixtures[0].descriptor
        for (name, appearance) in selected.sorted(by: { $0.key < $1.key }) {
            let rig = try CreatureRig(appearance, furDetail: .lobby)
            let bounds = rig.root.visualBounds(relativeTo: rig.root)
            for (label, angle) in [("front", Float(0)), ("side", Float.pi/2), ("back", Float.pi), ("happy", Float(0)), ("sad", Float(0)), ("sleep", Float(0))] {
                let smile: Float = label == "sad" ? -0.65 : (label == "sleep" ? 0.05 : (label == "happy" ? 0.95 : 0.45))
                rig.express(smile:smile,smilingEyes:label == "happy" ? 0.8 : 0,opening:label == "happy" ? 0.6 : 0.05)
                for eye in rig.eyes { eye.scale.y = label == "sleep" ? 0.055 : 1 }
                let camera = PerspectiveCamera(); camera.name = "preview-camera"
                camera.camera.fieldOfViewInDegrees = 40
                camera.look(at: bounds.center, from: bounds.center + [sin(angle)*4.4,0.3,cos(angle)*4.4], relativeTo: nil)
                let light = try await CreatureSceneLighting.studio(for: [rig.root])
                try await NativeSceneExport.capture([camera,rig.root,light], width: 900, height: 720, to: directory.appendingPathComponent(name+"-"+label+".png"))
            }
            print("Rendered \(name): front/side/back/happy/sad/sleep")
        }
    }
}
