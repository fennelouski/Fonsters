import Foundation
import simd

/// Transient rendering controls, separate from the owner's chosen feeling and memories.
nonisolated struct CreatureFacialExpression: Equatable, Sendable {
    var smile: Float = 0.45 // Signed mouth curvature: frown < 0, neutral = 0.
    var smilingEyes: Float = 0.15

    static func casual(time: Float, phase: Float, low: Bool, quiet: Bool) -> Self {
        let t = (max(0, time) + phase * 2.8).truncatingRemainder(dividingBy: 18)
        let knots: [(Float, Float)] = [(0, 0.45), (3, 0.45), (5, 0), (8, 0), (11, 0.72), (14, 0.72), (18, 0.45)]
        var amount: Float = 0.45
        for i in 1..<knots.count where t <= knots[i].0 {
            let u = (t - knots[i - 1].0) / (knots[i].0 - knots[i - 1].0)
            let smooth = u * u * (3 - 2 * u)
            amount = knots[i - 1].1 + (knots[i].1 - knots[i - 1].1) * smooth; break
        }
        if low { return .init(smile: -0.5 + sin(time * 0.4 + phase) * 0.08, smilingEyes: 0) }
        if quiet { amount *= 0.65 }
        return .init(smile: amount, smilingEyes: amount * amount * 0.8)
    }
}

/// An attention greeting followed by a two-second blend of observable face shape.
/// No emotion labels, identity, recordings, calibration archive or learned state.
nonisolated struct CreatureFaceDynamics {
    private(set) var expression = CreatureFacialExpression()
    private(set) var acknowledgingViewer = false
    private var clock: Float = 0
    private var attentiveFor: Float = 0
    private var awayFor: Float = 2
    private var acknowledgedAt: Float = -.greatestFiniteMagnitude
    private var lastWelcome: Float = -10

    mutating func advance(dt: Float, baseline: CreatureFacialExpression, sample: CreatureMirrorSample, low: Bool) {
        guard dt.isFinite, dt > 0 else { return }
        let dt = min(0.06, dt); clock += dt
        let attentive = sample.found && sample.valid && sample.viewerAttention >= 0.65 && (sample.eyeOpenness ?? 1) > 0.25
        if attentive { attentiveFor += dt; awayFor = 0 }
        else { attentiveFor = 0; awayFor += dt }
        if awayFor > 0.65 { acknowledgingViewer = false }
        if attentiveFor >= 0.25 && !acknowledgingViewer && clock - lastWelcome > 5 {
            acknowledgingViewer = true; acknowledgedAt = clock; lastWelcome = clock
        }
        var target = baseline
        if acknowledgingViewer && sample.found && sample.valid {
            let shape = sample.facialSmile ?? baseline.smile
            let elapsed = max(0, clock - acknowledgedAt)
            let u = min(1, max(0, (elapsed - 0.3) / 2))
            let mix = u * u * (3 - 2 * u)
            let smile = min(1, max(-0.85, shape))
            let eyes = min(1, max(0, sample.smilingEyes ?? max(0, smile) * max(0, smile) * 0.8))
            target.smile = 0.96 + (smile - 0.96) * mix
            target.smilingEyes = 0.7 + (eyes - 0.7) * mix
        }
        // The owner explicitly chose a low feeling. Camera cues never overwrite it.
        if low { target = baseline; target.smile = min(-0.15, target.smile); target.smilingEyes = 0 }
        let blend = 1 - exp(-dt * 7)
        expression.smile += (target.smile - expression.smile) * blend
        expression.smilingEyes += (target.smilingEyes - expression.smilingEyes) * blend
    }
    mutating func reset(to expression: CreatureFacialExpression = .init()) {
        self = .init(); self.expression = expression
    }
}

