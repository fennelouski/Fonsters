#if os(macOS)
import SwiftUI
import RealityKit
import Observation
import simd

@available(macOS 15.0, *)
@MainActor @Observable
final class PlayroomController {
    enum Reaction: String, CaseIterable { case idle, greet, play, rest, blink, look }
    private(set) var reaction: Reaction = .idle
    private(set) var message = "Coral is happy to see you."
    var soundEnabled = false
    @ObservationIgnored private let soundBank = CreatureSoundBank()
    var isSpeaking: Bool { soundBank.isPlaying }
    private(set) var personality: CreaturePersonality?
    private(set) var memoryStatus = "Memories stay on this Mac."
    @ObservationIgnored private var memories: PersonalityMemoryStore?
    var paused = false
    var staticMode = false
    var systemReduceMotion = false
    var backgrounded = false
    var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    var orbit: Double = -16
    var rendererError: String?
    var rendererReady = false
    @ObservationIgnored var rig: CreatureRig?
    @ObservationIgnored private var elapsed: Float = 0
    @ObservationIgnored private var actionTime: Float = 0
    @ObservationIgnored private var lastTime: Date?
    @ObservationIgnored private var gaze: SIMD2<Float> = .zero
    @ObservationIgnored private var actualGaze: SIMD2<Float> = .zero
    @ObservationIgnored private var pose: Pose = .init()
    @ObservationIgnored private var companionName = "Coral"
    private(set) var actionCount = 0
    @ObservationIgnored private(set) var frameCount = 0

    var shouldAnimate: Bool { !paused && !staticMode && !systemReduceMotion && !backgrounded && !lowPower && rendererReady }
    var motionStatus: String {
        if backgrounded { return "Paused in background" }
        if lowPower { return "Low Power · still" }
        if systemReduceMotion { return "Reduce Motion · still" }
        if staticMode { return "Still mode" }
        return paused ? "Paused" : "Living, at your pace"
    }
    struct Pose {
        var y: Float = 0, yaw: Float = 0, tilt: Float = 0, nod: Float = 0
        var squash: Float = 0, eyes: Float = 1, mouth: Float = 1, arms: Float = 0
    }

    func enablePersonalityLearning(_ store: PersonalityMemoryStore) {
        guard memories == nil else { return }
        memories = store
        personality = store.profile(for: companionName); memoryStatus = store.status
    }
    func likeSound(_ variant: Int) {
        guard let memories else { return }
        personality = memories.likeSound(variant, name: companionName); memoryStatus = memories.status
    }
    func auditionSound(_ variant: Int) {
        guard soundEnabled && !paused && !backgrounded else { return }
        soundBank.play("greet", preferredVariant: variant)
    }

