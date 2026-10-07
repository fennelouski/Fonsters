#if os(macOS) || os(iOS) || os(tvOS)
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import RealityKit

@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
struct LobbyStageView: View {
    let lobby: LocalLobbyController
    @State private var sceneEntities: [Entity] = []
    @State private var gestureStarted = false
    @State private var creatureCaptured = false
    @GestureState private var gestureActive = false
    var body: some View {
        GeometryReader { geometry in
            platformStage(size: geometry.size)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Explorable Fonster world with " + lobby.names.joined(separator: ", ")))
                .accessibilityValue(lobby.message)
                #if os(tvOS)
                .accessibilityHint("Use the area, companion and camera buttons to explore. Friendship buttons let the selected Fonster greet and play.")
                #else
                .accessibilityHint("Stroke a Fonster, tap a path to walk, or drag empty space to turn the world. Area and camera buttons offer the same navigation.")
                #endif
                .accessibilityAction(named: "Wave to a friend") { lobby.waveToFriend() }
                .accessibilityAction(named: "Play together") { lobby.playTogether() }
                .accessibilityAction(named: "Pass ball with chosen friend") { lobby.pair(quiet: false) }
                .accessibilityAction(named: "Sit with chosen friend") { lobby.pair(quiet: true) }
        }
    }
    @ViewBuilder private func platformStage(size: CGSize) -> some View {
        #if os(tvOS)
        scene(size: size).allowsHitTesting(false)
        #else
        interactiveStage(size: size)
        #endif
    }
    #if !os(tvOS)
    private func interactiveStage(size: CGSize) -> some View {
        scene(size: size)
            #if os(macOS)
            .background(VerificationSceneMarker(entities: sceneEntities))
            #endif
            .onContinuousHover { phase in
                if case .active(let point) = phase {
                    lobby.selectedMember.controller.look([Float(point.x / size.width - 0.5) * 2, Float(0.5 - point.y / size.height) * 2])
                }
            }
            .contentShape(Rectangle())
            .gesture(contactGesture(size: size))
            .onChange(of: gestureActive) { _, active in
                if !active && gestureStarted { lobby.cancelContact(); lobby.dragOrbit = nil; gestureStarted = false; creatureCaptured = false }
            }
            .onChange(of: size) { _, newSize in
                lobby.viewportAspect = Float(newSize.width / max(1, newSize.height)); lobby.updateCamera()
            }
            .onDisappear { lobby.cancelContact() }
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
            creatureCaptured = lobby.beginContact(at: value.startLocation, size: size)
            if !creatureCaptured { lobby.dragOrbit = lobby.cameraOrbit }
        } else if creatureCaptured { lobby.moveContact(at: value.location, size: size) }
        if !creatureCaptured && hypot(value.translation.width, value.translation.height) > 6 {
            lobby.cameraOrbit = (lobby.dragOrbit ?? lobby.cameraOrbit) - Float(value.translation.width) * 0.008
            lobby.updateCamera()
        }
    }
    private func ended(_ value: DragGesture.Value, size: CGSize) {
        if creatureCaptured { lobby.endContact() }
        else if hypot(value.translation.width, value.translation.height) <= 6 { lobby.walk(at: value.location, size: size) }
        lobby.dragOrbit = nil; gestureStarted = false; creatureCaptured = false
    }
    #endif
    private func scene(size: CGSize) -> some View {
        RealityView { content in
                content.camera = .virtual
                do {
                    let revision = lobby.roomRevision
                    lobby.viewportAspect = Float(size.width / max(1, size.height))
                    lobby.containers = []
                    for member in lobby.members {
                        let rig = try CreatureRig(member.descriptor, furDetail: lobby.members.count > 6 ? .world : .lobby)
                        member.controller.install(rig, name: member.name)
                        member.controller.orbit = 0
                        let container = Entity(); container.scale = .init(repeating: 0.55)
                        container.addChild(rig.root); content.add(container); lobby.containers.append(container)
                    }
                    let neighborhood = try LobbyWorldScene.make(lobby.world)
                    content.add(neighborhood.root); lobby.fountainDrops = neighborhood.fountainDrops
                    let ball = ModelEntity(mesh: .generateSphere(radius: 0.14), materials: [SimpleMaterial(color: FonsterPlatformColor(srgbRed: 0.96, green: 0.62, blue: 0.42, alpha: 1), roughness: 0.4, isMetallic: false)])
                    lobby.ball = ball; content.add(ball)
                    let camera = PerspectiveCamera(); camera.camera.fieldOfViewInDegrees = 42
                    camera.name = "preview-camera"; lobby.camera = camera
                    content.add(camera); content.camera = .virtual; lobby.updateCamera()
                    let key = DirectionalLight(); key.light.intensity = 2400
                    key.light.color = FonsterPlatformColor(srgbRed: 1, green: 0.9, blue: 0.8, alpha: 1)
                    key.look(at: [0, 0, 0], from: [-3, 5, 4], relativeTo: nil)
                    key.shadow = .init(maximumDistance: 30, depthBias: 1); content.add(key)
                    let fill = PointLight(); fill.light.intensity = 11000; fill.light.attenuationRadius = 20
                    fill.light.color = FonsterPlatformColor(srgbRed: 0.88, green: 0.91, blue: 1, alpha: 1); fill.position = [0, 2, 4]; content.add(fill)
                    content.add(try await CreatureSceneLighting.studio(for: Array(content.entities)))
                    guard !Task.isCancelled, lobby.roomRevision == revision else { return }
                    lobby.applyLayout(); lobby.ready = true; lobby.refreshGates()
                    sceneEntities = Array(content.entities)
                    #if os(macOS)
                    NativeSceneExport.verificationTask(entities: Array(content.entities), label: "lobby")
                    #endif
                } catch { lobby.error = "Couldn’t open this little room: \(error.localizedDescription)"; lobby.refreshGates() }
            }
    }

}
#endif
