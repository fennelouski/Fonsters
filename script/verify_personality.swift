import Foundation

@main struct VerifyPersonality {
    @MainActor static func main() throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let url = folder.appendingPathComponent("memories.json")
        let store = PersonalityMemoryStore(url: url)
        let initial = store.profile(for: "Moss")
        let start = Date(timeIntervalSince1970: 1000)
        for _ in 0..<100 { _ = store.learn("greet", name: "Moss", now: start) }
        precondition(store.profile(for: "Moss").hellos == 1)
        _ = store.learn("greet", name: "Moss", now: start.addingTimeInterval(4))
        let learned = store.learn("greet", name: "Moss", now: start.addingTimeInterval(8))!
        precondition(learned.hellos == 3 && learned.greetingWarmth > initial.greetingWarmth)
        precondition(learned.observations(name: "Moss").first!.contains("bolder"))
        for i in 1...8 { _ = store.learn("rest", name: "Moss", now: start.addingTimeInterval(Double(i * 4 + 10))) }
        let calm = store.profile(for: "Moss")
        precondition(calm.playEnergy < initial.playEnergy)
        _ = store.likeSound(2, name: "Moss")
        let reload = PersonalityMemoryStore(url: url).profile(for: "Moss")
        precondition(reload.publicID == initial.publicID && reload.favoriteSound == 2 && reload.rests == 8)
        precondition(store.profile(for: "Coral").publicID != initial.publicID)
        precondition(store.profile(for: "Moss").hellos == reload.hellos, "Absence must not reduce traits")
        let encoded = try JSONEncoder().encode(reload)
        let text = String(decoding: encoded, as: UTF8.self)
        precondition(!text.contains("seed") && !text.contains("email") && !text.contains("camera") && !text.contains("microphone"))
        let bad = folder.appendingPathComponent("unreadable.json")
        let sentinel = Data("future-format-preserve-me".utf8); try sentinel.write(to: bad)
        let protected = PersonalityMemoryStore(url: bad)
        _ = protected.learn("play", name: "Moss", now: start)
        let preserved = try Data(contentsOf: bad)
        precondition(preserved == sentinel)
        let newer = folder.appendingPathComponent("newer.json")
        let future = Data("{\"version\":2,\"profiles\":{}}".utf8)
        try future.write(to: newer)
        _ = PersonalityMemoryStore(url: newer).likeSound(1, name: "Moss")
        let futurePreserved = try Data(contentsOf: newer)
        precondition(futurePreserved == future)
        print("PASS: 100 rapid inputs learn once; meaningful hellos grow greeting warmth; quiet rituals change energy; sound preference and random identity survive reload; companions remain separate; no absence penalty or input/seed data; unreadable memories preserved.")
    }
}
