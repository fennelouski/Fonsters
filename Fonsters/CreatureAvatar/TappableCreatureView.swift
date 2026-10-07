//
//  TappableCreatureView.swift
//  Fonsters
//
//  Transient touch responses over the unchanged deterministic portrait.
//  Existing birthday / exported animation definitions remain available.
//

import SwiftUI

private let animationPhaseDuration: Double = 0.5

/// Wraps the creature with tap-to-animate. Applies transform and overlay from CreatureTapAnimation.
struct TappableCreatureView: View {
    let seed: String
    var size: CGFloat = 128
    var onTap: (() -> Void)?
    /// When this value changes (e.g. parent increments for birthday celebration), run a dance animation.
    var triggerBirthdayDanceID: Int = 0

    @State private var animationProgress: CGFloat = 0
    @State private var activeAnimation: CreatureTapAnimation?
    @State private var tapCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var touch = CreatureTouchDynamics()
    @State private var touchMap: CreatureTouchMap?
    @State private var contactStarted = false
    @State private var contactCaptured = false
    @GestureState private var gestureActive = false
    @State private var touchTask: Task<Void, Never>?
    @State private var animationTask: Task<Void, Never>?

    private var isAnimating: Bool { activeAnimation != nil }
    private var effectiveSeed: String {
        seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
    }

    var body: some View {
        let legacy = activeAnimation?.state(progress: animationProgress, size: size)
            ?? CreatureTapAnimationState(scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0, opacity: 1, overlay: nil)
        interactionBody(contactState(legacy))
            .task(id: seed) { cancelInteraction(); touchMap = CreatureTouchMap(seed: effectiveSeed) }
            .onChange(of: triggerBirthdayDanceID) { _, _ in triggerAnimation() }
            .onChange(of: reduceMotion) { _, _ in cancelInteraction() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { cancelInteraction() } }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                if lowPower { cancelInteraction() }
            }
            .onDisappear { cancelInteraction() }
    }
    private var motionAllowed: Bool { !reduceMotion && !lowPower && scenePhase == .active }
    private func contactState(_ legacy: CreatureTapAnimationState) -> CreatureTapAnimationState {
        guard motionAllowed else { return .init(scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0, opacity: 1, overlay: nil) }
        let pose = touch.response
        return .init(scaleX: legacy.scaleX * CGFloat(1 - pose.squash * 0.5),
                     scaleY: legacy.scaleY * CGFloat(1 + pose.squash),
                     rotationDegrees: legacy.rotationDegrees + Double(pose.lean) * 35,
                     rotation3DY: legacy.rotation3DY, offsetX: legacy.offsetX + CGFloat(pose.gaze.x * pose.energy) * size * 0.012,
                     offsetY: legacy.offsetY - CGFloat(pose.lift) * size * 0.3,
                     opacity: legacy.opacity, overlay: legacy.overlay)
    }
    @ViewBuilder private func interactionBody(_ state: CreatureTapAnimationState) -> some View {

        #if os(tvOS)
        Button(action: triggerAnimation) {
            creatureWithTransform(state: state)
                .overlay { overlayView(for: state.overlay, size: size) }
        }
        .buttonStyle(CreatureFocusableButtonStyle())
        #else
        creatureWithTransform(state: state)
            .overlay { overlayView(for: state.overlay, size: size) }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).updating($gestureActive) { _, active, _ in active = true }
                .onChanged { value in
                    guard scenePhase == .active, !lowPower, size > 0 else { return }
                    let point = contactStarted ? value.location : value.startLocation
                    let sample = touchMap?.sample(x: Double(point.x / size), y: Double(point.y / size), time: ProcessInfo.processInfo.systemUptime)
                    if !contactStarted {
                        contactStarted = true
                        guard let sample else { return }
                        animationTask?.cancel(); animationTask = nil; activeAnimation = nil
                        contactCaptured = touch.begin(sample)
                        startTouchClock()
                    } else if contactCaptured {
                        if let sample { touch.move(sample) } else { _ = touch.end(at: ProcessInfo.processInfo.systemUptime) }
                    }
                }.onEnded { _ in
                    if contactCaptured { _ = touch.end(at: ProcessInfo.processInfo.systemUptime); onTap?() }
                    contactStarted = false; contactCaptured = false
                    if !motionAllowed { touch.cancel() }
                })
            .onChange(of: gestureActive) { _, active in if !active && contactStarted { cancelInteraction() } }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Fonster portrait")
            .accessibilityHint("Touch the head gently or stroke more quickly for a playful response. Activate for a little dance.")
            .accessibilityAction { triggerAnimation() }
        #endif
    }
    private func startTouchClock() {
        touchTask?.cancel()
        guard motionAllowed else { return }
        touchTask = Task { @MainActor in
            for _ in 0..<3600 {
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
                guard !Task.isCancelled, motionAllowed else { return }
                if touch.active { touch.hold(at: ProcessInfo.processInfo.systemUptime) }
                else {
                    touch.settle(dt: 1 / 30)
                    if abs(touch.response.lean) < 0.001 && abs(touch.response.squash) < 0.001 && touch.response.lift < 0.001 { touch.cancel(); return }
                }
            }
            touch.cancel()
        }
    }
    private func cancelInteraction() {
        touchTask?.cancel(); touchTask = nil; animationTask?.cancel(); animationTask = nil
        touch.cancel(); contactStarted = false; contactCaptured = false; activeAnimation = nil
    }

    @ViewBuilder
    private func creatureWithTransform(state: CreatureTapAnimationState) -> some View {
        let rotated = CreatureAvatarView(seed: effectiveSeed, size: size)
            .scaleEffect(x: state.scaleX, y: state.scaleY)
            .rotationEffect(.degrees(state.rotationDegrees), anchor: .center)
        #if os(visionOS)
        rotated
            .rotation3DEffect(.degrees(state.rotation3DY), axis: (x: 0, y: 1, z: 0), anchor: .center)
            .offset(x: state.offsetX, y: state.offsetY)
            .opacity(state.opacity)
        #else
        rotated
            .rotation3DEffect(.degrees(state.rotation3DY), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.4)
            .offset(x: state.offsetX, y: state.offsetY)
            .opacity(state.opacity)
        #endif
    }

    @ViewBuilder
    private func overlayView(for overlay: CreatureTapOverlay?, size: CGFloat) -> some View {
        if let overlay = overlay {
            Group {
                switch overlay {
                case .blinkBand(let opacity):
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(.black.opacity(opacity))
                            .frame(height: size * 0.4)
                        Spacer(minLength: 0)
                    }
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)

                case .eyebrowBand(let offsetY, let opacity):
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(.black.opacity(opacity))
                            .frame(height: size * 0.08)
                            .offset(y: offsetY)
                        Spacer(minLength: 0)
                    }
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)

                case .rain(let intensity):
                    RainOverlay(intensity: intensity, size: size)
                        .frame(width: size, height: size)
                        .allowsHitTesting(false)

                case .explode(let burstScale, let flashOpacity):
                    ZStack {
                        Rectangle()
                            .fill(.white.opacity(flashOpacity))
                            .frame(width: size, height: size)
                        ExplodeOverlay(scale: burstScale, size: size)
                            .frame(width: size, height: size)
                    }
                    .allowsHitTesting(false)

                case .wipe(let progress):
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.black)
                            .frame(width: max(0, geo.size.width * (1 - progress)), height: geo.size.height)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)

                case .blinds(let openAmount):
                    BlindsOverlay(openAmount: openAmount, size: size)
                        .frame(width: size, height: size)
                        .allowsHitTesting(false)

                case .spotlight(let opacity):
                    RadialGradient(
                        colors: [.clear, .black.opacity(opacity)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func triggerAnimation() {
        guard !effectiveSeed.isEmpty, effectiveSeed != " " else { return }
        cancelInteraction()
        guard motionAllowed else { onTap?(); return }
        let kind = CreatureTapAnimation.pick(seed: effectiveSeed, tapCount: tapCount)
        tapCount += 1
        activeAnimation = kind
        animationProgress = 0

        withAnimation(.easeInOut(duration: animationPhaseDuration)) {
            animationProgress = 1
        }
        animationTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(animationPhaseDuration)) } catch { return }
            guard !Task.isCancelled, activeAnimation == kind else { return }
            withAnimation(.easeInOut(duration: animationPhaseDuration)) {
                animationProgress = 0
            }
            do { try await Task.sleep(for: .seconds(animationPhaseDuration)) } catch { return }
            if activeAnimation == kind {
                activeAnimation = nil
            }
            onTap?()
        }
    }
}

