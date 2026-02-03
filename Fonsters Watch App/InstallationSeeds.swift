//
//  InstallationSeeds.swift
//  Fonsters Watch App
//
//  watchOS: device-derived seed strings for first-launch creature creation.
//  Mirrors the same seed list shape as the main app (device, time, timezone, capacity, device variant).
//

import Foundation
import WatchKit

enum InstallationSeeds {
    static let hasSeededKey = "Fonsters.hasSeededInitialCreatures"

    static func seeds() -> [String] {
        let deviceName = Self.deviceName()
        let iso8601 = ClockSeed.seed(for: Date())
        let timeZone = Self.timeZoneSeed()
        let capacity = Self.capacitySeed()

        var result: [String] = []
        if !deviceName.isEmpty { result.append(deviceName) }
        result.append(iso8601)
        if !timeZone.isEmpty { result.append(timeZone) }
        if !capacity.isEmpty { result.append(capacity) }
        result.append(deviceName + " • device")
        return result
    }

    /// Current time as ISO 8601 string for use as a seed (e.g. when creating a Fonster on empty store at launch, or Clock monster).
    static func currentTimeSeed() -> String {
        ClockSeed.seed(for: Date())
    }

    private static func deviceName() -> String {
        let name = WKInterfaceDevice.current().name
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? "Device" : name
    }

    private static func timeZoneSeed() -> String {
        let tz = TimeZone.current
        let id = tz.identifier
        if !id.isEmpty { return id }
        if let abbr = tz.abbreviation(), !abbr.isEmpty { return abbr }
        return ""
    }

    private static func capacitySeed() -> String {
        var parts: [String] = []
        let ram = ProcessInfo.processInfo.physicalMemory
        parts.append("ram:\(ram)")
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return parts.joined(separator: "_")
        }
        do {
            let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey, .volumeTotalCapacityKey]
            let values = try docURL.resourceValues(forKeys: keys)
            if let avail = values.volumeAvailableCapacity {
                parts.append("storage_avail:\(avail)")
            }
            if let total = values.volumeTotalCapacity {
                parts.append("storage_total:\(total)")
            }
        } catch { }
        return parts.joined(separator: "_")
    }
}
