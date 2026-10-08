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
  let inputs = CreatureInputs(); var commands = 0, samples = 0
  inputs.onCommand = { _ in commands += 1 }; inputs.onMirror = { _ in samples += 1 }
  inputs.toggleMicrophone(); inputs.toggleCamera()
  inputs.verifyCommand("sleep"); inputs.verifyMirror(.init(eyeOpenness: 0.1))
  check(commands == 1 && samples == 1, "same native input routing exercised without hardware")
  inputs.setSuspended(true); let pausedSamples = samples
  inputs.verifyCommand("dance"); inputs.verifyMirror(.init())
  check(commands == 1 && samples == pausedSamples, "paused input produces no action/sample")
  inputs.setSuspended(false); inputs.verifyCommand("jump")
  check(commands == 2, "resume processes new spoken intent")
  inputs.stopAll(); let stoppedSamples = samples
  inputs.verifyCommand("dance"); inputs.verifyMirror(.init())
  check(commands == 2 && samples == stoppedSamples && !inputs.microphoneEnabled && !inputs.cameraEnabled, "stop rejects late input and turns both senses off")
  print("PASS no camera/microphone opened; numeric/text fixture provenance only")
 }
}