    func install(_ rig: CreatureRig, name: String) {
        self.rig = rig; elapsed = 0; actionTime = 0; lastTime = nil; pose = .init()
        companionName = name
        if let memories { personality = memories.profile(for: name); memoryStatus = memories.status }
        reaction = .idle; message = "\(name) is happy to see you."
        rendererReady = true
        apply(pose)
        writeVerificationProbe()
    }
    func perform(_ action: Reaction, name: String, learn: Bool = true) {
        reaction = action; actionTime = 0; actionCount += 1
        if learn, let memories, let updated = memories.learn(action.rawValue, name: name) {
            personality = updated; memoryStatus = memories.status
        }
        switch action {
        case .greet: message = "\(name) says a tiny hello."
        case .play: message = "\(name) is doing a happy little dance."
        case .rest: message = "\(name) settles in. No rush."
        case .blink: message = "A little blink from \(name)."
        case .look: message = "You have \(name)’s full attention."
        case .idle: message = "\(name) is happy to see you."
        }
        if soundEnabled && !paused && !backgrounded && action != .idle { soundBank.play(action.rawValue, preferredVariant: personality?.favoriteSound) }
        // One replaceable reaction and one pose. Repeated input cannot queue animations.
        if !shouldAnimate { pose = targetPose(); apply(pose) }
        writeVerificationProbe()
    }
    func silence() { soundBank.stop() }
    func look(_ point: SIMD2<Float>) {
        gaze = point
    }
    func refreshStillPose() {
        lastTime = nil
        if paused || backgrounded { soundBank.stop(); apply(pose) }
        else if !shouldAnimate { pose = targetPose(); apply(pose) }
        writeVerificationProbe()
    }
    func animate() async {
        lastTime = nil
        while !Task.isCancelled && shouldAnimate {
            let now = Date()
            let dt = min(0.06, Float(lastTime.map { now.timeIntervalSince($0) } ?? (1.0 / 30)))
            lastTime = now; elapsed += dt; actionTime += dt; frameCount += 1
            if reaction != .rest && reaction != .idle && actionTime > duration {
                reaction = .idle; actionTime = 0; message = "\(companionName) is happy to see you."
            }
            let target = targetPose()
            let blend = 1 - exp(-dt * 11)
            pose.y += (target.y - pose.y) * blend
            pose.yaw += (target.yaw - pose.yaw) * blend
            pose.tilt += (target.tilt - pose.tilt) * blend
            pose.nod += (target.nod - pose.nod) * blend
            pose.squash += (target.squash - pose.squash) * blend
            pose.eyes += (target.eyes - pose.eyes) * min(1, blend * 2.3)
            pose.mouth += (target.mouth - pose.mouth) * blend
            pose.arms += (target.arms - pose.arms) * blend
            actualGaze += (gaze - actualGaze) * blend
            apply(pose)
            if frameCount % 15 == 0 { writeVerificationProbe() }
            do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
        }
    }
    // Opt-in local test evidence. The probe contains no identity or input data.
    private func writeVerificationProbe() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--probe-file"), index + 1 < args.count else { return }
        let state: [String: Any] = ["frames": frameCount, "animating": shouldAnimate,
            "background": backgrounded, "paused": paused, "still": staticMode,
            "reduceMotion": systemReduceMotion, "lowPower": lowPower, "reaction": reaction.rawValue,
            "actions": actionCount, "sounds": soundEnabled, "soundPlays": soundBank.playCount,
            "soundPlaying": soundBank.isPlaying, "learnedInteractions": personality?.interactionCount ?? 0,
            "favoriteSound": personality?.favoriteSound ?? -1]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: args[index + 1]), options: .atomic)
        }
    }

    private var duration: Float {
        switch reaction { case .greet: 2.6; case .play: 3.8; case .blink: 0.6; case .look: 2.8; default: 1000 }
    }
    private func targetPose() -> Pose {
        let moving = shouldAnimate
        let t = moving ? elapsed : 0
        let a = moving ? actionTime : 0.9
        var result = Pose(y: moving ? sin(t * 1.9) * 0.016 : 0,
                          yaw: sin(t * 0.53) * 0.035,
                          nod: sin(t * 1.1) * 0.018,
                          squash: moving ? sin(t * 1.9) * 0.012 : 0)
        if moving {
            let blink = t.truncatingRemainder(dividingBy: 4.7)
            if blink > 4.43 { result.eyes = max(0.055, abs(blink - 4.56) / 0.13) }
        }
        switch reaction {
        case .greet:
            let warmth = Float(personality?.greetingWarmth ?? 0.5)
            result.tilt = -0.10; result.arms = moving ? sin(a * 13) * (0.27 + warmth * 0.3) + 0.22 : 0.3 + warmth * 0.3
            result.nod = moving ? -0.08 + sin(a * 5) * 0.09 : -0.1; result.mouth = 1.25
        case .play:
            let energy = Float(personality?.playEnergy ?? 0.5)
            result.y = moving ? abs(sin(a * 5)) * (0.13 + energy * 0.24) : 0.08
            result.tilt = moving ? sin(a * 5) * 0.18 : 0.16
            result.squash = moving ? -cos(a * 10) * 0.08 : 0
            result.arms = moving ? sin(a * 10) * 0.33 : 0.35
            result.mouth = 1.35
        case .rest:
            result.y = -0.08; result.nod = 0.18; result.eyes = 0.06
            result.squash = -0.065; result.mouth = 0.55; result.arms = -0.09
        case .blink:
            result.eyes = moving ? max(0.05, abs(a - 0.25) / 0.23) : 0.06
        case .look:
            result.yaw = 0.12; result.tilt = -0.11; result.eyes = 1.12
        case .idle: break
        }
        result.eyes = min(1.12, result.eyes)
        return result
    }
    private func apply(_ pose: Pose) {
        guard let rig else { return }
        rig.root.position.y = rig.groundOffset + pose.y
        rig.root.orientation = simd_quatf(angle: Float(orbit) * .pi / 180 + pose.yaw, axis: [0, 1, 0]) *
            simd_quatf(angle: pose.tilt, axis: [0, 0, 1])
        rig.root.scale = [1 - pose.squash * 0.5, 1 + pose.squash, 1 - pose.squash * 0.5]
        rig.head.orientation = simd_quatf(angle: pose.nod, axis: [1, 0, 0]) *
            simd_quatf(angle: actualGaze.x * 0.09, axis: [0, 1, 0])
        for eye in rig.eyes { eye.scale.y = max(0.055, pose.eyes) }
        for pupil in rig.pupils { pupil.position.x = actualGaze.x * 0.045; pupil.position.y = actualGaze.y * 0.03 }
        rig.mouth?.scale = [1, pose.mouth, 1]
        for (i, brow) in rig.brows.enumerated() {
            brow.orientation = simd_quatf(angle: (i == 0 ? 1 : -1) * pose.tilt * 0.8, axis: [0, 0, 1])
        }
        for (i, limb) in rig.limbs.enumerated() {
            let side: Float = limb.joint.name.contains("L") ? 1 : -1
            let wave = reaction == .greet && i > 1 ? pose.arms * 0.2 : pose.arms
            limb.joint.orientation = simd_quatf(angle: limb.angle + wave * side, axis: [0, 0, 1])
            limb.bend.orientation = simd_quatf(angle: wave * side * 0.9, axis: [0, 0, 1])
        }
    }
}
#endif
