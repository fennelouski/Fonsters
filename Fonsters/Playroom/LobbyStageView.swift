#if os(macOS) || os(iOS) || os(tvOS)
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import RealityKit
#if os(iOS)
import Combine
#endif

@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
struct LobbyStageView: View {
    let lobby: LocalLobbyController
    @State private var sceneEntities: [Entity] = []
    @State private var readySubscription: EventSubscription?
    @State private var gestureStarted = false
    @State private var creatureCaptured = false
    @State private var panning = false
    @State private var verticalPanning = false
    @GestureState private var gestureActive = false
    var body: some View {
        let cameraState = lobby.controls
        GeometryReader { geometry in
            platformStage(size: geometry.size, cameraState: cameraState)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Explorable Fonster world with " + lobby.names.joined(separator: ", ")))
                .accessibilityValue(lobby.message + " " + lobby.motionStatus + " " + lobby.cameraDescription)
                #if os(tvOS)
                .accessibilityHint("Use the area, companion and camera buttons to explore. Friendship buttons let the selected Fonster greet and play.")
                #else
                .accessibilityHint("Stroke a Fonster, tap a path to walk, or drag empty space horizontally or vertically to orbit. Shift-drag pans on Mac; pinch zooms on touch screens. Arrow keys orbit, W A S D pan, Q E move up and down, plus and minus zoom, and zero resets the view. Camera icons offer the same navigation.")
                #endif
                .accessibilityAction(named: "Wave to a friend") { lobby.waveToFriend() }
                .accessibilityAction(named: "Play together") { lobby.playTogether() }
                .accessibilityAction(named: "Pass ball with chosen friend") { lobby.pair(quiet: false) }
                .accessibilityAction(named: "Sit with chosen friend") { lobby.pair(quiet: true) }
        }
        .overlay {
            if !lobby.ready && lobby.error == nil {
                ProgressView().accessibilityLabel("Opening the Fonster world").allowsHitTesting(false)
            }
        }
        .onDisappear { readySubscription?.cancel(); readySubscription = nil }
    }
    @ViewBuilder private func platformStage(size: CGSize, cameraState: LocalLobbyController.ControlState) -> some View {
        #if os(tvOS)
        scene(size: size, cameraState: cameraState).allowsHitTesting(false)
        #else
        interactiveStage(size: size, cameraState: cameraState)
        #endif
    }
    #if !os(tvOS)
    private func interactiveStage(size: CGSize, cameraState: LocalLobbyController.ControlState) -> some View {
        scene(size: size, cameraState: cameraState)
            #if os(macOS)
            .background(VerificationSceneMarker(entities: sceneEntities, cornerRadius: 0))
            #endif
            .onContinuousHover { phase in
                if case .active(let point) = phase {
                    lobby.selectedMember.controller.look([Float(point.x / size.width - 0.5) * 2, Float(0.5 - point.y / size.height) * 2])
                }
            }
            .overlay { Rectangle().fill(.clear).contentShape(Rectangle()).gesture(contactGesture(size: size)) }
            .simultaneousGesture(MagnifyGesture().onChanged { value in
                if !lobby.cameraGestureActive { lobby.beginCameraGesture() }
                if let origin = lobby.cameraGestureOrigin { lobby.cameraZoom = min(2.5, max(0.45, origin.zoom / Float(value.magnification))); lobby.updateCamera() }
            }.onEnded { _ in lobby.endCameraGesture() })
            .onChange(of: gestureActive) { _, active in
                if !active && gestureStarted { lobby.cancelContact(); lobby.endCameraGesture(); lobby.dragOrbit = nil; gestureStarted = false; creatureCaptured = false }
            }
            .onChange(of: size, initial: true) { _, newSize in
                lobby.viewportHeight = Float(newSize.height)
                lobby.viewportAspect = Float(newSize.width / max(1, newSize.height)); lobby.updateCamera()
            }
            .onDisappear { lobby.cancelContact(); lobby.endCameraGesture() }
    }
    private func contactGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($gestureActive) { _, active, _ in active = true }
            .onChanged { changed($0, size: size) }
            .onEnded { ended($0, size: size) }
    }
    private func changed(_ value: DragGesture.Value, size: CGSize) {
        if !gestureStarted {
            gestureStarted = true
            #if os(macOS)
            panning = NSEvent.modifierFlags.contains(.shift)
            verticalPanning = panning && NSEvent.modifierFlags.contains(.option)
            let forceCamera = panning || NSEvent.modifierFlags.contains(.option)
            #else
            panning = false
            let forceCamera = false
            #endif
            creatureCaptured = !forceCamera && lobby.beginContact(at: value.startLocation, size: size)
            if !creatureCaptured { lobby.beginCameraGesture() }
        } else if creatureCaptured { lobby.moveContact(at: value.location, size: size) }
        if !creatureCaptured && hypot(value.translation.width, value.translation.height) > 6 {
            lobby.dragCamera(value.translation, pan: panning, verticalPan: verticalPanning)
        }
    }
    private func ended(_ value: DragGesture.Value, size: CGSize) {
        if creatureCaptured { lobby.endContact() }
        else if hypot(value.translation.width, value.translation.height) <= 6 { lobby.walk(at: value.location, size: size) }
        lobby.endCameraGesture(); lobby.dragOrbit = nil; gestureStarted = false; creatureCaptured = false
    }
    #endif
    @ViewBuilder private func scene(size: CGSize, cameraState: LocalLobbyController.ControlState) -> some View {
        #if os(iOS)
        NativeLobbyStage(lobby: lobby, size: size, cameraState: cameraState)
        #else
        RealityView { content in
                content.camera = .virtual
                do {
                    let revision = lobby.roomRevision
                    lobby.viewportAspect = Float(size.width / max(1, size.height))
                    let roots = try await LobbySceneAssembly.make(lobby)
                    guard !Task.isCancelled, lobby.roomRevision == revision else { return }
                    for entity in roots { content.add(entity) }
                    sceneEntities = roots
                    // Construction can finish before RealityView mounts its scene,
                    // particularly when reopening a cached environment. Enable
                    // interactions only after the native scene receives an update.
                    readySubscription?.cancel()
                    readySubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                        Task { @MainActor [weak lobby] in
                            guard let lobby, lobby.roomRevision == revision, !lobby.ready else { return }
                            LobbySceneAssembly.recordCameras(event.scene, lobby: lobby)
                            lobby.updateCamera(); lobby.ready = true; lobby.refreshGates()
                            readySubscription?.cancel(); readySubscription = nil
                        }
                    }
                    #if os(macOS)
                    NativeSceneExport.verificationTask(entities: Array(content.entities), label: "lobby")
                    #endif
                } catch { lobby.error = "Couldn’t open this little room: \(error.localizedDescription)"; lobby.refreshGates() }
            } update: { content in
                content.camera = .virtual
                lobby.updateCamera()
            }
        #endif
    }

}

