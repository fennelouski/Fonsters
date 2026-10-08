import Foundation
import RealityKit
import simd
@main struct VerifyDance {
 @MainActor static func main() throws {
  func check(_ value: Bool, _ label: String) { precondition(value, label); print("PASS " + label) }
  let lobby = LocalLobbyController(); lobby.continuousGallery = true
  let controller = lobby.selectedMember.controller
  let rig = try CreatureRig(lobby.selectedMember.descriptor, furDetail: .world)
  controller.install(rig, name: lobby.selectedMember.name)
  lobby.containers = lobby.members.map { _ in Entity() }
  lobby.ready = true; lobby.refreshGates(); lobby.openCare(lobby.selected)
  let dance = try LobbyDanceScene(); lobby.danceScene = dance
  func entityCount(_ e: Entity) -> Int { 1 + e.children.reduce(0) { $0 + entityCount($1) } }
  let nodes = entityCount(dance.root), revision = lobby.roomRevision
  let appearance = lobby.selectedMember.descriptor
  lobby.setDanceMode(.disco)
  check(controller.dancingContinuously && controller.reaction == .play, "party starts replaceable continuous dance")
  for _ in 0..<200 {
   lobby.celebrate(balloons: false); lobby.celebrate(balloons: true); lobby.advance(dt: 0.04)
  }
  check(entityCount(dance.root) == nodes, "200 celebration pairs reuse bounded entity pools")
  check(lobby.roomRevision == revision && controller.rig === rig && appearance == lobby.selectedMember.descriptor, "party preserves renderer revision, rig and appearance")
  let active = lobby.activeTime, frames = controller.frameCount
  lobby.paused = true; lobby.refreshGates()
  for _ in 0..<100 { lobby.advance(dt: 0.05) }
  check(lobby.activeTime == active && controller.frameCount == frames, "pause freezes dance lights and rig together")
  let actions = controller.actionCount; lobby.spoken(.jump)
  check(actions == controller.actionCount, "paused voice intent rejected")
  lobby.paused = false; lobby.reduceMotion = true; lobby.refreshGates()
  lobby.spoken(.sleep)
  check(controller.reaction == .rest && rig.eyes.allSatisfy { $0.scale.y <= 0.07 }, "spoken sleep produces still pose under Reduce Motion")
  let eyes = rig.eyes.map { $0.scale.y }
  controller.receiveMirror(.init(eyeOpenness: 1), time: 12)
  check(rig.eyes.map { $0.scale.y } == eyes, "camera motion cannot bypass Reduce Motion")
  lobby.reduceMotion = false; lobby.refreshGates()
  for _ in 0..<100 { controller.receiveMirror(.init(eyeOpenness: 1, motion: 1), time: 12) ; lobby.advance(dt: 0.04) }
  check(controller.reaction == .rest && rig.eyes.allSatisfy { $0.scale.y <= 0.07 }, "explicit sleep keeps priority over camera cues")
  for action in CreatureSpokenAction.allCases { lobby.spoken(action) }
  check(lobby.danceMode == .daylight && controller.reaction == .idle && !controller.dancingContinuously, "spoken Stop restores daylight and cancels dance")
  for gate in 0..<3 {
   lobby.backgrounded = gate == 0; lobby.lowPower = gate == 1; lobby.reviewingControls = gate == 2; lobby.refreshGates()
   let before = lobby.activeTime, count = controller.actionCount
   lobby.advance(dt: 0.05); lobby.spoken(.dance)
   check(lobby.activeTime == before && controller.actionCount == count, "background/low power/sheet gate " + String(gate))
  }
  lobby.backgrounded = false; lobby.lowPower = false; lobby.reviewingControls = false; lobby.refreshGates()
  let state = lobby.controls; lobby.setDanceMode(.spotlight); lobby.restoreControls(state)
  check(lobby.danceMode == .daylight, "control Undo restores previous world lighting")
  print("PASS original procedural party model checks; no hardware capture and no renderer screenshot assertion")
 }
}
