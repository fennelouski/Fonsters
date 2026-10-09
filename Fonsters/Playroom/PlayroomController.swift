#if os(macOS) || os(iOS) || os(tvOS)
import SwiftUI
import RealityKit
import Observation
import simd

@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
@MainActor @Observable
final class PlayroomController {
    enum Reaction: String, CaseIterable { case idle, greet, play, rest, blink, look, hop, spin, stretch, highFive, rub, fetch }
    private(set) var reaction: Reaction = .idle
    private(set) var message = "Coral is happy to see you."
    var soundEnabled = false
    @ObservationIgnored private let soundBank = CreatureSoundBank()
    var isSpeaking: Bool { soundBank.isPlaying }
    private(set) var personality: CreaturePersonality?
    var agentRituals = AgentRituals()
    private(set) var feeling: CreatureFeeling = .neutral
    private(set) var memoryStatus = "Memories stay on this Mac."
    @ObservationIgnored private var memories: PersonalityMemoryStore?
    @ObservationIgnored private var memoryIdentity: String?
    var paused = false
    var staticMode = false
    var systemReduceMotion = false
    var backgrounded = false
    var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    var orbit: Double = -16
    var rendererError: String?
    var rendererReady = false
    var environment = CompanionEnvironment.meadow
    var roaming = true
    var followingPointer = false
    private(set) var userRevision = 0
    @ObservationIgnored var rig: CreatureRig?
    @ObservationIgnored var toyBall: ModelEntity?
    @ObservationIgnored var touchCamera: PerspectiveCamera?
    @ObservationIgnored private(set) var touch = CreatureTouchDynamics()
    private(set) var touching = false
    @ObservationIgnored private var touchRecovery: Float = 0
    @ObservationIgnored private var lastTouchSound = -Double.greatestFiniteMagnitude
    @ObservationIgnored private(set) var groundPosition: SIMD2<Float> = .zero
    @ObservationIgnored private var wanderGoal: SIMD2<Float> = .zero
    @ObservationIgnored private var nextCuriosity: Float = 5
    @ObservationIgnored private var curiosityIndex = 0
    @ObservationIgnored private var locomotion: Float = 0
    @ObservationIgnored var autonomyEnabled = true
    @ObservationIgnored var writesProbe = true
    @ObservationIgnored var worldWalking = false
    @ObservationIgnored private var elapsed: Float = 0
    @ObservationIgnored private var actionTime: Float = 0
    @ObservationIgnored private var lastTime: Date?
    @ObservationIgnored private var gaze: SIMD2<Float> = .zero
    @ObservationIgnored private var actualGaze: SIMD2<Float> = .zero
    @ObservationIgnored private var pose: Pose = .init()
    @ObservationIgnored private var mirror = CreatureMirrorDynamics()
    @ObservationIgnored private var mirrorTime: Double = 0
    @ObservationIgnored private var handDynamics = CreatureHandDynamics()
    @ObservationIgnored private var mirrorHoldUntil: Float = 0
    @ObservationIgnored private var face = CreatureFaceDynamics()
    @ObservationIgnored private var attention: CreatureAttention.Target?
    @ObservationIgnored private var bodyAttentionYaw: Float = 0
    @ObservationIgnored private var headAttention: SIMD2<Float> = .zero
    @ObservationIgnored private var eyeAttention: SIMD2<Float> = .zero
    @ObservationIgnored private var viewerAttentionUntil: Float = 0
    var prefersViewerAttention: Bool { elapsed < viewerAttentionUntil || mirror.sample.found }
    var attentionMode: CreatureAttention.Mode { attention?.mode ?? .viewer }
    var renderedExpression: CreatureFacialExpression { .init(smile: pose.smile, smilingEyes: pose.smilingEyes) }
    var renderedHeadAngles: SIMD2<Float> { headAttention }
    var listening = false
    var dancingContinuously = false
    var movementPreview: CreatureMovementStyle?
    @ObservationIgnored private var companionName = "Coral"
    private(set) var actionCount = 0
    @ObservationIgnored private(set) var frameCount = 0

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--verify-manual") { autonomyEnabled = false; roaming = false }
        if let i = arguments.firstIndex(of: "--environment"), i + 1 < arguments.count,
           let theme = CompanionEnvironment(rawValue: arguments[i + 1]) { environment = theme }
    }

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
        var squash: Float = 0, eyes: Float = 0.94, mouth: Float = 1, arms: Float = 0
        var smile: Float = 0.45, smilingEyes: Float = 0.15
    }

    struct ControlState: Equatable {
        var selection: Int
        var environment: CompanionEnvironment
        var orbit: Double
        var sounds: Bool
        var roaming: Bool
        var following: Bool
        var paused: Bool
        var still: Bool
    }
    func controls(selection: Int) -> ControlState {
        .init(selection: selection, environment: environment, orbit: orbit, sounds: soundEnabled,
              roaming: roaming, following: followingPointer, paused: paused, still: staticMode)
    }
    func restoreControls(_ state: ControlState) {
        cancelTouch(); silence(); userRevision += 1
        if environment != state.environment { rendererReady = false }
        environment = state.environment; orbit = state.orbit; soundEnabled = state.sounds
        setRoaming(state.roaming); followingPointer = state.following; paused = state.paused; staticMode = state.still
        message = "Previous controls restored."
        refreshStillPose()
    }
    func stopActivity() {
        cancelTouch(); silence(); wanderGoal = groundPosition; nextCuriosity = elapsed + 6
        perform(.idle, name: companionName, learn: false, audible: false); userRevision += 1
        message = "Activity stopped. Shared memories stay with you."
    }

    func enablePersonalityLearning(_ store: PersonalityMemoryStore, identity: String? = nil, name: String? = nil) {
        guard memories == nil else { return }
        memories = store; memoryIdentity = identity
        personality = store.profile(for: name ?? companionName, identity: identity); memoryStatus = store.status
    }
    func rename(_ name: String) {
        message = message.replacingOccurrences(of: companionName, with: name)
        companionName = name
    }
    func likeSound(_ variant: Int) {
        guard let memories else { return }
        personality = memories.likeSound(variant, name: memoryIdentity ?? companionName); memoryStatus = memories.status
    }
    func useVisitorTemperament(_ card: FonsterVisitCard) {
        guard memories == nil else { return }
        personality = .init(visitorID: card.publicID, warmth: card.temperament.warmth, energy: card.temperament.energy)
        memoryStatus = "This guest's private memories stay with its owner."
        setFeeling(card.feeling ?? .neutral)
    }
    func setFeeling(_ chosen: CreatureFeeling) {
        feeling = chosen; userRevision += 1
        let expression = expressionBaseline(moving: false)
        face.reset(to: expression); pose.smile = expression.smile; pose.smilingEyes = expression.smilingEyes
        refreshStillPose(); apply(pose)
    }
    func auditionSound(_ variant: Int) {
        guard soundEnabled && !paused && !backgrounded && !lowPower else { return }
        soundBank.play("greet", preferredVariant: variant)
    }

    func install(_ rig: CreatureRig, name: String) {
        cancelTouch()
        self.rig = rig; elapsed = 0; actionTime = 0; lastTime = nil; pose = .init()
        userRevision += 1
        groundPosition = .zero; wanderGoal = .zero; nextCuriosity = 2.5; curiosityIndex = 0; locomotion = 0
        companionName = name
        if let memories { personality = memories.profile(for: name, identity: memoryIdentity); memoryStatus = memories.status }
        reaction = .idle; message = "\(name) is happy to see you."
        rendererReady = true
        bodyAttentionYaw = 0; headAttention = .zero; eyeAttention = .zero; attention = nil
        face.reset(to: expressionBaseline(moving: false)); pose = targetPose()
        apply(pose)
        writeVerificationProbe()
    }
    func perform(_ action: Reaction, name: String, learn: Bool = true, audible: Bool = true) {
        cancelTouch(); touchRecovery = 0
        mirror.reset(); dancingContinuously = false
        reaction = action; actionTime = 0; actionCount += 1
        if learn { mirrorHoldUntil = elapsed + duration; viewerAttentionUntil = elapsed + duration + 1 }
        if learn { userRevision += 1; wanderGoal = groundPosition; nextCuriosity = elapsed + 6 }
        let ritual: String
        switch action {
        case .hop, .spin, .fetch: ritual = "play"
        case .highFive: ritual = "greet"
        case .rub, .stretch: ritual = "rest"
        default: ritual = action.rawValue
        }
        if learn, let memories, let updated = memories.learn(ritual, name: memoryIdentity ?? name) {
            personality = updated; memoryStatus = memories.status
        }
        switch action {
        case .greet: message = "\(name) says a tiny hello."
        case .play: message = "\(name) is doing a happy little dance."
        case .rest: message = "\(name) settles in. No rush."
        case .blink: message = "A little blink from \(name)."
        case .look: message = "You have \(name)’s full attention."
        case .hop: message = "\(name) tries a happy little hop."
        case .spin: message = "One little twirl from \(name)."
        case .stretch: message = "\(name) takes a lovely long stretch."
        case .highFive: message = "A tiny high five from \(name)!"
        case .rub: message = "\(name) leans into a gentle rub."
        case .fetch: message = "\(name) is chasing the little ball."
        case .idle: message = "\(name) is happy to see you."
        }
        if audible && soundEnabled && !listening && !paused && !backgrounded && !lowPower && action != .idle {
            let cue = ["greet", "play", "rest", "blink", "look"].contains(ritual) ? ritual : "play"
            soundBank.play(cue, preferredVariant: personality?.favoriteSound)
        }
        // One replaceable reaction and one pose. Repeated input cannot queue animations.
        if !shouldAnimate { pose = targetPose(); apply(pose) }
        writeVerificationProbe()
    }
    func silence() { soundBank.stop() }
    func receiveMirror(_ sample: CreatureMirrorSample, time: Double) {
        guard shouldAnimate, !touch.active, sample.valid, elapsed >= mirrorHoldUntil else { return }
        let waving = mirror.receive(sample, time: time); mirrorTime = time
        if let handReaction = handDynamics.receive(sample.found ? sample.hands : [], time: time),
           let reaction = Reaction(rawValue: handReaction.rawValue) {
            perform(reaction, name: companionName, learn: false)
        }
        if waving { viewerAttentionUntil = elapsed + 2 }
        gaze = mirror.sample.gaze
    }
    func clearMirror() { handDynamics.reset(); mirror.reset(); face.reset(to: expressionBaseline(moving: shouldAnimate)); gaze = .zero }
    func setAttention(_ target: CreatureAttention.Target) {
        guard target.point.x.isFinite, target.point.y.isFinite, target.point.z.isFinite else { return }
        attention = target
        if !shouldAnimate && !paused && !backgrounded && !lowPower { apply(pose) }
    }
    func keepMovementStyle(_ style: CreatureMovementStyle?) {
        guard let memories, let updated = memories.keepMoves(style, identity: memoryIdentity ?? companionName) else { return }
        personality = updated; movementPreview = nil; memoryStatus = memories.status
    }
    func look(_ point: SIMD2<Float>) {
        guard !touch.active else { return }
        gaze = [point.x.isFinite ? min(1, max(-1, point.x)) : 0,
                point.y.isFinite ? min(1, max(-1, point.y)) : 0]
    }
    func beginTouch(_ sample: CreatureTouchDynamics.Sample) -> Bool {
        guard rendererReady, !paused, !backgrounded, !lowPower,
              touch.begin(sample, warmth: Float(personality?.greetingWarmth ?? 0.5), playEnergy: Float(personality?.playEnergy ?? 0.5)) else { return false }
        touching = true; userRevision += 1; reaction = .idle; actionTime = 0
        pose.yaw = atan2(sin(pose.yaw), cos(pose.yaw))
        wanderGoal = groundPosition; nextCuriosity = elapsed + 6; touchRecovery = 6
        soundBank.stop(); gaze = touch.response.gaze
        describeTouch(); applyTouchImmediately()
        return true
    }
    func moveTouch(_ sample: CreatureTouchDynamics.Sample) {
        guard !paused, !backgrounded, !lowPower else { cancelTouch(); return }
        touch.move(sample); touching = touch.active
        if touch.active { gaze = touch.response.gaze; describeTouch(); applyTouchImmediately() }
    }
    func endTouch(at time: Double = ProcessInfo.processInfo.systemUptime) {
        guard let manner = touch.end(at: time) else { cancelTouch(); return }
        touching = false; touchRecovery = 6
        // At most one learned ritual and one sound per meaningful completed stroke.
        // Pointer samples never write memories or sound files.
        let meaningful = touch.duration >= 0.35 && touch.distance >= 0.08
        let ritual = manner == .tickle || manner == .lively ? "play" : manner == .highFive ? "greet" : "rest"
        if meaningful, manner != .blink, let memories, let updated = memories.learn(ritual, name: memoryIdentity ?? companionName) {
            personality = updated; memoryStatus = memories.status
        }
        if soundEnabled && !paused && !backgrounded && !lowPower && time - lastTouchSound >= 0.6 {
            lastTouchSound = time
            soundBank.play(manner == .tickle || manner == .lively ? "play" : "greet", preferredVariant: personality?.favoriteSound)
        }
        if !shouldAnimate { touch.cancel(); applyTouchImmediately() }
        writeVerificationProbe()
    }
    func cancelTouch() { touch.cancel(); touching = false }
    func beginTouch(at point: CGPoint, size: CGSize) -> Bool {
        guard let camera = touchCamera, let ray = CreatureRig.touchRay(at: point, size: size, camera: camera),
              let hit = rig?.touchHit(origin: ray.origin, direction: ray.direction) else { return false }
        return beginTouch(hit.sample(at: ProcessInfo.processInfo.systemUptime))
    }
    func moveTouch(at point: CGPoint, size: CGSize) {
        guard touch.active, let camera = touchCamera, let ray = CreatureRig.touchRay(at: point, size: size, camera: camera),
              let hit = rig?.touchHit(origin: ray.origin, direction: ray.direction) else { endTouch(); return }
        moveTouch(hit.sample(at: ProcessInfo.processInfo.systemUptime))
    }
    private func describeTouch() {
        let suffix: String
        switch touch.response.manner {
        case .attention: suffix = "notices your touch."
        case .softStroke: suffix = "leans into your gentle stroke."
        case .cuddle: suffix = "settles into a little cuddle."
        case .tickle: suffix = "has a ticklish little giggle!"
        case .lively: suffix = "bobs back with a playful smile."
        case .highFive: suffix = "meets your hand with a high five!"
        case .blink: suffix = "gives a soft little blink."
        }
        let next = "\(companionName) \(suffix)"
        if message != next { message = next }
    }
    private func applyTouchImmediately() {
        if !shouldAnimate {
            // Explicit still-mode contact changes only the expression, never body motion.
            pose.eyes = touch.active ? touch.response.eyes : targetPose().eyes
            pose.mouth = touch.active ? touch.response.smile : targetPose().mouth
            let base = targetPose()
            pose.smile = touch.active ? min(1, max(0.06, (touch.response.smile - 0.55) * 1.1)) : base.smile
            pose.smilingEyes = touch.active ? max(0, pose.smile) * 0.6 : base.smilingEyes
            if feeling == .low { pose.smile = min(-0.15, base.smile); pose.smilingEyes = 0 }
            apply(pose)
        }
    }
    func followPointer() {
        followingPointer.toggle(); userRevision += 1
        if reaction == .rest { perform(.idle, name: companionName) }
        message = followingPointer ? "\(companionName) follows your pointer. Try a slow little circle." : "\(companionName) is happy to see you."
    }
    func stopMoving() {
        followingPointer = false; roaming = false; wanderGoal = groundPosition
        perform(.idle, name: companionName)
        message = "\(companionName) stays beside you."
    }
    func setRoaming(_ enabled: Bool) { roaming = enabled; userRevision += 1; if !enabled { wanderGoal = groundPosition } }
    func execute(_ intent: CreatureCommandIntent) {
        guard intent.targetName == companionName else { return }
        switch intent.action {
        case .hello: perform(.greet, name: companionName)
        case .dance: perform(.play, name: companionName)
        case .rest: perform(.rest, name: companionName)
        case .blink: perform(.blink, name: companionName)
        case .look: perform(.look, name: companionName)
        case .hop: perform(.hop, name: companionName)
        case .spin: perform(.spin, name: companionName)
        case .stretch: perform(.stretch, name: companionName)
        case .highFive: perform(.highFive, name: companionName)
        case .rub: perform(.rub, name: companionName)
        case .fetch: perform(.fetch, name: companionName)
        case .follow: if !followingPointer { followPointer() }
        case .roam: followingPointer = false; roaming = true; perform(.idle, name: companionName); nextCuriosity = elapsed + 0.5
        case .stop: stopMoving()
        case .greetFriend: break // Peer requests are validated and executed by the local lobby.
        }
    }
    func refreshStillPose() {
        lastTime = nil
        if !shouldAnimate { cancelTouch() }
        if paused || backgrounded || lowPower { soundBank.stop(); apply(pose) }
        else if !shouldAnimate { pose = targetPose(); apply(pose) }
        writeVerificationProbe()
    }
    func animate() async {
        lastTime = nil
        while !Task.isCancelled && shouldAnimate {
            let now = Date()
            let dt = min(0.06, Float(lastTime.map { now.timeIntervalSince($0) } ?? (1.0 / 30)))
            lastTime = now; advance(dt: dt)
            do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
        }
    }
    /// The lobby uses one shared clock for all rigs; the solo view uses animate().
    func advance(dt rawDT: Float) {
        guard shouldAnimate && rawDT.isFinite else { return }
        let dt = min(0.06, max(0, rawDT))
        if touch.active {
            touch.hold(at: ProcessInfo.processInfo.systemUptime)
            touching = touch.active; gaze = touch.response.gaze
            if touch.active { describeTouch() }
        } else { touch.settle(dt: dt) }
        touchRecovery = max(0, touchRecovery - dt)
        elapsed += dt; actionTime += dt; frameCount += 1
        if !dancingContinuously && reaction != .rest && reaction != .idle && actionTime > duration {
            if reaction == .spin { pose.yaw -= 2 * .pi }
            reaction = .idle; actionTime = 0; message = "\(companionName) is happy to see you."
        }
        if !touch.active && touchRecovery == 0 && autonomyEnabled && roaming && !followingPointer && reaction == .idle && elapsed > nextCuriosity {
            curiosityIndex += 1; nextCuriosity = elapsed + 3.8 + Float(curiosityIndex % 3) * 0.7
            wanderGoal = [sin(Float(curiosityIndex) * 2.1) * 0.48, cos(Float(curiosityIndex) * 1.7) * 0.29]
            let rituals: [Reaction] = [.look, .hop, .greet, .stretch, .play, .blink]
            if curiosityIndex % 2 == 0 { perform(rituals[(curiosityIndex / 2) % rituals.count], name: companionName, learn: false, audible: false) }
            gaze = [wanderGoal.x * 1.5, 0.12 + wanderGoal.y]
        }
        var targetGround = groundPosition
        if touch.active || touchRecovery > 0 {
            targetGround = groundPosition
        } else if reaction == .fetch {
            targetGround = actionTime < 2.8 ? [-0.30, 0.10] : [0.15, 0]
        } else if reaction == .idle {
            if followingPointer { targetGround = [gaze.x * 0.32, -gaze.y * 0.15] }
            else if roaming { targetGround = wanderGoal }
        }
        let delta = targetGround - groundPosition
        let distance = simd_length(delta)
        let step = min(distance, dt * (reaction == .fetch ? 0.48 : 0.24))
        if distance > 0.0001 { groundPosition += delta / distance * step }
        locomotion = dt > 0 ? step / dt : 0
        mirror.expire(time: mirrorTime + Double(dt)); mirrorTime += Double(dt)
        face.advance(dt: dt, baseline: expressionBaseline(moving: true), sample: mirror.sample, low: feeling == .low)
        var target = targetPose()
        if mirror.sample.found && !touch.active {
            target.tilt += mirror.sample.tilt + mirror.sample.bodyLean
            target.y -= mirror.sample.crouch * 0.12
            target.squash -= mirror.sample.crouch * 0.08
            target.arms += mirror.sample.raisedHand * 0.15
            if let eyes = mirror.sample.eyeOpenness { target.eyes = min(1, max(0.06, eyes)) }
            if mirror.sleeping { target.eyes = 0.06; target.nod = 0.18; target.y = -0.08; target.arms = -0.09; target.smile = 0; target.smilingEyes = 0 }
            else { target.y += sin(elapsed * 5) * mirror.sample.motion * 0.05; target.squash += mirror.sample.motion * 0.03 }
        }
        let contact = touch.response
        target.tilt += contact.lean; target.nod += contact.nod; target.squash += contact.squash
        target.y += contact.lift; target.arms += contact.arms
        if touch.active || contact.energy > 0.005 || abs(contact.eyes - 0.94) > 0.005 {
            target.eyes = contact.eyes; target.mouth = contact.smile
            target.smile = min(1, max(0.06, (contact.smile - 0.55) * 0.9)); target.smilingEyes = max(0, target.smile) * 0.6
            if contact.manner == .tickle && touch.active { target.tilt += sin(elapsed * 18) * 0.025 * contact.energy }
        }
        if feeling == .low { target.smile = min(-0.15, target.smile); target.smilingEyes = 0 }
        let blend = 1 - exp(-dt * (touch.active ? 18 : 11))
        pose.y += (target.y - pose.y) * blend; pose.yaw += (target.yaw - pose.yaw) * blend
        pose.tilt += (target.tilt - pose.tilt) * blend; pose.nod += (target.nod - pose.nod) * blend
        pose.squash += (target.squash - pose.squash) * blend
        pose.eyes += (target.eyes - pose.eyes) * min(1, blend * 2.3)
        pose.mouth += (target.mouth - pose.mouth) * blend; pose.arms += (target.arms - pose.arms) * blend
        pose.smile += (target.smile - pose.smile) * blend; pose.smilingEyes += (target.smilingEyes - pose.smilingEyes) * blend
        actualGaze += (gaze - actualGaze) * blend
        apply(pose, dt: dt)
        if frameCount % 15 == 0 { writeVerificationProbe() }
    }
    // Opt-in local test evidence. The probe contains no identity or input data.
    private func writeVerificationProbe() {
        guard writesProbe else { return }
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--probe-file"), index + 1 < args.count else { return }
        let state: [String: Any] = ["frames": frameCount, "animating": shouldAnimate,
            "background": backgrounded, "paused": paused, "still": staticMode,
            "reduceMotion": systemReduceMotion, "lowPower": lowPower, "reaction": reaction.rawValue,
            "actions": actionCount, "sounds": soundEnabled, "soundPlays": soundBank.playCount,
            "soundPlaying": soundBank.isPlaying, "learnedInteractions": personality?.interactionCount ?? 0,
            "favoriteSound": personality?.favoriteSound ?? -1, "roaming": roaming,
            "touching": touching, "touchManner": touch.response.manner.rawValue,
            "groundX": groundPosition.x, "groundZ": groundPosition.y]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: args[index + 1]), options: .atomic)
        }
    }

    private var duration: Float {
        switch reaction {
        case .greet: 2.6; case .play: 3.8; case .blink: 0.6; case .look: 2.8
        case .hop: 2.2; case .spin: 3; case .stretch: 3.4; case .highFive: 2; case .rub: 3.2; case .fetch: 5
        default: 1000
        }
    }
    private func expressionBaseline(moving: Bool) -> CreatureFacialExpression {
        let t = moving ? elapsed : 0, phase = rig?.expressionPhase ?? 0
        var expression = CreatureFacialExpression.casual(time: t, phase: phase, low: feeling == .low, quiet: feeling.prefersQuietCompany)
        if feeling == .low { return expression }
        if reaction == .rest { return .init(smile: 0, smilingEyes: 0) }
        if [.greet, .play, .hop, .highFive].contains(reaction) {
            let a = moving ? actionTime : 0.6
            let burst = dancingContinuously ? 0.55 + 0.25 * sin(t * 0.8 + phase) : max(0, 1 - max(0, a - 0.65) / 2)
            expression.smile = max(expression.smile, burst * (reaction == .play ? 0.92 : 0.82))
            expression.smilingEyes = expression.smile * expression.smile * 0.8
        }
        return expression
    }
    private func targetPose() -> Pose {
        let moving = shouldAnimate
        let t = moving ? elapsed : 0
        let a = moving ? actionTime : 0.9
        let style = movementPreview ?? personality?.learnedMoves ?? .init()
        var result = Pose(y: moving ? sin(t * 1.9) * 0.016 : 0,
                          yaw: sin(t * 0.53) * 0.035,
                          nod: sin(t * 1.1) * 0.018,
                          squash: moving ? sin(t * 1.9) * 0.012 : 0)
        if feeling.prefersQuietCompany {
            result.nod += 0.035; result.eyes = 0.82; result.y -= 0.02
        } else if feeling == .curious { result.nod -= 0.025; result.tilt += 0.025 }
        if moving {
            let blink = t.truncatingRemainder(dividingBy: 4.7)
            if blink > 4.43 { result.eyes = max(0.055, abs(blink - 4.56) / 0.13) }
            if locomotion > 0.02 || worldWalking { result.y += abs(sin(t * 8)) * 0.065; result.tilt += sin(t * 8) * 0.065; result.arms = sin(t * 8) * 0.20 }
        }
        switch reaction {
        case .greet:
            let warmth = Float(agentRituals.warmth(personality?.greetingWarmth ?? 0.5))
            result.tilt = -0.10; result.arms = moving ? sin(a * 13 * style.tempo) * (0.27 + warmth * 0.3) * style.wave + 0.22 : 0.3 + warmth * 0.3
            result.nod = moving ? -0.08 + sin(a * 5) * 0.09 : -0.1; result.mouth = 1.25
        case .play:
            let energy = Float(agentRituals.energy(personality?.playEnergy ?? 0.5)) * feeling.energy
            result.y = moving ? abs(sin(a * 5 * style.tempo)) * (0.13 + energy * 0.24) * style.amplitude : 0.08
            result.tilt = moving ? sin(a * 5 * style.tempo) * 0.18 * style.amplitude : 0.16
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
        case .hop:
            result.y = moving ? max(0, sin(a * 4.5)) * 0.36 * feeling.energy : 0.10
            result.squash = moving ? -cos(a * 9) * 0.055 : 0
            result.arms = 0.30; result.mouth = 1.25
        case .spin:
            result.yaw = moving ? min(1, a / 2.4) * 2 * .pi : 0.45
            result.arms = 0.4; result.tilt = 0.08; result.eyes = 0.8
        case .stretch:
            result.squash = 0.12; result.arms = 0.80; result.nod = -0.12; result.eyes = 0.5
        case .highFive:
            result.arms = 0.8; result.tilt = -0.12; result.mouth = 1.2; result.y = 0.08
        case .rub:
            result.tilt = moving ? sin(a * 3) * 0.12 : 0.12
            result.eyes = 0.28; result.nod = -0.08; result.mouth = 0.7
        case .fetch:
            result.y = moving ? abs(sin(a * 8)) * 0.08 : 0
            result.yaw = actionTime < 2.8 ? -0.35 : 0.30; result.arms = 0.15; result.eyes = 1.1
        case .idle: break
        }
        let expression = moving ? face.expression : expressionBaseline(moving: false)
        result.smile = feeling == .low ? min(-0.15, expression.smile) : expression.smile
        result.smilingEyes = feeling == .low ? 0 : expression.smilingEyes
        result.eyes = min(1.12, result.eyes)
        return result
    }
    private func updateAttention(rig: CreatureRig, pose: Pose, dt: Float) {
        guard !paused && !backgrounded && !lowPower && !touch.active && (!followingPointer || mirror.sample.found) else { return }
        let origin = rig.head.position(relativeTo: nil)
        var target = attention ?? .init(mode: .viewer, point: touchCamera?.position(relativeTo: nil) ?? origin + SIMD3<Float>(0, 0.5, 4))
        if mirror.sample.found, let camera = touchCamera {
            target = .init(mode: .viewer, point: camera.position(relativeTo: nil), cameraUp: target.cameraUp)
        }
        var direction = target.point - origin
        if target.mode == .viewer && !mirror.sample.found {
            let degrees: Float = 9 + (shouldAnimate ? sin(elapsed * 0.33 + rig.expressionPhase) * 6 : 0)
            direction = CreatureAttention.viewerDirection(from: origin, camera: target.point, up: target.cameraUp, degrees: degrees)
        }
        if mirror.sample.found && target.mode == .viewer {
            let distance = max(1, simd_length(direction))
            let rotation = touchCamera?.orientation(relativeTo: nil) ?? simd_quatf()
            direction += rotation.act(SIMD3<Float>(mirror.sample.gaze.x * 0.45, mirror.sample.gaze.y * 0.3, 0)) * distance
        }
        guard simd_length_squared(direction) > 0.0001 else { return }
        let blend: Float = dt > 0 ? 1 - exp(-dt * 6) : 1
        if target.mode != .travel && reaction != .spin {
            let parentDirection = rig.root.parent?.convert(direction: direction, from: nil) ?? direction
            let desired = atan2(parentDirection.x, parentDirection.z) - Float(orbit) * .pi / 180 - pose.yaw
            let turn = atan2(sin(desired), cos(desired))
            let bodyTarget = abs(turn) > 0.55 ? turn - (turn > 0 ? 0.25 : -0.25) : 0
            let difference = atan2(sin(bodyTarget - bodyAttentionYaw), cos(bodyTarget - bodyAttentionYaw))
            bodyAttentionYaw += difference * blend * 0.55
        } else { bodyAttentionYaw *= 1 - blend }
        rig.root.orientation = simd_quatf(angle: Float(orbit) * .pi / 180 + pose.yaw + bodyAttentionYaw, axis: [0, 1, 0]) *
            simd_quatf(angle: pose.tilt, axis: [0, 0, 1])
        let local = rig.root.convert(direction: direction, from: nil)
        let angles = CreatureAttention.angles(local)
        let headTarget = SIMD2<Float>(min(1.2, max(-1.2, angles.x)) * 0.82, min(1.15, max(-0.7, angles.y)) * 0.8)
        headAttention += (headTarget - headAttention) * blend
        eyeAttention = simd_clamp(angles - headAttention, SIMD2(repeating: -0.35), SIMD2(repeating: 0.35))
    }
    private func apply(_ pose: Pose, dt: Float = 0) {
        guard let rig else { return }
        rig.root.position = [groundPosition.x, rig.groundOffset + pose.y, groundPosition.y]
        rig.root.orientation = simd_quatf(angle: Float(orbit) * .pi / 180 + pose.yaw + bodyAttentionYaw, axis: [0, 1, 0]) *
            simd_quatf(angle: pose.tilt, axis: [0, 0, 1])
        rig.root.scale = [1 - pose.squash * 0.5, 1 + pose.squash, 1 - pose.squash * 0.5]
        updateAttention(rig: rig, pose: pose, dt: dt)
        let contact = touch.active || (followingPointer && !mirror.sample.found)
        rig.head.orientation = simd_quatf(angle: contact ? actualGaze.x * 0.14 : headAttention.x, axis: [0, 1, 0]) *
            simd_quatf(angle: pose.nod - (contact ? 0 : headAttention.y), axis: [1, 0, 0]) *
            simd_quatf(angle: pose.tilt * 0.45, axis: [0, 0, 1])
        for eye in rig.eyes { eye.scale.y = max(0.055, pose.eyes * (1 - pose.smilingEyes * 0.16)) }
        for (index, pupil) in rig.pupils.enumerated() {
            let yaw = contact ? actualGaze.x * 0.25 : eyeAttention.x
            let pitch = contact ? actualGaze.y * 0.2 : eyeAttention.y
            let travel = rig.pupilTravel[index]
            pupil.position = [sin(yaw) / sin(0.35) * travel.x, sin(pitch) / sin(0.35) * travel.y, 0.105 - (1 - cos(yaw) * cos(pitch)) * 0.04]
            pupil.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: -pitch, axis: [1, 0, 0])
        }
        rig.express(smile: pose.smile, smilingEyes: pose.smilingEyes * min(1, pose.eyes * 2), opening: pose.mouth)
        for (i, brow) in rig.brows.enumerated() {
            brow.orientation = simd_quatf(angle: (i == 0 ? 1 : -1) * pose.tilt * 0.8, axis: [0, 0, 1])
        }
        for (i, limb) in rig.limbs.enumerated() {
            let side: Float = limb.joint.name.contains("L") ? 1 : -1
            var wave = reaction == .greet && i > 1 ? pose.arms * 0.2 : pose.arms
            if mirror.sample.found && !mirror.sleeping && !touch.active {
                wave += (side > 0 ? mirror.sample.leftArm : mirror.sample.rightArm) * 0.75
            }
            limb.joint.orientation = simd_quatf(angle: limb.angle + wave * side, axis: [0, 0, 1])
            limb.bend.orientation = simd_quatf(angle: wave * side * 0.9, axis: [0, 0, 1])
        }
        if let toyBall {
            if reaction == .fetch {
                let a = shouldAnimate ? actionTime : 1.3
                if a < 1.2 {
                    let fraction = a / 1.2
                    toyBall.position = [0.68 - fraction * 1.20, -0.93 + sin(fraction * .pi) * 0.55, 0.32]
                } else if a < 2.8 { toyBall.position = [-0.52, -0.93, 0.32] }
                else { toyBall.position = [-0.52 + min(1, (a - 2.8) / 2) * 1.20, -0.93, 0.32] }
            } else { toyBall.position = [0.68, -0.93, 0.32] }
        }
    }
}
#endif
