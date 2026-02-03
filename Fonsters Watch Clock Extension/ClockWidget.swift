//
//  ClockWidget.swift
//  Fonsters Watch Clock Extension
//
//  watchOS complication: shows the Clock creature (seed = ISO 8601 for entry date).
//  Timeline entries every 2 seconds for ~2 minutes; system limits update rate.
//

import WidgetKit
import SwiftUI

struct ClockEntry: TimelineEntry {
    let date: Date
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        var entries: [ClockEntry] = []
        let interval: TimeInterval = 2
        let count = 60
        let startOfSecond = ClockSeed.startOfSecond(for: Date())
        for i in 0..<count {
            let entryDate = Calendar.current.date(byAdding: .second, value: Int(interval) * i, to: startOfSecond) ?? startOfSecond
            entries.append(ClockEntry(date: entryDate))
        }
        let reloadDate = entries.last.map { Calendar.current.date(byAdding: .second, value: Int(interval), to: $0.date) ?? $0.date } ?? Date()
        completion(Timeline(entries: entries, policy: .after(reloadDate)))
    }
}

struct ClockWidgetEntryView: View {
    var entry: ClockEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let seed = ClockSeed.seed(for: entry.date)
        Group {
            if let cgImage = creatureImage(for: seed) {
                Image(decorative: cgImage, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ClockWidget: Widget {
    let kind: String = "ClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockProvider()) { entry in
            ClockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Clock")
        .description("Creature that changes with the time.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

@main
struct ClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClockWidget()
    }
}
