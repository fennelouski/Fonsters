import Foundation

/// Appearance and legacy seeds never enter this small, portable memory model.
struct CreaturePersonality: Codable, Equatable {
    let publicID: UUID
    let baseWarmth: Double
    let baseEnergy: Double
    let naturalQuirk: String
    var hellos = 0
    var games = 0
    var rests = 0
    var discoveries = 0
    var soundLikes = [0, 0, 0]
    var lastLikedSound: Int?

    init(name: String) {
        publicID = UUID()
        switch name {
        case "Moss", "Wisp": baseWarmth = 0.25; baseEnergy = 0.35; naturalQuirk = "A shy, curious little soul."
        case "Coral", "Orbit", "Poppy": baseWarmth = 0.65; baseEnergy = 0.8; naturalQuirk = "Naturally bouncy, with a warm hello."
        case "Tide", "Nori", "Inky": baseWarmth = 0.45; baseEnergy = 0.3; naturalQuirk = "Thoughtful company for slow afternoons."
        default: baseWarmth = 0.5; baseEnergy = 0.55; naturalQuirk = "A curious little soul, finding its own rhythm."
        }
    }
    var interactionCount: Int { hellos + games + rests + discoveries }
    var greetingWarmth: Double { min(0.95, baseWarmth + Double(hellos) * 0.025) }
    var playEnergy: Double { (baseEnergy * 12 + Double(games)) / Double(12 + games + rests) }
    var favoriteSound: Int? {
        guard soundLikes.count == 3, let maxLikes = soundLikes.max(), maxLikes > 0 else { return nil }
        if let lastLikedSound, soundLikes.indices.contains(lastLikedSound), soundLikes[lastLikedSound] == maxLikes { return lastLikedSound }
        return soundLikes.firstIndex(of: maxLikes)
    }
    func observations(name: String) -> [String] {
        var notes: [String] = []
        if hellos >= 3 { notes.append("\(name)’s hello is getting a little bolder.") }
        if games >= 3 && games > rests { notes.append("A happy dance is becoming one of your shared rituals.") }
        if rests >= 3 && rests >= games { notes.append("\(name) is finding a calmer rhythm beside you.") }
        if discoveries >= 3 { notes.append("Those little moments of curiosity are becoming familiar.") }
        if let favoriteSound { notes.append("\(name) has a favorite \(Self.soundNames[favoriteSound].lowercased()) chirp.") }
        return notes.isEmpty ? ["Your shared rituals are just beginning."] : notes
    }
    static let soundNames = ["Warm", "Clear", "Bright"]
}

/// One isolated local preview file. Corrupt/newer data is preserved and never migrated.
@MainActor
final class PersonalityMemoryStore {
    private struct Archive: Codable { let version: Int; var profiles: [String: CreaturePersonality] }
    private var archive = Archive(version: 1, profiles: [:])
    private let url: URL
    private var mayWrite = true
    private var lastLearning: [String: Date] = [:]
    private(set) var status = "Memories stay on this Mac."

    init(url: URL) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let saved = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url))
                guard saved.version == 1, saved.profiles.values.allSatisfy({
                    $0.soundLikes.count == 3 && $0.soundLikes.allSatisfy { $0 >= 0 && $0 < 100_000 } &&
                    [$0.hellos, $0.games, $0.rests, $0.discoveries].allSatisfy { $0 >= 0 && $0 < 100_000 } &&
                    $0.baseWarmth.isFinite && (0...1).contains($0.baseWarmth) &&
                    $0.baseEnergy.isFinite && (0...1).contains($0.baseEnergy)
                }) else { throw CocoaError(.fileReadCorruptFile) }
                archive = saved
            } catch { mayWrite = false; status = "These memories are temporary; saved memories couldn’t be opened." }
        }
    }
    static func localPreview() -> PersonalityMemoryStore {
        let args = ProcessInfo.processInfo.arguments
        // Tests can use an isolated path; normal use has its own preview namespace.
        if let i = args.firstIndex(of: "--personality-file"), i + 1 < args.count {
            return .init(url: URL(fileURLWithPath: args[i + 1]))
        }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.nathanfennel.Fonsters.Playroom", isDirectory: true)
        return .init(url: folder.appendingPathComponent("personality-v1.json"))
    }
    func profile(for name: String) -> CreaturePersonality {
        if let saved = archive.profiles[name] { return saved }
        let new = CreaturePersonality(name: name)
        archive.profiles[name] = new; save()
        return new
    }
    func learn(_ event: String, name: String, now: Date = .now) -> CreaturePersonality? {
        guard ["greet", "play", "rest", "look"].contains(event),
              now.timeIntervalSince(lastLearning[name] ?? .distantPast) >= 3 else { return nil }
        lastLearning[name] = now
        var memory = profile(for: name)
        switch event {
        case "greet": memory.hellos = min(99_999, memory.hellos + 1)
        case "play": memory.games = min(99_999, memory.games + 1)
        case "rest": memory.rests = min(99_999, memory.rests + 1)
        default: memory.discoveries = min(99_999, memory.discoveries + 1)
        }
        archive.profiles[name] = memory; save(); return memory
    }
    func likeSound(_ variant: Int, name: String) -> CreaturePersonality {
        var memory = profile(for: name)
        guard memory.soundLikes.indices.contains(variant) else { return memory }
        memory.soundLikes[variant] = min(99_999, memory.soundLikes[variant] + 1)
        memory.lastLikedSound = variant
        archive.profiles[name] = memory; save(); return memory
    }
    private func save() {
        guard mayWrite else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(archive).write(to: url, options: .atomic)
            status = "Memories stay on this Mac."
        } catch { status = "These memories are temporary; they couldn’t be saved." }
    }
}
