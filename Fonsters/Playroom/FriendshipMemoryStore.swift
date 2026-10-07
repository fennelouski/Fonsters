import Foundation
import Observation

/// New public identities and mutable local social memories have their own archive.
@MainActor @Observable
final class FriendshipMemoryStore {
    private struct Archive: Codable {
        let version: Int
        var identities: [String: UUID] = [:]
        var feelings: [String: CreatureFeeling] = [:]
        var appearances: [String: String] = [:]
        var friendships: [String: CreatureFriendship] = [:]
    }
    private static var shared: FriendshipMemoryStore?
    private var archive = Archive(version: 1)
    private let url: URL
    private var mayWrite = true
    @ObservationIgnored private var lastMoment: [String: Double] = [:]
    @ObservationIgnored private var lastDeliberate: [String: Double] = [:]
    private(set) var status = "Friendship memories stay on this Mac."

    init(url: URL) {
        self.url = url
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < 2_000_000 else { throw VisitCardError.invalid }
            let saved = try JSONDecoder().decode(Archive.self, from: data)
            guard saved.version == 1, saved.identities.count <= 1000, saved.friendships.count <= 10_000,
                  Set(saved.identities.values).count == saved.identities.count,
                  saved.feelings.count <= 1000, saved.appearances.count <= 1000,
                  saved.feelings.keys.allSatisfy({ UUID(uuidString: $0) != nil }),
                  saved.appearances.allSatisfy({ UUID(uuidString: $0.key) != nil && $0.value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil }),
                  saved.friendships.allSatisfy({ key, friendship in
                      key == Self.key(friendship.first, friendship.second) && friendship.first != friendship.second &&
                      [friendship.hellos, friendship.games, friendship.quietMoments].allSatisfy { (0..<100_000).contains($0) }
                  }) else { throw VisitCardError.invalid }
            archive = saved
        } catch { mayWrite = false; status = "Saved social memories were preserved. This session is temporary." }
    }
    static func localPreview() -> FriendshipMemoryStore {
        if let shared { return shared }
        let args = ProcessInfo.processInfo.arguments
        let url: URL
        if let index = args.firstIndex(of: "--social-file"), index + 1 < args.count {
            url = URL(fileURLWithPath: args[index + 1])
        } else if let index = args.firstIndex(of: "--personality-file"), index + 1 < args.count {
            url = URL(fileURLWithPath: args[index + 1]).appendingPathExtension("social.json")
        } else {
            url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("com.nathanfennel.Fonsters.Playroom/social-v1.json")
        }
        let store = FriendshipMemoryStore(url: url); shared = store; return store
    }
    func identity(for name: String) -> UUID {
        if let id = archive.identities[name] { return id }
        let id = UUID(); archive.identities[name] = id; save(); return id
    }
    func feeling(for id: UUID) -> CreatureFeeling { archive.feelings[id.uuidString] ?? .neutral }
    func setFeeling(_ feeling: CreatureFeeling, for id: UUID) {
        guard self.feeling(for: id) != feeling else { return }
        archive.feelings[id.uuidString] = feeling; save()
    }
    func register(_ card: FonsterVisitCard) throws {
        try card.validate()
        let key = card.publicID.uuidString, digest = card.appearanceDigest
        if let existing = archive.appearances[key] {
            guard existing == digest else { throw VisitCardError.changedIdentity }
            return
        }
        guard archive.appearances.count < 1000 else { throw VisitCardError.invalid }
        archive.appearances[key] = digest; save()
    }
    func friendship(_ a: UUID, _ b: UUID) -> CreatureFriendship {
        archive.friendships[Self.key(a, b)] ?? .init(first: minID(a, b), second: maxID(a, b))
    }
    @discardableResult
    func record(_ kind: String, _ a: UUID, _ b: UUID, activeSeconds: Double, autonomous: Bool = false, session: UUID,
                wallSeconds: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard a != b, activeSeconds.isFinite, activeSeconds >= 0,
              ["hello", "game", "quiet"].contains(kind) else { return false }
        let key = Self.key(a, b), clockKey = session.uuidString + ":" + key
        if autonomous {
            guard activeSeconds - (lastMoment[clockKey] ?? -.infinity) >= 40 else { return false }
        } else {
            // Still mode can develop friendships through deliberate interactions.
            guard wallSeconds.isFinite, wallSeconds - (lastDeliberate[key] ?? -.infinity) >= 3 else { return false }
            lastDeliberate[key] = wallSeconds
        }
        lastMoment[clockKey] = activeSeconds
        var bond = friendship(a, b)
        switch kind {
        case "hello": bond.hellos = min(99_999, bond.hellos + 1)
        case "game": bond.games = min(99_999, bond.games + 1)
        default: bond.quietMoments = min(99_999, bond.quietMoments + 1)
        }
        archive.friendships[key] = bond; save(); return true
    }
    private static func key(_ a: UUID, _ b: UUID) -> String { [a.uuidString, b.uuidString].sorted().joined(separator: ":") }
    private func minID(_ a: UUID, _ b: UUID) -> UUID { a.uuidString < b.uuidString ? a : b }
    private func maxID(_ a: UUID, _ b: UUID) -> UUID { a.uuidString < b.uuidString ? b : a }
    private func save() {
        guard mayWrite else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(archive).write(to: url, options: .atomic)
            status = "Friendship memories stay on this Mac."
        } catch { status = "These social memories are temporary; they couldn't be saved." }
    }
}
