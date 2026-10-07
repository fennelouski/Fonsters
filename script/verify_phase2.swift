import Foundation
import AppKit
import RealityKit
import FoundationModels

@main struct VerifyPhaseTwo {
    @MainActor static func main() async throws {
        if #available(macOS 26.0, *) { print("Apple Intelligence availability: \(SystemLanguageModel.default.availability)") }
        if CommandLine.arguments.contains("--live-model") {
            let interpreter = TypedActionInterpreter()
            guard interpreter.capability == "Apple Intelligence · on this Mac" else { print("UNTESTED: live model unavailable; settings unchanged."); return }
            let present = ["Coral", "Moss", "Iris", "Orbit"]
            let cases: [(String, String, [String], CreatureCommandIntent?, String)] = [
                ("Please do one little pirouette.", "Coral", ["Coral"], .init(action: .spin, targetName: "Coral", peerName: nil), "apple_on_device_model"),
                ("Coral, wave to Moss.", "Iris", present, .init(action: .greetFriend, targetName: "Coral", peerName: "Moss"), "known_command_fallback"),
                ("Moss, settle down for a nap.", "Coral", present, .init(action: .rest, targetName: "Moss", peerName: nil), "known_command_fallback"),
                ("Build a spaceship.", "Coral", present, nil, "apple_on_device_model"),
                ("Moss, get some shut-eye.", "Coral", present, .init(action: .rest, targetName: "Moss", peerName: nil), "apple_on_device_model"),
                ("Make a friendly introduction to Visitor.", "Coral", ["Coral", "Moss", "Iris", "Visitor"], .init(action: .greetFriend, targetName: "Coral", peerName: "Visitor"), "apple_on_device_model")
            ]
            for (index, item) in cases.enumerated() {
                var result: CreatureCommandIntent?
                interpreter.submit(item.0, selected: item.1, allowed: item.2, revision: 0,
                                   currentRevision: { 0 }, apply: { result = $0 })
                for _ in 0..<300 where interpreter.isBusy { try await Task.sleep(for: .milliseconds(100)) }
                guard !interpreter.isBusy else { interpreter.cancel(); throw CocoaError(.featureUnsupported) }
                let diagnostic = "Live case \(index + 1) source: \(interpreter.lastSource); generated action: \(interpreter.lastModelAction ?? "none"); error code: \(interpreter.lastErrorCode ?? "none"); applied action: \(result?.action.rawValue ?? "none"); actor: \(result?.targetName ?? "none"); peer: \(result?.peerName ?? "none")\n"
                FileHandle.standardOutput.write(Data(diagnostic.utf8))
                precondition(result == item.3 && interpreter.lastSource == item.4, "Native command classification differed from the intended action, target or source")
            }
            print("PASS: live Apple on-device model interpreted pirouette and shut-eye and rejected an unsupported request; known named greetings and naps routed immediately with exact roles")
            return
        }
        let names = ["Coral", "Moss", "Iris", "Orbit"]
        for (text, action) in [("say hello", "hello"), ("take a nap", "rest"), ("do a little twirl", "spin"),
                               ("high five", "highFive"), ("chase the ball", "fetch"), ("wander around", "roam"),
                               ("follow my pointer", "follow"), ("please stretch", "stretch")] {
            precondition(CreatureCommandIntent.fallback(text, selected: "Coral", allowed: names)?.action.rawValue == action)
        }
        let greeting = CreatureCommandIntent.fallback("wave to Moss", selected: "Coral", allowed: names)
        precondition(greeting?.targetName == "Coral" && greeting?.peerName == "Moss" && greeting?.action == .greetFriend)
        precondition(CreatureCommandIntent.fallback("Moss, dance", selected: "Coral", allowed: names)?.targetName == "Moss")
        precondition(CreatureCommandIntent.fallback("hop and nap", selected: "Coral", allowed: names) == nil)
        precondition(CreatureCommandIntent.fallback("wave to Moss and nap", selected: "Coral", allowed: names) == nil)
        precondition(CreatureCommandIntent.fallback("wave to Tide", selected: "Coral", allowed: names) == nil)
        precondition(CreatureCommandIntent.fallback("wave to Moss and Iris", selected: "Coral", allowed: names) == nil)
        precondition(CreatureCommandIntent.hasMultiplePeers("Make a friendly introduction to Moss and Iris", selected: "Coral", allowed: names))
        precondition(CreatureCommandIntent.explicitPeer(in: "Make a friendly introduction to Visitor.", allowed: ["Coral", "Visitor"]) == "Visitor")
        precondition(CreatureCommandIntent.fallback("Tide, dance", selected: "Coral", allowed: names) == nil)
        precondition(CreatureCommandIntent.fallback("restless", selected: "Coral", allowed: names) == nil)
        precondition(CreatureCommandIntent.validate(action: "unknown", target: "selected", peer: nil, selected: "Coral", allowed: names) == nil)
        precondition(CreatureCommandIntent.validate(action: "dance", target: "Absent", peer: nil, selected: "Coral", allowed: names) == nil)
        precondition(CreatureCommandIntent.validate(action: "greetFriend", target: "Coral", peer: "Coral", selected: "Coral", allowed: names) == nil)
        precondition(CreatureCommandIntent.validate(action: "greetFriend", target: "Coral", peer: "Moss", selected: "Coral", allowed: ["Coral"]) == nil)
        print("PASS: bounded commands, known synonyms, exact room targets, peer validation and conflicting/unknown requests")
        let interpreter = TypedActionInterpreter()
        var applied = 0, revision = 0
        interpreter.submit("twirl", selected: "Coral", allowed: names, revision: 0, currentRevision: { revision }, apply: { _ in applied += 1 })
        interpreter.cancel()
        try await Task.sleep(for: .milliseconds(40)); precondition(applied == 0 && !interpreter.isBusy)
        interpreter.submit("twirl", selected: "Coral", allowed: names, revision: 0, currentRevision: { revision }, apply: { _ in applied += 1 })
        revision = 1
        try await Task.sleep(for: .milliseconds(40)); precondition(applied == 0)
        interpreter.submit("twirl", selected: "Coral", allowed: names, revision: 1, currentRevision: { revision }, apply: { _ in applied += 1 })
        try await Task.sleep(for: .milliseconds(40)); precondition(applied == 1 && !interpreter.isBusy)
        interpreter.submit("wave to Moss and nap", selected: "Coral", allowed: names, revision: 1, currentRevision: { revision }, apply: { _ in applied += 1 })
        try await Task.sleep(for: .milliseconds(40)); precondition(applied == 1 && !interpreter.isBusy)
        interpreter.submit("Make a friendly introduction to Moss and Iris", selected: "Coral", allowed: names, revision: 1, currentRevision: { revision }, apply: { _ in applied += 1 })
        precondition(applied == 1 && !interpreter.isBusy)
        print("PASS: typed-command fallback executes once; cancellation, multiple peers and newer interaction discard stale requests")
        let fixture = PlayroomCompanion.fixtures[4]
        let controller = PlayroomController(); controller.lowPower = false
        controller.install(try CreatureRig(fixture.descriptor), name: fixture.name)
        controller.enablePersonalityLearning(PersonalityMemoryStore.localPreview())
        let beforeLearning = controller.personality!.interactionCount
        for _ in 0..<900 { controller.advance(dt: 1.0 / 30) }
        precondition(simd_length(controller.groundPosition) > 0.02)
        precondition(controller.personality!.interactionCount == beforeLearning)
        for action in PlayroomController.Reaction.allCases {
            controller.perform(action, name: fixture.name, learn: false)
            for _ in 0..<180 { controller.advance(dt: 1.0 / 30) }
            let matrix = controller.rig!.root.transform.matrix
            precondition([matrix.columns.0.x, matrix.columns.1.y, matrix.columns.2.z, matrix.columns.3.y].allSatisfy(\.isFinite))
            precondition(abs(controller.groundPosition.x) < 0.5 && abs(controller.groundPosition.y) < 0.3)
        }
        controller.stopMoving(); let stopped = controller.groundPosition
        for _ in 0..<900 { controller.advance(dt: 1.0 / 30) }
        precondition(controller.groundPosition == stopped)
        print("PASS: autonomous walks change position without learning; every extended reaction stays finite and bounded; stop holds position")
        var simulation = LocalLobbySimulation(names: names)
        for _ in 0..<12_000 {
            _ = simulation.step(dt: 1.0 / 30, wander: true)
            for i in simulation.agents.indices {
                let position = simulation.agents[i].position
                precondition(position.x.isFinite && position.y.isFinite && abs(position.x) <= 1.5 && abs(position.y) <= 0.88)
                for j in simulation.agents.indices where j > i { precondition(simd_distance(position, simulation.agents[j].position) >= 0.87) }
            }
        }
        precondition(simulation.socialEvents > 5)
        simulation.gather(); let from = simulation.agents.map(\.position)
        for _ in 0..<120 { _ = simulation.step(dt: 1.0 / 30, wander: false) }
        precondition(simulation.agents.map(\.position) != from)
        _ = simulation.act("rest", actor: 0); let resting = simulation.agents[0].position
        for _ in 0..<33_000 { _ = simulation.step(dt: 1.0 / 30, wander: true) }
        precondition(simulation.agents[0].position == resting)
        precondition(simulation.agents[0].reaction == "rest")
        print("PASS: 12,000 lobby steps keep four separated agents in bounds; peers greet/copy hops; gather works and deliberate rest is respected")
        let lobby = LocalLobbyController(); lobby.lowPower = false
        for member in lobby.members { member.controller.install(try CreatureRig(member.descriptor), name: member.name) }
        lobby.ready = true; lobby.refreshGates()
        let memories = lobby.members.map { $0.controller.personality!.interactionCount }
        let follow = CreatureCommandIntent.validate(action: "follow", target: "Coral", peer: nil, selected: "Coral", allowed: names)!
        lobby.execute(follow); lobby.execute(follow)
        precondition(lobby.members[0].controller.followingPointer)
        lobby.execute(CreatureCommandIntent.validate(action: "roam", target: "Coral", peer: nil, selected: "Coral", allowed: names)!)
        precondition(!lobby.members[0].controller.followingPointer)
        for _ in 0..<1800 { lobby.advance(dt: 1.0 / 30) }
        precondition(lobby.socialCount > 0 && lobby.members.map { $0.controller.personality!.interactionCount } == memories)
        for gate in ["pause", "still", "reduceMotion", "background", "lowPower"] {
            lobby.paused = gate == "pause"; lobby.still = gate == "still"; lobby.reduceMotion = gate == "reduceMotion"
            lobby.backgrounded = gate == "background"; lobby.lowPower = gate == "lowPower"; lobby.refreshGates()
            let frames = lobby.frames, positions = lobby.simulation.agents.map(\.position)
            for _ in 0..<30 { lobby.advance(dt: 1.0 / 30) }
            precondition(lobby.frames == frames && lobby.simulation.agents.map(\.position) == positions)
            lobby.perform(.highFive)
            precondition(lobby.selectedMember.controller.reaction == .highFive)
        }
        print("PASS: real four-rig lobby uses shared ticking, automatic peer events do not learn, and all five room motion gates stop frames while accepting static reactions")
    }
}
