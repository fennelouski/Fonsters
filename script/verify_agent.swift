import Foundation
import RealityKit
import simd

@main struct VerifyAgent {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        func tryRead(_ url: URL) -> FonsterAgentProgram {
            do { return try FonsterAgentDocument.read(url) } catch { preconditionFailure("Couldn't read valid local handoff") }
        }
        let base = Date()
        let id = UUID(), peer = UUID()
        let program = FonsterAgentProgram(fonsterID: id, actions: [.init(kind: .greet, peerID: peer)], now: base)
        let bytes = try program.encoded()
        for baseline in [0.0, 0.04, 0.5, 0.95, 1.0] {
            precondition(AgentRituals().warmth(baseline) == baseline && AgentRituals().energy(baseline) == baseline)
        }
        var gentle = AgentRituals(); gentle.rests = 12
        precondition(gentle.energy(0.04) == 0 && gentle.energy(0.8) >= 0.7)
        let handoffURL = directory.appendingPathComponent("example.fonster-agent.json")
        try bytes.write(to: handoffURL)
        precondition(tryRead(handoffURL).programID == program.programID)
        print("PASS: an unused agent leaves all valid owner temperament values unchanged; bounded contributions cannot leave 0–1; native selected-file handoff reads the actual serialized plan")
        precondition(AgentRitualMemoryStore.localPreview() === AgentRitualMemoryStore.localPreview())
        let privatePlan = FonsterAgentProgram(fonsterID: id, actions: [.init(kind: .react, reaction: "look"), .init(kind: .reflect, reflectionField: .feeling, cue: .bright)])
        let template = try FonsterAgentDocument(program: privatePlan)
        let publicCopy = try FonsterAgentProgram.decode(template.data)
        precondition(publicCopy.programID != privatePlan.programID && publicCopy.actions == [.init(kind: .react, reaction: "look")])
        precondition(!String(decoding: template.data, as: UTF8.self).contains("reflection"))
        print("PASS: exported templates remove every human reflection step and use fresh public plan IDs; all lobby windows share session learning caps")
        let decoded = try FonsterAgentProgram.decode(bytes)
        precondition(decoded.programID == program.programID && decoded.fonsterID == id)
        func rejects(_ operation: () throws -> Void) {
            do { try operation(); preconditionFailure("Accepted a denied action") } catch {}
        }
        var object = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        for key in ["email", "seed", "location", "prompt", "url", "credential", "conversation"] {
            var polluted = object; polluted[key] = "private"
            rejects { _ = try FonsterAgentProgram.decode(JSONSerialization.data(withJSONObject: polluted)) }
        }
        for action in [["kind": "execute", "command": "anything"], ["kind": "react", "reaction": "anything"], ["kind": "explore", "area": "park", "latitude": 1], ["kind": "bench", "peerID": peer.uuidString], ["kind": "feeling", "feeling": "cozy", "reaction": "hop"]] as [[String: Any]] {
            object["actions"] = [action]
            rejects { _ = try FonsterAgentProgram.decode(JSONSerialization.data(withJSONObject: object)) }
        }
        rejects { _ = try FonsterAgentProgram.decode(Data(repeating: 65, count: 16_385)) }
        rejects { try FonsterAgentProgram(fonsterID: id, actions: Array(repeating: .init(kind: .bench), count: 13)).validate() }
        rejects { try FonsterAgentProgram(fonsterID: id, agentLabel: "two\nlines", actions: [.init(kind: .bench)]).validate() }
        rejects { try program.validate(now: base.addingTimeInterval(301)) }
        rejects { try program.validate(now: base.addingTimeInterval(-6)) }
        print("PASS: strict 16 KB versioned files round-trip random public IDs; private fields, arbitrary execution, invalid/oversized/expired/future plans and unsupported actions are rejected")

