import Foundation
import simd

/// Transient contact dynamics. No input path, care state, identity or human inference is stored.
struct CreatureTouchDynamics {
    enum Zone: String { case crown, cheek, eye, belly, paw }
    enum Manner: String { case attention, softStroke, cuddle, tickle, lively, highFive, blink }
    struct Sample {
        var point: SIMD2<Float>
        var zone: Zone
        var time: Double
    }
    struct Response: Equatable {
        var manner = Manner.attention
        var lean: Float = 0
        var nod: Float = 0
        var squash: Float = 0
        var lift: Float = 0
        var eyes: Float = 0.94
        var smile: Float = 1
        var arms: Float = 0
        var gaze = SIMD2<Float>.zero
        var energy: Float = 0
    }
    private(set) var active = false
    private(set) var response = Response()
    private(set) var speed: Float = 0
    private(set) var distance: Float = 0
    private(set) var duration: Double = 0
    private(set) var reversals = 0
    private var startedAt: Double = 0
    private var last: Sample?
    private var previousDirection = SIMD2<Float>.zero
    private var lastReversal = -Double.greatestFiniteMagnitude
    private var warmth: Float = 0.5
    private var playEnergy: Float = 0.5
    private var filteredPoint = SIMD2<Float>.zero
    private var playfulAt = -Double.greatestFiniteMagnitude
    private var lastMovementAt: Double = 0
    private var quietAnchor = SIMD2<Float>.zero

