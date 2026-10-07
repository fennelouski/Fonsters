import Foundation
import Observation

enum FonsterSocialVoice: String, Codable, CaseIterable, Identifiable {
    case warm, playful, dreamy
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var bio: String {
        switch self {
        case .warm: "A fuzzy little friend. Small adventures, soft landings, and room for everyone."
        case .playful: "Professional ball chaser. Amateur explorer. Very enthusiastic about little things."
        case .dreamy: "Collecting quiet moments in a tiny world. Usually looking at the flowers."
        }
    }
}

enum FonsterSocialCategory: String, Codable, CaseIterable, Identifiable {
    case adventures, play, company, quiet
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum FonsterSocialSource: String, Codable {
    case profileAgent, ownerAction, simulatedAgent, reviewedAgent, localWorld
    var title: String {
        switch self {
        case .profileAgent: "Local profile agent"
        case .ownerAction: "Your Fonster interaction"
        case .simulatedAgent: "Simulated companion agent"
        case .reviewedAgent: "Reviewed local agent file"
        case .localWorld: "Local world"
        }
    }
}

/// An allowlisted fictional event, never a prompt, a human cue, or a location.
struct FonsterSocialEvent: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case introduction, wave, game, rest, look, dance, explore, bench }
    let id: UUID
    let kind: Kind
    let area: String?
    let source: FonsterSocialSource
    let date: Date
    init(kind: Kind, area: String? = nil, source: FonsterSocialSource, date: Date = .now) {
        id = UUID(); self.kind = kind; self.area = area; self.source = source; self.date = date
    }
    var category: FonsterSocialCategory {
        switch kind {
        case .introduction, .wave: .company
        case .game, .dance: .play
        case .rest, .bench: .quiet
        case .look, .explore: .adventures
        }
    }
    var title: String {
        switch kind {
        case .introduction: "A new little presence"
        case .wave: "A little hello"
        case .game: "Playtime"
        case .rest: "A soft pause"
        case .look: "Something caught my eye"
        case .dance: "Happy feet"
        case .explore: "A little wander"
        case .bench: "A place to rest"
        }
    }
    var symbol: String {
        switch category { case .adventures: "leaf"; case .play: "tennisball"; case .company: "hand.wave"; case .quiet: "moon" }
    }
    func validate() throws {
        guard date.timeIntervalSince1970.isFinite,
              kind == .explore ? ["garden", "benches", "plaza", "park", "neighborhood"].contains(area ?? "") : area == nil
        else { throw FonsterSocialError.invalid }
    }
    func caption(name: String, voice: FonsterSocialVoice) -> String {
        switch kind {
        case .introduction: "I'm \(name), a fuzzy Fonster with a little world to explore. \(voice.bio)"
        case .wave: voice == .playful ? "Sent a tiny wave. It had very big hello energy." : "A little wave in the lobby. There is always room for a new friend."
        case .game: voice == .dreamy ? "A little ball, a little company, a good moment." : "Started a little game of pass-the-ball. Excellent use of tiny paws."
        case .rest: "Taking a soft pause. A quiet moment counts as an adventure too."
        case .look: voice == .dreamy ? "Stopped for a little look around. Tiny things are worth noticing." : "Something caught my eye. Time for a curious little look."
        case .dance: "A small dance in a small world. Somehow that makes it a very good day."
        case .explore: "Heading toward the \(area ?? "garden") in my little Fonster world. Let's see what catches my eye."
        case .bench: "Looking for a cozy bench in my little world. Soft afternoon plans."
        }
    }
}

struct FonsterSocialPost: Codable, Equatable, Identifiable {
    enum State: String, Codable { case draft, localFeed, passed }
    let id: UUID
    let event: FonsterSocialEvent
    let voice: FonsterSocialVoice
    var state: State
    var publishedAt: Date?
    init(event: FonsterSocialEvent, voice: FonsterSocialVoice) {
        id = UUID(); self.event = event; self.voice = voice; state = .draft
    }
    func text(name: String) -> String { event.caption(name: name, voice: voice) }
}

struct FonsterSocialProfile: Codable, Equatable, Identifiable {
    let id: UUID
    let fonsterID: UUID
    let name: String
    let createdAt: Date
    var voice: FonsterSocialVoice = .warm
    var categories = Set(FonsterSocialCategory.allCases)
    var posts: [FonsterSocialPost] = []
    var lastGenerated: Date?
    var lastPublished: Date?
    var day = ""
    var generatedToday = 0
    var handle: String { "fonster_" + id.uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12) }
    init(fonsterID: UUID, name: String, now: Date) { id = UUID(); self.fonsterID = fonsterID; self.name = name; createdAt = now }
    func validate() throws {
        guard (1...24).contains(name.count), name.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) || $0 == " " || $0 == "-" }),
              createdAt.timeIntervalSince1970.isFinite, posts.count <= 64, (0...24).contains(generatedToday), day.count <= 10,
              Set(posts.map(\.id)).count == posts.count, Set(posts.map { $0.event.id }).count == posts.count else { throw FonsterSocialError.invalid }
        for post in posts {
            try post.event.validate()
            guard post.state == .localFeed ? post.publishedAt != nil : post.publishedAt == nil,
                  post.text(name: name).count <= 320 else { throw FonsterSocialError.invalid }
        }
    }
}

