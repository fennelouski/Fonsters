import Foundation
import simd
@main struct VerifyMirroring {
 @MainActor static func main() throws {
  func check(_ value: Bool, _ label: String) { precondition(value, label); print("PASS " + label) }
  for action in CreatureSpokenAction.allCases {
   check(CreatureSpokenAction.parse(action.rawValue) == action, "spoken " + action.rawValue)
  }
  for text in ["don't dance", "do not sleep", "dance and jump", "I don't want you to dance", "jump off a bridge", "share my profile", "", "stop dancing", "make an account", "wave then sleep", "please ignore and dance"] {
   check(CreatureSpokenAction.parse(text) == nil, "reject ambiguous/negated phrase: " + text)
  }
  check(CreatureSpokenAction.parse("Can you please dance now?") == .dance, "bounded polite action")
  var mirror = CreatureMirrorDynamics()
  for i in 0..<4 { _ = mirror.receive(.init(eyeOpenness: 0.1), time: Double(i) * 0.2) }
  check(!mirror.sleeping, "brief eye closure never sleeps")
  for i in 4..<10 { _ = mirror.receive(.init(eyeOpenness: 0.1), time: Double(i) * 0.2) }
  check(mirror.sleeping, "sustained closure settles")
  _ = mirror.receive(.init(eyeOpenness: 1), time: 2)
  check(!mirror.sleeping, "open eyes wake immediately")
  var waves = 0
  for i in 0..<30 {
   if mirror.receive(.init(eyeOpenness: 1, raisedHand: 0.9, handX: Float(i % 2) * 0.15), time: 3 + Double(i) * 0.2) { waves += 1 }
  }
  check((1...3).contains(waves), "raised-hand reversals wave with cooldown")
  mirror.expire(time: 15); check(!mirror.sample.found && !mirror.sleeping, "lost camera returns to neutral")
  _ = mirror.receive(.init(gaze: [.nan, 0], eyeOpenness: 0), time: 16)
  check(!mirror.sample.found, "nonfinite cues rejected")
  _ = mirror.receive(.init(bodyLean: 0.2, leftArm: 0.8, rightArm: 0.3, crouch: 0.4), time: 17)
  check(mirror.sample.bodyLean == 0.2 && mirror.sample.leftArm == 0.8 && mirror.sample.crouch == 0.4, "body and both arm cues remain bounded and available")
  _ = mirror.receive(.init(bodyLean: .nan), time: 17.1)
  check(mirror.sample.bodyLean == 0.2, "invalid body motion cannot replace a valid pose")
  var lesson = CreatureImitationLesson(kind: .sway)
  for i in 0..<30 { lesson.observe(.init(motion: 0.9), time: Double(i) * 0.2) }
  check(lesson.ready && lesson.draft.valid && lesson.draft.amplitude > 1, "bounded visual rehearsal produces a stronger sway")
  var voice = CreatureImitationLesson(kind: .voice)
  for t in [1.0, 3.0, 5.0] { voice.observeVoice(time: t) }
  check(voice.ready && voice.draft.valid, "three discrete spoken dances teach timing only")
  let folder = URL(fileURLWithPath: CommandLine.arguments[1]); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let file = folder.appendingPathComponent("personality.json")
  let store = PersonalityMemoryStore(url: file), initial = store.profile(for: "friend", identity: "private-care")
  let kept = store.keepMoves(lesson.draft, identity: "private-care")!
  check(kept.publicID == initial.publicID && kept.learnedMoves == lesson.draft, "learning preserves appearance/public identity")
  check(PersonalityMemoryStore(url: file).profile(for: "friend", identity: "private-care").learnedMoves == lesson.draft, "movement memory survives reopen")
  _ = store.keepMoves(nil, identity: "private-care")
  check(store.profile(for: "friend", identity: "private-care").learnedMoves == nil, "undo/reset clears only learned movement")
  var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(initial)) as! [String: Any]
  object.removeValue(forKey: "learnedMoves")
  let oldData = try JSONSerialization.data(withJSONObject: object)
  let old = try JSONDecoder().decode(CreaturePersonality.self, from: oldData)
  check(old.publicID == initial.publicID && old.learnedMoves == nil, "old v1 personality remains readable without migration")
  let suite = "fonsters.camera.verify." + UUID().uuidString
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let history = CameraUseHistory(defaults: defaults)
  let now = Date(timeIntervalSince1970: 2_000_000_000)
  check(history.needsEducation(at: now), "first camera use requires education")
  history.reviewed(at: now)
  check(!history.needsEducation(at: now.addingTimeInterval(CameraUseHistory.interval - 1)), "review within 30 days skips education")
  check(history.needsEducation(at: now.addingTimeInterval(CameraUseHistory.interval)), "30-day boundary renews education")
  history.used(at: now.addingTimeInterval(20 * 86400))
  check(!history.needsEducation(at: now.addingTimeInterval(49 * 86400)), "recent use extends education freshness")
  check(history.needsEducation(at: now.addingTimeInterval(50 * 86400)), "stale use and review require education")
  check(history.needsEducation(at: now.addingTimeInterval(-1)), "future clock timestamp cannot bypass education")
  check(!CameraUseHistory(defaults: defaults).needsEducation(at: now.addingTimeInterval(21 * 86400)), "camera history survives reopen")
  for _ in 0..<10_000 {
   let c = ParentChallenge()
   precondition(c.first * c.second < 100 || c.first == 10 || c.second == 10, "easy parent challenge bounds")
  }
  check(true, "10,000 parent questions stay below 100 except factor ten")
  let combinations: [[CreatureHandSign]] = [[.thumbsUp], [.peace], [.thumbsDown], [.thumbsUp, .thumbsUp], [.peace, .peace], [.thumbsDown, .thumbsDown], [.thumbsUp, .peace], [.thumbsUp, .thumbsDown], [.peace, .thumbsDown]]
  check(Set(combinations.compactMap { CreatureHandReaction.matching($0)?.rawValue }).count == 9, "nine single/double/mixed hand combinations have distinct reactions")
  for signs in combinations {
   var hands = CreatureHandDynamics(); var events = 0
   for i in 0..<50 { if hands.receive(signs, time: Double(i) * 0.18) != nil { events += 1 } }
   check(events == 1, "held sign fires once: " + String(describing: signs))
   _ = hands.receive([], time: 10); _ = hands.receive([], time: 10.5)
   _ = hands.receive(signs.reversed(), time: 11)
   check(hands.receive(signs, time: 11.6) != nil, "release rearms regardless of hand order")
  }
  var flicker = CreatureHandDynamics()
  check(flicker.receive([.peace], time: 0) == nil && flicker.receive([], time: 0.2) == nil, "brief noisy gesture causes no reaction")
  let wrist = SIMD2<Float>(0.5, 0.3)
  let bases = [SIMD2<Float>(0.44, 0.45), [0.5, 0.46], [0.55, 0.45], [0.59, 0.42]]
  let folded = bases.map { (tip: $0, knuckle: $0) }
  check(CreatureHandPose(wrist: wrist, thumbTip: [0.36, 0.65], thumbIP: [0.36, 0.50], fingers: folded).sign == .thumbsUp, "folded fingers with upward thumb recognized")
  check(CreatureHandPose(wrist: wrist, thumbTip: [0.36, 0.1], thumbIP: [0.36, 0.25], fingers: folded).sign == .thumbsDown, "folded fingers with downward thumb recognized")
  var peace = folded; peace[0].tip.y = 0.68; peace[1].tip.y = 0.72
  check(CreatureHandPose(wrist: wrist, thumbTip: [0.4, 0.4], thumbIP: [0.4, 0.38], fingers: peace).sign == .peace, "extended index/middle with folded ring/little recognized")
  var open = peace; open[2].tip.y = 0.72; open[3].tip.y = 0.68
  check(CreatureHandPose(wrist: wrist, thumbTip: [0.4, 0.4], thumbIP: [0.4, 0.38], fingers: open).sign == nil, "open palm cannot accidentally trigger a peace sign")
  history.reviewed()
  check(!history.needsEducation(), "fresh review recovers safely from a clock rollback")
  let inputs = CreatureInputs(cameraHistory: history); var commands = 0, samples = 0
  inputs.onCommand = { _ in commands += 1 }; inputs.onMirror = { _ in samples += 1 }
  inputs.toggleMicrophone(); inputs.toggleCamera()
  check(!inputs.microphoneEnabled && !inputs.cameraEnabled, "inputs require a parent action before any permission request")
  inputs.toggleMicrophone(parentApproved: true); inputs.toggleCamera(parentApproved: true)
  inputs.verifyCommand("sleep"); inputs.verifyMirror(.init(eyeOpenness: 0.1))
  check(commands == 1 && samples == 1, "same native input routing exercised without hardware")
  inputs.setSuspended(true); let pausedSamples = samples
  inputs.verifyCommand("dance"); inputs.verifyMirror(.init())
  check(commands == 1 && samples == pausedSamples, "paused input produces no action/sample")
  inputs.setSuspended(false); inputs.verifyCommand("jump")
  check(commands == 2, "resume processes new spoken intent")
  inputs.pauseForNavigation(); let navigationSamples = samples
  check(inputs.cameraEnabled && !inputs.cameraActive, "leaving detail pauses hardware while preserving explicit camera intent")
  inputs.verifyMirror(.init())
  check(samples == navigationSamples, "camera-unusable view rejects late frames")
  inputs.setSuspended(false); inputs.verifyMirror(.init())
  check(inputs.cameraActive && samples == navigationSamples + 1, "returning to detail resumes the opted-in camera")
  inputs.toggleCamera(); inputs.pauseForNavigation(); inputs.setSuspended(false)
  check(!inputs.cameraEnabled && !inputs.cameraActive, "manual off survives navigation and return")
  inputs.toggleCamera(parentApproved: true); inputs.pauseForNavigation()
  inputs.setSuspended(false, at: Date().addingTimeInterval(CameraUseHistory.interval + 60))
  check(!inputs.cameraEnabled && !inputs.cameraActive && inputs.cameraReviewRequired, "return after a month requests review instead of silently reopening hardware")
  inputs.consumeCameraReviewRequest()
  check(!inputs.cameraReviewRequired, "review request is consumed once")
  inputs.stopAll(); let stoppedSamples = samples
  inputs.verifyCommand("dance"); inputs.verifyMirror(.init())
  check(commands == 2 && samples == stoppedSamples && !inputs.microphoneEnabled && !inputs.cameraEnabled, "stop rejects late input and turns both senses off")
  print("PASS no camera/microphone opened; numeric/text fixture provenance only")
 }
}
