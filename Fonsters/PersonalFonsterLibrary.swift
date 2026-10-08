import Foundation
import SwiftData
import CloudKit
import CryptoKit

/// No account name, email or raw CloudKit identifier is persisted or exported.
/// An internal, namespaced digest picks the same starter appearances per account.
@MainActor enum PersonalFonsterLibrary {
    struct Starter: Equatable { let id: UUID; let key: String; let name: String; let seed: String }
    private static let names = ["Bramble", "Mochi", "Clover", "Pip", "Bumble", "Fig", "Sprout", "Coco", "Fern", "Bean", "Juniper", "Peach", "Doodle", "Maple", "Biscuit", "Sunny"]
    private static func digest(_ text: String) -> [UInt8] { Array(SHA256.hash(data: Data(text.utf8))) }
    static func accountToken(recordName: String) -> String {
        digest("fonsters-private-starters-v1:" + recordName).map { String(format: "%02x", $0) }.joined()
    }
    static func starters(token: String) -> [Starter] {
        let bytes = digest(token)
        return (0..<4).map { slot in
            let key = accountToken(recordName: token + ":" + String(slot))
            var uuidBytes = Array(digest(key).prefix(16)); uuidBytes[6] = (uuidBytes[6] & 15) | 80; uuidBytes[8] = (uuidBytes[8] & 63) | 128
            let id = UUID(uuid: (uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3], uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7], uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11], uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]))
            return Starter(id: id, key: key, name: names[(Int(bytes[0]) + slot * 3) % names.count], seed: friendlySeed(entropy: key))
        }
    }
    /// The frozen renderer is untouched. Pick original appearances with visible
    /// eyes and a mouth that the existing fuzzy volumetric rig can faithfully host.
    static func friendlySeed(entropy: String) -> String {
        for attempt in 0..<256 {
            let seed = "personal-fonster-v1-\(entropy)-\(attempt)"
            let appearance = CreatureAppearanceDescriptor.resolve(seed: seed)
            if appearance.supported && appearance.head.radius >= 6 && appearance.parts.contains(where: { $0.kind == "eye" }) && appearance.parts.contains(where: { $0.kind == "mouth" }) { return seed }
        }
        return PlayroomCompanion.fixtures[Int(digest(entropy)[0]) % PlayroomCompanion.fixtures.count].seed
    }
    static func canonical(_ records: [Fonster]) -> [Fonster] {
        var starters: [String: Fonster] = [:]
        var custom: [Fonster] = []
        for record in records {
            guard let key = record.starterKey else { custom.append(record); continue }
            if let current = starters[key] {
                let lhs = record.profileModifiedAt ?? record.createdAt
                let rhs = current.profileModifiedAt ?? current.createdAt
                let stableTie = record.name == current.name ? (record.biographyData ?? Data()).lexicographicallyPrecedes(current.biographyData ?? Data()) : record.name < current.name
                if lhs > rhs || (lhs == rhs && stableTie) { starters[key] = record }
            } else { starters[key] = record }
        }
        return (custom + starters.values).sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt }
    }
    static func insertStarters(token: String, into context: ModelContext) throws {
        // Refetch after async account resolution; imports/custom creations win.
        guard try context.fetchCount(FetchDescriptor<Fonster>()) == 0 else { return }
        for starter in starters(token: token) {
            let record = Fonster(id: starter.id, name: starter.name, seed: starter.seed, createdAtISO8601: Fonster.currentCreatedAtISO8601())
            record.starterKey = starter.key; context.insert(record)
        }
        try context.save()
    }
    static func ensureStarters(in context: ModelContext) async throws {
        guard try context.fetchCount(FetchDescriptor<Fonster>()) == 0 else { return }
        let args = ProcessInfo.processInfo.arguments
        // Old deterministic UI demonstrations remain isolated and reproducible.
        if args.contains("--verify-manual") && !args.contains("--verify-personal-library") { return }
        let token: String
        if args.contains("--prototype") || Bundle.main.bundleIdentifier == "com.nathanfennel.Fonsters.Playroom" {
            token = args.contains("--verify-personal-library") ? "synthetic-account-library-test-v1" : offlineToken()
        } else {
            let cloud = CKContainer.default()
            let status = try await cloud.accountStatus()
            switch status {
            case .available:
                token = accountToken(recordName: try await cloud.userRecordID().recordName)
            case .noAccount, .restricted:
                token = offlineToken()
            default:
                // A transient account/network failure must not mint another set.
                throw LibraryError.accountUnavailable
            }
        }
        guard !Task.isCancelled else { return }
        try insertStarters(token: token, into: context)
    }
    private static func offlineToken() -> String {
        let key = "Fonsters.privateOfflineStarterToken.v1"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let token = UUID().uuidString; UserDefaults.standard.set(token, forKey: key); return token
    }
    enum LibraryError: LocalizedError {
        case accountUnavailable
        var errorDescription: String? { "Your iCloud starter library couldn't be opened yet. Try again when iCloud is available, or create a Fonster now." }
    }
}
