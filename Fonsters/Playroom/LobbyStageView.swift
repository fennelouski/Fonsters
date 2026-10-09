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
                .accessibilityValue(lobby.ready ? lobby.message + " " + lobby.motionStatus + " " + lobby.cameraDescription + " " + lobby.explorationStatus : lobby.error ?? "Opening the Fonster world")
                #if os(tvOS)
                .accessibilityHint("Use the area, companion and camera buttons to explore. Friendship buttons let the selected Fonster greet and play.")
                #else
                .accessibilityHint("Stroke a Fonster, tap a path to walk, or drag empty space to pan the world. In solo care, dragging orbits the Fonster. Shift-drag pans on Mac; pinch zooms on touch screens. Arrow keys orbit, W A S D pan, Q E move up and down, plus and minus zoom, and zero resets the view. Camera icons offer the same navigation.")
                #endif
                .accessibilityAction(named: "Explore with this Fonster") { if lobby.inCare && !lobby.exploring { lobby.toggleExploration() } }
                .accessibilityAction(named: "Walk forward") { lobby.walkStep([0, -1]) }
                .accessibilityAction(named: "Walk backward") { lobby.walkStep([0, 1]) }
                .accessibilityAction(named: "Walk left") { lobby.walkStep([-1, 0]) }
                .accessibilityAction(named: "Walk right") { lobby.walkStep([1, 0]) }
                .accessibilityAction(named: "Focus on this Fonster") { lobby.lookAtSelected() }
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
        .task(id: lobby.cameraNavigationActive) { if lobby.cameraNavigationActive { await lobby.animateCameraNavigation() } }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in lobby.clearCameraKeys() }
        #endif
        .onDisappear { lobby.clearCameraKeys(); readySubscription?.cancel(); readySubscription = nil }
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
            panning = lobby.exploring || !lobby.inCare || NSEvent.modifierFlags.contains(.shift)
            verticalPanning = panning && NSEvent.modifierFlags.contains(.option)
            let forceCamera = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.option)
            #else
            panning = lobby.exploring || !lobby.inCare
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
                let revision = lobby.roomRevision
                do {
                    lobby.error = nil
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
                } catch {
                    guard !Task.isCancelled, !(error is CancellationError), lobby.roomRevision == revision else { return }
                    lobby.error = "Couldn’t open this little room: \(error.localizedDescription)"; lobby.refreshGates()
                }
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
        let revision = lobby.roomRevision, members = lobby.members
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 42
        camera.camera.near = 0.05; camera.camera.far = 1000
        camera.name = "preview-camera"; lobby.camera = camera; lobby.updateCamera()
        var roots: [Entity] = [camera]
        lobby.containers = []
        for member in members {
            let container = Entity(); container.scale = .init(repeating: 0.55)
            if member.descriptor.supported {
                let rig = try CreatureRig(member.descriptor, furDetail: lobby.members.count > 6 ? .world : .lobby)
                member.controller.install(rig, name: member.name); member.controller.orbit = 0
                container.addChild(rig.root)
            } else if let seed = member.localCompanion?.seed, let image = creatureImage(for: seed) {
                // Unsupported families retain their exact legacy portrait rather
                // than inventing a different 3D silhouette.
                let texture = try await TextureResource(image: image, options: .init(semantic: .color))
                guard !Task.isCancelled, lobby.roomRevision == revision else { throw CancellationError() }
                var material = UnlitMaterial(); material.color = .init(tint: .white, texture: .init(texture))
                material.blending = .transparent(opacity: .init(floatLiteral: 1))
                let portrait = ModelEntity(mesh: .generatePlane(width: 1.9, height: 1.9), materials: [material])
                container.addChild(portrait)
            }
            roots.append(container); lobby.containers.append(container)
        }
        lobby.mirrorGuestsRoot = Entity(); lobby.mirrorGuests = []
        for i in 0..<3 {
            let container = Entity(); container.scale = .init(repeating: 0.55)
            container.position = [Float(i - 1) * 2.3, 0.594, -1.5 - Float(i % 2)]
            let companion = PlayroomCompanion.fixtures[i + 1]
            let rig = try CreatureRig(companion.descriptor, furDetail: .world)
            let guest = PlayroomController(); guest.autonomyEnabled = false; guest.roaming = false; guest.writesProbe = false; guest.soundEnabled = false
            guest.install(rig, name: "Camera companion"); container.addChild(rig.root)
            container.isEnabled = false; lobby.mirrorGuestsRoot.addChild(container); lobby.mirrorGuests.append(guest)
        }
        roots.append(lobby.mirrorGuestsRoot)
        let stream = LobbyWorldStream(); lobby.streamedWorld = stream
        stream.mappedWorld = lobby.mappedArea
        stream.update(center: lobby.cameraPan); roots.append(stream.root)
        let neighborhood = try LobbyWorldScene.make(lobby.world)
        lobby.generatedScenery = neighborhood.root; neighborhood.root.isEnabled = lobby.mappedArea == nil
        roots.append(neighborhood.root); lobby.fountainDrops = neighborhood.fountainDrops
        var markerMaterial = UnlitMaterial(color: FonsterPlatformColor(srgbRed: 0.30, green: 0.75, blue: 0.58, alpha: 1))
        markerMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.8))
        let marker = ModelEntity(mesh: .generateCylinder(height: 0.015, radius: 0.22), materials: [markerMaterial])
        marker.name = "walking-destination"; marker.isEnabled = false
        lobby.destinationMarker = marker; roots.append(marker)
        let ball = ModelEntity(mesh: .generateSphere(radius: 0.14), materials: [SimpleMaterial(color: FonsterPlatformColor(srgbRed: 0.96, green: 0.62, blue: 0.42, alpha: 1), roughness: 0.4, isMetallic: false)])
        lobby.ball = ball; roots.append(ball)
        let key = DirectionalLight(); key.light.intensity = 2400
        key.light.color = FonsterPlatformColor(srgbRed: 1, green: 0.9, blue: 0.8, alpha: 1)
        key.look(at: [0, 0, 0], from: [-3, 5, 4], relativeTo: nil)
        key.shadow = .init(maximumDistance: 30, depthBias: 1); roots.append(key)
        let fill = PointLight(); fill.light.intensity = 11000; fill.light.attenuationRadius = 20
        fill.light.color = FonsterPlatformColor(srgbRed: 0.88, green: 0.91, blue: 1, alpha: 1)
        fill.position = [0, 2, 4]; roots.append(fill)
        let dance = try LobbyDanceScene(); dance.key = key; dance.fill = fill
        roots.append(dance.root)
        let ambient = try await CreatureSceneLighting.studio(for: roots)
        roots.append(ambient); dance.ambient = ambient
        guard !Task.isCancelled, lobby.roomRevision == revision else { throw CancellationError() }
        lobby.danceScene = dance; lobby.updateDance()
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
        var inCare = false
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LobbyViewport, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? size.width, height: proposal.height ?? size.height)
    }
    func makeUIView(context: Context) -> LobbyViewport {
        let viewport = LobbyViewport(size: size)
        let view = viewport.renderer
        view.environment.background = .color(.init(srgbRed: 0.91, green: 0.94, blue: 0.87, alpha: 1))
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        let coordinator = context.coordinator, revision = lobby.roomRevision
        lobby.viewportAspect = Float(size.width / max(1, size.height))
        coordinator.buildTask = Task { @MainActor [weak viewport, weak lobby] in
            guard let viewport, let lobby else { return }
            do {
                lobby.error = nil
                let roots = try await LobbySceneAssembly.make(lobby)
                guard !Task.isCancelled, lobby.roomRevision == revision else { return }
                let anchor = AnchorEntity(world: .zero)
                for entity in roots { anchor.addChild(entity) }
                viewport.attach(anchor)
                coordinator.readySubscription?.cancel()
                coordinator.readySubscription = viewport.renderer.scene.subscribe(to: SceneEvents.Update.self) { event in
                    Task { @MainActor [weak lobby, weak coordinator] in
                        guard let lobby, let coordinator, lobby.roomRevision == revision, !lobby.ready else { return }
                        LobbySceneAssembly.recordCameras(event.scene, lobby: lobby)
                        viewport.fit(camera: lobby.camera)
                        lobby.updateCamera(); lobby.ready = true; lobby.refreshGates()
                        coordinator.readySubscription?.cancel(); coordinator.readySubscription = nil
                    }
                }
            } catch {
                guard !Task.isCancelled, !(error is CancellationError), lobby.roomRevision == revision else { return }
                lobby.error = "Couldn’t open this little room: \(error.localizedDescription)"
                lobby.refreshGates()
            }
        }
        return viewport
    }
    func updateUIView(_ viewport: LobbyViewport, context: Context) {
        if context.coordinator.inCare != lobby.inCare {
            // UIKit can restore the removed search field's responder while the
            // scene rotates. End editing only on this window's care transition;
            // later command/parent fields remain usable.
            viewport.window?.endEditing(true); context.coordinator.inCare = lobby.inCare
        }
        let view = viewport.renderer
        view.environment.background = lobby.danceMode == .daylight
            ? .color(.init(srgbRed: 0.91, green: 0.94, blue: 0.87, alpha: 1))
            : .color(.init(srgbRed: 0.075, green: 0.07, blue: 0.14, alpha: 1))
        lobby.viewportAspect = Float(size.width / max(1, size.height)); lobby.updateCamera()
        viewport.fit(camera: lobby.camera)
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
            if let window = view.window {
                NSLog("Fonsters native viewport: geometry %@, bounds %@, window %@, root %@", String(describing: size), String(describing: view.bounds), String(describing: window.bounds), String(describing: window.rootViewController?.view.bounds ?? .zero))
            }
            if let data = try? JSONSerialization.data(withJSONObject: diagnostic, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("fonsters-native-camera.json"), options: .atomic)
            }
        }
    }
    static func dismantleUIView(_ viewport: LobbyViewport, coordinator: Coordinator) {
        coordinator.buildTask?.cancel(); coordinator.readySubscription?.cancel()
        viewport.renderer.scene.anchors.removeAll()
    }
    /// Keep one square rendering surface through rotation and clip it to the
    /// visible window. Adjust its lens so the visible vertical field stays 42°;
    /// the shared controller's camera fitting and touch projection stay exact.
    /// No scene/entity transfer or creature-state reset occurs on rotation.
    final class LobbyViewport: UIView {
        let renderer: ARView
        private weak var camera: PerspectiveCamera?
        init(size: CGSize) {
            let side = max(size.width, size.height)
            renderer = ARView(frame: CGRect(x: 0, y: 0, width: side, height: side), cameraMode: .nonAR, automaticallyConfigureSession: false)
            super.init(frame: CGRect(origin: .zero, size: size)); clipsToBounds = true; addSubview(renderer)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
        func attach(_ anchor: AnchorEntity) { renderer.scene.addAnchor(anchor) }
        func fit(camera: PerspectiveCamera?) {
            self.camera = camera
            let side = max(bounds.width, bounds.height)
            guard side > 0, bounds.height > 0 else { return }
            camera?.camera.fieldOfViewInDegrees = Float(2 * atan(tan(21 * Double.pi / 180) * side / bounds.height) * 180 / Double.pi)
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            let side = max(bounds.width, bounds.height)
            renderer.frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
            fit(camera: camera)
            renderer.setNeedsLayout(); renderer.layoutIfNeeded()
            if ProcessInfo.processInfo.arguments.contains("--world-camera-diagnostics") {
                NSLog("Fonsters laid out viewport: container %@, renderer %@", String(describing: bounds), String(describing: renderer.bounds))
            }
        }
    }
}
#endif
#endif