    mutating func begin(_ sample: Sample, warmth: Float = 0.5, playEnergy: Float = 0.5) -> Bool {
        guard Self.valid(sample) else { return false }
        self = .init()
        active = true; startedAt = sample.time; lastMovementAt = sample.time; last = sample
        self.warmth = Self.unit(warmth); self.playEnergy = Self.unit(playEnergy)
        filteredPoint = Self.point(sample.point)
        quietAnchor = filteredPoint
        respond(zone: sample.zone, at: sample.time)
        return true
    }
    /// Speed is measured in creature radii/second. It is movement energy, not measured force.
    mutating func move(_ sample: Sample) {
        guard active, Self.valid(sample), let last else { return }
        let elapsed = sample.time - last.time
        guard elapsed > 0 else { return }
        // A long delivery gap is a discontinuity, never a fling or catch-up.
        guard elapsed <= 0.3 else { cancel(); return }
        let dt = Float(elapsed), point = Self.point(sample.point)
        let delta = point - Self.point(last.point), travel = simd_length(delta)
        if simd_distance(point, quietAnchor) > 0.003 { lastMovementAt = sample.time; quietAnchor = point }
        let instantaneous = min(6, travel / max(0.008, dt))
        let blend = 1 - exp(-dt * 14)
        speed += (instantaneous - speed) * blend
        filteredPoint += (point - filteredPoint) * (1 - exp(-dt * 24))
        distance = min(100, distance + travel); duration = max(0, sample.time - startedAt)
        if travel > 0.012 {
            let direction = delta / travel
            if simd_length(previousDirection) > 0.5, simd_dot(previousDirection, direction) < -0.35,
               sample.time - lastReversal > 0.10 {
                reversals = min(32, reversals + 1); lastReversal = sample.time
            }
            previousDirection = direction
        }
        self.last = sample
        respond(zone: sample.zone, at: sample.time)
    }
    mutating func end(at time: Double) -> Manner? {
        guard active, time.isFinite, let last, time >= last.time, time - last.time <= 0.3 else { cancel(); return nil }
        duration = max(duration, time - startedAt)
        let manner = response.manner
        active = false
        return manner
    }
    mutating func hold(at time: Double) {
        guard let last else { return }
        move(.init(point: last.point, zone: last.zone, time: time))
    }
    mutating func cancel() { self = .init() }
    /// Release has one decaying pose; another contact replaces it immediately.
    mutating func settle(dt: Float) {
        guard !active, dt.isFinite, dt > 0 else { return }
        let decay = exp(-min(0.06, dt) * 12)
        response.lean *= decay; response.nod *= decay; response.squash *= decay
        response.lift *= decay; response.arms *= decay; response.energy *= decay
        response.gaze *= decay; response.eyes = 0.94 + (response.eyes - 0.94) * decay
        response.smile = 1 + (response.smile - 1) * decay
    }
    private mutating func respond(zone: Zone, at time: Double) {
        let wasTickle = response.manner == .tickle
        let energy = min(1, speed / 2.2)
        var manner = Manner.attention
        if zone == .eye { manner = .blink }
        else if zone == .paw { manner = .highFive }
        else if zone == .belly, (reversals >= 2 && speed > 0.25) || speed > (wasTickle ? 0.85 : 1.4) { manner = .tickle; playfulAt = time }
        else if speed > 1.7 { manner = .lively; playfulAt = time }
        // A tiny pose hold lets the rendered body answer a fast stroke without
        // flipping between excited and relaxed on adjacent input/render frames.
        else if time - playfulAt < 0.18 && (response.manner == .lively || (zone == .belly && response.manner == .tickle)) { manner = response.manner }
        else if duration > 0.35 && speed < 0.18 && time - lastMovementAt > 0.22 { manner = .cuddle }
        else if duration > 0.14 && distance > 0.035 { manner = .softStroke }

        var output = Response(manner: manner, gaze: filteredPoint, energy: energy)
        let affection = 0.65 + warmth * 0.35
        output.lean = filteredPoint.x * (0.04 + min(0.14, energy * 0.12))
        output.nod = -filteredPoint.y * 0.045
        output.squash = -0.012 - min(0.065, energy * 0.045)
        output.smile = 1.06 + affection * 0.08
        switch manner {
        case .attention: output.eyes = 1; output.arms = 0.05
        case .softStroke:
            output.lean = filteredPoint.x * 0.13 * affection
            output.nod -= zone == .crown ? 0.10 : 0.035
            output.eyes = 0.42 + (1 - warmth) * 0.12; output.squash = -0.025
        case .cuddle:
            output.eyes = 0.42; output.nod -= 0.065; output.lean = filteredPoint.x * 0.10; output.arms = -0.035
        case .tickle:
            output.eyes = 0.52; output.smile = 1.25; output.arms = 0.15 + energy * 0.12
            output.lift = (0.035 + energy * 0.065) * (0.65 + playEnergy * 0.35)
            output.lean = filteredPoint.x * 0.12
        case .lively:
            output.eyes = 1.10; output.lean *= -0.65; output.lift = 0.04; output.smile = 1.18
        case .highFive: output.arms = 0.55; output.smile = 1.20; output.eyes = 1
        case .blink: output.eyes = 0.08; output.lean *= 0.2; output.squash = -0.01
        }
        response = output
    }
    static func valid(_ sample: Sample) -> Bool { sample.time.isFinite && sample.point.x.isFinite && sample.point.y.isFinite }
    private static func unit(_ value: Float) -> Float { value.isFinite ? min(1, max(0, value)) : 0.5 }
    private static func point(_ value: SIMD2<Float>) -> SIMD2<Float> { .init(min(1, max(-1, value.x)), min(1, max(-1, value.y))) }
}

/// Uses the resolved, clipped pixels rather than a rectangular avatar hit area.
struct CreatureTouchMap {
    let descriptor: CreatureAppearanceDescriptor
    init(seed: String) { descriptor = .resolve(seed: seed) }
    func sample(x: Double, y: Double, time: Double) -> CreatureTouchDynamics.Sample? {
        guard x.isFinite, y.isFinite, x >= 0, y >= 0, x < 1, y < 1 else { return nil }
        let px = Int(x * 32), py = Int(y * 32)
        guard descriptor.silhouette.contains(.init(x: px, y: py)) else { return nil }
        let part = descriptor.parts.first { $0.pixels.contains(.init(x: px, y: py)) }
        let head = descriptor.head
        let point = SIMD2<Float>(Float((x * 32 - head.centerX) / max(1, head.radius * head.ellipseX)),
                                 Float((head.centerY - y * 32) / max(1, head.radius * head.ellipseY)))
        let zone: CreatureTouchDynamics.Zone
        switch part?.kind {
        case "eye": zone = .eye
        case "appendage": zone = .paw
        case "body": zone = .belly
        default: zone = point.y > 0.45 ? .crown : .cheek
        }
        return .init(point: point, zone: zone, time: time)
    }
}
