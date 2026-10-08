#if os(macOS) || os(iOS) || os(tvOS)
import RealityKit
import Foundation
import simd
#if os(macOS)
import AppKit
#else
import UIKit
#endif

nonisolated enum FonsterDanceMode: String, CaseIterable, Sendable {
    case daylight, spotlight, disco
    var title: String { switch self { case .daylight: "Daylight"; case .spotlight: "Spotlight"; case .disco: "Disco" } }
    var symbol: String { switch self { case .daylight: "sun.max"; case .spotlight: "light.beacon.max"; case .disco: "sparkles" } }
}

/// A reusable original party set. Decorations never replace the world or rigs.
/// One shared active clock drives slow lights, DJ and bounded pooled celebrations.
@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
@MainActor final class LobbyDanceScene {
    let root = Entity()
    private let party = Entity(), solo = Entity(), confettiRoot = Entity(), balloonRoot = Entity()
    private let discoBall = Entity(), beams = Entity()
    private let spotlight = SpotLight()
    private var glow: [PointLight] = []
    private var tiles: [ModelEntity] = []
    private var confetti: [ModelEntity] = []
    private var balloons: [ModelEntity] = []
    private var dj: CreatureRig?
    private var burstTime: Double?
    private var balloonTime: Double?
    private var mode = FonsterDanceMode.daylight
    var key: DirectionalLight?
    var fill: PointLight?
    var ambient: Entity?

