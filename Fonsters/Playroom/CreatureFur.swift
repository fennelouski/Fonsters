#if os(macOS)
import AppKit
import RealityKit
import CryptoKit
import simd

/// Original curved fibre geometry, batched per skin surface. No assets, textures or
/// per-fibre entities/animation. The resolved appearance supplies every coat colour.
@available(macOS 15.0, *)
@MainActor
enum CreatureFur {
    static let styleVersion = 2
    static let segments = 3
    static let sides = 4
    struct Surface {
        let mesh: MeshResource
        let strands: Int
        let triangles: Int
        let trimmedStrands: Int
        let estimatedBytes: Int
    }
    private static var cache: [String: Surface] = [:]
    private static var recent: [String] = []
    private static var cachedBytes = 0
    /// Only immutable mesh resources are reused; each rig gets new animated entities.
    static func surface(key: String, name: String, make: () -> Geometry) throws -> Surface {
        if let saved = cache[key] {
            recent.removeAll { $0 == key }; recent.append(key)
            return saved
        }
        let geometry = make()
        let surface = Surface(mesh: try geometry.resource(name: name), strands: geometry.strands,
                              triangles: geometry.triangles, trimmedStrands: geometry.trimmedStrands,
                              estimatedBytes: (geometry.positions.count + geometry.normals.count) * 12 +
                                (geometry.indices.count + geometry.materials.count) * 4)
        cache[key] = surface; recent.append(key)
        cachedBytes += surface.estimatedBytes
        while recent.count > 80 || cachedBytes > 64 * 1024 * 1024 {
            if let old = cache.removeValue(forKey: recent.removeFirst()) { cachedBytes -= old.estimatedBytes }
        }
        return surface
    }
    struct Geometry {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var materials: [UInt32] = []
        var strands = 0
        var trimmedStrands = 0
        var maximumLength: Float = 0
        var triangles: Int { indices.count / 3 }
        @MainActor func resource(name: String) throws -> MeshResource {
            var mesh = MeshDescriptor(name: name)
            mesh.positions = MeshBuffers.Positions(positions)
            mesh.normals = MeshBuffers.Normals(normals)
            mesh.primitives = .triangles(indices)
            mesh.materials = .perFace(materials)
            return try MeshResource.generate(from: [mesh])
        }
    }
    private struct Noise {
        var state: UInt64
        mutating func unit() -> Float {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float((state >> 40) & 0xffffff) / Float(0xffffff)
        }
    }
    static func seed(for descriptor: CreatureAppearanceDescriptor) -> UInt64 {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: (try? encoder.encode(descriptor)) ?? Data())
        return digest.prefix(8).reduce(UInt64(styleVersion)) { ($0 << 8) ^ UInt64($1) }
    }
    static func appearanceKey(_ descriptor: CreatureAppearanceDescriptor) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: (try? encoder.encode(descriptor)) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }
    static func materials(for descriptor: CreatureAppearanceDescriptor) -> [PhysicallyBasedMaterial] {
        descriptor.rgbaPalette.flatMap { rgba in
            [0.90, 1.0, 1.10].map { tone in
                var material = PhysicallyBasedMaterial()
                material.baseColor = .init(tint: NSColor(srgbRed: min(1, CGFloat(rgba[0]) / 255 * tone),
                    green: min(1, CGFloat(rgba[1]) / 255 * tone), blue: min(1, CGFloat(rgba[2]) / 255 * tone), alpha: 1))
                material.roughness = .init(floatLiteral: 0.96)
                material.metallic = .init(floatLiteral: 0)
                material.clearcoat = .init(floatLiteral: 0)
                return material
            }
        }
    }
    static func head(_ descriptor: CreatureAppearanceDescriptor, radii: [Float], pixel: Float, depth: Float,
                     skinIndex: Int, count: Int = 12_000, toneVariation: Bool = true) -> Geometry {
        let h = descriptor.head, around = radii.count - 1
        let seed = seed(for: descriptor)
        var noise = Noise(state: seed)
        var geometry = Geometry()
        reserve(&geometry, count: count)
        var paint = Array(repeating: skinIndex, count: 1024)
        for part in descriptor.parts where ["beard", "hair", "marking"].contains(part.kind) {
            for (i, p) in part.pixels.enumerated() { paint[p.y * 32 + p.x] = Int(part.paletteIndices[i]) }
        }
        var features = descriptor.parts.filter { ["eye", "brow", "nose"].contains($0.kind) }.map { part in
            let w = Float((part.pixels.map(\.x).max() ?? 0) - (part.pixels.map(\.x).min() ?? 0) + 1) * pixel
            let height = Float((part.pixels.map(\.y).max() ?? 0) - (part.pixels.map(\.y).min() ?? 0) + 1) * pixel
            return (x: Float(part.centerX - h.centerX) * pixel, y: Float(h.centerY - part.centerY) * pixel,
                    rx: w * 0.80 + 0.025, ry: height * 0.80 + 0.025)
        }
        let smile = CreatureRig.smileLayout(for: descriptor)
        features.append((x: Float(smile.centerX - h.centerX) * pixel, y: Float(h.centerY - smile.centerY) * pixel,
                         rx: smile.width * 0.70 + 0.025, ry: smile.height * 0.78 + 0.025))
        for i in 0..<count {
            let z = 1 - 2 * (Float(i) + 0.5) / Float(count)
            let angle = (Float(i) * 2.39996323 + noise.unit() * 0.24).truncatingRemainder(dividingBy: 2 * .pi)
            let index = angle / (2 * .pi) * Float(around), lower = Int(index)
            let r = (radii[lower] + (radii[lower + 1] - radii[lower]) * (index - Float(lower))) * pixel
            let ring = sqrt(max(0, 1 - z * z))
            let root = SIMD3<Float>(r * cos(angle) * ring, r * sin(angle) * ring, depth * z)
            let normal = simd_normalize(SIMD3<Float>(root.x / (r * r), root.y / (r * r), root.z / (depth * depth)))
            let nearFeature = z > 0 && features.contains { f in
                let x = (root.x - f.x) / f.rx, y = (root.y - f.y) / f.ry
                return x * x + y * y < 1
            }
            let length: Float = nearFeature ? 0.007 + noise.unit() * 0.005 : 0.055 + pow(noise.unit(), 1.4) * 0.062
            let width: Float = nearFeature ? 0.0011 : 0.0017 + noise.unit() * 0.0010
            let px = min(31, max(0, Int((root.x / pixel + Float(h.centerX)).rounded())))
            let py = min(31, max(0, Int((Float(h.centerY) - root.y / pixel).rounded())))
            let color = z > 0 ? paint[py * 32 + px] : skinIndex
            append(&geometry, root: root - normal * 0.002, normal: normal, length: length, width: width,
                   palette: color, scale: .one, toneVariation: toneVariation, noise: &noise)
            if nearFeature { geometry.trimmedStrands += 1 }
        }
        return geometry
    }
    /// The mesh lives under the original ellipsoid model. Inverse scale gives
    /// each fibre a consistent world-space length even on narrow arms and feet.
    static func ellipsoid(axes: SIMD3<Float>, palette: Int, seed: UInt64, density: Float = 1,
                          toneVariation: Bool = true) -> Geometry {
        let area = 4 * Float.pi * pow((pow(axes.x * axes.y, 1.6075) + pow(axes.y * axes.z, 1.6075) + pow(axes.x * axes.z, 1.6075)) / 3, 1 / 1.6075)
        let count = min(Int(4200 * density), max(80, Int(area * 2200 * density)))
        var geometry = Geometry(), noise = Noise(state: seed)
        reserve(&geometry, count: count)
        let length = min(0.070, max(0.023, min(axes.x, axes.z) * 0.18))
        for i in 0..<count {
            let z = 1 - 2 * (Float(i) + 0.5) / Float(count)
            let angle = Float(i) * 2.39996323 + noise.unit() * 0.18, ring = sqrt(max(0, 1 - z * z))
            let point = SIMD3<Float>(cos(angle) * ring, sin(angle) * ring, z)
            let root = point * axes, normal = simd_normalize(point / axes)
            append(&geometry, root: root - normal * 0.001, normal: normal,
                   length: length * (0.7 + noise.unit() * 0.8), width: 0.0014 + noise.unit() * 0.0006,
                   palette: palette, scale: axes, toneVariation: toneVariation, noise: &noise)
        }
        return geometry
    }
    private static func reserve(_ geometry: inout Geometry, count: Int) {
        geometry.positions.reserveCapacity(count * (segments + 1) * sides)
        geometry.normals.reserveCapacity(count * (segments + 1) * sides)
        geometry.indices.reserveCapacity(count * segments * sides * 6)
        geometry.materials.reserveCapacity(count * segments * sides * 2)
    }
    private static func append(_ geometry: inout Geometry, root: SIMD3<Float>, normal: SIMD3<Float>,
                               length: Float, width: Float, palette: Int, scale: SIMD3<Float>,
                               toneVariation: Bool, noise: inout Noise) {
        let reference: SIMD3<Float> = abs(normal.y) < 0.9 ? [0, 1, 0] : [1, 0, 0]
        let u = simd_normalize(simd_cross(normal, reference)), v = simd_cross(normal, u)
        let swirl = noise.unit() * 2 * .pi
        let randomTangent = u * cos(swirl) + v * sin(swirl)
        let comb = SIMD3<Float>(0, -1, 0) - normal * simd_dot(SIMD3<Float>(0, -1, 0), normal)
        let tangent = randomTangent * 0.32 + comb * 0.45
        let start = UInt32(geometry.positions.count)
        let brightness = noise.unit()
        for band in 0...segments {
            let t = Float(band) / Float(segments)
            let center = root + normal * length * t + tangent * length * (0.2 * t + 0.75 * t * t)
            let direction = simd_normalize(normal + tangent * (0.2 + 1.5 * t))
            let a = simd_normalize(simd_cross(direction, reference)), b = simd_cross(direction, a)
            let radius = width * (1 - t * 0.94)
            for side in 0..<sides {
                let radial: SIMD3<Float>
                switch side { case 0: radial = a; case 1: radial = b; case 2: radial = -a; default: radial = -b }
                geometry.positions.append((center + radial * radius) / scale)
                geometry.normals.append(simd_normalize(radial * scale))
            }
        }
        for band in 0..<segments {
            let tone = toneVariation ? (band == 0 ? 0 : (band == segments - 1 && brightness > 0.28 ? 2 : 1)) : 1
            let material = UInt32(min(5, max(0, palette)) * 3 + tone)
            for side in 0..<sides {
                let a = start + UInt32(band * sides + side), b = start + UInt32(band * sides + (side + 1) % sides)
                let c = a + UInt32(sides), d = b + UInt32(sides)
                geometry.indices.append(a); geometry.indices.append(b); geometry.indices.append(c)
                geometry.indices.append(b); geometry.indices.append(d); geometry.indices.append(c)
                geometry.materials.append(material); geometry.materials.append(material)
            }
        }
        geometry.strands += 1; geometry.maximumLength = max(geometry.maximumLength, length)
    }
}
#endif
