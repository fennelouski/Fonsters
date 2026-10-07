import Foundation

/// A finite local choreography, not code, credentials, prompts, or a connection.
struct FonsterAgentProgram: Codable, Equatable {
    static let byteLimit = 16_384
    let version: Int
    let programID: UUID
    let fonsterID: UUID
    let agentLabel: String
    let createdAt: Date
    let expiresAt: Date
    let actions: [FonsterAgentAction]

    init(fonsterID: UUID, agentLabel: String = "Little companion pilot", actions: [FonsterAgentAction], now: Date = .now) {
        version = 1; programID = UUID(); self.fonsterID = fonsterID; self.agentLabel = agentLabel
        createdAt = now; expiresAt = now.addingTimeInterval(300); self.actions = actions
    }
    func validate(now: Date = .now) throws {
        guard version == 1, !actions.isEmpty, actions.count <= 12,
              (1...32).contains(agentLabel.count), agentLabel.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_" )).contains($0) }),
              createdAt.timeIntervalSince1970.isFinite, expiresAt.timeIntervalSince1970.isFinite,
              createdAt <= now.addingTimeInterval(5), expiresAt > now,
              (1...300).contains(expiresAt.timeIntervalSince(createdAt)) else { throw FonsterAgentError.invalid }
        for action in actions { try action.validate() }
    }
    func publicHandoff(now: Date = .now) throws -> Self {
        let publicActions = actions.filter { $0.kind != .reflect }
        guard !publicActions.isEmpty else { throw FonsterAgentError.noPublicActions }
        return .init(fonsterID: fonsterID, agentLabel: agentLabel, actions: publicActions, now: now)
    }
    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    static func decode(_ data: Data, now: Date = .now) throws -> Self {
        guard data.count <= byteLimit else { throw FonsterAgentError.tooLarge }
        let topKeys: Set<String> = ["version", "programID", "fonsterID", "agentLabel", "createdAt", "expiresAt", "actions"]
        let actionKeys: Set<String> = ["kind", "reaction", "area", "peerID", "feeling", "reflectionField", "cue"]
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == topKeys,
              let actions = object["actions"] as? [[String: Any]], actions.allSatisfy({ Set($0.keys).isSubset(of: actionKeys) && !$0.values.contains(where: { $0 is NSNull }) }) else { throw FonsterAgentError.invalid }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        guard let program = try? decoder.decode(Self.self, from: data) else { throw FonsterAgentError.invalid }
        try program.validate(now: now); return program
    }
}

struct FonsterAgentAction: Codable, Equatable {
    enum Kind: String, Codable { case react, explore, feeling, greet, playTogether, quietTogether, bench, reflect }
    let kind: Kind
    var reaction: String?
    var area: String?
    var peerID: UUID?
    var feeling: CreatureFeeling?
    var reflectionField: HumanReflectionField?
    var cue: HumanReflectionCue?