    init() throws {
        root.name = "fonsters-dance-world"
        for entity in [solo, party, confettiRoot, balloonRoot] { root.addChild(entity) }
        solo.addChild(box([8, 0.025, 8], [0, 0.04, 1.6], .init(srgbRed: 0.20, green: 0.19, blue: 0.31, alpha: 1)))
        let nightGround = ModelEntity(mesh: .generatePlane(width: 100, depth: 100), materials: [UnlitMaterial(color: .init(srgbRed: 0.075, green: 0.07, blue: 0.14, alpha: 1))])
        nightGround.position.y = -0.062; solo.addChild(nightGround)
        spotlight.light.intensity = 45000; spotlight.light.attenuationRadius = 18
        spotlight.light.innerAngleInDegrees = 22; spotlight.light.outerAngleInDegrees = 44
        spotlight.light.color = .init(srgbRed: 1, green: 0.86, blue: 0.65, alpha: 1)
        solo.addChild(spotlight)
        let colors: [SIMD3<Float>] = [[0.36, 0.65, 0.85], [0.71, 0.44, 0.85], [0.89, 0.52, 0.65], [0.44, 0.79, 0.70]]
        for x in 0..<8 { for z in 0..<7 {
            let color = colors[(x + z) % colors.count]
            let tile = luminousBox([0.83, 0.028, 0.83], [-3.06 + Float(x) * 0.87, 0.07, -0.70 + Float(z) * 0.87], color * 0.55)
            party.addChild(tile); tiles.append(tile)
        } }
        party.addChild(box([5.5, 0.36, 1.4], [0, 0.2, -2.4], .init(srgbRed: 0.24, green: 0.22, blue: 0.34, alpha: 1)))
        party.addChild(box([2.1, 0.5, 0.7], [0, 0.65, -2.25], .init(srgbRed: 0.14, green: 0.16, blue: 0.23, alpha: 1)))
        for x: Float in [-2.15, 2.15] {
            party.addChild(box([0.74, 1.25, 0.68], [x, 1.02, -2.4], .init(srgbRed: 0.14, green: 0.15, blue: 0.22, alpha: 1)))
            for y: Float in [0.74, 1.25] {
                let speaker = ModelEntity(mesh: .generateSphere(radius: 0.25), materials: [LobbyWorldScene.material(0.28, 0.29, 0.38)])
                speaker.position = [x, y, -2.02]; speaker.scale.z = 0.12; party.addChild(speaker)
            }
        }
        let rig = try CreatureRig(PlayroomCompanion.fixtures[2].descriptor, furDetail: .world)
        rig.root.scale = .init(repeating: 0.40); rig.root.position = [0, 1.0, -2.6]; party.addChild(rig.root); dj = rig
        for x: Float in [-0.48, 0.48] {
            let deck = ModelEntity(mesh: .generateCylinder(height: 0.04, radius: 0.23), materials: [LobbyWorldScene.material(0.40, 0.44, 0.62)])
            deck.position = [x, 0.93, -2.15]; party.addChild(deck)
        }
        discoBall.position = [0, 2.95, -0.8]; party.addChild(discoBall)
        let ball = ModelEntity(mesh: .generateSphere(radius: 0.42), materials: [SimpleMaterial(color: .init(white: 0.72, alpha: 1), roughness: 0.3, isMetallic: true)])
        discoBall.addChild(ball)
        for row in 0..<8 { for col in 0..<16 {
            let latitude = Float(row + 1) / 9 * .pi, longitude = Float(col) / 16 * .pi * 2
            let p = SIMD3<Float>(sin(latitude) * cos(longitude), cos(latitude), sin(latitude) * sin(longitude)) * 0.427
            let mirror = luminousBox([0.10, 0.10, 0.01], p, colors[(row + col) % 4] * 0.8)
            discoBall.addChild(mirror); mirror.look(at: p * 2, from: p, relativeTo: discoBall)
        } }
        party.addChild(beams)
        for i in 0..<6 {
            let beam = luminousBox([0.012, 0.012, 7], [-2.8 + Float(i) * 1.1, 2.25 + Float(i % 2) * 0.25, 0.6], colors[i % 4] * 0.55)
            beam.orientation = simd_quatf(angle: (i % 2 == 0 ? 1 : -1) * 0.45, axis: [0, 1, 0]); beams.addChild(beam)
        }
        for i in 0..<4 {
            let light = PointLight(); light.position = [i % 2 == 0 ? -3 : 3, 1.9, i < 2 ? -0.8 : 4.5]
            light.light.intensity = 1500; light.light.attenuationRadius = 7
            light.light.color = color(colors[i]); party.addChild(light); glow.append(light)
        }
        for i in 0..<72 {
            let piece = luminousBox([0.05, 0.014, 0.09], .zero, colors[i % 4]); confettiRoot.addChild(piece); confetti.append(piece)
        }
        for i in 0..<12 {
            let balloon = ModelEntity(mesh: .generateSphere(radius: 0.18), materials: [LobbyWorldScene.material(CGFloat(colors[i % 4].x), CGFloat(colors[i % 4].y), CGFloat(colors[i % 4].z))])
            balloon.scale = [1, 1.3, 1]; balloonRoot.addChild(balloon); balloons.append(balloon)
        }
        apply(.daylight, time: 0, moving: false, target: [0, 0.6, 2.7])
    }
    func celebrate(balloons: Bool, time: Double) { if balloons { balloonTime = time } else { burstTime = time } }
    func clearCelebrations() { burstTime = nil; balloonTime = nil; confettiRoot.isEnabled = false; balloonRoot.isEnabled = false }
    func apply(_ mode: FonsterDanceMode, time: Double, moving: Bool, target: SIMD3<Float>) {
        self.mode = mode
        let night = mode != .daylight
        solo.isEnabled = night; party.isEnabled = mode == .disco
        key?.light.intensity = night ? 450 : 2400; fill?.light.intensity = night ? 4200 : 11000
        if var component = ambient?.components[ImageBasedLightComponent.self] { component.intensityExponent = night ? -0.6 : 1; ambient?.components.set(component) }
        spotlight.look(at: target, from: target + [0, 4.8, 1], relativeTo: nil)
        let t = Float(time)
        if moving && night {
            discoBall.orientation = simd_quatf(angle: t * 0.30, axis: [0, 1, 0])
            beams.orientation = simd_quatf(angle: sin(t * 0.35) * 0.18, axis: [0, 1, 0])
            if let dj {
                dj.root.position.y = 1.0 + abs(sin(t * 3)) * 0.04
                dj.head.orientation = simd_quatf(angle: sin(t * 3) * 0.10, axis: [0, 0, 1])
                dj.mouth?.scale.y = 1.3
                for limb in dj.limbs { limb.joint.orientation = simd_quatf(angle: limb.angle + sin(t * 4) * 0.35, axis: [0, 0, 1]) }
            }
            for (i, light) in glow.enumerated() { light.light.intensity = 1300 + sin(t * 0.8 + Float(i)) * 250 }
        }
        // Static/reduced mode keeps the party set, but suppresses moving lasers
        // and falling particles. No strobe, blink cycle or exposure pulses.
        beams.isEnabled = mode == .disco && moving
        confettiRoot.isEnabled = night && moving && burstTime != nil
        balloonRoot.isEnabled = night && moving && balloonTime != nil
        if let start = burstTime {
            let age = Float(time - start)
            if age > 4 { burstTime = nil; confettiRoot.isEnabled = false }
            else { for (i, piece) in confetti.enumerated() {
                let angle = Float(i) * 2.39996, speed = 0.6 + Float(i % 7) * 0.15
                piece.position = [sin(angle) * age * speed, 0.8 + age * (2.6 + Float(i % 5) * 0.24) - age * age * 0.85, 2 + cos(angle) * age * speed]
                piece.orientation = simd_quatf(angle: age * (2 + Float(i % 3)), axis: simd_normalize([1, 0.4, 0.6]))
            } }
        }
        if let start = balloonTime {
            let age = Float(time - start)
            if age > 7 { balloonTime = nil; balloonRoot.isEnabled = false }
            else { for (i, balloon) in balloons.enumerated() { balloon.position = [sin(Float(i) * 2.4) * 2.5, max(0.25, 4.5 - age * (0.43 + Float(i % 3) * 0.1)), 2 + cos(Float(i) * 2.4) * 2] } }
        }
    }
    private func color(_ rgb: SIMD3<Float>) -> FonsterPlatformColor { .init(srgbRed: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: 1) }
    private func luminousBox(_ size: SIMD3<Float>, _ p: SIMD3<Float>, _ rgb: SIMD3<Float>) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0), materials: [UnlitMaterial(color: color(rgb))]); entity.position = p; return entity
    }
    private func box(_ size: SIMD3<Float>, _ p: SIMD3<Float>, _ color: FonsterPlatformColor) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.01), materials: [SimpleMaterial(color: color, roughness: 0.9, isMetallic: false)]); entity.position = p; return entity
    }
}
#endif
