import Foundation
import RealityKit
import simd

@main struct VerifyFaces {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        for camera: SIMD3<Float> in [[0, 0, 5], [3, 2, 5], [-2, -1, 5]] {
            let ray = simd_normalize(camera)
            for degrees: Float in [3, 9, 15] {
                let actual = CreatureAttention.viewerDirection(from: .zero, camera: camera, up: [0, 1, 0], degrees: degrees)
                let offset = acos(min(1, max(-1, simd_dot(ray, actual)))) * 180 / .pi
                precondition(abs(offset - degrees) < 0.01 && actual.y > ray.y)
            }
        }
        let positions: [SIMD3<Float>] = [[0, 0, -3], [1, 0, -3], [2, 0, -3]]
        precondition(CreatureAttention.choose(actor: 0, positions: positions, visible: [true, true, true], walking: false, forceViewer: false, socialPeer: 2).1 == 2)
        precondition(CreatureAttention.choose(actor: 0, positions: positions, visible: [true, true, false], walking: false, forceViewer: false, socialPeer: 2).1 == 1)
        precondition(CreatureAttention.choose(actor: 0, positions: positions, visible: [true, false, false], walking: false, forceViewer: false, socialPeer: nil).0 == .viewer)
        precondition(CreatureAttention.choose(actor: 0, positions: positions, visible: [true, true, true], walking: false, forceViewer: true, socialPeer: 1).0 == .viewer)
        precondition(CreatureAttention.choose(actor: 0, positions: positions, visible: [true, true, true], walking: true, forceViewer: true, socialPeer: 1).0 == .travel)
        precondition(CreatureAttention.visible([0, 0, -3], camera: matrix_identity_float4x4, aspect: 1))
        precondition(!CreatureAttention.visible([5, 0, -3], camera: matrix_identity_float4x4, aspect: 1))
        precondition(!CreatureAttention.visible([0, 0, 3], camera: matrix_identity_float4x4, aspect: 1))
        print("PASS: viewer rays rise exactly 3/9/15 degrees; travel, explicit social peer, visible nearest peer, solo and command priorities; off-screen/behind-camera peers excluded")

        let cycle = (0..<540).map { CreatureFacialExpression.casual(time: Float($0) / 30, phase: 0, low: false, quiet: false) }
        precondition(cycle.filter { $0.smile == 0 }.count >= 85 && cycle.contains { $0.smile > 0.7 && $0.smilingEyes > 0.35 })
        for i in 0..<1080 { precondition(CreatureFacialExpression.casual(time: Float(i) / 30, phase: 2, low: true, quiet: false).smile < 0) }
        for smile: Float in [-0.85, 0, 0.45, 1] {
            let center = CreatureMouthCurve.edges(t: 0, width: 1, height: 0.4, smile: smile, opening: 1)
            let corner = CreatureMouthCurve.edges(t: 1, width: 1, height: 0.4, smile: smile, opening: 1)
            precondition(smile == 0 || (corner.0.y - center.0.y) * smile > 0)
            for t in stride(from: Float(-1), through: 1, by: 0.02) {
                let e = CreatureMouthCurve.edges(t: t, width: 1, height: 0.4, smile: smile, opening: 1)
                precondition(e.0.y > e.1.y && e.0.x.isFinite && e.1.y.isFinite)
            }
        }
        func lips(_ bend: Float, roll: Float = 0) -> [SIMD2<Float>] {
            (0..<32).map { i in
                let a = Float(i) / 32 * 2 * .pi, x = cos(a) * 0.15
                let y = sin(a) * 0.012 + bend * x * x
                return [x * cos(roll) - y * sin(roll), x * sin(roll) + y * cos(roll)]
            }
        }
        precondition(CreatureFaceLandmarkCues.smile(lips: lips(2), yaw: 0, roll: 0)! > 0.4)
        precondition(CreatureFaceLandmarkCues.smile(lips: lips(-2), yaw: 0, roll: 0)! < -0.4)
        precondition(CreatureFaceLandmarkCues.smile(lips: lips(0), yaw: 0, roll: 0) == 0)
        precondition(abs(CreatureFaceLandmarkCues.smile(lips: lips(2, roll: 0.3), yaw: 0, roll: 0.3)! - CreatureFaceLandmarkCues.smile(lips: lips(2), yaw: 0, roll: 0)!) < 0.001)
        precondition(CreatureFaceLandmarkCues.smile(lips: lips(2), yaw: 0.5, roll: 0) == nil)
        precondition(CreatureFaceLandmarkCues.attention(yaw: 0, eyes: 1, pupilOffsets: [0.02, -0.02]) > 0.9)
        precondition(CreatureFaceLandmarkCues.attention(yaw: 0.5, eyes: 1, pupilOffsets: []) == 0)
        precondition(CreatureFaceLandmarkCues.attention(yaw: 0, eyes: 0.1, pupilOffsets: []) == 0)
        print("PASS: idle holds neutral and varied smiles; low stays negative; smile/neutral/frown curves never cross; lip-roll compensation, missing/yawed cues and approximate attention bounds")

