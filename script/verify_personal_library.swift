import Foundation
import SwiftData

@main struct VerifyPersonalLibrary {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let token = PersonalFonsterLibrary.accountToken(recordName: "synthetic-account-alpha")
        let first = PersonalFonsterLibrary.starters(token: token)
        let second = PersonalFonsterLibrary.starters(token: token)
        let other = PersonalFonsterLibrary.starters(token: PersonalFonsterLibrary.accountToken(recordName: "synthetic-account-beta"))
        precondition(first == second && first != other && Set(first.map(\.id)).count == 4)
        precondition(first.allSatisfy { !$0.seed.contains("synthetic-account-alpha") && CreatureAppearanceDescriptor.resolve(seed: $0.seed).supported })
        let schema = Schema([Fonster.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = container.mainContext
        try PersonalFonsterLibrary.insertStarters(token: token, into: context)
        try PersonalFonsterLibrary.insertStarters(token: token, into: context)
        var records = try context.fetch(FetchDescriptor<Fonster>())
        precondition(records.count == 4)
        let original = records[0]
        let duplicate = Fonster(id: original.id, name: "Luma", seed: original.seed, createdAt: original.createdAt)
        duplicate.starterKey = original.starterKey; duplicate.profileModifiedAt = Date().addingTimeInterval(5)
        duplicate.biography = .init(background: "Born beneath a paper moon.", likes: ["Comets", "Picnics"], dislikes: ["Loud alarms"], movies: ["Spirited Away"], shows: ["Bluey"], creators: ["Hayao Miyazaki"], celebrities: ["LeVar Burton"])
        context.insert(duplicate); try context.save()
        records = try context.fetch(FetchDescriptor<Fonster>())
        let display = PersonalFonsterLibrary.canonical(records)
        precondition(records.count == 5 && display.count == 4 && display.contains { $0.name == "Luma" && $0.biography.likes == ["Comets", "Picnics"] })
        precondition(PersonalFonsterLibrary.canonical(Array(records.reversed())).map(\.name) == display.map(\.name))
        let custom = Fonster(name: "Custom friend", seed: PersonalFonsterLibrary.friendlySeed(entropy: "independent-custom-example"))
        context.insert(custom); try context.save()
        let allRecords = try context.fetch(FetchDescriptor<Fonster>())
        precondition(PersonalFonsterLibrary.canonical(allRecords).count == 5 && custom.starterKey == nil)
        print("PASS: same-account starters, different-account diversity, idempotent setup, converging duplicate starters without deleting records, independent custom creation")

        let appearance = CreatureAppearanceDescriptor.resolve(seed: duplicate.seed)
        let privateID = duplicate.id, publicID = UUID()
        let legacy = FonsterVisitCard(publicID: publicID, name: "Luma", appearance: appearance, warmth: 0.5, energy: 0.5)
        let v1 = try legacy.encoded()
        let v1Decoded = try FonsterVisitCard.decode(v1)
        precondition(v1Decoded == legacy)
        precondition(!String(decoding: v1, as: UTF8.self).contains("biography"))
        var biography = duplicate.biography
        biography.background += " Contact human@example.com @home."; biography.creators.append("private@example.com")
        let card = FonsterVisitCard(publicID: publicID, name: "Luma", appearance: appearance, warmth: 0.5, energy: 0.5, biography: biography)
        let data = try card.encoded(), string = String(decoding: data, as: UTF8.self)
        let v2Decoded = try FonsterVisitCard.decode(data)
        precondition(card.version == 2 && v2Decoded == card)
        precondition(!string.contains("@") && !string.contains(duplicate.seed) && !string.contains(privateID.uuidString) && !string.contains(duplicate.starterKey!))
        precondition(card.biography?.likes == ["Comets", "Picnics"] && card.biography?.celebrities == ["LeVar Burton"])
        var hostile = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var hidden = hostile["biography"] as! [String: Any]; hidden["account"] = "synthetic-account-alpha"; hostile["biography"] = hidden
        do { _ = try FonsterVisitCard.decode(JSONSerialization.data(withJSONObject: hostile)); preconditionFailure("Hidden metadata accepted") } catch {}
        precondition(FonsterBiography.list(from: "Comets, Comets, Picnics\nStars") == ["Comets", "Picnics", "Stars"])
        print("PASS: original v1 visits, opt-in v2 profile round trip, field bounds, no email/seed/private IDs in public data, unknown metadata rejection")

        // This file was written by a separate executable using the exact old model.
        let migrated = try ModelContainer(for: schema, configurations: [ModelConfiguration("LegacyMigration", schema: schema, url: root.appendingPathComponent("legacy.sqlite"), cloudKitDatabase: .none)])
        let old = try migrated.mainContext.fetch(FetchDescriptor<Fonster>())
        precondition(old.count == 1 && old[0].name == "Legacy Friend" && old[0].seed == "do-not-change-legacy-seed")
        precondition(old[0].history == ["prior-seed"] && old[0].biography.isEmpty && old[0].starterKey == nil)
        old[0].name = "Legacy Luma"; old[0].biography = duplicate.biography; old[0].profileModifiedAt = Date()
        try migrated.mainContext.save()
        let reopened = try ModelContainer(for: schema, configurations: [ModelConfiguration("LegacyMigration", schema: schema, url: root.appendingPathComponent("legacy.sqlite"), cloudKitDatabase: .none)])
        let persisted = try reopened.mainContext.fetch(FetchDescriptor<Fonster>())
        precondition(persisted.count == 1 && persisted[0].name == "Legacy Luma" && persisted[0].biography == duplicate.biography && persisted[0].seed == "do-not-change-legacy-seed")
        print("PASS: actual previous-schema SQLite upgrade, original seed/history retained, edited name and all profile fields persist after reopen")
        print("Starter names for synthetic account: " + first.map(\.name).joined(separator: ", "))
    }
}