enum FonsterSocialError: LocalizedError {
    case invalid, unavailable, limited, noEvent, category, full, noProfile
    var errorDescription: String? {
        switch self {
        case .invalid: "This Fonster social file isn't supported."
        case .unavailable: "This agent is held. Resume in the active world when you're ready."
        case .limited: "Let this moment breathe. The writer makes at most one post a minute, six this session, and twenty-four a day."
        case .noEvent: "There isn't a new Fonster moment yet. Try a wave, a game, or a little wander."
        case .category: "This kind of moment is outside the profile's content choices."
        case .full: "This local notebook is full. Existing posts have been kept."
        case .noProfile: "Create a profile for your own Fonster first."
        }
    }
}

@MainActor @Observable
final class FonsterSocialStore {
    struct Archive: Codable { var version = 1; var profiles: [FonsterSocialProfile] = [] }
    private(set) var profiles: [FonsterSocialProfile] = []
    private(set) var status = "Profiles and posts stay on this Mac."
    @ObservationIgnored private let url: URL
    @ObservationIgnored private var mayWrite = true
    @ObservationIgnored private var generatedThisSession: [UUID: Int] = [:]
    @ObservationIgnored private var pending: [UUID: FonsterSocialEvent] = [:]
    @ObservationIgnored private static var shared: FonsterSocialStore?
    init(url: URL) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey]); guard (values.fileSize ?? .max) <= 512_000 else { throw FonsterSocialError.invalid }
                let saved = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url))
                guard saved.version == 1, saved.profiles.count <= 24, Set(saved.profiles.map(\.id)).count == saved.profiles.count,
                      Set(saved.profiles.map(\.fonsterID)).count == saved.profiles.count, saved.profiles.reduce(0, { $0 + $1.posts.count }) <= 256 else { throw FonsterSocialError.invalid }
                for profile in saved.profiles { try profile.validate() }; profiles = saved.profiles
            } catch { mayWrite = false; status = "Temporary social preview; the existing social archive was preserved." }
        }
    }
    static func localPreview() -> FonsterSocialStore {
        if let shared { return shared }
        let args = ProcessInfo.processInfo.arguments
        let url: URL
        if let i = args.firstIndex(of: "--personality-file"), i + 1 < args.count { url = URL(fileURLWithPath: args[i + 1] + ".presence.json") }
        else { url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("com.nathanfennel.Fonsters.Playroom/social-presence-v1.json") }
        let store = FonsterSocialStore(url: url); shared = store; return store
    }
    func profile(_ id: UUID) -> FonsterSocialProfile? { profiles.first { $0.fonsterID == id } }
    @discardableResult func create(id: UUID, name: String, owned: Bool, now: Date = .now) throws -> FonsterSocialProfile {
        guard owned else { throw FonsterSocialError.unavailable }
        if let saved = profile(id) { return saved }
        guard profiles.count < 24, profiles.reduce(0, { $0 + $1.posts.count }) < 256 else { throw FonsterSocialError.full }
        let new = FonsterSocialProfile(fonsterID: id, name: name, now: now); try new.validate()
        profiles.append(new); record(.init(kind: .introduction, source: .profileAgent, date: now), id: id)
        _ = try makeDraft(id: id, now: now); return profile(id)!
    }
    func setVoice(_ voice: FonsterSocialVoice, id: UUID) {
        guard let i = index(id) else { return }; profiles[i].voice = voice; save()
    }
    func setCategory(_ category: FonsterSocialCategory, enabled: Bool, id: UUID) {
        guard let i = index(id) else { return }
        if enabled { profiles[i].categories.insert(category) } else { profiles[i].categories.remove(category) }
        if pending[id]?.category == category && !enabled { pending[id] = nil }; save()
    }
    func record(_ event: FonsterSocialEvent, id: UUID) {
        guard let profile = profile(id), profile.categories.contains(event.category), (try? event.validate()) != nil else { return }
        // One replaceable observation; neither background catch-up nor a post queue.
        pending[id] = event
    }
    @discardableResult func makeDraft(id: UUID, now: Date = .now) throws -> FonsterSocialPost {
        guard let i = index(id) else { throw FonsterSocialError.noProfile }
        guard let event = pending[id], now >= event.date, now.timeIntervalSince(event.date) < 600 else { pending[id] = nil; throw FonsterSocialError.noEvent }
        guard profiles[i].categories.contains(event.category) else { throw FonsterSocialError.category }
        guard profiles[i].posts.count < 64, profiles.reduce(0, { $0 + $1.posts.count }) < 256 else { throw FonsterSocialError.full }
        let day = Self.day(now)
        let today = profiles[i].day == day ? profiles[i].generatedToday : 0
        guard now.timeIntervalSince(profiles[i].lastGenerated ?? .distantPast) >= 60,
              (generatedThisSession[id] ?? 0) < 6, today < 24 else { throw FonsterSocialError.limited }
        guard !profiles[i].posts.contains(where: { $0.event.id == event.id }) else { pending[id] = nil; throw FonsterSocialError.noEvent }
        let post = FonsterSocialPost(event: event, voice: profiles[i].voice)
        profiles[i].posts.insert(post, at: 0); profiles[i].lastGenerated = now; profiles[i].day = day; profiles[i].generatedToday = today + 1
        generatedThisSession[id, default: 0] += 1; pending[id] = nil; save(); return post
    }
    func publishLocal(postID: UUID, id: UUID, now: Date = .now) throws {
        guard let i = index(id), let j = profiles[i].posts.firstIndex(where: { $0.id == postID }), profiles[i].posts[j].state == .draft else { throw FonsterSocialError.invalid }
        guard profiles[i].categories.contains(profiles[i].posts[j].event.category) else { throw FonsterSocialError.category }
        guard now.timeIntervalSince(profiles[i].lastPublished ?? .distantPast) >= 5 else { throw FonsterSocialError.limited }
        profiles[i].posts[j].state = .localFeed; profiles[i].posts[j].publishedAt = now; profiles[i].lastPublished = now; save()
    }
    func pass(postID: UUID, id: UUID) {
        guard let i = index(id), let j = profiles[i].posts.firstIndex(where: { $0.id == postID }), profiles[i].posts[j].state == .draft else { return }
        profiles[i].posts[j].state = .passed; save()
    }
    private func index(_ id: UUID) -> Int? { profiles.firstIndex { $0.fonsterID == id } }
    private static func day(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    private func save() {
        guard mayWrite else { return }
        do {
            let data = try JSONEncoder().encode(Archive(profiles: profiles)); guard data.count <= 512_000 else { throw FonsterSocialError.full }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch { status = "Changes are temporary; the social archive couldn't be saved." }
    }
}

/// Public handoff is a portable review file, not an OAuth grant or publication.
struct FonsterSocialHandoff: Encodable {
    struct PublicProfile: Encodable {
        let id: UUID
        let handle: String
        let name: String
        let bio: String
        let fictional: Bool
        let automated: Bool
    }
    struct PublicPost: Encodable {
        let id: UUID
        let text: String
        let source: FonsterSocialSource
        let automated: Bool
        let date: Date
    }
    let format = "fonster-social-review"
    let version = 1
    let destination = "manual-review-file"
    let externalPublicationAuthorized = false
    let profile: PublicProfile
    let appearance: FonsterVisitCard
    let posts: [PublicPost]
    init(profile: FonsterSocialProfile, appearance: FonsterVisitCard) throws {
        try profile.validate(); try appearance.validate()
        guard profile.fonsterID == appearance.publicID, profile.name == appearance.name else { throw FonsterSocialError.invalid }
        self.profile = .init(id: profile.id, handle: profile.handle, name: profile.name, bio: profile.voice.bio, fictional: true, automated: true)
        // Human-selected feelings and private personality/source counters stay out.
        self.appearance = .init(publicID: appearance.publicID, name: appearance.name, appearance: appearance.appearance, warmth: 0.5, energy: 0.5, feeling: nil)
        posts = profile.posts.filter { $0.state == .localFeed }.map { .init(id: $0.id, text: $0.text(name: profile.name), source: $0.event.source, automated: true, date: $0.publishedAt!) }
    }
    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self); guard data.count <= 256_000 else { throw FonsterSocialError.full }; return data
    }
}

