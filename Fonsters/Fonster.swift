//
//  Fonster.swift
//  Fonsters
//
//  SwiftData model for a user-created creature (Fonster).
//
//  - name: User-facing label (e.g. "Bob"); distinct from seed.
//  - seed: Source text that drives the deterministic creature image; same seed
//    always produces the same creature.
//  - randomSource: When set (e.g. "quote", "words"), Refresh uses that API and
//    Undo/Redo are available (history/future capped at 20).
//
//  All of the above persist. Undo/redo work as implemented; they are only
//  exposed in the UI when randomSource != nil.
//

import Foundation
import SwiftData

@Model
public final class Fonster {
    @Attribute(.unique) public var id: UUID
    /// User-chosen display name; shown in the list and detail header.
    public var name: String
    /// Source text for the creature; editing this changes the creature.
    public var seed: String
    /// If set, Refresh fetches from random-text API; Undo/Redo are shown.
    public var randomSource: String?
    /// JSON-encoded [String]; max 20 entries for undo stack.
    public var historyData: Data?
    /// JSON-encoded [String]; max 20 entries for redo stack.
    public var futureData: Data?
    public var createdAt: Date
    /// Full ISO 8601 date-time with timezone offset at creation (e.g. "2025-02-03T14:30:00-08:00"). Nil for legacy records.
    public var createdAtISO8601: String?

    public init(
        id: UUID = UUID(),
        name: String = "",
        seed: String = "",
        randomSource: String? = nil,
        history: [String] = [],
        future: [String] = [],
        createdAt: Date = Date(),
        createdAtISO8601: String? = nil
    ) {
        self.id = id
        self.name = name
        self.seed = seed
        self.randomSource = randomSource
        self.historyData = Self.encodeHistory(history)
        self.futureData = Self.encodeHistory(future)
        self.createdAt = createdAt
        self.createdAtISO8601 = createdAtISO8601
    }

    /// Returns the current moment as ISO 8601 with local timezone (for new creations).
    public static func currentCreatedAtISO8601() -> String {
        formatCreatedAtISO8601(Date())
    }

    private static func formatCreatedAtISO8601(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// Calendar (month, day) for birthday; uses creation timezone from ISO or current local for legacy.
    public var birthdayMonthDay: (month: Int, day: Int)? {
        if let iso = createdAtISO8601, iso.count >= 10 {
            let prefix = String(iso.prefix(10))
            let parts = prefix.split(separator: "-")
            guard parts.count == 3,
                  let month = Int(parts[1]),
                  let day = Int(parts[2]),
                  (1...12).contains(month),
                  (1...31).contains(day) else { return nil }
            return (month, day)
        }
        let cal = Calendar.current
        let comp = cal.dateComponents([.month, .day], from: createdAt)
        guard let m = comp.month, let d = comp.day else { return nil }
        return (m, d)
    }

    /// True if today (in local time) is this Fonster's birthday.
    public var isBirthdayToday: Bool {
        guard let bday = birthdayMonthDay else { return false }
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        return today.month == bday.month && today.day == bday.day
    }

    private static let cap = 20

    public var history: [String] {
        get { Self.decodeHistory(historyData) }
        set { historyData = Self.encodeHistory(Array(newValue.suffix(Self.cap))) }
    }

    public var future: [String] {
        get { Self.decodeHistory(futureData) }
        set { futureData = Self.encodeHistory(Array(newValue.prefix(Self.cap))) }
    }

    private static func encodeHistory(_ arr: [String]) -> Data? {
        try? JSONEncoder().encode(arr)
    }

    private static func decodeHistory(_ data: Data?) -> [String] {
        guard let data = data,
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    /// Pushes current seed onto history, clears future, and sets seed to newSeed. Use when applying Refresh or Load random.
    public func pushHistoryAndSetSeed(_ newSeed: String) {
        var h = history
        h.append(seed)
        history = Array(h.suffix(Self.cap))
        future = []
        seed = newSeed
    }

    /// Restores previous seed from history; returns false if history is empty.
    public func undo() -> Bool {
        guard let prev = history.popLast() else { return false }
        var f = future
        f.insert(seed, at: 0)
        future = Array(f.prefix(Self.cap))
        seed = prev
        return true
    }

    /// Restores next seed from future; returns false if future is empty.
    public func redo() -> Bool {
        guard let next = future.first else { return false }
        var h = history
        h.append(seed)
        history = Array(h.suffix(Self.cap))
        future = Array(future.dropFirst())
        seed = next
        return true
    }
}
