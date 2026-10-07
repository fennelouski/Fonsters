#if os(macOS)
import SwiftUI
import RealityKit
import AppKit

@available(macOS 15.0, *)
struct CreatureStageView: View {
    let companion: PlayroomCompanion
    let controller: PlayroomController
    var onSceneReady: (([Entity]) -> Void)? = nil
    @State private var contactStarted = false
    @State private var contactCaptured = false
    @GestureState private var gestureActive = false
    @State private var touchEntities: [Entity] = []

    var body: some View {
        GeometryReader { geometry in
            interactiveStage(size: geometry.size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(companion.name), a fluffy three dimensional Fonster")
            .accessibilityValue(controller.message)
            .accessibilityHint("Stroke the fuzzy head gently, hold for a cuddle, or touch a paw for a high five. Quick strokes are playful. The same reactions are available as buttons. Drag the Turn slider to see every side.")
            .accessibilityAction(named: "Say hello") { controller.perform(.greet, name: companion.name) }
            .accessibilityAction(named: "Play") { controller.perform(.play, name: companion.name) }
            .accessibilityAction(named: "Gentle rub") { controller.perform(.rub, name: companion.name) }
            .accessibilityAction(named: "High five") { controller.perform(.highFive, name: companion.name) }
        }
    }

    private func interactiveStage(size: CGSize) -> some View {
        scene
            .background(VerificationSceneMarker(entities: touchEntities))
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): controller.look([Float(p.x / size.width - 0.5) * 2, Float(0.5 - p.y / size.height) * 2])
                case .ended: controller.look(.zero)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).updating($gestureActive) { _, active, _ in active = true }
                .onChanged { value in
                    if !contactStarted {
                        contactStarted = true
                        contactCaptured = controller.beginTouch(at: value.startLocation, size: size)
                    } else if contactCaptured { controller.moveTouch(at: value.location, size: size) }
                }.onEnded { _ in
                    if contactCaptured { controller.endTouch() }
                    contactStarted = false; contactCaptured = false
                })
            .onChange(of: gestureActive) { _, active in
                if !active && contactStarted { controller.cancelTouch(); contactStarted = false; contactCaptured = false }
            }
            .onDisappear { controller.cancelTouch(); controller.touchCamera = nil }
            .overlay { TouchGestureVerification(controller: controller, entities: touchEntities).allowsHitTesting(false) }
    }

    private var scene: some View {
        RealityView { content in
                do {
                    let rig = try CreatureRig(companion.descriptor)
                    controller.install(rig, name: companion.name)
                    content.add(rig.root)
                    let camera = PerspectiveCamera()
                    camera.name = "preview-camera"
                    camera.camera.fieldOfViewInDegrees = 33
                    camera.look(at: [0, -0.12, 0], from: [0, 0.55, 5.15], relativeTo: nil)
                    controller.touchCamera = camera
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
                    touchEntities = Array(content.entities)
                    onSceneReady?(Array(content.entities))
                    NativeSceneExport.verificationTask(entities: Array(content.entities), label: "solo")

                } catch {
                    controller.rendererError = error.localizedDescription
                }
            }
    }
}
#endif