        let baseline = CreatureFacialExpression(smile: 0.1, smilingEyes: 0.01)
        let sample = CreatureMirrorSample(eyeOpenness: 0.94, found: true, facialSmile: -0.55, smilingEyes: 0, viewerAttention: 0.95)
        var face = CreatureFaceDynamics(); face.reset(to: baseline)
        for _ in 0..<8 { face.advance(dt: 1 / 30, baseline: baseline, sample: sample, low: false) }
        precondition(face.acknowledgingViewer)
        for _ in 0..<10 { face.advance(dt: 1 / 30, baseline: baseline, sample: sample, low: false) }
        precondition(face.expression.smile > 0.65 && face.expression.smilingEyes > 0.4)
        for _ in 0..<72 { face.advance(dt: 1 / 30, baseline: baseline, sample: sample, low: false) }
        precondition(abs(face.expression.smile + 0.55) < 0.03)
        face.advance(dt: 1 / 30, baseline: baseline, sample: .init(facialSmile: .nan, viewerAttention: 1), low: false)
        precondition(face.expression.smile.isFinite && face.expression.smilingEyes.isFinite)
        let frozen = face.expression
        face.advance(dt: 0, baseline: baseline, sample: .init(), low: false)
        precondition(face.expression == frozen)
        for _ in 0..<60 { face.advance(dt: 1 / 30, baseline: baseline, sample: .init(), low: false) }
        precondition(!face.acknowledgingViewer && abs(face.expression.smile - baseline.smile) < 0.01)
        face.reset(to: .init(smile: -0.5, smilingEyes: 0))
        for _ in 0..<180 {
            face.advance(dt: 1 / 30, baseline: .init(smile: -0.5, smilingEyes: 0), sample: sample, low: true)
            precondition(face.expression.smile < 0 && face.expression.smilingEyes == 0)
        }
        print("PASS: brief welcome grin with smiling eyes, signed facial-shape matching within three seconds, zero-dt freeze, loss fallback and owner-selected low feeling priority")