        let lobby = LocalLobbyController(); lobby.lowPower = false; lobby.wander = false
        while let next = lobby.availableCompanions.first { lobby.addCompanion(next) }
        for member in lobby.members {
            member.controller.install(try CreatureRig(member.descriptor, furDetail: .world), name: member.name)
            let container = Entity(); container.addChild(member.controller.rig!.root); lobby.containers.append(container)
        }
        lobby.ready = true; lobby.refreshGates(); lobby.applyLayout()
        let director = lobby.agent
        precondition(director.scopes == Set(FonsterAgentScope.allCases))
        precondition(HumanReflectionField.allCases.allSatisfy { director.reflections[$0]?.enabled == false && director.reflections[$0]?.audience == .thisMac })
        let originalLearning = lobby.members.map { $0.controller.personality!.interactionCount }
        let owned = lobby.selectedMember.id, friend = lobby.members[lobby.peerIndex].id
        var clock = base
        func step(_ seconds: Double) {
            for _ in 0..<Int(seconds * 30) { clock = clock.addingTimeInterval(1.0 / 30); lobby.advance(dt: 1.0 / 30, now: clock) }
        }
        try director.prepareDemo(lobby: lobby, now: clock)
        try director.start(lobby: lobby, now: clock)
        let revision = lobby.userRevision
        step(70)
        precondition(!director.running && director.cursor == 8 && director.completedPrograms == 1)
        precondition(director.history.count == 8 && director.history.allSatisfy { $0.source == .simulated })
        precondition(lobby.members.map { $0.controller.personality!.interactionCount } == originalLearning)
        precondition(lobby.members.dropFirst().allSatisfy { $0.controller.agentRituals.total == 0 })
        precondition(lobby.selectedMember.controller.agentRituals.total == 1 && lobby.userRevision == revision)
        precondition(lobby.social.friendship(owned, friend).meaningfulMoments > 0)
        rejects { try director.start(lobby: lobby, now: clock) }
        print("PASS: all eight simulated actions run in a native 12-Fonster world; only the owned Fonster learns, source is recorded, owner learning stays unchanged, friendships grow and plan replay is rejected")

        try director.prepare(.init(fonsterID: owned, actions: [.init(kind: .explore, area: "neighborhood"), .init(kind: .react, reaction: "spin")], now: clock), source: .localHandoff, lobby: lobby, now: clock)
        try director.start(lobby: lobby, now: clock)
        step(20)
        precondition(director.history.first?.source == .localHandoff)
        // Any owner input replaces both the current route and future actions.
        lobby.perform(.rest)
        let cursor = director.cursor, historyCount = director.history.count
        step(30)
        precondition(!director.running && director.cursor == cursor && director.history.count == historyCount)
        precondition(lobby.selectedMember.controller.reaction == .rest && lobby.simulation.agents[0].route.isEmpty)
        print("PASS: reviewed local actions use the same native executor; a direct owner interaction stops movement and pending actions immediately")

        for gate in ["pause", "still", "reduceMotion", "background", "lowPower"] {
            try director.prepare(.init(fonsterID: owned, actions: [.init(kind: .react, reaction: "hop"), .init(kind: .feeling, feeling: .bright)], now: clock), source: .simulated, lobby: lobby, now: clock)
            try director.start(lobby: lobby, now: clock)
            lobby.paused = gate == "pause"; lobby.still = gate == "still"; lobby.reduceMotion = gate == "reduceMotion"; lobby.backgrounded = gate == "background"; lobby.lowPower = gate == "lowPower"; lobby.refreshGates()
            let frames = lobby.frames, positions = lobby.simulation.agents.map(\.position), learned = director.memories.profile(owned)
            step(12)
            precondition(director.cursor == 0 && lobby.frames == frames && lobby.simulation.agents.map(\.position) == positions && director.memories.profile(owned) == learned)
            if gate == "still" || gate == "reduceMotion" {
                try director.performNext(lobby: lobby, now: clock, manual: true)
                for _ in 0..<100 { rejects { try director.performNext(lobby: lobby, now: clock, manual: true) } }
                precondition(director.cursor == 1 && lobby.frames == frames)
            }
            lobby.paused = false; lobby.still = false; lobby.reduceMotion = false; lobby.backgrounded = false; lobby.lowPower = false; lobby.refreshGates()
            step(1)
            precondition(director.cursor <= 1)
            director.revoke(lobby: lobby)
        }
        print("PASS: pause, static mode, Reduce Motion, background and Low Power freeze automatic actions/geometry/learning; manual static poses are bounded, 100 repeated taps cannot queue actions, resume doesn't catch up")

        // Changing scopes invalidates the reviewed plan, including overlapping movement.
        director.setScope(.movement, enabled: false, lobby: lobby)
        rejects { try director.prepare(.init(fonsterID: owned, actions: [.init(kind: .react, reaction: "fetch")], now: clock), source: .localHandoff, lobby: lobby, now: clock) }
        rejects { try director.prepare(.init(fonsterID: owned, actions: [.init(kind: .explore, area: "park")], now: clock), source: .localHandoff, lobby: lobby, now: clock) }
        director.setScope(.movement, enabled: true, lobby: lobby)
        rejects { try director.prepare(.init(fonsterID: UUID(), actions: [.init(kind: .bench)], now: clock), source: .localHandoff, lobby: lobby, now: clock) }
        rejects { try director.prepare(.init(fonsterID: owned, actions: [.init(kind: .greet, peerID: UUID())], now: clock), source: .localHandoff, lobby: lobby, now: clock) }
        let guest = FonsterVisitCard(publicID: UUID(), name: "Guest", appearance: PlayroomCompanion.fixtures[3].descriptor, warmth: 0.5, energy: 0.5)
        try lobby.invite(guest); lobby.ready = true; lobby.selected = 3
        rejects { try director.prepare(.init(fonsterID: guest.publicID, actions: [.init(kind: .react, reaction: "play")], now: clock), source: .localHandoff, lobby: lobby, now: clock) }
        lobby.endVisit(); lobby.ready = true; lobby.selected = 0; lobby.refreshGates()
        print("PASS: disabled scopes, absent peers, non-owned public IDs and visitor control are rejected; room changes revoke plans")

