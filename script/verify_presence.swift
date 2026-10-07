import Foundation
import RealityKit
import simd

@main struct VerifyPresence {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let base = Date(), id = UUID()
        func rejects(_ operation: () throws -> Void) { do { try operation(); preconditionFailure("Accepted a denied social operation") } catch {} }
        let url = folder.appendingPathComponent("profiles.json")
        let store = FonsterSocialStore(url: url)
        rejects { _ = try store.create(id: UUID(), name: "Visitor", owned: false) }
        rejects { _ = try store.create(id: UUID(), name: "private@example.com", owned: true) }
        let original = try store.create(id: id, name: "Coral", owned: true, now: base)
        precondition(original.id != id && original.posts.count == 1 && original.posts[0].state == .draft)
        precondition(original.handle.hasPrefix("fonster_") && original.handle.count == 20)
        let restored = FonsterSocialStore(url: url)
        precondition(restored.profile(id)!.id == original.id)
        precondition(FonsterSocialStore.localPreview() === FonsterSocialStore.localPreview())
        print("PASS: owned-only profile creation, random public handles, stable reload and shared window/session store; no external accounts or startup agent")

        let adapter = FonsterLocalFeedAdapter()
        try adapter.publish(original.posts[0].id, profileID: id, store: store, now: base)
        rejects { try adapter.publish(original.posts[0].id, profileID: id, store: store, now: base) }
        let event = FonsterSocialEvent(kind: .game, source: .ownerAction, date: base.addingTimeInterval(61))
        store.record(event, id: id)
        let draft = try store.makeDraft(id: id, now: event.date)
        for _ in 0..<100 { store.record(event, id: id); rejects { _ = try store.makeDraft(id: id, now: event.date) } }
        precondition(store.profile(id)!.posts.count == 2)
        store.pass(postID: draft.id, id: id)
        precondition(store.profile(id)!.posts.first!.state == .passed)
        store.setCategory(.quiet, enabled: false, id: id)
        store.record(.init(kind: .rest, source: .ownerAction, date: base.addingTimeInterval(130)), id: id)
        rejects { _ = try store.makeDraft(id: id, now: base.addingTimeInterval(130)) }
        print("PASS: explicit review/local publication, duplicate prevention, 100 repeated draft attempts, category revocation and retained passed posts")

        let card = FonsterVisitCard(publicID: id, name: "Coral", appearance: PlayroomCompanion.fixtures[0].descriptor, warmth: 0.92, energy: 0.12, feeling: .low)
        let bytes = try FonsterReviewFileAdapter().prepare(profile: store.profile(id)!, appearance: card)
        let object = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        precondition(object["externalPublicationAuthorized"] as? Bool == false && object["destination"] as? String == "manual-review-file")
        let publicProfile = object["profile"] as! [String: Any], appearance = object["appearance"] as! [String: Any]
        precondition(publicProfile["fictional"] as? Bool == true && publicProfile["automated"] as? Bool == true)
        precondition(appearance["feeling"] == nil && (appearance["temperament"] as! [String: Double]) == ["warmth":0.5,"energy":0.5])
        let publicPosts = object["posts"] as! [[String: Any]]
        precondition(publicPosts.count == 1 && publicPosts[0]["automated"] as? Bool == true)
        let serialized = String(decoding: bytes, as: UTF8.self)
        for word in ["little-fonster-", "email", "reflection", "conversation", "latitude", "longitude", "credential", "hellos", "friendships", "generatedToday"] { precondition(!serialized.contains(word)) }
        precondition(!adapter.canPublishExternally && !FonsterReviewFileAdapter().canPublishExternally)
        let document = try FonsterSocialDocument(profile: store.profile(id)!, card: card)
        precondition(document.data == bytes)
        try document.data.write(to: folder.appendingPathComponent("Coral.fonster-social-review.json"))
        print("PASS: native review file contains only the fictional profile, seed-free resolved appearance and approved local posts; no draft, passed post, feeling, owner temperament, private fact or publication grant")

