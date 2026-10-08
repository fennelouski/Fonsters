import Foundation
import simd

/// Numeric cues only: no image, recording, transcript, biometric template or identity.
nonisolated struct CreatureMirrorSample: Sendable {
    var gaze: SIMD2<Float> = .zero
    var eyeOpenness: Float? = nil
    var tilt: Float = 0
    var motion: Float = 0
    var raisedHand: Float = 0
    var handX: Float? = nil
    var found = true
    var facialSmile: Float? = nil
    var smilingEyes: Float? = nil
    var viewerAttention: Float = 0
    var valid: Bool {
        gaze.x.isFinite && gaze.y.isFinite && tilt.isFinite && motion.isFinite && raisedHand.isFinite &&
        (eyeOpenness?.isFinite ?? true) && (handX?.isFinite ?? true) &&
        (facialSmile?.isFinite ?? true) && (smilingEyes?.isFinite ?? true) && viewerAttention.isFinite
    }
}

nonisolated struct CreatureMovementStyle: Codable, Equatable, Sendable {
    var tempo: Float = 1
    var amplitude: Float = 1
    var wave: Float = 1
    var valid: Bool { [tempo, amplitude, wave].allSatisfy { $0.isFinite && (0.65...1.4).contains($0) } }
}

/// Confidence is checked by Vision before this state machine. Hysteresis prevents
/// a single noisy frame from putting a friend to sleep or repeatedly waving.
nonisolated struct CreatureMirrorDynamics {
    private(set) var sample = CreatureMirrorSample(found: false)
    private(set) var sleeping = false
    private var closedSince: Double?
    private var lastSeen: Double = -.greatestFiniteMagnitude
    private var previousHand: Float?
    private var lastHandDirection: Float = 0
    private var reversals = 0
    private var waveStart: Double = 0
    private var lastWave: Double = -.greatestFiniteMagnitude
    mutating func receive(_ input: CreatureMirrorSample, time: Double) -> Bool {
        guard input.valid, time.isFinite else { return false }
        guard input.found else { reset(); return false }
        let dt = Float(max(0, min(0.4, time - lastSeen)))
        if time - lastSeen > 0.8 {
            sample = input; sample.gaze = simd_clamp(input.gaze, SIMD2(repeating: -0.8), SIMD2(repeating: 0.8))
            sample.tilt = min(0.22, max(-0.22, input.tilt)); sample.motion = min(1, max(0, input.motion)); sample.raisedHand = min(1, max(0, input.raisedHand))
            closedSince = nil; reversals = 0; previousHand = nil
        }
        else {
            let blend = min(1, dt * 9)
            sample.gaze += (simd_clamp(input.gaze, SIMD2(repeating: -0.8), SIMD2(repeating: 0.8)) - sample.gaze) * blend
            sample.tilt += (min(0.22, max(-0.22, input.tilt)) - sample.tilt) * blend
            sample.motion += (min(1, max(0, input.motion)) - sample.motion) * blend
            sample.raisedHand = min(1, max(0, input.raisedHand)); sample.eyeOpenness = input.eyeOpenness
        }
        sample.facialSmile = input.facialSmile.map { min(1, max(-0.85, $0)) }
        sample.smilingEyes = input.smilingEyes.map { min(1, max(0, $0)) }
        sample.viewerAttention = min(1, max(0, input.viewerAttention))
        sample.found = true; lastSeen = time
        if let eyes = input.eyeOpenness {
            if eyes < 0.22 { if closedSince == nil { closedSince = time }; sleeping = time - (closedSince ?? time) >= 1.4 }
            else if eyes > 0.45 { closedSince = nil; sleeping = false }
        } else { closedSince = nil; sleeping = false }
        if input.raisedHand > 0.45, let x = input.handX {
            if time - waveStart > 1.8 { waveStart = time; reversals = 0; previousHand = nil; lastHandDirection = 0 }
            if let previousHand, abs(x - previousHand) > 0.025 {
                let direction: Float = x > previousHand ? 1 : -1
                if lastHandDirection != 0 && direction != lastHandDirection { reversals += 1 }
                lastHandDirection = direction
            }
            previousHand = x
            if reversals >= 2 && time - lastWave > 2.8 { lastWave = time; reversals = 0; return true }
        } else { previousHand = nil; reversals = 0; lastHandDirection = 0 }
        return false
    }
    mutating func expire(time: Double) { if time - lastSeen > 0.8 { reset() } }
    mutating func reset() { sample = .init(found: false); sleeping = false; closedSince = nil; previousHand = nil; reversals = 0 }
}

