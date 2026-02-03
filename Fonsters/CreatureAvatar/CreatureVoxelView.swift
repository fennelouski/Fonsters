//
//  CreatureVoxelView.swift
//  Fonsters
//
//  visionOS-only: 3D voxel representation of the creature from the same grid
//  as the 2D renderer. Includes subtle arm/appendage animation.
//

#if os(visionOS)

import SwiftUI
import RealityKit
import UIKit

/// Renders the creature as a 3D voxel grid; same seed produces the same layout.
/// Appendage cells (edges and config-based) get subtle rotation animation.
/// Tap triggers a 1s reaction (500ms forward, 500ms reverse): scale pulse, bounce, or spin.
struct CreatureVoxelView: View {
    let seed: String
    var size: CGFloat = 160

    @State private var tapProgress: CGFloat = 0
    @State private var activeTapReaction: Int = -1 // 0 scale, 1 bounce, 2 spin
    @State private var tapCount: Int = 0

    private let phaseDuration: Double = 0.5
    private var effectiveSeed: String {
        seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
    }

    var body: some View {
        CreatureVoxelRealityView(
            seed: effectiveSeed,
            tapProgress: tapProgress,
            tapReactionKind: activeTapReaction
        )
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { runTapReaction() }
    }

    private func runTapReaction() {
        guard !effectiveSeed.isEmpty, effectiveSeed != " ", activeTapReaction < 0 else { return }
        let kind = segmentPick(seed: effectiveSeed + (tapCount == 0 ? "" : "_\(tapCount)"), segmentId: "voxel_tap", n: 3)
        tapCount += 1
        activeTapReaction = kind
        tapProgress = 0

        withAnimation(.easeInOut(duration: phaseDuration)) {
            tapProgress = 1
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(phaseDuration * 1_000_000_000))
            guard activeTapReaction == kind else { return }
            withAnimation(.easeInOut(duration: phaseDuration)) {
                tapProgress = 0
            }
            try? await Task.sleep(nanoseconds: UInt64(phaseDuration * 1_000_000_000))
            if activeTapReaction == kind {
                activeTapReaction = -1
            }
        }
    }
}

/// RealityView content; receives tap progress and reaction kind to apply to root entity.
private struct CreatureVoxelRealityView: View {
    let seed: String
    let tapProgress: CGFloat
    let tapReactionKind: Int

    var body: some View {
        RealityView { content in
            let effectiveSeed = seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
            let grid = generateCreatureGrid(seed: effectiveSeed)
            let (palette, _) = getPaletteForSeed(seed: effectiveSeed)
            let config = resolveConfig(seed: effectiveSeed)

            let voxelSize: Float = 1.0 / Float(GRID_SIZE)
            let root = Entity()
            root.name = "creatureRoot"

            for y in 0..<GRID_SIZE {
                for x in 0..<GRID_SIZE {
                    let idx = grid[y][x]
                    if idx == -1 { continue }
                    let color = hexToRealityColor(palette.indices.contains(Int(idx)) ? palette[Int(idx)] : "#888888")
                    let box = ModelEntity(
                        mesh: .generateBox(size: voxelSize, cornerRadius: 0),
                        materials: [SimpleMaterial(color: color, isMetallic: false)]
                    )
                    let px = (Float(x) - Float(GRID_SIZE) / 2) * voxelSize
                    let py = (Float(GRID_SIZE - 1 - y) - Float(GRID_SIZE) / 2) * voxelSize
                    box.position = [px, py, 0]
                    box.name = isAppendageCell(x: x, y: y, config: config) ? "appendage_\(x)_\(y)" : "voxel_\(x)_\(y)"
                    root.addChild(box)
                }
            }

            content.add(root)
        } update: { content in
            let t = Float(Date().timeIntervalSince1970)
            let progress = Float(tapProgress)
            let kind = tapReactionKind

            for entity in content.entities {
                guard entity.name == "creatureRoot" else { continue }

                // Tap reaction: 0 = scale pulse, 1 = bounce (Y), 2 = spin (Y axis)
                if kind >= 0 {
                    let scale: Float = kind == 0 ? 1 + 0.15 * progress : 1
                    entity.transform.scale = [scale, scale, scale]
                    let bounceY: Float = kind == 1 ? 0.08 * progress : 0
                    let spinY: Float = kind == 2 ? Float(progress * .pi * 2) : 0
                    entity.position = [0, bounceY, 0]
                    entity.transform.rotation = simd_quatf(angle: spinY, axis: [0, 1, 0])
                } else {
                    entity.transform.scale = [1, 1, 1]
                    entity.position = [0, 0, 0]
                    entity.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
                }

                for child in entity.children {
                    if child.name.hasPrefix("appendage_") {
                        let sway = sin(t * 0.8) * 0.06
                        let tilt = sin(t * 0.5 + 1) * 0.04
                        child.transform.rotation = simd_quatf(angle: sway, axis: [0, 0, 1])
                        child.transform.rotation = simd_quatf(angle: tilt, axis: [1, 0, 0]) * child.transform.rotation
                    }
                }
                break
            }
        }
    }
}

private func hexToRealityColor(_ hex: String) -> UIColor {
    if hex == TRANSPARENT { return .clear }
    guard hex.hasPrefix("#"), let n = Int(hex.dropFirst(), radix: 16) else {
        return .gray
    }
    let r = CGFloat((n >> 16) & 0xFF) / 255
    let g = CGFloat((n >> 8) & 0xFF) / 255
    let b = CGFloat(n & 0xFF) / 255
    return UIColor(red: r, green: g, blue: b, alpha: 1)
}

/// Heuristic: cells at grid edges or in "appendage" regions get subtle animation.
private func isAppendageCell(x: Int, y: Int, config: CreatureConfig) -> Bool {
    if !config.hasAppendages { return false }
    let edge = 4
    if x < edge || x >= GRID_SIZE - edge || y < edge || y >= GRID_SIZE - edge {
        return true
    }
    return false
}

#endif