/// The same authored entities, materials, rigs and camera serve both native
/// hosts. Assemble before attachment so a partial scene cannot become ready.
@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
@MainActor private enum LobbySceneAssembly {
    static func make(_ lobby: LocalLobbyController) async throws -> [Entity] {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 42
        camera.camera.near = 0.05; camera.camera.far = 1000
        camera.name = "preview-camera"; lobby.camera = camera; lobby.updateCamera()
        var roots: [Entity] = [camera]
        lobby.containers = []
        for member in lobby.members {
            let container = Entity(); container.scale = .init(repeating: 0.55)
            if member.descriptor.supported {
                let rig = try CreatureRig(member.descriptor, furDetail: lobby.members.count > 6 ? .world : .lobby)
                member.controller.install(rig, name: member.name); member.controller.orbit = 0
                container.addChild(rig.root)
            } else if let seed = member.localCompanion?.seed, let image = creatureImage(for: seed) {
                // Unsupported families retain their exact legacy portrait rather
                // than inventing a different 3D silhouette.
                let texture = try await TextureResource(image: image, options: .init(semantic: .color))
                var material = UnlitMaterial(); material.color = .init(tint: .white, texture: .init(texture))
                material.blending = .transparent(opacity: .init(floatLiteral: 1))
                let portrait = ModelEntity(mesh: .generatePlane(width: 1.9, height: 1.9), materials: [material])
                container.addChild(portrait)
            }
            roots.append(container); lobby.containers.append(container)
        }
        let neighborhood = try LobbyWorldScene.make(lobby.world)
        roots.append(neighborhood.root); lobby.fountainDrops = neighborhood.fountainDrops
        let ball = ModelEntity(mesh: .generateSphere(radius: 0.14), materials: [SimpleMaterial(color: FonsterPlatformColor(srgbRed: 0.96, green: 0.62, blue: 0.42, alpha: 1), roughness: 0.4, isMetallic: false)])
        lobby.ball = ball; roots.append(ball)
        let key = DirectionalLight(); key.light.intensity = 2400
        key.light.color = FonsterPlatformColor(srgbRed: 1, green: 0.9, blue: 0.8, alpha: 1)
        key.look(at: [0, 0, 0], from: [-3, 5, 4], relativeTo: nil)
        key.shadow = .init(maximumDistance: 30, depthBias: 1); roots.append(key)
        let fill = PointLight(); fill.light.intensity = 11000; fill.light.attenuationRadius = 20
        fill.light.color = FonsterPlatformColor(srgbRed: 0.88, green: 0.91, blue: 1, alpha: 1)
        fill.position = [0, 2, 4]; roots.append(fill)
        roots.append(try await CreatureSceneLighting.studio(for: roots))
        lobby.applyLayout()
        return roots
    }
    static func recordCameras(_ scene: RealityKit.Scene, lobby: LocalLobbyController) {
        let query = EntityQuery(where: .has(PerspectiveCameraComponent.self))
        lobby.sceneCameraDetails = scene.performQuery(query).map {
            "\($0.name) at \($0.position), FOV \($0.components[PerspectiveCameraComponent.self]?.fieldOfViewInDegrees ?? 0)"
        }
    }
}

