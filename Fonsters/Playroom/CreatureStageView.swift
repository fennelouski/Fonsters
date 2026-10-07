#if os(macOS)
import SwiftUI
import RealityKit
import AppKit

@available(macOS 15.0, *)
struct CreatureStageView: View {
    let companion: PlayroomCompanion
    let controller: PlayroomController
    @State private var rubbing = false

    var body: some View {
        GeometryReader { geometry in
            RealityView { content in
                do {
                    let rig = try CreatureRig(companion.descriptor)
                    controller.install(rig, name: companion.name)
                    content.add(rig.root)
                    let camera = PerspectiveCamera()
                    camera.name = "preview-camera"
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
                    let ball = ModelEntity(mesh: .generateSphere(radius: 0.13),
                                           materials: [SimpleMaterial(color: NSColor(srgbRed: 0.96, green: 0.62, blue: 0.42, alpha: 1), roughness: 0.45, isMetallic: false)])
                    ball.name = "little-play-ball"; ball.position = [0.68, -0.93, 0.32]
                    content.add(ball); controller.toyBall = ball
                    content.add(try await CreatureSceneLighting.studio(for: Array(content.entities)))
                    NativeSceneExport.verificationTask(entities: Array(content.entities), label: "solo")

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
            .gesture(TapGesture(count: 2).exclusively(before: TapGesture()).onEnded { tap in
                switch tap {
                case .first: controller.perform(.highFive, name: companion.name)
                case .second: controller.perform(.greet, name: companion.name)
                }
            })
            .simultaneousGesture(DragGesture(minimumDistance: 6).onChanged { value in
                if !rubbing { rubbing = true; controller.perform(.rub, name: companion.name) }
                controller.look([Float(value.location.x / geometry.size.width - 0.5) * 2,
                                 Float(0.5 - value.location.y / geometry.size.height) * 2])
            }.onEnded { _ in rubbing = false })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(companion.name), a three dimensional Fonster")
            .accessibilityValue(controller.message)
            .accessibilityHint("Tap for hello, double tap for a high five, or gently drag for a rub. The same actions are available as buttons. Drag the Turn slider to see every side.")
            .accessibilityAction(named: "Say hello") { controller.perform(.greet, name: companion.name) }
            .accessibilityAction(named: "Play") { controller.perform(.play, name: companion.name) }
            .accessibilityAction(named: "Gentle rub") { controller.perform(.rub, name: companion.name) }
            .accessibilityAction(named: "High five") { controller.perform(.highFive, name: companion.name) }
        }
    }
}
#endif