        let savedFeeling = lobby.selectedMember.controller.feeling
        for field in HumanReflectionField.allCases {
            let cue = field.choices[0]
            let reflect = FonsterAgentAction(kind: .reflect, reflectionField: field, cue: cue)
            rejects { try director.prepare(.init(fonsterID: owned, actions: [reflect], now: clock), source: .localHandoff, lobby: lobby, now: clock) }
            director.setReflection(field, rule: .init(enabled: true, cue: cue), lobby: lobby)
            try director.prepare(.init(fonsterID: owned, actions: [reflect, .init(kind: .react, reaction: "blink")], now: clock), source: .localHandoff, lobby: lobby, now: clock)
            try director.start(lobby: lobby, now: clock); step(20)
            precondition(lobby.selectedMember.controller.feeling == savedFeeling)
            precondition(lobby.card(for: lobby.selectedMember, includeFeeling: true).feeling == savedFeeling)
            director.setReflection(field, rule: .init(enabled: true, cue: cue, audience: .localCompanions), lobby: lobby)
            rejects { try director.prepare(.init(fonsterID: owned, actions: [reflect], now: clock), source: .localHandoff, lobby: lobby, now: clock) }
            let socialReflect = FonsterAgentAction(kind: .reflect, peerID: friend, reflectionField: field, cue: cue)
            try director.prepare(.init(fonsterID: owned, actions: [socialReflect, .init(kind: .react, reaction: "spin")], now: clock), source: .localHandoff, lobby: lobby, now: clock)
            try director.start(lobby: lobby, now: clock); step(9)
            director.setReflection(field, rule: .init(enabled: false, cue: cue), lobby: lobby)
            precondition(!director.running && director.program == nil && lobby.simulation.pairGame == nil)
            rejects { try director.prepare(.init(fonsterID: owned, actions: [socialReflect], now: clock), source: .localHandoff, lobby: lobby, now: clock) }
        }
        precondition(lobby.selectedMember.controller.feeling == savedFeeling)
        print("PASS: feeling/activity/travel each require a matching owner-chosen cue and audience; reflection is transient, never changes exported feelings, and per-field revocation cancels every pending action")

        let ritualURL = directory.appendingPathComponent("rituals.json")
        let memory = AgentRitualMemoryStore(url: ritualURL)
        for i in 0..<10 { let learned = memory.learn("play", id: id, source: .localHandoff, now: base.addingTimeInterval(Double(i) * 60)); precondition(learned == (i < 3)) }
        precondition(memory.profile(id).total == 3)
        let reload = AgentRitualMemoryStore(url: ritualURL)
        for i in 3..<10 { let learned = reload.learn("greet", id: id, source: .simulated, now: base.addingTimeInterval(Double(i) * 60)); precondition(learned == (i < 6)) }
        let reloadAgain = AgentRitualMemoryStore(url: ritualURL)
        precondition(!reloadAgain.learn("rest", id: id, source: .simulated, now: base.addingTimeInterval(720)))
        precondition(reloadAgain.profile(id).localHandoff == 3 && reloadAgain.profile(id).simulated == 3)
        let preservedURL = directory.appendingPathComponent("future-agent.json")
        let future = Data("{\"version\":99,\"rituals\":{}}".utf8); try future.write(to: preservedURL)
        let preserved = AgentRitualMemoryStore(url: preservedURL)
        _ = preserved.learn("play", id: id, source: .simulated)
        let preservedBytes = try Data(contentsOf: preservedURL); precondition(preservedBytes == future)
        let contents = String(decoding: try Data(contentsOf: ritualURL), as: UTF8.self)
        for privateField in ["seed", "email", "travel", "activity", "feeling", "prompt", "conversation", "agentLabel"] { precondition(!contents.contains(privateField)) }
        print("PASS: separate agent rituals persist source counts, minute/session/day caps survive reload, human cues never enter the archive, and newer archives are preserved")
        print("PASS: agent verification complete; all fixtures used isolated synthetic archives")
    }
}