nonisolated enum CreatureAttention {
    enum Mode: String, Sendable { case viewer, peer, travel }
    struct Target: Sendable {
        var mode: Mode
        var point: SIMD3<Float>
        var cameraUp: SIMD3<Float> = [0, 1, 0]
    }
    static func viewerDirection(from origin: SIMD3<Float>, camera: SIMD3<Float>, up: SIMD3<Float>, degrees: Float) -> SIMD3<Float> {
        let delta = camera - origin
        guard delta.x.isFinite, delta.y.isFinite, delta.z.isFinite, simd_length_squared(delta) > 0.0001 else { return [0, 0, 1] }
        let ray = simd_normalize(delta)
        let perpendicular = up - ray * simd_dot(up, ray)
        guard simd_length_squared(perpendicular) > 0.0001 else { return ray }
        let angle = min(15, max(3, degrees)) * .pi / 180
        return ray * cos(angle) + simd_normalize(perpendicular) * sin(angle)
    }
    static func angles(_ direction: SIMD3<Float>) -> SIMD2<Float> {
        guard direction.x.isFinite, direction.y.isFinite, direction.z.isFinite else { return .zero }
        return [atan2(direction.x, direction.z), atan2(direction.y, hypot(direction.x, direction.z))]
    }
    static func visible(_ position: SIMD3<Float>, camera: simd_float4x4, aspect: Float) -> Bool {
        guard aspect.isFinite, aspect > 0 else { return false }
        let point = camera.inverse * SIMD4<Float>(position, 1)
        guard point.z < -0.05 else { return false }
        let halfHeight = -point.z * tan(Float.pi * 21 / 180)
        return abs(point.x) <= halfHeight * aspect * 1.05 && abs(point.y) <= halfHeight * 1.05
    }
    static func choose(actor: Int, positions: [SIMD3<Float>], visible: [Bool], walking: Bool, forceViewer: Bool, socialPeer: Int?) -> (Mode, Int?) {
        if walking { return (.travel, nil) }
        if forceViewer { return (.viewer, nil) }
        guard positions.indices.contains(actor), visible.count == positions.count else { return (.viewer, nil) }
        let peers = positions.indices.filter { $0 != actor && visible[$0] }
        if let socialPeer, peers.contains(socialPeer) { return (.peer, socialPeer) }
        if let peer = peers.min(by: { simd_distance_squared(positions[$0], positions[actor]) < simd_distance_squared(positions[$1], positions[actor]) }) {
            return (.peer, peer)
        }
        return (.viewer, nil)
    }
}

/// Geometry measurements, not a classifier of anyone's actual emotions.
nonisolated enum CreatureFaceLandmarkCues {
    static func smile(lips: [SIMD2<Float>], yaw: Float, roll: Float) -> Float? {
        guard lips.count >= 8, yaw.isFinite, roll.isFinite, abs(yaw) < 0.4,
              lips.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let unrolled = lips.map { SIMD2<Float>($0.x * cos(roll) + $0.y * sin(roll), -$0.x * sin(roll) + $0.y * cos(roll)) }
        guard let minX = unrolled.map(\.x).min(), let maxX = unrolled.map(\.x).max(), maxX - minX > 0.005 else { return nil }
        let width = maxX - minX, center = (minX + maxX) * 0.5
        let edges = unrolled.filter { $0.x <= minX + width * 0.13 || $0.x >= maxX - width * 0.13 }
        let middle = unrolled.filter { abs($0.x - center) < width * 0.22 }
        guard edges.count >= 2, middle.count >= 2 else { return nil }
        let bend = (edges.map(\.y).reduce(0, +) / Float(edges.count) - middle.map(\.y).reduce(0, +) / Float(middle.count)) / width
        if abs(bend) < 0.025 { return 0 }
        return min(1, max(-0.85, (bend - (bend > 0 ? 0.025 : -0.025)) * 8))
    }
    static func attention(yaw: Float, eyes: Float?, pupilOffsets: [Float]) -> Float {
        guard yaw.isFinite, abs(yaw) < 0.38, (eyes ?? 0) > 0.3 else { return 0 }
        // Missing pupils gracefully fall back to face direction, with lower confidence.
        let pupils = pupilOffsets.filter(\.isFinite)
        let looking = pupils.isEmpty ? Float(0.72) : max(0, 1 - (pupils.map(abs).max() ?? 1) * 2.5)
        return min(1, max(0, (1 - abs(yaw) / 0.5) * looking))
    }
}

nonisolated enum CreatureMouthCurve {
    static func edges(t: Float, width: Float, height: Float, smile: Float, opening: Float) -> (SIMD2<Float>, SIMD2<Float>) {
        let smile = min(1, max(-0.85, smile)), opening = min(1.4, max(0.3, opening))
        let center = smile * height * (-0.02 + 0.32 * t * t)
        let gap = height * (0.024 + 0.5 * max(0, smile) * opening) * (1 - 0.97 * t * t)
        return ([t * width / 2, center + gap * 0.05], [t * width / 2, center - gap * 0.95])
    }
}
