//
//  TappableCreatureView.swift
//  Fonsters
//
//  Wraps CreatureAvatarView with tap gesture; runs one of 22 animations
//  (500ms forward, 500ms reverse). iOS, macOS, tvOS, visionOS 2D.
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

    private var isAnimating: Bool { activeAnimation != nil }
    private var effectiveSeed: String {
        seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
    }

    var body: some View {
        let state = activeAnimation?.state(progress: animationProgress, size: size)
            ?? CreatureTapAnimationState(scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0, opacity: 1, overlay: nil)

        #if os(tvOS)
        Button(action: triggerAnimation) {
            creatureWithTransform(state: state)
                .overlay { overlayView(for: state.overlay, size: size) }
        }
        .buttonStyle(CreatureFocusableButtonStyle())
        .onChange(of: triggerBirthdayDanceID) { _, _ in triggerAnimation() }
        #else
        creatureWithTransform(state: state)
            .overlay { overlayView(for: state.overlay, size: size) }
            .contentShape(Rectangle())
            .onTapGesture { triggerAnimation() }
            .onChange(of: triggerBirthdayDanceID) { _, _ in triggerAnimation() }
        #endif
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
        guard !effectiveSeed.isEmpty, effectiveSeed != " ", !isAnimating else { return }
        let kind = CreatureTapAnimation.pick(seed: effectiveSeed, tapCount: tapCount)
        tapCount += 1
        activeAnimation = kind
        animationProgress = 0

        withAnimation(.easeInOut(duration: animationPhaseDuration)) {
            animationProgress = 1
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(animationPhaseDuration * 1_000_000_000))
            guard activeAnimation == kind else { return }
            withAnimation(.easeInOut(duration: animationPhaseDuration)) {
                animationProgress = 0
            }
            try? await Task.sleep(nanoseconds: UInt64(animationPhaseDuration * 1_000_000_000))
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
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.6), lineWidth: 3)
                }
            }
    }
}
#endif

#Preview {
    TappableCreatureView(seed: "glow leaf coral flame forest", size: 128)
        .padding()
}
