//
//  ClockDetailView.swift
//  Fonsters Watch App
//
//  Full-screen creature driven by current time (ISO 8601 seed). Updates at
//  calendar second boundaries so the creature stays in sync with the system clock.
//  No Digital Crown or Modify; Clock has no user-customizable parameters.
//

import SwiftUI

private struct SecondBoundarySchedule: TimelineSchedule {
    func entries(from start: Date, mode: TimelineScheduleMode) -> SecondBoundaryEntries {
        SecondBoundaryEntries(start: start)
    }
}

private struct SecondBoundaryEntries: Sequence, IteratorProtocol {
    var current: Date
    let cal = Calendar.current

    init(start: Date) {
        current = ClockSeed.startOfSecond(for: start)
    }

    mutating func next() -> Date? {
        let nextDate = current
        current = cal.date(byAdding: .second, value: 1, to: current) ?? current
        return nextDate
    }
}

extension TimelineSchedule where Self == SecondBoundarySchedule {
    static var secondBoundary: SecondBoundarySchedule { SecondBoundarySchedule() }
}

struct ClockDetailView: View {
    var body: some View {
        TimelineView(.secondBoundary) { context in
            VStack(spacing: 8) {
                WatchCreatureView(seed: ClockSeed.seed(for: context.date), size: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Clock")
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Clock")
        .navigationBarTitleDisplayMode(.inline)
    }
}
