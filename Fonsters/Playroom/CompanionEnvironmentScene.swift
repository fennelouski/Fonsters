#if os(macOS) || os(iOS)
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import RealityKit
import simd

/// Hand-built small worlds with matte surfaces. Decorations stay behind the
/// contact volumes and walking space; the same geometry runs on Mac and iPhone.
@available(macOS 15.0, iOS 18.0, *)
@MainActor enum CompanionEnvironmentScene {
    static func make(_ theme: CompanionEnvironment) -> Entity {
        let root = Entity(); root.name = "companion-environment-" + theme.rawValue
        func material(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> SimpleMaterial {
            SimpleMaterial(color: FonsterPlatformColor(srgbRed: r, green: g, blue: b, alpha: 1), roughness: 1, isMetallic: false)
        }
        func sphere(_ radius: Float, _ position: SIMD3<Float>, _ scale: SIMD3<Float>, _ mat: SimpleMaterial) {
            let e = ModelEntity(mesh: .generateSphere(radius: radius), materials: [mat]); e.position = position; e.scale = scale; root.addChild(e)
        }
        let ground = theme == .seaside ? material(0.91, 0.83, 0.67) : theme == .moonlit ? material(0.46, 0.48, 0.67) : material(0.67, 0.79, 0.58)
        let terrain = ModelEntity(mesh: .generatePlane(width: 120, depth: 120), materials: [ground])
        terrain.position = [0, -1.09, 0]; root.addChild(terrain)
        if theme == .seaside {
            let sea = ModelEntity(mesh: .generatePlane(width: 120, depth: 110), materials: [material(0.65, 0.82, 0.85)])
            sea.position = [0, -1.085, -58.1]; root.addChild(sea)
        }
        let path = theme == .moonlit ? material(0.82, 0.82, 0.93) : material(0.95, 0.90, 0.77)
        for i in 0..<7 {
            let stone = ModelEntity(mesh: .generateCylinder(height: 0.025, radius: 0.19), materials: [path])
            stone.position = [sin(Float(i) * 0.6) * 0.6, -1.071, -0.6 - Float(i) * 0.23]; stone.scale.z = 0.72; root.addChild(stone)
        }
        if theme == .seaside {
            for i in 0..<5 { sphere(0.22, [-1.5 + Float(i) * 0.23, -1.04, -1.3], [1, 0.45, 0.8], material(0.78, 0.74, 0.67)) }
            for i in 0..<3 {
                let wave = ModelEntity(mesh: .generateBox(size: [3.3, 0.02, 0.06], cornerRadius: 0.015), materials: [material(0.89, 0.97, 0.95)])
                wave.position = [0, -1.075, -3.0 - Float(i) * 0.43]; root.addChild(wave)
            }
        } else {
            for side: Float in [-1, 1] {
                let trunk = ModelEntity(mesh: .generateCylinder(height: 0.7, radius: 0.065), materials: [material(0.64, 0.46, 0.35)]); trunk.position = [side * 1.65, -0.74, -1.55]; root.addChild(trunk)
                for i in 0..<3 { sphere(0.36, [side * 1.65 + Float(i - 1) * 0.20, -0.20 + Float(i % 2) * 0.15, -1.55], [1, 1.1, 1], theme == .moonlit ? material(0.55, 0.57, 0.75) : material(0.44, 0.64, 0.39)) }
            }
            for i in 0..<16 {
                let angle = Float(i) * 2.39996, x = sin(angle) * 1.65, z = -0.65 + cos(angle) * 1.15
                if z > 0.1 && abs(x) < 0.85 { continue }
                sphere(0.07, [x, -1.01, z], [1, 0.6, 1], theme == .moonlit ? material(0.97, 0.88, 0.65) : material(0.98, 0.71, 0.64))
            }
        }
        return root
    }
}
#endif