#if os(iOS)
/// An explicit non-AR RealityKit host gives the phone world a stable authored
/// camera through full-screen presentation and environment restoration.
/// SwiftUI owns the HUD, gestures, keyboard handlers and lifecycle gates.
@available(iOS 18.0, *)
private struct NativeLobbyStage: UIViewRepresentable {
    let lobby: LocalLobbyController
    let size: CGSize
    // Explicit value input keeps native view updates active for deliberate
    // camera navigation while the shared simulation clock is held.
    let cameraState: LocalLobbyController.ControlState
    @MainActor final class Coordinator {
        var buildTask: Task<Void, Never>?
        var readySubscription: (any Cancellable)?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.init(srgbRed: 0.91, green: 0.94, blue: 0.87, alpha: 1))
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        let coordinator = context.coordinator, revision = lobby.roomRevision
        lobby.viewportAspect = Float(size.width / max(1, size.height))
        coordinator.buildTask = Task { @MainActor [weak view, weak lobby] in
            guard let view, let lobby else { return }
            do {
                let roots = try await LobbySceneAssembly.make(lobby)
                guard !Task.isCancelled, lobby.roomRevision == revision else { return }
                let anchor = AnchorEntity(world: .zero)
                for entity in roots { anchor.addChild(entity) }
                view.scene.addAnchor(anchor)
                coordinator.readySubscription = view.scene.subscribe(to: SceneEvents.Update.self) { event in
                    Task { @MainActor [weak lobby, weak coordinator] in
                        guard let lobby, let coordinator, lobby.roomRevision == revision, !lobby.ready else { return }
                        LobbySceneAssembly.recordCameras(event.scene, lobby: lobby)
                        lobby.updateCamera(); lobby.ready = true; lobby.refreshGates()
                        coordinator.readySubscription?.cancel(); coordinator.readySubscription = nil
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                lobby.error = "Couldn’t open this little room: \(error.localizedDescription)"
                lobby.refreshGates()
            }
        }
        return view
    }
    func updateUIView(_ view: ARView, context: Context) {
        lobby.viewportAspect = Float(size.width / max(1, size.height)); lobby.updateCamera()
        view.setNeedsDisplay()
        if ProcessInfo.processInfo.arguments.contains("--world-camera-diagnostics") {
            let authored = lobby.camera?.transformMatrix(relativeTo: nil) ?? matrix_identity_float4x4
            let actual = view.cameraTransform.matrix
            func columns(_ matrix: simd_float4x4) -> [[Float]] {
                (0..<4).map { [matrix[$0].x, matrix[$0].y, matrix[$0].z, matrix[$0].w] }
            }
            let cameras = view.scene.performQuery(EntityQuery(where: .has(PerspectiveCameraComponent.self))).map {
                ["name": $0.name, "matchesController": $0 == lobby.camera,
                 "position": [$0.position.x, $0.position.y, $0.position.z]] as [String: Any]
            }
            let diagnostic: [String: Any] = ["authored": columns(authored), "active": columns(actual), "cameras": cameras]
            if let data = try? JSONSerialization.data(withJSONObject: diagnostic, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("fonsters-native-camera.json"), options: .atomic)
            }
        }
    }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.buildTask?.cancel(); coordinator.readySubscription?.cancel()
        view.scene.anchors.removeAll()
    }
}
#endif
#endif