        let fixture = PlayroomCompanion.fixtures[1]
        let rig = try CreatureRig(fixture.descriptor)
        let controller = PlayroomController(); controller.lowPower = false; controller.orbit = 0
        controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false
        controller.install(rig, name: fixture.name)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(rig.descriptor)
        let mesh = rig.facialGeometry!.cavity.model!.mesh
        controller.staticMode = true
        let origin = rig.head.position(relativeTo: nil)
        controller.setAttention(.init(mode: .viewer, point: origin + [0, 0, 5]))
        precondition(controller.renderedHeadAngles.y > 0.1 && rig.pupils.allSatisfy { $0.position.y > 0 })
        controller.setAttention(.init(mode: .peer, point: origin + [2, 0, 4]))
        precondition(controller.renderedHeadAngles.x > 0.25)
        controller.setFeeling(.low)
        for reaction in PlayroomController.Reaction.allCases {
            controller.perform(reaction, name: fixture.name, learn: false, audible: false)
            precondition(controller.renderedExpression.smile < 0 && rig.facialGeometry!.curvature < 0)
        }
        controller.setFeeling(.neutral); controller.perform(.idle, name: fixture.name, learn: false, audible: false)
        controller.staticMode = false
        var minSmile: Float = 1, maxSmile: Float = 0
        for _ in 0..<600 {
            controller.advance(dt: 1 / 30); minSmile = min(minSmile, controller.renderedExpression.smile); maxSmile = max(maxSmile, controller.renderedExpression.smile)
        }
        precondition(minSmile < 0.01 && maxSmile > 0.7)
        precondition(rig.facialGeometry!.cavity.model!.mesh === mesh)
        let after = try encoder.encode(rig.descriptor)
        precondition(after == before)
        for gate in ["pause", "still", "reduce", "background", "power"] {
            controller.paused = gate == "pause"; controller.staticMode = gate == "still"; controller.systemReduceMotion = gate == "reduce"
            controller.backgrounded = gate == "background"; controller.lowPower = gate == "power"
            let pose = rig.head.transform, expression = controller.renderedExpression
            controller.receiveMirror(sample, time: 100); for _ in 0..<120 { controller.advance(dt: 1 / 30) }
            precondition(rig.head.transform == pose && controller.renderedExpression == expression)
        }
        controller.paused = false; controller.staticMode = false; controller.systemReduceMotion = false
        controller.backgrounded = false; controller.lowPower = false
        controller.followingPointer = true // Camera tracking supersedes an old pointer-follow selection.
        controller.touchCamera = PerspectiveCamera()
        controller.touchCamera!.position = rig.head.position(relativeTo: nil) + [0, 0, 5]
        controller.setAttention(.init(mode: .peer, point: origin + [-3, 0, 2]))
        for i in 0..<120 {
            controller.receiveMirror(.init(gaze: .zero), time: 1000 + Double(i) / 30)
            controller.advance(dt: 1 / 30)
        }
        precondition(abs(controller.renderedHeadAngles.x) < 0.06 && abs(controller.renderedHeadAngles.y) < 0.06, "camera eye contact replaces peer gaze and upward idle offset")
        var horizontal: [Float] = []
        for x in [Float(-0.65), Float(0.65)] {
            for i in 0..<90 {
                controller.receiveMirror(.init(gaze: [x, 0]), time: 1100 + Double(i) / 30)
                controller.advance(dt: 1 / 30)
            }
            horizontal.append(rig.head.orientation.imag.y)
        }
        precondition(horizontal[0] < -0.04 && horizontal[1] > 0.04, "camera gaze follows both horizontal directions")
        controller.followingPointer = false; controller.clearMirror()
        print("PASS: real rig camera gaze faces forward, follows both directions, and overrides stale pointer/peer attention")
        print("PASS: actual RealityKit head/pupils look upward and at peers, every static action respects low, twenty-second idle varies, mesh resource reused, appearance bytes unchanged and five motion gates freeze live face updates")

        let lobby = LocalLobbyController(); lobby.lowPower = false; lobby.wander = false; lobby.ready = true
        lobby.continuousGallery = true; lobby.viewportAspect = 1.5
        lobby.camera = PerspectiveCamera(); lobby.camera!.camera.fieldOfViewInDegrees = 42
        for member in lobby.members {
            let container = Entity(); let r = try CreatureRig(member.descriptor)
            container.addChild(r.root); lobby.containers.append(container)
            member.controller.lowPower = false; member.controller.orbit = 0; member.controller.install(r, name: member.name)
        }
        lobby.applyLayout()
        // Initial/return staging now eases over multiple seconds. Test travel
        // after the world owns placement again, rather than mid-transition.
        for _ in 0..<240 { lobby.advance(dt: 1 / 30) }
        precondition(lobby.members.allSatisfy { $0.controller.attentionMode == .peer })
        precondition(lobby.walk(to: lobby.world.destination(in: .plaza, slot: 0)))
        lobby.advance(dt: 1 / 30)
        precondition(lobby.selectedMember.controller.attentionMode == .travel)
        lobby.openCare(0)
        for _ in 0..<40 { lobby.advance(dt: 1 / 30) }
        precondition(lobby.inCare && lobby.selectedMember.controller.attentionMode == .viewer)
        lobby.returnToLobby(); for _ in 0..<240 { lobby.advance(dt: 1 / 30) }
        lobby.stopActivity(); lobby.playTogether(); lobby.applyLayout()
        precondition(lobby.members.allSatisfy { $0.controller.attentionMode == .viewer })
        print("PASS: real lobby assigns peer gaze, a deliberate walk looks ahead, care hides peers and looks at viewer, whole-room play turns toward viewer")
    }
}
