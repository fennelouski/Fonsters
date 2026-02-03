//
//  CreatureTapAnimation.swift
//  Fonsters
//
//  Tap-to-animate: 22 animation types driven by progress t in [0,1].
//  Forward 0→1 (500ms), reverse 1→0 (500ms). View-level transforms and overlays only.
//

import SwiftUI

/// Animation kind for tap reaction. Each maps progress t ∈ [0,1] to transform and overlay.
public enum CreatureTapAnimation: CaseIterable {
    case blink
    case eyebrowRaise
    case armWave
    case footKick
    case slideOffAndBack
    case squishAndPop
    case bounce
    case wiggle
    case shake
    case pulse
    case rain
    case snow
    case explode
    case wipe
    case dissolve
    case zoom
    case blinds
    case push
    case flip
    case spinOut
    case spotlight
    case bounceIn

    public static let count = 22

    /// Pick animation deterministically from seed (and optional tap salt for variety).
    public static func pick(seed: String, tapCount: Int = 0) -> CreatureTapAnimation {
        let salt = tapCount == 0 ? "" : "_\(tapCount)"
        let idx = segmentPick(seed: seed + salt, segmentId: "tap_animation", n: count)
        return CreatureTapAnimation.allCases[idx]
    }
}

// MARK: - Transform and overlay state (for 2D view)

public struct CreatureTapAnimationState {
    public var scaleX: CGFloat
    public var scaleY: CGFloat
    public var rotationDegrees: Double
    public var rotation3DY: Double
    public var offsetX: CGFloat
    public var offsetY: CGFloat
    public var opacity: CGFloat
    /// Overlay kind for the wrapper to render
    public var overlay: CreatureTapOverlay?
}

public enum CreatureTapOverlay {
    /// Top band opacity (blink = dark band on top 40%)
    case blinkBand(opacity: CGFloat)
    /// Thin band at top, vertical offset (eyebrow raise)
    case eyebrowBand(offsetY: CGFloat, opacity: CGFloat)
    /// Rain: diagonal lines, intensity 0...1
    case rain(intensity: CGFloat)
    /// Snow: dots drifting, intensity 0...1
    case snow(intensity: CGFloat)
    /// Explode: radial burst scale 0...1
    case explode(scale: CGFloat, flashOpacity: CGFloat)
    /// Wipe: horizontal reveal 0...1 (0 = hidden, 1 = full)
    case wipe(progress: CGFloat)
    /// Blinds: stripe heights 0...1
    case blinds(openAmount: CGFloat)
    /// Spotlight: radial vignette opacity 0...1
    case spotlight(opacity: CGFloat)
}

extension CreatureTapAnimation {
    /// Compute state from progress t (0 = idle/start, 1 = peak). Reverse phase uses same t going 1→0.
    public func state(progress t: CGFloat, size: CGFloat) -> CreatureTapAnimationState {
        switch self {
        case .blink:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1,
                overlay: .blinkBand(opacity: t * 0.85)
            )
        case .eyebrowRaise:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1,
                overlay: .eyebrowBand(offsetY: -8 * t, opacity: 0.6 * t)
            )
        case .armWave:
            let deg = -10 + 20 * t // -10° → +10° then reverse
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: deg, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .footKick:
            let deg = 8 * t
            let offY = 4 * t
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: deg, rotation3DY: 0, offsetX: 2 * t, offsetY: offY,
                opacity: 1, overlay: nil
            )
        case .slideOffAndBack:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0,
                offsetX: size * t, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .squishAndPop:
            let sy = 1 - 0.25 * t
            let sx = 1 + 0.05 * t
            return CreatureTapAnimationState(
                scaleX: sx, scaleY: sy, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .bounce:
            let s = 1 + 0.2 * t
            return CreatureTapAnimationState(
                scaleX: s, scaleY: s, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .wiggle:
            let deg = -8 + 16 * sin(t * .pi)
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: deg, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .shake:
            let x = 6 * sin(t * .pi * 4)
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: x, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .pulse:
            let s = 1 + 0.12 * t
            return CreatureTapAnimationState(
                scaleX: s, scaleY: s, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .rain:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1,
                overlay: .rain(intensity: t)
            )
        case .snow:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1,
                overlay: .snow(intensity: t)
            )
        case .explode:
            let burst = t
            let flash = t <= 0.5 ? t * 2 * 0.4 : (1 - t) * 2 * 0.4
            let scale = 1 + 0.05 * t
            return CreatureTapAnimationState(
                scaleX: scale, scaleY: scale, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1,
                overlay: .explode(scale: burst, flashOpacity: flash)
            )
        case .wipe:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1,
                overlay: .wipe(progress: t)
            )
        case .dissolve:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1 - t,
                overlay: nil
            )
        case .zoom:
            let s = 0.6 + 0.4 * t
            return CreatureTapAnimationState(
                scaleX: s, scaleY: s, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .blinds:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1,
                overlay: .blinds(openAmount: t)
            )
        case .push:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0,
                offsetX: -size * (1 - t), offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .flip:
            let angle = t * 180
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: angle, offsetX: 0, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .spinOut:
            let deg = 360 * t
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: deg, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1, overlay: nil
            )
        case .spotlight:
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: 0,
                opacity: 1,
                overlay: .spotlight(opacity: t * 0.5)
            )
        case .bounceIn:
            let bounce = t < 0.5 ? t * 2 : 1 - (t - 0.5) * 2
            let easeOut = 1 - pow(1 - bounce, 1.5)
            let offY = -size * 0.3 * (1 - easeOut)
            return CreatureTapAnimationState(
                scaleX: 1, scaleY: 1, rotationDegrees: 0, rotation3DY: 0, offsetX: 0, offsetY: offY,
                opacity: 1, overlay: nil
            )
        }
    }
}
