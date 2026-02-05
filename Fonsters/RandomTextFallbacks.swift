//
//  RandomTextFallbacks.swift
//  Fonsters
//
//  Random text sources: "quote" uses Quotable API (api.quotable.io) with local fallback;
//  "words", "uuid", and "lorem" are local-only. Register sources with a closure that
//  returns optional text; the fetch layer uses API for quote, local for the rest.
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
    /// Registers the built-in fallbacks: "words", "uuid", "quote", and "lorem".
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
        register(source: "quote") {
            let quotes = [
                "The only way to do great work is to love what you do. — Steve Jobs",
                "In the middle of difficulty lies opportunity. — Albert Einstein",
                "It is during our darkest moments that we must focus to see the light. — Aristotle",
                "The journey of a thousand miles begins with a single step. — Lao Tzu",
                "Be the change that you wish to see in the world. — Mahatma Gandhi",
                "The only impossible journey is the one you never begin. — Tony Robbins",
                "Everything you can imagine is real. — Pablo Picasso",
                "What we think, we become. — Buddha",
                "The best time to plant a tree was 20 years ago. The second best time is now. — Chinese proverb",
                "Do what you can, with what you have, where you are. — Theodore Roosevelt"
            ]
            return quotes.randomElement()
        }
        register(source: "lorem") {
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."
        }
    }
}

// MARK: - Fetch with fallback

private let quotableAPIURL = URL(string: "https://api.quotable.io/random")!

/// Fetches random text: for "quote" uses Quotable API with local fallback; for "words", "uuid", "lorem" uses local only.
/// Returns (text, usedFallback). Call from main app or Watch; ensure RandomTextFallbacks.registerDefaults() has been called at app launch.
func fetchRandomTextWithFallback(source: String) async -> (String?, Bool) {
    switch source {
    case "quote":
        return await fetchQuoteWithFallback()
    case "words", "uuid", "lorem":
        let text = RandomTextFallbacks.localText(for: source)
        return (text, text != nil)
    default:
        let text = RandomTextFallbacks.localText(for: source)
        return (text, text != nil)
    }
}

private func fetchQuoteWithFallback() async -> (String?, Bool) {
    do {
        let (data, response) = try await URLSession.shared.data(from: quotableAPIURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let fallback = RandomTextFallbacks.localText(for: "quote")
            return (fallback, fallback != nil)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let content = json?["content"] as? String, !content.isEmpty {
            let author = json?["author"] as? String
            let text = author.map { "\(content) — \($0)" } ?? content
            return (text, false)
        }
    } catch { }
    let fallback = RandomTextFallbacks.localText(for: "quote")
    return (fallback, fallback != nil)
}

/// Fetches random text from the API; on failure uses the local fallback for that source if registered. Returns nil only if both API and fallback fail.
func fetchRandomText(source: String) async -> String? {
    let (text, _) = await fetchRandomTextWithFallback(source: source)
    return text
}
