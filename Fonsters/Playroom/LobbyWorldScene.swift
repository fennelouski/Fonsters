#if os(macOS)
import AppKit
import RealityKit
import simd

/// Original, lightweight toy-town scenery, built entirely with native geometry.
@available(macOS 15.0, *)
@MainActor
enum LobbyWorldScene {
    struct Scene { let root: Entity; let fountainDrops: [Entity] }
    static func make(_ world: LobbyWorld) throws -> Scene {
        let root = Entity(); root.name = "fonster-neighborhood"
        let grass = material(0.66, 0.79, 0.61), path = material(0.96, 0.91, 0.80)
        let stone = material(0.86, 0.82, 0.74), white = material(0.98, 0.97, 0.90)
        let wood = material(0.70, 0.47, 0.31), dark = material(0.34, 0.39, 0.40)
        let water = material(0.43, 0.77, 0.86, roughness: 0.23)
        let ground = box([100, 0.12, 100], [0, -0.13, 0], material(0.88, 0.91, 0.82))
        root.addChild(ground)
        root.addChild(cylinder(world.radius, 0.10, [0, -0.05, 0], grass))
        // Paths connect areas into one continuous place rather than display platforms.
        root.addChild(box([world.radius * 1.75, 0.025, 1.45], [0, 0.008, 0.15], path, corner: 0.18))
        root.addChild(box([1.45, 0.025, world.radius * 1.55], [0, 0.009, -0.15], path, corner: 0.18))
        let plazaRadius: Float = world.population >= 5 ? 2.7 : 2.0
        root.addChild(cylinder(plazaRadius, 0.027, [0, 0.012, 0.25], path))
        for i in 0..<48 {
            let a = Float(i) / 48 * .pi * 2
            let tile = box([0.27, 0.035, 0.17], [sin(a) * plazaRadius, 0.018, 0.25 + cos(a) * plazaRadius], stone, corner: 0.025)
            tile.orientation = simd_quatf(angle: a, axis: [0, 1, 0]); root.addChild(tile)
        }
        for p in world.benches { root.addChild(bench(at: p, wood: wood, legs: dark)) }
        for (i, p) in world.trees.enumerated() {
            root.addChild(tree(at: p, variation: i, wood: wood))
            root.addChild(cylinder(0.5, 0.035, [p.x, 0.01, p.y], material(0.58, 0.73, 0.52)))
        }
        var drops: [Entity] = []
        if world.population >= 5 {
            let p: SIMD2<Float> = [0, -1.65]
            root.addChild(cylinder(0.76, 0.17, [p.x, 0.085, p.y], stone))
            root.addChild(cylinder(0.63, 0.025, [p.x, 0.18, p.y], water))
            root.addChild(cylinder(0.16, 0.65, [p.x, 0.46, p.y], white))
            root.addChild(cylinder(0.38, 0.09, [p.x, 0.79, p.y], stone))
            root.addChild(cylinder(0.30, 0.025, [p.x, 0.84, p.y], water))
            let spout = sphere(0.065, [p.x, 1.0, p.y], water); spout.scale.y = 4; root.addChild(spout)
            for i in 0..<16 {
                let drop = sphere(0.04, [p.x, 1.15, p.y], water); drop.name = "fountain-drop-\(i)"
                root.addChild(drop); drops.append(drop)
            }
            animate(drops, time: 0)
        }
        if world.population >= 8 {
            // A separate park lawn, stepping stones, flower beds and a picnic table.
            root.addChild(cylinder(1.7, 0.035, [-4.3, 0.014, -1.55], material(0.73, 0.84, 0.66)))
            for i in 0..<8 {
                let x = -1.8 - Float(i) * 0.34, z = -0.8 - Float(i) * 0.17
                root.addChild(box([0.43, 0.03, 0.31], [x, 0.03, z], white, corner: 0.07))
            }
            root.addChild(picnic(at: [-4.6, 0.6], wood: wood, legs: dark))
        }
        for (i, p) in world.buildings.enumerated() { root.addChild(try house(at: p, index: i)) }
        // Flowers and small lights stay out of all walking routes.
        let flowerCount = world.population >= 8 ? 44 : 18
        for i in 0..<flowerCount {
            let angle = Float(i) * 2.39996, radius = world.radius - 0.7 - Float(i % 3) * 0.18
            let p = SIMD2<Float>(sin(angle), cos(angle)) * radius
            if world.obstacles.contains(where: { $0.contains(p, clearance: 0.4) }) { continue }
            let blossom = sphere(0.08, [p.x, 0.20, p.y], i % 2 == 0 ? material(0.97, 0.70, 0.63) : white)
            blossom.scale = [1, 0.55, 1]; root.addChild(blossom)
            root.addChild(cylinder(0.018, 0.18, [p.x, 0.09, p.y], material(0.40, 0.58, 0.36)))
        }
        for x: Float in [-3.4, 3.4] where world.population >= 5 {
            root.addChild(cylinder(0.045, 1.35, [x, 0.675, 1.9], dark))
            root.addChild(sphere(0.14, [x, 1.43, 1.9], white))
            root.addChild(cylinder(0.17, 0.06, [x, 0.03, 1.9], stone))
        }
        return .init(root: root, fountainDrops: drops)
    }
    static func animate(_ drops: [Entity], time: Float) {
        for (i, drop) in drops.enumerated() {
            let fraction = (time * 0.52 + Float(i % 4) / 4).truncatingRemainder(dividingBy: 1)
            let angle = Float(i / 4) / 4 * .pi * 2
            let r = fraction * 0.53
            drop.position = [sin(angle) * r, 1.1 + sin(fraction * .pi) * 0.22 - fraction * 0.88, -1.65 + cos(angle) * r]
        }
    }
    static func material(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, roughness: Float = 0.85) -> SimpleMaterial {
        SimpleMaterial(color: NSColor(srgbRed: r, green: g, blue: b, alpha: 1), roughness: .init(floatLiteral: roughness), isMetallic: false)
    }
    private static func box(_ size: SIMD3<Float>, _ p: SIMD3<Float>, _ m: SimpleMaterial, corner: Float = 0.04) -> ModelEntity {
        let e = ModelEntity(mesh: .generateBox(size: size, cornerRadius: min(corner, min(size.x, min(size.y, size.z)) * 0.45)), materials: [m]); e.position = p; return e
    }
    private static func cylinder(_ r: Float, _ h: Float, _ p: SIMD3<Float>, _ m: SimpleMaterial) -> ModelEntity {
        let e = ModelEntity(mesh: .generateCylinder(height: h, radius: r), materials: [m]); e.position = p; return e
    }
    private static func sphere(_ r: Float, _ p: SIMD3<Float>, _ m: SimpleMaterial) -> ModelEntity {
        let e = ModelEntity(mesh: .generateSphere(radius: r), materials: [m]); e.position = p; return e
    }
    private static func bench(at p: SIMD2<Float>, wood: SimpleMaterial, legs: SimpleMaterial) -> Entity {
        let e = Entity(); e.name = "bench"; e.position = [p.x, 0, p.y]
        for z: Float in [-0.17, 0, 0.17] { e.addChild(box([1.72, 0.08, 0.14], [0, 0.38, z], wood)) }
        for y: Float in [0.63, 0.80] { e.addChild(box([1.72, 0.13, 0.08], [0, y, -0.25], wood)) }
        for x: Float in [-0.64, 0.64] {
            e.addChild(box([0.07, 0.40, 0.43], [x, 0.20, 0], legs))
            e.addChild(box([0.07, 0.64, 0.07], [x, 0.50, -0.25], legs))
        }
        return e
    }
    private static func picnic(at p: SIMD2<Float>, wood: SimpleMaterial, legs: SimpleMaterial) -> Entity {
        let e = Entity(); e.position = [p.x, 0, p.y]; e.name = "picnic-table"
        e.addChild(box([1.5, 0.10, 0.65], [0, 0.62, 0], wood))
        for z: Float in [-0.61, 0.61] { e.addChild(box([1.5, 0.08, 0.23], [0, 0.33, z], wood)) }
        for x: Float in [-0.53, 0.53] { e.addChild(box([0.10, 0.56, 0.50], [x, 0.28, 0], legs)) }
        return e
    }
    private static func tree(at p: SIMD2<Float>, variation: Int, wood: SimpleMaterial) -> Entity {
        let e = Entity(); e.position = [p.x, 0, p.y]; e.name = "soft-tree"
        e.addChild(cylinder(0.12, 1.45, [0, 0.725, 0], wood))
        let m = variation % 2 == 0 ? material(0.44, 0.65, 0.44) : material(0.59, 0.73, 0.49)
        for p: SIMD3<Float> in [[0, 1.62, 0], [-0.28, 1.37, 0.07], [0.3, 1.40, -0.03]] {
            let crown = sphere(0.55, p, m); crown.scale.y = 1.3; e.addChild(crown)
        }
        return e
    }
    private static func house(at p: SIMD2<Float>, index: Int) throws -> Entity {
        let e = Entity(); e.position = [p.x, 0, p.y]; e.name = "little-house-\(index)"
        let walls = [material(0.94, 0.78, 0.60), material(0.72, 0.78, 0.89), material(0.90, 0.72, 0.73)]
        let roof = [material(0.73, 0.45, 0.40), material(0.49, 0.56, 0.71), material(0.61, 0.48, 0.64)][index % 3]
        e.addChild(box([1.44, 1.35, 1.24], [0, 0.675, 0], walls[index % 3], corner: 0.09))
        let vertices: [SIMD3<Float>] = [[-0.87, 1.31, -0.77], [0.87, 1.31, -0.77], [0, 1.97, -0.77],
                                       [-0.87, 1.31, 0.77], [0.87, 1.31, 0.77], [0, 1.97, 0.77]]
        let faces: [[Int]] = [[0, 2, 1], [3, 4, 5], [0, 3, 5], [0, 5, 2], [2, 5, 4], [2, 4, 1], [0, 1, 4], [0, 4, 3]]
        var points: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = []
        for face in faces {
            let a = vertices[face[0]], b = vertices[face[1]], c = vertices[face[2]]
            let normal = simd_normalize(simd_cross(b - a, c - a))
            points += [a, b, c]; normals += Array(repeating: normal, count: 3)
        }
        var mesh = MeshDescriptor(name: "original-gable-roof")
        mesh.positions = .init(points); mesh.normals = .init(normals); mesh.primitives = .triangles(Array(0..<UInt32(points.count)))
        e.addChild(ModelEntity(mesh: try MeshResource.generate(from: [mesh]), materials: [roof]))
        let trim = material(0.98, 0.96, 0.87), glass = material(0.38, 0.59, 0.67)
        e.addChild(box([0.37, 0.69, 0.055], [0, 0.35, 0.65], material(0.54, 0.43, 0.37), corner: 0.07))
        e.addChild(sphere(0.025, [0.11, 0.35, 0.69], trim))
        for x: Float in [-0.47, 0.47] {
            e.addChild(box([0.36, 0.40, 0.045], [x, 0.91, 0.65], trim))
            e.addChild(box([0.27, 0.30, 0.055], [x, 0.91, 0.68], glass))
            e.addChild(box([0.025, 0.32, 0.065], [x, 0.91, 0.71], trim))
            e.addChild(box([0.28, 0.025, 0.065], [x, 0.91, 0.71], trim))
        }
        e.addChild(box([1.60, 0.07, 1.48], [0, 0.035, 0], trim))
        return e
    }
}
#endif
