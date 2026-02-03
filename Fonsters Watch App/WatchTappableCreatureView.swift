//
//  WatchTappableCreatureView.swift
//  Fonsters Watch App
//
//  Wraps WatchCreatureView with tap-to-animate: scale pulse 500ms forward, 500ms reverse.
//

import SwiftUI

private let phaseDuration: Double = 0.5

struct WatchTappableCreatureView: View {
    let seed: String
    let size: CGFloat

    @State private var progress: CGFloat = 0
    @State private var isAnimating = false

    private var effectiveSeed: String {
        seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
    }

    private var scale: CGFloat {
        1 + 0.15 * progress
    }

    var body: some View {
        WatchCreatureView(seed: effectiveSeed, size: size)
            .scaleEffect(scale)
            .contentShape(Rectangle())
            .onTapGesture { trigger() }
    }

    private func trigger() {
        guard !isAnimating, effectiveSeed != " " else { return }
        isAnimating = true
        progress = 0

        withAnimation(.easeInOut(duration: phaseDuration)) {
            progress = 1
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(phaseDuration * 1_000_000_000))
            withAnimation(.easeInOut(duration: phaseDuration)) {
                progress = 0
            }
            try? await Task.sleep(nanoseconds: UInt64(phaseDuration * 1_000_000_000))
            isAnimating = false
        }
    }
}