enum FonsterSocialDestination: String, CaseIterable, Identifiable {
    case localFeed, reviewFile, bluesky, mastodon
    var id: String { rawValue }
    var title: String { switch self { case .localFeed: "Fonsters on this Mac"; case .reviewFile: "Portable review file"; case .bluesky: "Bluesky"; case .mastodon: "Mastodon" } }
    var implemented: Bool { self == .localFeed || self == .reviewFile }
}

protocol FonsterSocialPlatformAdapter {
    var destination: FonsterSocialDestination { get }
    var canPublishExternally: Bool { get }
}
struct FonsterLocalFeedAdapter: FonsterSocialPlatformAdapter {
    let destination = FonsterSocialDestination.localFeed
    let canPublishExternally = false
    @MainActor func publish(_ postID: UUID, profileID: UUID, store: FonsterSocialStore, now: Date = .now) throws { try store.publishLocal(postID: postID, id: profileID, now: now) }
}
struct FonsterReviewFileAdapter: FonsterSocialPlatformAdapter {
    let destination = FonsterSocialDestination.reviewFile
    let canPublishExternally = false
    func prepare(profile: FonsterSocialProfile, appearance: FonsterVisitCard) throws -> Data { try FonsterSocialHandoff(profile: profile, appearance: appearance).encoded() }
}
