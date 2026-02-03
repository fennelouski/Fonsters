//
//  InstallationSeeds.swift
//  Fonsters
//
//  Returns device-derived seed strings for first-launch creature creation.
//  Same seed list shape on all platforms; implementation uses #if os(...).
//

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import Foundation
#endif

enum InstallationSeeds {
    static let hasSeededKey = "Fonsters.hasSeededInitialCreatures"

    /// Seed strings for initial creatures: device name, ISO 8601 time, time zone, capacity, device name variant.
    /// Returns fewer entries if a source is unavailable; never empty.
    static func seeds() -> [String] {
        let deviceName = Self.deviceName()
        let iso8601 = Self.iso8601Time()
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

    /// Current time as ISO 8601 string for use as a seed (e.g. when creating a Fonster on empty store at launch).
    static func currentTimeSeed() -> String {
        iso8601Time()
    }

    private static func deviceName() -> String {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let name = UIDevice.current.name
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? "Device" : name
        #elseif os(macOS)
        let name = Host.current().localizedName ?? ""
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? "Device" : name
        #else
        return "Device"
        #endif
    }

    private static func iso8601Time() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
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
            #if os(iOS) || os(visionOS)
            let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
            #elseif os(tvOS) || os(watchOS)
            let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey]
            #else
            let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey, .volumeTotalCapacityKey]
            #endif
            let values = try docURL.resourceValues(forKeys: keys)
            #if os(iOS) || os(visionOS)
            if let avail = values.volumeAvailableCapacityForImportantUsage {
                parts.append("storage_avail:\(avail)")
            }
            #elseif !os(tvOS) && !os(watchOS)
            if let avail = values.volumeAvailableCapacity {
                parts.append("storage_avail:\(avail)")
            }
            #endif
            if let total = values.volumeTotalCapacity {
                parts.append("storage_total:\(total)")
            }
        } catch {
            // Omit storage; RAM seed still used
        }
        return parts.joined(separator: "_")
    }
}
