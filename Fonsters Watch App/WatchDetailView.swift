//
//  WatchDetailView.swift
//  Fonsters Watch App
//
//  Screen 2: Full-screen creature image. Digital Crown scrubs evolution (one
//  frame per character of seed). Navigate to modify (screen 3) optional.
//

import SwiftUI
import SwiftData

struct WatchDetailView: View {
    @Bindable var fonster: Fonster
    @State private var crownFrameIndex: Double = 0

    private var seedLength: Int {
        let s = fonster.seed.trimmingCharacters(in: .whitespaces)
        return max(1, s.isEmpty ? 1 : s.count)
    }

    private var effectiveSeedForDisplay: String {
        let s = fonster.seed.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return " " }
        let idx = Int(crownFrameIndex.rounded()) % max(1, s.count)
        let len = min(max(idx + 1, 1), s.count)
        return String(s.prefix(len))
    }

    var body: some View {
        VStack(spacing: 8) {
            WatchTappableCreatureView(seed: effectiveSeedForDisplay, size: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(displayName)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .digitalCrownRotation(
            $crownFrameIndex,
            from: 0,
            through: Double(seedLength - 1),
            by: 0.5,
            sensitivity: .low,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .navigationTitle("Creature")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                NavigationLink {
                    WatchModifyView(fonster: fonster)
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
    }

    private var displayName: String {
        if !fonster.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return fonster.name
        }
        return "Fonster"
    }
}

