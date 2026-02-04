//
//  BirthdayCelebrationOverlay.swift
//  Fonsters
//
//  Full-screen celebration overlay: confetti, balloons, lasers, sparkles, bubbles, or hearts.
//  Fills the view; auto-dismisses after a fixed duration.
//

import SwiftUI

/// Which celebration effect to show (chosen by caller from Fonster.seed).
public enum CelebrationEffect: Int, CaseIterable {
    case confetti = 0
    case balloons
    case lasers
    case sparkles
    case bubbles
    case hearts
}

/// Full-screen overlay that draws one of six celebration effects and calls onDismiss after duration.
/// Tap anywhere to dismiss early; otherwise auto-dismisses after 4.5 seconds.
public struct BirthdayCelebrationOverlay: View {
    let size: CGSize
    let effect: CelebrationEffect
    let onDismiss: () -> Void

    private let duration: Double = 4.5

    public init(size: CGSize, effect: CelebrationEffect, onDismiss: @escaping () -> Void) {
        self.size = size
        self.effect = effect
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1/60)) { context in
                effectView(date: context.date)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
            #if os(tvOS)
            VStack {
                Spacer(minLength: 0)
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 60)
            }
            .frame(width: size.width, height: size.height)
            #else
            Color.clear
                .contentShape(Rectangle())
                .frame(width: size.width, height: size.height)
                .onTapGesture { onDismiss() }
            #endif
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                onDismiss()
            }
        }
    }

    @ViewBuilder
    private func effectView(date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        switch effect {
        case .confetti:
            ConfettiEffectView(size: size, time: t)
        case .balloons:
            BalloonsEffectView(size: size, time: t)
        case .lasers:
            LasersEffectView(size: size, time: t)
        case .sparkles:
            SparklesEffectView(size: size, time: t)
        case .bubbles:
            BubblesEffectView(size: size, time: t)
        case .hearts:
            HeartsEffectView(size: size, time: t)
        }
    }
}

// MARK: - Confetti (Canvas, many falling rectangles)

private struct ConfettiEffectView: View {
    let size: CGSize
    let time: TimeInterval

    private let particleCount = 70
    private let gravity: CGFloat = 280
    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            for i in 0..<particleCount {
                let u = confettiSeed(i)
                let startX = CGFloat(u.0) * w
                let startY: CGFloat = -20
                let vx = (CGFloat(u.1) - 0.5) * 120
                let vy = CGFloat(u.2) * 60 + 40
                let rotSpeed = (CGFloat(u.3) - 0.5) * 4
                let fallTime = time + Double(i) * 0.02
                let x = startX + vx * CGFloat(fallTime)
                let y = startY + vy * CGFloat(fallTime) + 0.5 * gravity * CGFloat(fallTime * fallTime)
                let rotation = Angle(radians: rotSpeed * fallTime)
                let color = colors[i % colors.count]
                let rectW: CGFloat = 6
                let rectH: CGFloat = 4
                var path = Path(roundedRect: CGRect(x: -rectW/2, y: -rectH/2, width: rectW, height: rectH), cornerSize: CGSize(width: 1, height: 1))
                path = path.applying(CGAffineTransform(rotationAngle: CGFloat(rotation.radians)))
                path = path.applying(CGAffineTransform(translationX: x, y: y))
                context.fill(path, with: .color(color.opacity(y > h + 20 ? 0 : 0.9)))
            }
        }
    }

    private func confettiSeed(_ i: Int) -> (Double, Double, Double, Double) {
        var s = UInt64(i)
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u0 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u1 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u2 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u3 = Double(s & 0xFFFF) / 65536
        return (u0, u1, u2, u3)
    }
}

// MARK: - Balloons (rising ellipses / SF Symbol)

private struct BalloonsEffectView: View {
    let size: CGSize
    let time: TimeInterval

    private let count = 30
    private let colors: [Color] = [.red, .orange, .pink, .purple, .blue]

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<count, id: \.self) { i in
                let u = balloonSeed(i)
                let startX = CGFloat(u.0) * size.width
                let startY = size.height + 30
                let riseDuration: Double = 4 + Double(u.1) * 2
                let progress = (time.truncatingRemainder(dividingBy: riseDuration + 1) / riseDuration).clamped01()
                let y = startY - progress * (size.height + 80)
                let wobble = sin(time * 3 + Double(i)) * 8
                let x = startX + CGFloat(wobble)
                let scale = 0.4 + CGFloat(u.2) * 0.4
                Image(systemName: "balloon.fill")
                    .font(.system(size: 28 * scale))
                    .foregroundStyle(colors[i % colors.count].opacity(0.95))
                    .position(x: x, y: y)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func balloonSeed(_ i: Int) -> (Double, Double, Double) {
        var s = UInt64(i) &* 6364136223846793005 &+ 1442695040888963407
        let u0 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u1 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u2 = Double(s & 0xFFFF) / 65536
        return (u0, u1, u2)
    }
}

