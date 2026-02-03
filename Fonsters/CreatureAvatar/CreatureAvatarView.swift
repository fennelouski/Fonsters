//
//  CreatureAvatarView.swift
//  Fonsters
//
//  SwiftUI view that displays the deterministic 32×32 creature for a seed string.
//  Uses pixel-perfect scaling (no interpolation). iOS uses UIImage; macOS, tvOS,
//  and visionOS use CGImage (avoids NSImage display quirks on macOS). Same seed
//  always shows the same creature.
//

import SwiftUI

/// Renders the creature for the given seed at the given display size (default 128 pt).
public struct CreatureAvatarView: View {
    public let seed: String
    public let size: CGFloat

    public init(seed: String, size: CGFloat = 128) {
        self.seed = seed
        self.size = size
    }

    public var body: some View {
        let effectiveSeed = seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
        Group {
            if let cgImage = creatureImage(for: effectiveSeed) {
                #if canImport(UIKit)
                Image(uiImage: UIImage(cgImage: cgImage))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                #elseif os(macOS)
                // macOS: use decorative CGImage (avoids NSImage display issues)
                Image(decorative: cgImage, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .drawingGroup(opaque: false)
                #else
                // tvOS, visionOS
                Image(cgImage: cgImage, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .drawingGroup(opaque: false)
                #endif
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    CreatureAvatarView(seed: "glow leaf coral flame forest", size: 128)
        .padding()
}
