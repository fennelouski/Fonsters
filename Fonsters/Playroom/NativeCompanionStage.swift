#if os(macOS) || os(iOS)
import SwiftUI
import RealityKit
#if os(iOS)
import UIKit
import Combine
#endif

/// Identical procedural geometry and lighting in the desktop and phone hosts.
@available(macOS 15.0, iOS 18.0, *)
@MainActor enum CompanionSceneAssembly {
    struct Result {
        let rig: CreatureRig
        let entities: [Entity]
    }
    static func make(companion: PlayroomCompanion, controller: PlayroomController) async throws -> Result {
        let rig = try CreatureRig(companion.descriptor)
        controller.install(rig, name: companion.name); controller.rendererReady = false
        let camera = PerspectiveCamera()
        camera.name = "preview-camera"; camera.camera.fieldOfViewInDegrees = 33
        camera.camera.near = 0.05; camera.camera.far = 1000
        camera.look(at: [0, -0.12, 0], from: [0, 0.55, 5.15], relativeTo: nil)
        controller.touchCamera = camera
        var entities: [Entity] = [camera, rig.root]
        let key = DirectionalLight()
        key.light.intensity = 2400; key.light.color = FonsterPlatformColor(srgbRed: 1, green: 0.88, blue: 0.75, alpha: 1)
        key.look(at: [0, 0, 0], from: [-2, 4, 3], relativeTo: nil)
        key.shadow = .init(maximumDistance: 8, depthBias: 1); entities.append(key)
        let fill = PointLight()
        fill.light.intensity = 950; fill.light.attenuationRadius = 8
        fill.light.color = FonsterPlatformColor(srgbRed: 0.71, green: 0.81, blue: 1, alpha: 1)
        fill.position = [2, 1.5, 2]; entities.append(fill)
        let rim = PointLight()
        rim.light.intensity = 1200; rim.light.attenuationRadius = 8; rim.position = [-1, 2, -2]; entities.append(rim)
        entities.append(CompanionEnvironmentScene.make(controller.environment))
        let ball = ModelEntity(mesh: .generateSphere(radius: 0.13), materials: [SimpleMaterial(color: FonsterPlatformColor(srgbRed: 0.96, green: 0.62, blue: 0.42, alpha: 1), roughness: 0.45, isMetallic: false)])
        ball.name = "little-play-ball"; ball.position = [0.68, -0.93, 0.32]; entities.append(ball); controller.toyBall = ball
        entities.append(try await CreatureSceneLighting.studio(for: entities))
        return .init(rig: rig, entities: entities)
    }
}

#if os(iOS)
/// The companion and world both use explicit non-AR phone views. SwiftUI owns
/// interaction and lifecycle; this host never runs an AR camera session.
@available(iOS 18.0, *)
struct NativeCompanionStage: UIViewRepresentable {
    let companion: PlayroomCompanion
    let controller: PlayroomController
    let controls: PlayroomController.ControlState
    var onSceneReady: (([Entity]) -> Void)?
    @MainActor final class Coordinator {
        var buildTask: Task<Void, Never>?
        var readySubscription: (any Cancellable)?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(srgbRed: 0.97, green: 0.95, blue: 0.90, alpha: 1))
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        let coordinator = context.coordinator
        coordinator.buildTask = Task { @MainActor [weak view, weak controller] in
            guard let view, let controller else { return }
            do {
                let scene = try await CompanionSceneAssembly.make(companion: companion, controller: controller)
                guard !Task.isCancelled, controller.rig === scene.rig else { return }
                let anchor = AnchorEntity(world: .zero)
                for entity in scene.entities { anchor.addChild(entity) }
                view.scene.addAnchor(anchor)
                coordinator.readySubscription = view.scene.subscribe(to: SceneEvents.Update.self) { _ in
                    Task { @MainActor [weak controller, weak coordinator] in
                        guard let controller, let coordinator, controller.rig === scene.rig, !controller.rendererReady else { return }
                        controller.rendererReady = true; controller.refreshStillPose()
                        onSceneReady?(scene.entities)
                        coordinator.readySubscription?.cancel(); coordinator.readySubscription = nil
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                controller.rendererError = error.localizedDescription
            }
        }
        return view
    }
    func updateUIView(_ view: ARView, context: Context) { view.setNeedsDisplay() }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.buildTask?.cancel(); coordinator.readySubscription?.cancel(); view.scene.anchors.removeAll()
    }
}
#endif
#endif
