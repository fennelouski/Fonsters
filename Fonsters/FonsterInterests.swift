import Foundation

nonisolated enum FonsterInterestCategory: String, Codable, CaseIterable, Sendable {
    case likes, dislikes, movies, shows, creators, celebrities, music, places
}

/// Persist a public catalog reference, never a typed query, supplied title or URL.
nonisolated struct FonsterInterestSelection: Codable, Equatable, Hashable, Sendable {
    let category: FonsterInterestCategory
    let catalogID: String
}

nonisolated struct FonsterInterestEntity: Identifiable, Equatable, Sendable {
    let id: String
    let group: String
    let title: String
    let source: String
    let symbol: String
    let category: FonsterInterestCategory
    let summary: String
    let url: URL
    let aliases: [String]
}

/// Small editorial catalog checked against source pages on 2026-10-08. These
/// are checked snapshots, NOT live API matches. No remote images or requests.
/// Unknown imported IDs cannot supply their own display text, URLs or evidence.
nonisolated enum FonsterInterestCatalog {
    static let revision = "checked-2026-10-08"
    static let entities: [FonsterInterestEntity] = [
        item("bluey-official", "bluey", "Bluey", "Official website", "globe", .shows, "Animated adventures with Bluey and her family.", "https://www.bluey.tv/", ["bluey"]),
        item("bluey-wikipedia", "bluey", "Bluey (TV series)", "Wikipedia", "book.closed", .shows, "An encyclopedia entry about the television series.", "https://en.wikipedia.org/wiki/Bluey_(2018_TV_series)", ["bluey"]),
        item("spirited-away-wikipedia", "spirited-away", "Spirited Away", "Wikipedia", "book.closed", .movies, "A fantasy animated film directed by Hayao Miyazaki.", "https://en.wikipedia.org/wiki/Spirited_Away", ["spirited away", "sen to chihiro"]),
        item("disneyland-official", "disneyland", "Disneyland Park", "Official website", "globe", .places, "A theme park in Anaheim, California.", "https://disneyland.disney.go.com/destinations/disneyland/", ["disneyland", "disney", "anaheim"]),
        item("disneyland-wikipedia", "disneyland", "Disneyland", "Wikipedia", "book.closed", .places, "An encyclopedia entry about the original Disney theme park.", "https://en.wikipedia.org/wiki/Disneyland", ["disneyland", "disney", "anaheim"]),
        item("paris-wikipedia", "paris", "Paris", "Wikipedia", "book.closed", .places, "The capital city of France.", "https://en.wikipedia.org/wiki/Paris", ["paris", "france"]),
        item("mkbhd-youtube", "mkbhd", "Marques Brownlee", "YouTube", "play.rectangle", .creators, "Technology videos on the MKBHD channel.", "https://www.youtube.com/@mkbhd", ["mkbhd", "marques brownlee"]),
        item("mkbhd-wikipedia", "mkbhd", "Marques Brownlee", "Wikipedia", "book.closed", .creators, "An encyclopedia entry about the technology creator.", "https://en.wikipedia.org/wiki/Marques_Brownlee", ["mkbhd", "marques brownlee"]),
        item("nasa-official", "nasa", "NASA", "Official website", "globe", .creators, "The United States space agency.", "https://www.nasa.gov/", ["nasa", "space"]),
        item("taylor-swift-official", "taylor-swift", "Taylor Swift", "Official website", "globe", .music, "The artist's official website.", "https://www.taylorswift.com/", ["taylor swift", "taylor"]),
        item("taylor-swift-wikipedia", "taylor-swift", "Taylor Swift", "Wikipedia", "book.closed", .music, "An encyclopedia entry about the singer and songwriter.", "https://en.wikipedia.org/wiki/Taylor_Swift", ["taylor swift", "taylor"])
    ]
    private static func item(_ id: String, _ group: String, _ title: String, _ source: String, _ symbol: String,
                             _ category: FonsterInterestCategory, _ summary: String, _ url: String, _ aliases: [String]) -> FonsterInterestEntity {
        .init(id: id, group: group, title: title, source: source, symbol: symbol, category: category,
              summary: summary, url: URL(string: url)!, aliases: aliases)
    }
    static func entity(_ id: String) -> FonsterInterestEntity? { entities.first { $0.id == id } }
    static func validated(_ selections: [FonsterInterestSelection]) -> [FonsterInterestSelection] {
        var seen = Set<FonsterInterestSelection>()
        return Array(selections.filter { entity($0.catalogID) != nil && seen.insert($0).inserted }.prefix(32))
    }
    static func key(_ query: String) -> String {
        String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(128))
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    static func search(_ query: String, category: FonsterInterestCategory) -> [FonsterInterestEntity] {
        let terms = FonsterBiography.list(from: key(query)).filter { $0.count >= 2 }
        guard !terms.isEmpty else { return [] }
        return entities.filter { entity in
            let categoryMatches = category == .likes || category == .dislikes || category == .celebrities || entity.category == category
            return categoryMatches && terms.contains { term in
                ([key(entity.title)] + entity.aliases).contains { $0.contains(term) || term.contains($0) }
            }
        }
    }
}

protocol FonsterInterestResolving: Sendable {
    nonisolated func resolve(_ query: String, category: FonsterInterestCategory) async throws -> [FonsterInterestEntity]
}

/// Cancellable, asynchronous native provider seam. Cache is bounded and private
/// to this process. The protected app intentionally never submits draft queries.
actor FonsterCatalogResolver: FonsterInterestResolving {
    static let shared = FonsterCatalogResolver()
    private var cache: [String: [FonsterInterestEntity]] = [:]
    init() {}
    func resolve(_ query: String, category: FonsterInterestCategory) async throws -> [FonsterInterestEntity] {
        try Task.checkCancellation()
        let key = category.rawValue + ":" + FonsterInterestCatalog.key(query)
        if let cached = cache[key] { return cached }
        let result = FonsterInterestCatalog.search(query, category: category)
        if cache.count >= 128 { cache.removeAll(keepingCapacity: true) }
        cache[key] = result
        return result
    }
}
