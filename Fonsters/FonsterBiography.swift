import Foundation

/// User-authored character details, separate from appearance and learned care.
/// Stored privately with the Fonster; new visits include only chosen source IDs.
nonisolated struct FonsterBiography: Codable, Equatable, Sendable {
    var background = ""
    var likes: [String] = []
    var dislikes: [String] = []
    var movies: [String] = []
    var shows: [String] = []
    var creators: [String] = []
    var celebrities: [String] = []
    // Optional JSON field preserves biographies written before interest chips.
    var interests: [FonsterInterestSelection]? = nil
    var music: [String]? = nil
    var places: [String]? = nil
    var isEmpty: Bool { background.isEmpty && lists.allSatisfy(\.isEmpty) && (interests ?? []).isEmpty }
    private var lists: [[String]] { [likes, dislikes, movies, shows, creators, celebrities, music ?? [], places ?? []] }

    static func list(from text: String) -> [String] {
        var seen = Set<String>()
        return text.split(whereSeparator: { $0 == "," || $0 == "\n" }).compactMap {
            let item = String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
            return !item.isEmpty && seen.insert(item.lowercased()).inserted ? item : nil
        }.prefix(8).map { $0 }
    }
    var normalized: Self {
        var result = self
        result.background = String(background.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600))
        result.likes = Self.list(from: likes.joined(separator: ","))
        result.dislikes = Self.list(from: dislikes.joined(separator: ","))
        result.movies = Self.list(from: movies.joined(separator: ","))
        result.shows = Self.list(from: shows.joined(separator: ","))
        result.creators = Self.list(from: creators.joined(separator: ","))
        result.celebrities = Self.list(from: celebrities.joined(separator: ","))
        result.music = music.map { Self.list(from: $0.joined(separator: ",")) }
        result.places = places.map { Self.list(from: $0.joined(separator: ",")) }
        let checked = FonsterInterestCatalog.validated(interests ?? [])
        result.interests = checked.isEmpty ? nil : checked
        return result
    }
    /// A recipient can resolve only bundled checked entity IDs. All free text
    /// remains on the owner's device, including imported legacy biographies.
    var recipientSnapshot: Self {
        var result = Self()
        let checked = FonsterInterestCatalog.validated(interests ?? [])
        result.interests = checked.isEmpty ? nil : checked
        return result
    }
    /// Retained to validate/decode old version 2 visits. New visits use only IDs.
    var publicSnapshot: Self {
        var result = normalized
        result.background = result.background.replacingOccurrences(of: "[^\\s<>]+@[^\\s<>]+", with: "…", options: .regularExpression)
        result.background = result.background.replacingOccurrences(of: "@", with: "")
        result.likes.removeAll { $0.contains("@") }; result.dislikes.removeAll { $0.contains("@") }
        result.movies.removeAll { $0.contains("@") }; result.shows.removeAll { $0.contains("@") }
        result.creators.removeAll { $0.contains("@") }; result.celebrities.removeAll { $0.contains("@") }
        return result
    }
    var isValidPublicSnapshot: Bool {
        self == normalized && !background.contains("@") && lists.joined().allSatisfy { !$0.contains("@") }
    }
}
