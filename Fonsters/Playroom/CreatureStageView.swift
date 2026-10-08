#if os(macOS) || os(iOS)
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import RealityKit

@available(macOS 15.0, iOS 18.0, *)
struct CreatureStageView: View {
    let companion: PlayroomCompanion
    let controller: PlayroomController
    var onSceneReady: (([Entity]) -> Void)? = nil
    @State private var contactStarted = false
    @State private var contactCaptured = false
    @GestureState private var gestureActive = false
    @State private var touchEntities: [Entity] = []

    var body: some View {
        let controls = controller.controls(selection: 0)
        GeometryReader { geometry in
            interactiveStage(size: geometry.size, controls: controls)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(companion.name), a fluffy three dimensional Fonster")
            .accessibilityValue(controller.rendererReady ? controller.message + " " + controller.motionStatus : "Opening the companion environment.")
            .accessibilityIdentifier("creatureContactSurface")
            .accessibilityHint("Stroke the fuzzy head gently, hold for a cuddle, or touch a paw for a high five. Quick strokes are playful. The same reactions are available as buttons. Drag the Turn slider to see every side.")
            .accessibilityAction(named: "Say hello") { controller.perform(.greet, name: companion.name) }
            .accessibilityAction(named: "Play") { controller.perform(.play, name: companion.name) }
            .accessibilityAction(named: "Gentle rub") { controller.perform(.rub, name: companion.name) }
            .accessibilityAction(named: "High five") { controller.perform(.highFive, name: companion.name) }
        }
    }

    private func interactiveStage(size: CGSize, controls: PlayroomController.ControlState) -> some View {
        scene(controls: controls)
            #if os(macOS)
            .background(VerificationSceneMarker(entities: touchEntities))
            #endif
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): controller.look([Float(p.x / size.width - 0.5) * 2, Float(0.5 - p.y / size.height) * 2])
                case .ended: controller.look(.zero)
                }
            }
            // A SwiftUI surface owns contact independently of the native
            // renderer's UIKit/AppKit hit testing, including after remounting.
            .overlay {
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(contactGesture(size: size))
            }
            .onChange(of: gestureActive) { _, active in
                if !active && contactStarted { controller.cancelTouch(); contactStarted = false; contactCaptured = false }
            }
            .onDisappear { controller.cancelTouch() }
            #if os(macOS)
            .overlay { TouchGestureVerification(controller: controller, entities: touchEntities).allowsHitTesting(false) }
            #endif
    }

    private func contactGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0).updating($gestureActive) { _, active, _ in active = true }
                .onChanged { value in
                    if !contactStarted {
                        contactStarted = true
                        contactCaptured = controller.beginTouch(at: value.startLocation, size: size)
                    } else if contactCaptured { controller.moveTouch(at: value.location, size: size) }
                }.onEnded { _ in
                    if contactCaptured { controller.endTouch() }
                    contactStarted = false; contactCaptured = false
                }
    }

    @ViewBuilder private func scene(controls: PlayroomController.ControlState) -> some View {
        #if os(iOS)
        NativeCompanionStage(companion: companion, controller: controller, controls: controls, onSceneReady: onSceneReady)
        #else
        RealityView { content in
            content.camera = .virtual
            do {
                let scene = try await CompanionSceneAssembly.make(companion: companion, controller: controller)
                guard !Task.isCancelled, controller.rig === scene.rig else { return }
                for entity in scene.entities { content.add(entity) }
                controller.rendererReady = true
                touchEntities = scene.entities
                onSceneReady?(scene.entities)
                NativeSceneExport.verificationTask(entities: scene.entities, label: "solo")
            } catch {
                guard !Task.isCancelled else { return }
                controller.rendererError = error.localizedDescription
            }
        }
        #endif
    }
}
#endif
