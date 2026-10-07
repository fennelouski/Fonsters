import Foundation
import RealityKit
import Observation

private final class ObservationFlag: @unchecked Sendable { var changed = false }

@main struct VerifySocial {
    @MainActor static func main() throws {
        let base = URL(fileURLWithPath: CommandLine.arguments[1])
        let store = FriendshipMemoryStore(url: base.appendingPathComponent("sender.json"))
        let receiver = FriendshipMemoryStore(url: base.appendingPathComponent("receiver.json"))
        let session = UUID()
        var cards: [FonsterVisitCard] = []
        for fixture in PlayroomCompanion.fixtures {
            let id = store.identity(for: fixture.name)
            let card = FonsterVisitCard(publicID: id, name: fixture.name, appearance: fixture.descriptor, warmth: 0.5, energy: 0.6)
            let data = try card.encoded(), decoded = try FonsterVisitCard.decode(data)
            precondition(card == decoded && decoded.feeling == nil)
            precondition(decoded.appearance.raster == generateCreatureGrid(seed: fixture.seed).flatMap { $0 })
            precondition(!String(decoding: data, as: UTF8.self).contains(fixture.seed))
            try receiver.register(decoded); cards.append(decoded)
        }
        print("PASS: twelve seed-free public visit files round-trip with exact legacy portraits and bounded appearances")
        let encoded = try cards[0].encoded()
        let document = try FonsterVisitDocument(card: cards[0])
        precondition(document.data == encoded)
        let file = base.appendingPathComponent("Coral.fonster.json")
        try document.data.write(to: file)
        let selectedFile = try FonsterVisitDocument.readSelectedFile(file)
        precondition(selectedFile == cards[0])
        let largeFile = base.appendingPathComponent("too-large.json")
        try Data(repeating: 0, count: FonsterVisitCard.byteLimit + 1).write(to: largeFile)
        do { _ = try FonsterVisitDocument.readSelectedFile(largeFile); preconditionFailure() } catch VisitCardError.tooLarge { }
        do { _ = try FonsterVisitDocument.readSelectedFile(URL(string: "https://example.invalid/fonster.json")!); preconditionFailure() } catch VisitCardError.invalid { }
        print("PASS: native FileDocument bytes and selected-file reader round-trip; oversized and non-file URLs are rejected without network access")
        func rejected(_ mutate: (inout [String: Any]) -> Void) throws {
            var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
            mutate(&object)
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            do { _ = try FonsterVisitCard.decode(data); preconditionFailure("Accepted malformed or private visit data") }
            catch is VisitCardError { }
        }
        try rejected { $0["email"] = "private@example.invalid" }
        try rejected { $0["seed"] = "private-seed" }
        try rejected { $0["version"] = 2 }
        try rejected { $0["name"] = "private@example.invalid" }
        try rejected { root in var a = root["appearance"] as! [String: Any]; a["seed"] = "private"; root["appearance"] = a }
        try rejected { root in var a = root["appearance"] as! [String: Any]; a["raster"] = [0]; root["appearance"] = a }
        try rejected { root in var a = root["appearance"] as! [String: Any]; var h = a["head"] as! [String: Any]; h["radius"] = 1000; a["head"] = h; root["appearance"] = a }
        try rejected { root in var a = root["appearance"] as! [String: Any]; var parts = a["parts"] as! [[String: Any]]; parts.append(parts[0]); a["parts"] = parts; root["appearance"] = a }
        try rejected { root in var a = root["appearance"] as! [String: Any]; var parts = a["parts"] as! [[String: Any]]; parts[0]["style"] = "private-identifier"; a["parts"] = parts; root["appearance"] = a }
        try rejected { root in var a = root["appearance"] as! [String: Any]; var parts = a["parts"] as! [[String: Any]]; var pixels = parts[0]["pixels"] as! [[String: Any]]; pixels[0]["x"] = 32; parts[0]["pixels"] = pixels; a["parts"] = parts; root["appearance"] = a }
        do { _ = try FonsterVisitCard.decode(Data(repeating: 0, count: FonsterVisitCard.byteLimit + 1)); preconditionFailure() } catch is VisitCardError { }
        print("PASS: unknown/private metadata, malformed shapes/raster/coordinates/parts, version and byte limits rejected")
        let feelingCard = FonsterVisitCard(publicID: cards[0].publicID, name: "Coral", appearance: cards[0].appearance,
                                           warmth: 0.5, energy: 0.6, feeling: .low)
        let decodedFeeling = try FonsterVisitCard.decode(feelingCard.encoded())
        precondition(decodedFeeling.feeling == .low)
        store.setFeeling(.cozy, for: cards[0].publicID)
        let other = cards[1].publicID
        precondition(store.record("hello", cards[0].publicID, other, activeSeconds: 0, session: session, wallSeconds: 10))
        precondition(!store.record("game", cards[0].publicID, other, activeSeconds: 0.1, session: session, wallSeconds: 10.1))
        precondition(store.record("game", cards[0].publicID, other, activeSeconds: 3.1, session: session, wallSeconds: 13.1))
        precondition(!store.record("hello", cards[0].publicID, other, activeSeconds: 10, autonomous: true, session: session))
        precondition(store.record("quiet", cards[0].publicID, other, activeSeconds: 45, autonomous: true, session: session))
        precondition(store.record("quiet", cards[0].publicID, other, activeSeconds: 45, session: session, wallSeconds: 16.2))
        let loaded = FriendshipMemoryStore(url: base.appendingPathComponent("sender.json"))
        precondition(loaded.identity(for: "Coral") == cards[0].publicID && loaded.feeling(for: cards[0].publicID) == .cozy)
        precondition(loaded.friendship(other, cards[0].publicID).meaningfulMoments == 4)
        precondition(receiver.identity(for: "Coral") != cards[0].publicID)
        let changed = FonsterVisitCard(publicID: cards[0].publicID, name: "Coral", appearance: cards[1].appearance, warmth: 0.5, energy: 0.5)
        do { try receiver.register(changed); preconditionFailure() } catch VisitCardError.changedIdentity { }
        try receiver.register(feelingCard)
        let brokenURL = base.appendingPathComponent("newer.json"), broken = Data("{\"version\":99}".utf8)
        try broken.write(to: brokenURL)
        let temporary = FriendshipMemoryStore(url: brokenURL); _ = temporary.identity(for: "Coral")
        let preserved = try Data(contentsOf: brokenURL)
        precondition(preserved == broken)
        print("PASS: opt-in feeling, stable independent public IDs, friendship reload/cooldowns, identity protection and preservation of unreadable archives")
        let lobby = LocalLobbyController(); lobby.lowPower = false
        let observed = ObservationFlag()
        withObservationTracking { _ = lobby.selectedFriendship } onChange: { observed.changed = true }
        for _ in 0..<20 { _ = LocalLobbyController() }
        precondition(!observed.changed, "View recreation must not rewrite the observed social archive")
        func install() throws {
            for member in lobby.members { member.controller.install(try CreatureRig(member.descriptor), name: member.name) }
            lobby.ready = true; lobby.refreshGates()
        }
        try lobby.invite(feelingCard); try install()
        precondition(lobby.hasVisitor && lobby.members.count == 4 && lobby.members[3].name == "Visitor")
        precondition(lobby.members[3].localCompanion == nil && lobby.members[3].controller.feeling == .low)
        lobby.selected = 3; lobby.chooseFeeling(.bright)
        precondition(lobby.members[3].controller.feeling == .low)
        let guestID = lobby.members[3].id, privateBefore = lobby.members[3].controller.personality!
        let localBefore = lobby.members.prefix(3).map { $0.controller.personality!.interactionCount }
        lobby.selected = 0; lobby.buddy = 3; lobby.chooseFeeling(.cozy); lobby.pair(quiet: false)
        precondition(lobby.simulation.pairGame != nil)
        var previousBall = lobby.simulation.ballPosition, ballMoved = false
        for _ in 0..<100 {
            lobby.advance(dt: 1.0 / 30)
            let ball = lobby.simulation.ballPosition
            precondition([ball.x, ball.y, ball.z].allSatisfy(\.isFinite) && ball.y >= 0.14 && ball.y < 1.2)
            if ball != previousBall { ballMoved = true }; previousBall = ball
        }
        precondition(ballMoved)
        for gate in 0..<5 {
            lobby.paused = gate == 0; lobby.still = gate == 1; lobby.reduceMotion = gate == 2
            lobby.backgrounded = gate == 3; lobby.lowPower = gate == 4; lobby.refreshGates()
            let positions = lobby.simulation.agents.map(\.position), ball = lobby.simulation.ballPosition, frames = lobby.frames
            let moments = lobby.selectedFriendship.meaningfulMoments
            for _ in 0..<300 { lobby.advance(dt: 1.0 / 30) }
            precondition(lobby.frames == frames && lobby.simulation.agents.map(\.position) == positions && lobby.simulation.ballPosition == ball)
            precondition(lobby.selectedFriendship.meaningfulMoments == moments)
        }
        lobby.paused = false; lobby.still = false; lobby.reduceMotion = false; lobby.backgrounded = false; lobby.lowPower = false; lobby.refreshGates()
        for _ in 0..<100 { lobby.pair(quiet: false) }
        let justOneGame = lobby.selectedFriendship.meaningfulMoments
        precondition(justOneGame <= 2)
        lobby.perform(.rest); precondition(lobby.simulation.pairGame == nil)
        lobby.pair(quiet: true); precondition(lobby.simulation.pairGame == nil && lobby.simulation.agents[0].reaction == "rub")
        for _ in 0..<1800 { lobby.advance(dt: 1.0 / 30) }
        precondition(lobby.members[3].controller.personality == privateBefore)
        let localAfter = lobby.members.prefix(3).map { $0.controller.personality!.interactionCount }
        precondition(localAfter[1] == localBefore[1] && localAfter[2] == localBefore[2])
        let bond = lobby.social.friendship(lobby.members[0].id, guestID)
        lobby.endVisit(); try install(); precondition(!lobby.hasVisitor && lobby.names[3] == "Orbit")
        try lobby.invite(feelingCard); try install()
        precondition(lobby.social.friendship(lobby.members[0].id, guestID) == bond)
        precondition(CreatureCommandIntent.fallback("wave to Visitor", selected: "Coral", allowed: lobby.names)?.peerName == "Visitor")
        let unusualName = FonsterVisitCard(publicID: guestID, name: "Blue-Bean", appearance: feelingCard.appearance, warmth: 0.5, energy: 0.6)
        try lobby.invite(unusualName); try install()
        precondition(lobby.members[3].name == "Visitor" && lobby.members[3].visitCard!.name == "Blue-Bean")
        precondition(CreatureCommandIntent.mentionsAbsentCreature("Visitor, dance", allowed: ["Coral"]))
        print("PASS: repeated view initialization leaves observed memories unchanged; custom display names have a bounded Visitor command alias")
        print("PASS: seed-free guest rig, name collision, read-only visitor feeling, two-player ball/quiet activities, 100 replacements, all five pause gates, no private guest learning and friendship retained across visits")
    }
}
