import Foundation
import RealityKit
import AppKit

@main struct RenderAllModels {
    @MainActor static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var selected: [String: CreatureAppearanceDescriptor] = [:]
        for i in 0..<1000 {
            let appearance = CreatureAppearanceDescriptor.resolve(seed: "little-fonster-\(i)")
            if let volume = appearance.volume, selected[volume.family] == nil { selected[volume.family] = appearance }
        }
        selected["articulated"] = PlayroomCompanion.fixtures[0].descriptor
        for (name, appearance) in selected.sorted(by: { $0.key < $1.key }) {
            let rig = try CreatureRig(appearance, furDetail: .lobby)
            let bounds = rig.root.visualBounds(relativeTo: rig.root)
            for (label, angle) in [("front", Float(0)), ("side", Float.pi/2), ("back", Float.pi)] {
                let camera = PerspectiveCamera(); camera.name = "preview-camera"
                camera.camera.fieldOfViewInDegrees = 40
                camera.look(at: bounds.center, from: bounds.center + [sin(angle)*4.4,0.3,cos(angle)*4.4], relativeTo: nil)
                let light = try await CreatureSceneLighting.studio(for: [rig.root])
                try await NativeSceneExport.capture([camera,rig.root,light], width: 900, height: 720, to: directory.appendingPathComponent(name+"-"+label+".png"))
            }
            print("Rendered \(name): front/side/back")
        }
    }
}