        let capped = FonsterSocialStore(url: folder.appendingPathComponent("caps.json"))
        _ = try capped.create(id: id, name: "Coral", owned: true, now: base)
        for index in 1..<6 {
            let date = base.addingTimeInterval(Double(index * 61)); capped.record(.init(kind: .look, source: .simulatedAgent, date: date), id: id)
            _ = try capped.makeDraft(id: id, now: date)
        }
        let seventh = base.addingTimeInterval(370)
        capped.record(.init(kind: .wave, source: .simulatedAgent, date: seventh), id: id)
        rejects { _ = try capped.makeDraft(id: id, now: seventh) }
        let reopen = FonsterSocialStore(url: folder.appendingPathComponent("caps.json"))
        let tooSoon = base.addingTimeInterval(330)
        reopen.record(.init(kind: .look, source: .simulatedAgent, date: tooSoon), id: id)
        rejects { _ = try reopen.makeDraft(id: id, now: tooSoon) }
        reopen.record(.init(kind: .look, source: .simulatedAgent, date: seventh), id: id)
        _ = try reopen.makeDraft(id: id, now: seventh)
        let stale = base.addingTimeInterval(450)
        reopen.record(.init(kind: .look, source: .simulatedAgent, date: stale), id: id)
        rejects { _ = try reopen.makeDraft(id: id, now: stale.addingTimeInterval(601)) }
        var daily = reopen.profile(id)!; daily.generatedToday = 24
        let dailyURL = folder.appendingPathComponent("daily.json")
        try JSONEncoder().encode(FonsterSocialStore.Archive(profiles: [daily])).write(to: dailyURL)
        let dailyStore = FonsterSocialStore(url: dailyURL)
        dailyStore.record(.init(kind: .look, source: .localWorld, date: base.addingTimeInterval(500)), id: id)
        rejects { _ = try dailyStore.makeDraft(id: id, now: base.addingTimeInterval(500)) }
        for payload in ["{\"version\":99,\"profiles\":[]}", "broken"] {
            let preserveURL = folder.appendingPathComponent(UUID().uuidString + ".json"), data = Data(payload.utf8)
            try data.write(to: preserveURL)
            let preserved = FonsterSocialStore(url: preserveURL)
            _ = try preserved.create(id: UUID(), name: "Moss", owned: true, now: base)
            let after = try Data(contentsOf: preserveURL); precondition(after == data)
        }
        print("PASS: minute, six-per-session and persisted daily caps; reload cannot bypass cooldown; stale observations have no catch-up; newer/corrupt archives preserved")

        let nativeStore = FonsterSocialStore(url: folder.appendingPathComponent("native.json"))
        let lobby = LocalLobbyController(presenceStore: nativeStore); lobby.lowPower = false; lobby.wander = false
        for member in lobby.members {
            member.controller.install(try CreatureRig(member.descriptor, furDetail: .world), name: member.name)
            let entity = Entity(); entity.addChild(member.controller.rig!.root); lobby.containers.append(entity)
        }
        lobby.ready = true; lobby.refreshGates()
        let nativeID = lobby.selectedMember.id
        _ = try nativeStore.create(id: nativeID, name: lobby.selectedMember.name, owned: true, now: base)
        let ownerLearning = lobby.members.map { $0.controller.personality?.interactionCount ?? 0 }
        lobby.agent.setReflection(.feeling, rule: .init(enabled: true, cue: .bright, audience: .localCompanions), lobby: lobby)
        try lobby.presence.start(lobby: lobby, now: base)
        var clock = base
        func step(_ seconds: Double) { for _ in 0..<Int(seconds * 30) { clock = clock.addingTimeInterval(1.0 / 30); lobby.advance(dt: 1.0 / 30, now: clock) } }
        step(5)
        precondition(lobby.agent.running && lobby.agent.program!.actions.allSatisfy { $0.kind != .reflect })
        for gate in 0..<6 {
            switch gate { case 0: lobby.paused = true; case 1: lobby.still = true; case 2: lobby.reduceMotion = true; case 3: lobby.backgrounded = true; case 4: lobby.lowPower = true; default: lobby.reviewingControls = true }
            let frames = lobby.frames, positions = lobby.simulation.agents.map(\.position), cursor = lobby.agent.cursor, posts = nativeStore.profile(nativeID)!.posts.count
            step(2)
            precondition(lobby.frames == frames && lobby.simulation.agents.map(\.position) == positions && lobby.agent.cursor == cursor && nativeStore.profile(nativeID)!.posts.count == posts)
            lobby.paused = false; lobby.still = false; lobby.reduceMotion = false; lobby.backgrounded = false; lobby.lowPower = false; lobby.reviewingControls = false
        }
        step(140)
        precondition(nativeStore.profile(nativeID)!.posts.count >= 2)
        precondition(nativeStore.profile(nativeID)!.posts.contains { $0.event.source == .simulatedAgent })
        precondition(lobby.members.map { $0.controller.personality?.interactionCount ?? 0 } == ownerLearning)
        precondition(nativeStore.profile(nativeID)!.posts.allSatisfy { $0.state == .draft })
        print("PASS: actual native furry rigs, continuous finite companion plans and sourced adventure drafts; private reflection excluded; six motion/review gates hold frames, routes, posts and learning")

        lobby.perform(.greet)
        precondition(!lobby.presence.running && !lobby.agent.running && !lobby.simulation.agents[lobby.selected].walking)
        let count = nativeStore.profile(nativeID)!.posts.count
        for _ in 0..<100 { try lobby.presence.start(lobby: lobby, now: clock); lobby.presence.stop(lobby: lobby) }
        step(20); precondition(nativeStore.profile(nativeID)!.posts.count == count && !lobby.presence.running)
        lobby.presence.setMode(.localFeed, lobby: lobby)
        try lobby.presence.start(lobby: lobby, now: clock)
        step(75)
        precondition(nativeStore.profile(nativeID)!.posts.contains { $0.state == .localFeed })
        lobby.presence.stop(lobby: lobby)
        precondition(!lobby.agent.running)
        print("PASS: owner takeover stops agent/routes immediately; 100 start/stop taps cause no queue; explicitly chosen local-only auto-posting works; pause retains all records")
        print("PASS: social-presence verification complete with isolated synthetic archives")
    }
}