    func validate() throws {
        let valid: Bool
        switch kind {
        case .react: valid = reaction.map { ["greet", "play", "rest", "blink", "look", "hop", "spin", "stretch", "highFive", "rub", "fetch"].contains($0) } == true && area == nil && peerID == nil && feeling == nil && reflectionField == nil && cue == nil
        case .explore: valid = area.map { ["garden", "benches", "plaza", "park", "neighborhood"].contains($0) } == true && reaction == nil && peerID == nil && feeling == nil && reflectionField == nil && cue == nil
        case .feeling: valid = feeling != nil && reaction == nil && area == nil && peerID == nil && reflectionField == nil && cue == nil
        case .greet, .playTogether, .quietTogether: valid = peerID != nil && reaction == nil && area == nil && feeling == nil && reflectionField == nil && cue == nil
        case .bench: valid = reaction == nil && area == nil && peerID == nil && feeling == nil && reflectionField == nil && cue == nil
        case .reflect: valid = reflectionField != nil && cue?.field == reflectionField && reaction == nil && area == nil && feeling == nil
        }
        guard valid else { throw FonsterAgentError.invalid }
    }
    var title: String {
        switch kind {
        case .react: return ["greet": "A tiny hello", "play": "Happy dance", "rest": "Slow down", "blink": "Blink", "look": "Look around", "hop": "Little hop", "spin": "Twirl", "stretch": "Stretch", "highFive": "High five", "rub": "Gentle nuzzle", "fetch": "Toss a ball"][reaction ?? ""] ?? "Reaction"
        case .explore: return "Explore \(area ?? "the world")"
        case .feeling: return "Choose \(feeling?.title.lowercased() ?? "a feeling")"
        case .greet: return "Greet a friend"
        case .playTogether: return "Pass the ball with a friend"
        case .quietTogether: return "Keep a friend company"
        case .bench: return "Rest on a bench"
        case .reflect: return "Reflect your chosen \(reflectionField?.title.lowercased() ?? "cue")"
        }
    }
    var ritual: String? {
        switch kind {
        case .greet: return "greet"
        case .playTogether: return "play"
        case .quietTogether, .bench: return "rest"
        case .explore: return "look"
        case .react:
            switch reaction { case "greet", "highFive": return "greet"; case "play", "hop", "spin", "fetch": return "play"; case "rest", "rub", "stretch": return "rest"; case "look": return "look"; default: return nil }
        default: return nil
        }
    }
}

enum FonsterAgentError: LocalizedError {
    case invalid, tooLarge, expired, replay, unavailable, denied, noPeer, noArea, reflectionDenied, rateLimited, noPublicActions
    var errorDescription: String? {
        switch self {
        case .invalid: "Use a version 1 action file with 1–12 supported actions and a lifetime of up to five minutes."
        case .tooLarge: "The action file is larger than 16 KB."
        case .expired: "This plan expired. Prepare a fresh plan."
        case .replay: "This plan already ran. Prepare a fresh plan."
        case .unavailable: "Choose one of your local Fonsters in an active world."
        case .denied: "That influence is switched off."
        case .noPeer: "That friend is no longer in this local world."
        case .noArea: "That place hasn't opened in this world."
        case .noPublicActions: "Private reflection stays on this Mac. Prepare a plan with movement or reactions to save a template."
        case .rateLimited: "Give this moment room to finish. Actions are spaced at least eight seconds apart."
        case .reflectionDenied: "Reflection needs a matching cue you chose, with that field switched on."
        }
    }
}

enum FonsterAgentScope: String, CaseIterable, Identifiable {
    case movement, reactions, feelings, friendships, learning
    var id: String { rawValue }
    var title: String {
        switch self { case .movement: "Movement"; case .reactions: "Reactions"; case .feelings: "Fonster feelings"; case .friendships: "Local friendships"; case .learning: "Personality learning" }
    }
}
enum FonsterAgentSource: String, Codable { case simulated, localHandoff
    var title: String { self == .simulated ? "Simulated pilot" : "Reviewed local file" }
}
enum HumanReflectionField: String, Codable, CaseIterable, Identifiable {
    case feeling, activity, travel
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var choices: [HumanReflectionCue] { HumanReflectionCue.allCases.filter { $0.field == self } }
}
enum HumanReflectionCue: String, Codable, CaseIterable, Identifiable {
    case bright, quiet, focused, resting, outAndAbout, exploring
    var id: String { rawValue }
    var field: HumanReflectionField {
        switch self { case .bright, .quiet: .feeling; case .focused, .resting: .activity; case .outAndAbout, .exploring: .travel }
    }
    var title: String {
        switch self { case .bright: "Feeling bright"; case .quiet: "Feeling quiet"; case .focused: "Focusing"; case .resting: "Taking a break"; case .outAndAbout: "Out and about"; case .exploring: "Exploring somewhere" }
    }
    var reaction: String {
        switch self { case .bright: "hop"; case .quiet, .focused, .resting: "rest"; case .outAndAbout, .exploring: "look" }
    }
}
enum HumanReflectionAudience: String, CaseIterable, Identifiable { case thisMac, localCompanions
    var id: String { rawValue }
    var title: String { self == .thisMac ? "This Mac only" : "Local companions" }
}
struct HumanReflectionRule {
    var enabled = false
    var cue: HumanReflectionCue
    var audience: HumanReflectionAudience = .thisMac
}