// MARK: - Overlay helpers

private struct RainOverlay: View {
    let intensity: CGFloat
    let size: CGFloat

    private let lineCount = 12

    var body: some View {
        Canvas { context, canvasSize in
            let spacing = canvasSize.width / CGFloat(lineCount + 1)
            for i in 0..<lineCount {
                let x = spacing * CGFloat(i + 1)
                let len = 8 + intensity * 6
                let alpha = intensity * 0.4
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + 2, y: len))
                context.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 1)
            }
        }
    }
}

private struct ExplodeOverlay: View {
    let scale: CGFloat
    let size: CGFloat

    private let rayCount = 12

    var body: some View {
        Canvas { context, canvasSize in
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2
            let baseLen = min(canvasSize.width, canvasSize.height) * 0.4 * scale
            for i in 0..<rayCount {
                let angle = (CGFloat(i) / CGFloat(rayCount)) * 2 * .pi
                let dx = cos(angle) * baseLen
                let dy = sin(angle) * baseLen
                var path = Path()
                path.move(to: CGPoint(x: cx, y: cy))
                path.addLine(to: CGPoint(x: cx + dx, y: cy + dy))
                context.stroke(path, with: .color(.orange.opacity(0.6 * scale)), lineWidth: 2)
            }
        }
    }
}

private struct BlindsOverlay: View {
    let openAmount: CGFloat
    let size: CGFloat

    private let stripeCount = 6

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<stripeCount, id: \.self) { i in
                Rectangle()
                    .fill(.black.opacity(1 - openAmount))
                    .frame(height: size / CGFloat(stripeCount))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - tvOS focus-aware button style

#if os(tvOS)
/// ButtonStyle for tvOS that shows a clear focus state so the creature area is
/// visibly selected when the user navigates with the remote. Select (tap/click) triggers the animation.
private struct CreatureFocusableButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        let scale: CGFloat = (isFocused ? 1.03 : 1.0) * (configuration.isPressed ? 0.98 : 1.0)
        configuration.label
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .focusEffectDisabled()
    }
}
#endif

#Preview {
    TappableCreatureView(seed: "glow leaf coral flame forest", size: 128)
        .padding()
}
