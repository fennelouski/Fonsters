//
//  RandomTextFallbacks.swift
//  Fonsters
//
//  Locally defined fallbacks when the random-text API fails. Register sources
//  with a closure that returns optional text; the fetch layer tries API first,
//  then uses the fallback for that source if present.
//

import Foundation

/// Registry of local fallbacks by source id (e.g. "words", "uuid", "quote", "lorem").
/// Thread-safe for concurrent reads and single-writer updates.
enum RandomTextFallbacks {
    private static let lock = NSLock()
    private static var providers: [String: () -> String?] = [:]

    /// Register a fallback for a source. Re-registering overwrites.
    static func register(source: String, provider: @escaping () -> String?) {
        lock.lock()
        defer { lock.unlock() }
        providers[source] = provider
    }

    /// Remove the fallback for a source.
    static func unregister(source: String) {
        lock.lock()
        defer { lock.unlock() }
        providers.removeValue(forKey: source)
    }

    /// Return locally generated text for the source, or nil if no fallback is registered.
    static func localText(for source: String) -> String? {
        lock.lock()
        let provider = providers[source]
        lock.unlock()
        return provider?()
    }

    /// All source ids that have a registered fallback.
    static var registeredSources: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(providers.keys).sorted()
    }
}

// MARK: - Default fallbacks

extension RandomTextFallbacks {
    /// Registers the built-in fallbacks: "words" (random word list) and "uuid".
    static func registerDefaults() {
        register(source: "uuid") { UUID().uuidString }
        register(source: "words") {
            let words = [
                "glow", "leaf", "coral", "flame", "forest", "river", "stone", "cloud",
                "star", "moon", "sun", "wind", "wave", "seed", "root", "vine", "frost",
                "ember", "shadow", "light"
            ]
            let count = 4 + (words.count % 5)
            return (0..<count).map { _ in words.randomElement()! }.joined(separator: " ")
        }
    }
}

// MARK: - Fetch with fallback

private let randomTextAPIBase = "https://nathanfennel.com/api/creature-avatar/random-text"

/// Fetches random text from the API; on failure uses the local fallback for that source if registered.
/// Returns (text, usedFallback). Call from main app or Watch; ensure RandomTextFallbacks.registerDefaults() has been called at app launch if you want built-in "words" and "uuid" fallbacks.
func fetchRandomTextWithFallback(source: String) async -> (String?, Bool) {
    let urlString = "\(randomTextAPIBase)?source=\(source.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? source)"
    guard let url = URL(string: urlString) else {
        let fallback = RandomTextFallbacks.localText(for: source)
        return (fallback, fallback != nil)
    }
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let fallback = RandomTextFallbacks.localText(for: source)
            return (fallback, fallback != nil)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let text = json?["text"] as? String { return (text, false) }
    } catch { }
    let fallback = RandomTextFallbacks.localText(for: source)
    return (fallback, fallback != nil)
}

/// Fetches random text from the API; on failure uses the local fallback for that source if registered. Returns nil only if both API and fallback fail.
func fetchRandomText(source: String) async -> String? {
    let (text, _) = await fetchRandomTextWithFallback(source: source)
    return text
}
