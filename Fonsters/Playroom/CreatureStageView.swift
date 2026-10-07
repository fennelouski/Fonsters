#if os(macOS)
import SwiftUI
import RealityKit
import AppKit

@available(macOS 15.0, *)
struct CreatureStageView: View {
    let companion: PlayroomCompanion
    let controller: PlayroomController

    var body: some View {
        GeometryReader { geometry in
            RealityView { content in
                do {
                    let rig = try CreatureRig(companion.descriptor)
                    controller.install(rig, name: companion.name)
                    content.add(rig.root)
                    let camera = PerspectiveCamera()
                    camera.camera.fieldOfViewInDegrees = 33
                    camera.look(at: [0, -0.12, 0], from: [0, 0.55, 5.15], relativeTo: nil)
                    content.add(camera)
                    content.camera = .virtual
                    let key = DirectionalLight()
                    key.light.intensity = 2400
                    key.light.color = NSColor(srgbRed: 1, green: 0.88, blue: 0.75, alpha: 1)
                    key.look(at: [0, 0, 0], from: [-2, 4, 3], relativeTo: nil)
                    key.shadow = .init(maximumDistance: 8, depthBias: 1)
                    content.add(key)
                    let fill = PointLight()
                    fill.light.intensity = 950
                    fill.light.attenuationRadius = 8
                    fill.light.color = NSColor(srgbRed: 0.71, green: 0.81, blue: 1, alpha: 1)
                    fill.position = [2, 1.5, 2]
                    content.add(fill)
                    let rim = PointLight()
                    rim.light.intensity = 1200; rim.light.attenuationRadius = 8
                    rim.position = [-1, 2, -2]
                    content.add(rim)
                    let platform = ModelEntity(mesh: .generateCylinder(height: 0.14, radius: 1.19),
                                               materials: [SimpleMaterial(color: NSColor(srgbRed: 0.90, green: 0.85, blue: 0.91, alpha: 1), roughness: 0.85, isMetallic: false)])
                    platform.position = [0, -1.16, 0]
                    content.add(platform)

                } catch {
                    controller.rendererError = error.localizedDescription
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): controller.look([Float(p.x / geometry.size.width - 0.5) * 2, Float(0.5 - p.y / geometry.size.height) * 2])
                case .ended: controller.look(.zero)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { controller.perform(.greet, name: companion.name) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(companion.name), a three dimensional Fonster")
            .accessibilityValue(controller.message)
            .accessibilityHint("Use the Say hello, Play, Rest, and Blink buttons below. Drag the Turn slider to see every side.")
            .accessibilityAction(named: "Say hello") { controller.perform(.greet, name: companion.name) }
            .accessibilityAction(named: "Play") { controller.perform(.play, name: companion.name) }
        }
    }
}
#endif
