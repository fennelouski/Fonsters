//
//  LoadingView.swift
//  Fonsters
//
//  In-app loading animation: black + moving dark blue lines, icon fade-in,
//  background fade-out, lines animate off, icon shrink and fade-out.
//  Same animation on iOS, macOS, visionOS, watchOS, tvOS. See docs/LAUNCH_AND_LOADING_ANIMATION.md.
//

import SwiftUI

/// Phase-driven loading animation (~1 s total). Calls `onComplete()` when done.
struct LoadingView: View {
    var onComplete: () -> Void

    private static let phaseDuration: Double = 0.2
    private static let totalPhases = 5

    @State private var phase = 0
    @State private var lineOffset: CGFloat = 0
    @State private var iconOpacity: Double = 0
    @State private var backgroundOpacity: Double = 1
    @State private var linesOffset: CGFloat = 0
    @State private var iconScale: CGFloat = 1
    @State private var iconFadeOut: Double = 1

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // LaunchBackground (dark blue lines) — moving, then fade out, then slide off
            Image("LaunchBackground")
                .resizable()
                .scaledToFill()
                .offset(x: lineOffset + linesOffset, y: 0)
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            // LaunchIcon — fade in, then shrink and fade out
            Image("LaunchIcon")
                .resizable()
                .scaledToFit()
                #if os(watchOS)
                .frame(maxWidth: 80, maxHeight: 80)
                #else
                .frame(maxWidth: 160, maxHeight: 160)
                #endif
                .scaleEffect(iconScale)
                .opacity(iconOpacity * iconFadeOut)
        }
        .animation(.easeInOut(duration: Self.phaseDuration), value: lineOffset)
        .animation(.easeInOut(duration: Self.phaseDuration), value: iconOpacity)
        .animation(.easeInOut(duration: Self.phaseDuration), value: backgroundOpacity)
        .animation(.easeInOut(duration: Self.phaseDuration), value: linesOffset)
        .animation(.easeInOut(duration: Self.phaseDuration), value: iconScale)
        .animation(.easeInOut(duration: Self.phaseDuration), value: iconFadeOut)
        .task {
            await runPhases()
        }
    }

    private func runPhases() async {
        // Phase 0: lines moving (subtle drift)
        phase = 0
        lineOffset = 8
        try? await Task.sleep(nanoseconds: UInt64(Self.phaseDuration * 1_000_000_000))

        // Phase 1: icon fades in
        phase = 1
        iconOpacity = 1
        try? await Task.sleep(nanoseconds: UInt64(Self.phaseDuration * 1_000_000_000))

        // Phase 2: background (lines image) fades out
        phase = 2
        backgroundOpacity = 0
        try? await Task.sleep(nanoseconds: UInt64(Self.phaseDuration * 1_000_000_000))

        // Phase 3: lines animate off screen
        phase = 3
        linesOffset = -400
        try? await Task.sleep(nanoseconds: UInt64(Self.phaseDuration * 1_000_000_000))

        // Phase 4: icon shrinks and fades out
        phase = 4
        iconScale = 0.3
        iconFadeOut = 0
        try? await Task.sleep(nanoseconds: UInt64(Self.phaseDuration * 1_000_000_000))

        onComplete()
    }
}

#Preview {
    LoadingView(onComplete: {})
}
