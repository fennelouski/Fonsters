import Foundation

/// This value is the entire command surface. Text can never become code or a tool call.
struct CreatureCommandIntent: Equatable, Sendable {
    private static let prototypeNames = ["Coral", "Moss", "Iris", "Tide", "Orbit", "Plum", "Poppy", "Inky", "Pebble", "Nori", "Ember", "Wisp", "Visitor"]
    enum Action: String, CaseIterable, Sendable {
        case hello, dance, rest, blink, look, hop, spin, stretch, highFive, rub, fetch, follow, roam, stop, greetFriend
        var title: String {
            switch self {
            case .hello: "say hello"; case .dance: "dance"; case .rest: "rest"; case .blink: "blink"
            case .look: "look around"; case .hop: "hop"; case .spin: "twirl"; case .stretch: "stretch"
            case .highFive: "give a high five"; case .rub: "enjoy a gentle rub"; case .fetch: "chase the ball"
            case .follow: "follow your pointer"; case .roam: "wander"; case .stop: "stay beside you"
            case .greetFriend: "greet a friend"
            }
        }
    }
    let action: Action
    let targetName: String
    let peerName: String?

    static func explicitActor(in text: String, allowed: [String]) -> String? {
        let first = text.lowercased().split { !$0.isLetter && !$0.isNumber }.first.map(String.init)
        return allowed.first { $0.lowercased() == first }
    }

    static func mentionsAbsentCreature(_ text: String, allowed: [String]) -> Bool {
        let words = Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        return prototypeNames.contains { words.contains($0.lowercased()) && !allowed.contains($0) }
    }

    static func hasConflictingKnownActions(_ text: String) -> Bool { knownActions(in: text).count > 1 }
    /// A recipient explicitly following “to” or “with” stays the recipient.
    static func explicitPeer(in text: String, allowed: [String]) -> String? {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var peers = Set<String>()
        for i in words.indices where ["to", "with"].contains(words[i]) && i + 1 < words.count {
            if let peer = allowed.first(where: { $0.lowercased() == words[i + 1] }) { peers.insert(peer) }
        }
        return peers.count == 1 ? peers.first : nil
    }
    static func hasMultiplePeers(_ text: String, selected: String, allowed: [String]) -> Bool {
        let words = Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        guard words.contains("to") || words.contains("with") else { return false }
        let actor = explicitActor(in: text, allowed: allowed) ?? selected
        return allowed.filter { $0 != actor && words.contains($0.lowercased()) }.count > 1
    }

    private static func knownActions(in text: String) -> Set<Action> {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let set = Set(words)
        let vocabulary: [(Action, Set<String>)] = [
            (.hello, ["hello", "wave", "greet", "hi"]), (.dance, ["dance", "dancing"]),
            (.rest, ["rest", "nap", "sleep", "sleepy"]), (.blink, ["blink"]), (.look, ["look"]),
            (.hop, ["hop", "jump", "bounce"]), (.spin, ["spin", "twirl"]), (.stretch, ["stretch"]),
            (.rub, ["rub", "pet", "tickle"]), (.fetch, ["fetch", "ball", "chase"]),
            (.follow, ["follow"]), (.roam, ["roam", "wander", "walk", "explore"]), (.stop, ["stop", "stay"])
        ]
        var matches = Set(vocabulary.filter { !$0.1.isDisjoint(with: set) }.map(\.0))
        if words.joined(separator: " ").contains("high five") || set.contains("highfive") { matches.insert(.highFive) }
        return matches
    }

    static func validate(action: String, target: String, peer: String?, selected: String, allowed: [String]) -> Self? {
        guard let kind = Action(rawValue: action) else { return nil }
        func resolve(_ name: String) -> String? {
            if name == "selected" { return allowed.contains(selected) ? selected : nil }
            return allowed.first { $0.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }
        }
        guard let name = resolve(target) else { return nil }
        if kind == .greetFriend {
            guard let peer, let friend = resolve(peer), friend != name else { return nil }
            return .init(action: kind, targetName: name, peerName: friend)
        }
        return .init(action: kind, targetName: name, peerName: nil)
    }

    /// Known phrases remain useful on Macs without an available on-device model.
    static func fallback(_ text: String, selected: String, allowed: [String]) -> Self? {
        guard text.count <= 400 else { return nil }
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let set = Set(words)
        guard !mentionsAbsentCreature(text, allowed: allowed) else { return nil }
        let named = allowed.filter { set.contains($0.lowercased()) }
        let explicitTarget = explicitActor(in: text, allowed: allowed) ?? selected
        let matches = knownActions(in: text)
        guard matches.count == 1, let action = matches.first else { return nil }
        if action == .hello && (set.contains("to") || set.contains("with")) {
            let peers = named.filter { $0 != explicitTarget }
            guard peers.count == 1, let friend = peers.first else { return nil }
            return validate(action: "greetFriend", target: explicitTarget, peer: friend, selected: selected, allowed: allowed)
        }
        return validate(action: action.rawValue, target: explicitTarget, peer: nil, selected: selected, allowed: allowed)
    }
}