// MARK: - Lasers (Canvas lines crossing the view)

private struct LasersEffectView: View {
    let size: CGSize
    let time: TimeInterval

    private let lineCount = 12

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let cx = w / 2
            let cy = h / 2
            for i in 0..<lineCount {
                let angle = (CGFloat(i) / CGFloat(lineCount)) * 2 * .pi + CGFloat(time * 0.3)
                let pulse = 0.5 + 0.5 * sin(time * 2 + Double(i))
                let len = min(w, h) * 0.6 * (0.3 + CGFloat(pulse))
                let dx = cos(angle) * len
                let dy = sin(angle) * len
                var path = Path()
                path.move(to: CGPoint(x: cx - dx, y: cy - dy))
                path.addLine(to: CGPoint(x: cx + dx, y: cy + dy))
                let hue = Double(i) / Double(lineCount)
                context.stroke(path, with: .color(Color(hue: hue, saturation: 1, brightness: 1).opacity(0.7)), lineWidth: 3)
            }
        }
    }
}

// MARK: - Sparkles (twinkling dots)

private struct SparklesEffectView: View {
    let size: CGSize
    let time: TimeInterval

    private let count = 50
    private let colors: [Color] = [.yellow, .white, .orange]

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            for i in 0..<count {
                let u = sparkleSeed(i)
                let x = CGFloat(u.0) * w
                let y = CGFloat(u.1) * h
                let phase = time + Double(i) * 0.2
                let twinkle = (sin(phase * 4) + 1) / 2
                let r: CGFloat = 2 + CGFloat(u.2) * 2
                let color = colors[i % colors.count].opacity(0.3 + 0.7 * twinkle)
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
            }
        }
    }

    private func sparkleSeed(_ i: Int) -> (Double, Double, Double) {
        var s = UInt64(i) &* 6364136223846793005 &+ 1442695040888963407
        let u0 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u1 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u2 = Double(s & 0xFFFF) / 65536
        return (u0, u1, u2)
    }
}

// MARK: - Bubbles (rising circles)

private struct BubblesEffectView: View {
    let size: CGSize
    let time: TimeInterval

    private let count = 22
    private let colors: [Color] = [.cyan, .blue, .white, .mint]

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<count, id: \.self) { i in
                let u = bubbleSeed(i)
                let startX = CGFloat(u.0) * size.width
                let startY = size.height + 20
                let dur: Double = 5 + Double(u.1) * 3
                let progress = (time.truncatingRemainder(dividingBy: dur + 1) / dur).clamped01()
                let y = startY - progress * (size.height + 60)
                let wobble = sin(time * 2 + Double(i) * 0.5) * 15
                let x = startX + CGFloat(wobble)
                let r: CGFloat = 8 + CGFloat(u.2) * 12
                Circle()
                    .stroke(colors[i % colors.count].opacity(0.8), lineWidth: 1.5)
                    .background(Circle().fill(colors[i % colors.count].opacity(0.2)))
                    .frame(width: r * 2, height: r * 2)
                    .position(x: x, y: y)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func bubbleSeed(_ i: Int) -> (Double, Double, Double) {
        var s = UInt64(i + 100) &* 6364136223846793005 &+ 1442695040888963407
        let u0 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u1 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u2 = Double(s & 0xFFFF) / 65536
        return (u0, u1, u2)
    }
}

// MARK: - Hearts (floating SF Symbol hearts)

private struct HeartsEffectView: View {
    let size: CGSize
    let time: TimeInterval

    private let count = 25
    private let colors: [Color] = [.pink, .red, .orange]

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let u = heartSeed(i)
                let x = CGFloat(u.0) * size.width
                let startY = size.height + 20
                let dur: Double = 4 + Double(u.1) * 2
                let progress = (time.truncatingRemainder(dividingBy: dur + 1) / dur).clamped01()
                let y = startY - progress * (size.height + 80)
                let scale = 0.5 + CGFloat(u.2) * 0.6
                let pulse = 1 + 0.1 * sin(time * 5 + Double(i))
                Image(systemName: "heart.fill")
                    .font(.system(size: 24 * scale * pulse))
                    .foregroundStyle(colors[i % colors.count].opacity(0.9))
                    .position(x: x, y: y)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func heartSeed(_ i: Int) -> (Double, Double, Double) {
        var s = UInt64(i + 200) &* 6364136223846793005 &+ 1442695040888963407
        let u0 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u1 = Double(s & 0xFFFF) / 65536
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let u2 = Double(s & 0xFFFF) / 65536
        return (u0, u1, u2)
    }
}

private extension Double {
    func clamped01() -> Double {
        min(1, max(0, self))
    }
}