/// Agent contributions have their own versioned archive; owner memories and
/// appearance identity are unchanged. Counts, never human context, are retained.
struct AgentRituals: Codable, Equatable {
    var hellos = 0, games = 0, rests = 0, discoveries = 0
    var simulated = 0, localHandoff = 0
    var day = ""
    var today = 0
    var lastLearned: Date?
    var total: Int { hellos + games + rests + discoveries }
    func warmth(_ base: Double) -> Double { min(1, max(0, base + Double(min(hellos, 12)) * 0.008)) }
    func energy(_ base: Double) -> Double { min(1, max(0, base + Double(min(games, 12) - min(rests, 12)) * 0.008)) }
}

@MainActor final class AgentRitualMemoryStore {
    private static var sharedPreview: AgentRitualMemoryStore?
    private struct Archive: Codable { let version: Int; var rituals: [String: AgentRituals] }
    private var archive = Archive(version: 1, rituals: [:])
    private var sessionCounts: [UUID: Int] = [:]
    private let url: URL
    private var mayWrite = true
    private(set) var status = "Agent rituals stay on this Mac."
    init(url: URL) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                guard data.count < 65_536 else { throw FonsterAgentError.invalid }
                let saved = try JSONDecoder().decode(Archive.self, from: data)
                guard saved.version == 1, saved.rituals.count <= 24, saved.rituals.allSatisfy({ UUID(uuidString: $0.key) != nil && [$0.value.hellos, $0.value.games, $0.value.rests, $0.value.discoveries, $0.value.simulated, $0.value.localHandoff].allSatisfy { (0...9999).contains($0) } && (0...6).contains($0.value.today) && $0.value.total == $0.value.simulated + $0.value.localHandoff }) else { throw FonsterAgentError.invalid }
                archive = saved
            } catch { mayWrite = false; status = "Agent rituals are temporary; the existing archive was preserved." }
        }
    }
    static func localPreview() -> AgentRitualMemoryStore {
        if let sharedPreview { return sharedPreview }
        let store = makeLocalPreview(); sharedPreview = store; return store
    }
    private static func makeLocalPreview() -> AgentRitualMemoryStore {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--personality-file"), i + 1 < args.count { return .init(url: URL(fileURLWithPath: args[i + 1]).appendingPathExtension("agent.json")) }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("com.nathanfennel.Fonsters.Playroom")
        return .init(url: folder.appendingPathComponent("agent-rituals-v1.json"))
    }
    func profile(_ id: UUID) -> AgentRituals { archive.rituals[id.uuidString] ?? .init() }
    @discardableResult func learn(_ ritual: String, id: UUID, source: FonsterAgentSource, now: Date = .now) -> Bool {
        guard ["greet", "play", "rest", "look"].contains(ritual), sessionCounts[id, default: 0] < 3 else { return false }
        var value = profile(id)
        guard now.timeIntervalSince(value.lastLearned ?? .distantPast) >= 60, value.total < 9999 else { return false }
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let day = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        if value.day != day { value.day = day; value.today = 0 }
        guard value.today < 6 else { return false }
        switch ritual { case "greet": value.hellos += 1; case "play": value.games += 1; case "rest": value.rests += 1; default: value.discoveries += 1 }
        if source == .simulated { value.simulated += 1 } else { value.localHandoff += 1 }
        value.today += 1; value.lastLearned = now
        sessionCounts[id, default: 0] += 1; archive.rituals[id.uuidString] = value
        guard mayWrite else { return true }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(archive).write(to: url, options: .atomic)
        } catch { status = "Agent rituals are temporary; they couldn't be saved." }
        return true
    }
}