/// Voice deliberately accepts one short action, optionally a polite prefix.
/// Negation, multiple actions and conversation never cause a guessed movement.
nonisolated enum CreatureSpokenAction: String, CaseIterable, Sendable {
    case wave, dance, sleep, jump, blink, spin, stretch, stop
    static func parse(_ text: String) -> Self? {
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        guard !words.isEmpty, words.count <= 7 else { return nil }
        let aliases: [String: Self] = ["wave": .wave, "hello": .wave, "hi": .wave, "dance": .dance,
            "sleep": .sleep, "rest": .sleep, "nap": .sleep, "jump": .jump, "hop": .jump,
            "blink": .blink, "spin": .spin, "twirl": .spin, "stretch": .stretch, "stop": .stop]
        let polite = Set(["please", "fonster", "hey", "can", "you", "now"])
        let actions = words.filter { !polite.contains($0) }
        guard actions.count == 1 else { return nil }
        return aliases[actions[0]]
    }
    var symbol: String {
        switch self {
        case .wave: "hand.wave"; case .dance: "music.note"; case .sleep: "moon.zzz"; case .jump: "arrow.up"
        case .blink: "eye"; case .spin: "arrow.trianglehead.2.clockwise.rotate.90"; case .stretch: "figure.flexibility"; case .stop: "stop.fill"
        }
    }
}

/// A bounded rehearsal. The draft is disposable; only Keep writes three scalars.
nonisolated struct CreatureImitationLesson {
    enum Kind: String, CaseIterable { case wave, sway, voice }
    let kind: Kind
    private(set) var count = 0
    private(set) var draft = CreatureMovementStyle()
    private var first: Double?
    private var last: Double?
    private var sum: Float = 0
    private var previousSignal: Float?
    private var direction: Float = 0
    private var lastTurn: Double?
    private var turnIntervals: [Double] = []
    init(kind: Kind) { self.kind = kind }
    var progress: Double { min(1, Double(count) / (kind == .voice ? 3 : 24)) }
    var ready: Bool { progress == 1 }
    mutating func observe(_ sample: CreatureMirrorSample, time: Double) {
        guard kind != .voice, sample.found, sample.valid, !ready,
              kind != .wave || sample.raisedHand > 0.45 else { return }
        if let last, time - last < 0.15 { return }
        if first == nil { first = time }
        last = time; count += 1
        sum += kind == .wave ? sample.raisedHand : sample.motion
        let signal = kind == .wave ? sample.handX : sample.gaze.x
        if let signal, let previousSignal, abs(signal - previousSignal) > 0.01 {
            let nextDirection: Float = signal > previousSignal ? 1 : -1
            if direction != 0, nextDirection != direction {
                if let lastTurn, (0.18...2).contains(time - lastTurn) { turnIntervals.append(time - lastTurn); if turnIntervals.count > 8 { turnIntervals.removeFirst() } }
                lastTurn = time
            }
            direction = nextDirection
        }
        previousSignal = signal
        if ready {
            let strength = sum / Float(count)
            if kind == .wave { draft.wave = min(1.4, max(0.65, 0.75 + strength * 0.6)) }
            else { draft.amplitude = min(1.4, max(0.65, 0.7 + strength * 0.7)) }
            if !turnIntervals.isEmpty {
                let halfPeriod = turnIntervals.reduce(0, +) / Double(turnIntervals.count)
                draft.tempo = min(1.4, max(0.65, Float(0.5 / halfPeriod)))
            }
        }
    }
    mutating func observeVoice(time: Double) {
        guard kind == .voice, !ready, time.isFinite, last == nil || time - last! > 0.6 else { return }
        if first == nil { first = time }; last = time; count += 1
        if ready { draft.tempo = min(1.4, max(0.65, Float(4 / max(2.8, time - (first ?? time))))) }
    }
}
