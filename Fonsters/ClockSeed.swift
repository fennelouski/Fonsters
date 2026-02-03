//
//  ClockSeed.swift
//  Fonsters
//
//  Shared ISO 8601 date string for use as a creature seed (e.g. Clock monster).
//  Same format as watch InstallationSeeds.currentTimeSeed(); used by the watch
//  app and by the watchOS complication timeline.
//

import Foundation

enum ClockSeed {
    /// ISO 8601 string including seconds for the given date (current timezone).
    /// Same format as InstallationSeeds.currentTimeSeed() on watch.
    static func seed(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    /// Start of the calendar second containing the given date (truncates fractional seconds).
    /// Use to align timeline entries to the system clock.
    static func startOfSecond(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return cal.date(from: comps) ?? date
    }
}
