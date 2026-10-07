#if os(macOS)
import SwiftUI
import RealityKit
import AppKit
import Metal
import simd

@available(macOS 15.0, *)
@MainActor
final class CreatureRig {
    let root = Entity()
    let head = Entity()
    let descriptor: CreatureAppearanceDescriptor
    var eyes: [Entity] = []
    var pupils: [Entity] = []
    var mouth: Entity?
    var limbs: [(joint: Entity, bend: Entity, angle: Float)] = []
    let pixel: Float = 0.0625
    let depth: Float = 0.64
    var baseHead: SIMD3<Float> = .zero
    var groundOffset: Float = 0
    var brows: [Entity] = []

    init(_ descriptor: CreatureAppearanceDescriptor) throws {
        self.descriptor = descriptor
        root.name = "companion"
        root.addChild(head)
        let h = descriptor.head
        baseHead = point(h.centerX, h.centerY)
        head.position = baseHead
        let skinIndex = Int(descriptor.parts.first(where: { $0.kind == "head" })?.paletteIndices.first ?? 0)
        let skin = color(skinIndex)
        var surface = material(skin)
        if let image = skinTexture(skinIndex: skinIndex) {
            let texture = try TextureResource(image: image, options: .init(semantic: .color))
            let sampler = MTLSamplerDescriptor()
            sampler.minFilter = .nearest; sampler.magFilter = .nearest
            surface.baseColor = .init(tint: .white, texture: .init(texture, sampler: .init(sampler)))
        }
        let mesh = try headMesh()
        let model = ModelEntity(mesh: mesh, materials: [surface, material(skin)])
        model.name = "resolved-head"
        head.addChild(model)
        for part in descriptor.parts {
            switch part.kind {
            case "eye": addEye(part)
            case "mouth": addMouth(part)
            case "body": addBody(part, skin: skin)
            case "appendage": addLimb(part, skin: skin)
            case "ear": addEar(part, skin: skin)
            case "horn": addHorn(part, skin: skin)
            case "antler": addAntlers(part, skin: skin)
            case "brow": addBrow(part)
            case "nose": addNose(part)
            default: break // Surface texture carries resolved hair, brows, beard, nose and markings.
            }
        }
        groundOffset = -1.08 - root.visualBounds(relativeTo: root).min.y
    }

    func point(_ x: Double, _ y: Double, z: Float = 0) -> SIMD3<Float> {
        [(Float(x) - 15.5) * pixel, (15.5 - Float(y)) * pixel, z]
    }
    func color(_ index: Int) -> NSColor {
        let p = descriptor.rgbaPalette[min(5, max(0, index))]
        return NSColor(srgbRed: CGFloat(p[0]) / 255, green: CGFloat(p[1]) / 255,
                       blue: CGFloat(p[2]) / 255, alpha: 1)
    }
    func material(_ color: NSColor, roughness: Float = 0.52) -> PhysicallyBasedMaterial {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: color)
        mat.roughness = .init(floatLiteral: roughness)
        mat.metallic = .init(floatLiteral: 0)
        mat.clearcoat = .init(floatLiteral: 0.16)
        mat.clearcoatRoughness = .init(floatLiteral: 0.35)
        return mat
    }
    func ball(_ color: NSColor, radius: Float = 1, scale: SIMD3<Float>, at position: SIMD3<Float>, parent: Entity) -> ModelEntity {
        let model = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material(color)])
        model.scale = scale; model.position = position; parent.addChild(model)
        return model
    }
    func extent(_ p: CreatureAppearanceDescriptor.Part) -> (Float, Float) {
        (Float((p.pixels.map(\.x).max() ?? 0) - (p.pixels.map(\.x).min() ?? 0) + 1) * pixel,
         Float((p.pixels.map(\.y).max() ?? 0) - (p.pixels.map(\.y).min() ?? 0) + 1) * pixel)
    }
    func faceDepth(_ x: Double, _ y: Double) -> Float {
        let h = descriptor.head
        let dx = Float((x - h.centerX) / (h.radius * (h.shape == "ellipse" ? h.ellipseX : 1)))
        let dy = Float((y - h.centerY) / (h.radius * (h.shape == "ellipse" ? h.ellipseY : 1)))
        return depth * sqrt(max(0.12, 1 - dx * dx - dy * dy))
    }
    func facePosition(_ p: CreatureAppearanceDescriptor.Part) -> SIMD3<Float> {
        point(p.centerX, p.centerY, z: faceDepth(p.centerX, p.centerY) + 0.025) - baseHead
    }

    // A closed, smooth volume: the legacy head outline is inflated through 40 rings.
    // The front and back have independent materials, and thickness is comparable to width.
    func headMesh() throws -> MeshResource {
        let h = descriptor.head
        let cells = Set(h.footprint.map { $0.y * 32 + $0.x })
        let around = 96, rings = 40
        var radii: [Float] = []
        for j in 0...around {
            let theta = Float(j) / Float(around) * 2 * .pi
            var radius: Float = 0
            for step in 0...400 {
                let r = Float(step) / 20
                let x = Int((Float(h.centerX) + r * cos(theta)).rounded())
                let y = Int((Float(h.centerY) - r * sin(theta)).rounded())
                if x < 0 || x >= 32 || y < 0 || y >= 32 || !cells.contains(y * 32 + x) { break }
                radius = r
            }
            radii.append(max(radius, 0.5))
        }
        // Suppress pixel stair steps without changing the overall resolved shape.
        for _ in 0..<3 {
            let old = radii
            for j in 0..<around { radii[j] = (old[(j + around - 1) % around] + 2 * old[j] + old[(j + 1) % around]) / 4 }
            radii[around] = radii[0]
        }
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], uv: [SIMD2<Float>] = []
        for i in 0...rings {
            let latitude = -Float.pi / 2 + Float(i) / Float(rings) * .pi
            for j in 0...around {
                let theta = Float(j) / Float(around) * 2 * .pi
                let r = radii[j] * pixel
                let x = r * cos(theta) * cos(latitude), y = r * sin(theta) * cos(latitude)
                let z = depth * sin(latitude)
                positions.append([x, y, z])
                normals.append(simd_normalize(SIMD3<Float>(x / max(0.01, r * r), y / max(0.01, r * r), z / (depth * depth))))
                uv.append([(x / pixel + Float(h.centerX) + 0.5) / 32,
                           (32 - (Float(h.centerY) - y / pixel + 0.5)) / 32])
            }
        }
        var indices: [UInt32] = [], materials: [UInt32] = []
        for i in 0..<rings {
            for j in 0..<around {
                let a = UInt32(i * (around + 1) + j), b = a + 1, c = a + UInt32(around + 1), d = c + 1
                indices += [a, b, c, b, d, c]
                materials += [i >= rings / 2 ? 0 : 1, i >= rings / 2 ? 0 : 1]
            }
        }
        var descriptor = MeshDescriptor(name: "inflated-resolved-silhouette-v1")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        descriptor.primitives = .triangles(indices)
        descriptor.materials = .perFace(materials)
        return try MeshResource.generate(from: [descriptor])
    }

    func skinTexture(skinIndex: Int) -> CGImage? {
        var grid = Array(repeating: Array(repeating: Int8(skinIndex), count: 32), count: 32)
        for part in descriptor.parts where ["beard", "hair", "marking"].contains(part.kind) {
            for (i, p) in part.pixels.enumerated() { grid[p.y][p.x] = part.paletteIndices[i] }
        }
        var bytes = gridToRgbaBuffer(grid: grid, palette: descriptor.palette, false)
        return bytes.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: 32, height: 32, bitsPerComponent: 8,
                      bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }

    func addEye(_ part: CreatureAppearanceDescriptor.Part) {
        let eye = Entity(); eye.name = part.id; eye.position = facePosition(part)
        let (w, h) = extent(part)
        // The resolved eye shape is retained as a rounded outline, with a glossy iris.
        let white = NSColor(srgbRed: 0.98, green: 0.96, blue: 0.88, alpha: 1)
        if part.style == "square" {
            let model = ModelEntity(mesh: .generateBox(size: [w * 1.35, h * 1.35, 0.15], cornerRadius: 0.045), materials: [material(white)])
            eye.addChild(model)
        } else {
            _ = ball(white, scale: [w * 0.74, h * 0.74, 0.13], at: .zero, parent: eye)
        }
        let pupil = Entity(); pupil.position = [0, 0, 0.105]
        _ = ball(color(Int(part.paletteIndices.first ?? 2)), scale: [w * 0.44, h * 0.44, 0.062], at: .zero, parent: pupil)
        _ = ball(NSColor(srgbRed: 0.05, green: 0.035, blue: 0.07, alpha: 1), scale: [w * 0.21, h * 0.31, 0.045], at: [0, 0, 0.046], parent: pupil)
        _ = ball(.white, scale: [0.028, 0.028, 0.015], at: [-0.025, 0.034, 0.09], parent: pupil)
        eye.addChild(pupil); head.addChild(eye); eyes.append(eye); pupils.append(pupil)
    }
    func addMouth(_ part: CreatureAppearanceDescriptor.Part) {
        let (w, h) = extent(part)
        let group = Entity(); group.position = facePosition(part)
        let model = ModelEntity(mesh: .generateBox(size: [w * 0.94, h * 0.85, 0.065], cornerRadius: min(0.07, h * 0.34)), materials: [material(color(Int(part.paletteIndices.first ?? 3)), roughness: 0.52)])
        group.addChild(model)
        _ = ball(NSColor(srgbRed: 0.075, green: 0.045, blue: 0.10, alpha: 1), scale: [w * 0.34, h * 0.27, 0.025], at: [0, 0, 0.042], parent: group)
        _ = ball(color(Int(part.paletteIndices.first ?? 3)), scale: [w * 0.23, h * 0.08, 0.012], at: [0, -h * 0.19, 0.069], parent: group)
        head.addChild(group); mouth = group
    }
    func addBrow(_ part: CreatureAppearanceDescriptor.Part) {
        let (w, h) = extent(part)
        let brow = ModelEntity(mesh: .generateBox(size: [w, h, 0.05], cornerRadius: min(0.04, h * 0.25)),
                               materials: [material(color(Int(part.paletteIndices.first ?? 3)))])
        brow.position = facePosition(part)
        head.addChild(brow); brows.append(brow)
    }
    func addNose(_ part: CreatureAppearanceDescriptor.Part) {
        let (w, h) = extent(part)
        _ = ball(color(Int(part.paletteIndices.first ?? 2)), scale: [w * 0.52, h * 0.51, 0.14], at: facePosition(part), parent: head)
    }
    func addBody(_ part: CreatureAppearanceDescriptor.Part, skin: NSColor) {
        let (w, h) = extent(part)
        let body = ball(skin, scale: [w * 0.52, h * 0.52, 0.4], at: point(part.centerX, part.centerY, z: -0.10), parent: root)
        body.name = "body"
    }
    func addEar(_ part: CreatureAppearanceDescriptor.Part, skin: NSColor) {
        let (w, h) = extent(part)
        _ = ball(skin, scale: [w * 0.55, h * 0.55, 0.20], at: point(part.centerX, part.centerY, z: 0.02) - baseHead, parent: head)
    }
    func addHorn(_ part: CreatureAppearanceDescriptor.Part, skin: NSColor) {
        let (w, h) = extent(part)
        let horn = ModelEntity(mesh: .generateCone(height: h, radius: w * 0.52), materials: [material(skin)])
        horn.position = point(part.centerX, part.centerY) - baseHead
        head.addChild(horn)
    }
    func addAntlers(_ part: CreatureAppearanceDescriptor.Part, skin: NSColor) {
        guard let top = part.pixels.map(\.y).min(), let bottom = part.pixels.map(\.y).max(),
              let left = part.pixels.map(\.x).min(), let right = part.pixels.map(\.x).max() else { return }
        let stemTop = point(15.5, Double(top + 2)) - baseHead
        let stemBottom = point(15.5, Double(bottom)) - baseHead
        tube(from: stemBottom, to: stemTop, radius: 0.043, color: skin, parent: head)
        tube(from: stemTop, to: point(Double(left), Double(top), z: -0.02) - baseHead, radius: 0.035, color: skin, parent: head)
        tube(from: stemTop, to: point(Double(right), Double(top), z: -0.02) - baseHead, radius: 0.035, color: skin, parent: head)
    }
    func tube(from: SIMD3<Float>, to: SIMD3<Float>, radius: Float, color: NSColor, parent: Entity) {
        let delta = to - from
        let length = simd_length(delta)
        guard length > 0.001 else { return }
        let sphere = ball(color, scale: [radius, length / 2 + radius, radius], at: (from + to) / 2, parent: parent)
        sphere.orientation = simd_quatf(from: [0, 1, 0], to: delta / length)
    }
    func addLimb(_ part: CreatureAppearanceDescriptor.Part, skin: NSColor) {
        let h = descriptor.head
        let sorted = part.pixels.sorted {
            hypot(Double($0.x) - h.centerX, Double($0.y) - h.centerY) < hypot(Double($1.x) - h.centerX, Double($1.y) - h.centerY)
        }
        guard let first = sorted.first, let last = sorted.last else { return }
        // Visible raster strokes can start beyond the smoothed contour. Place their
        // joints inside the nearest resolved head cell, while retaining the clipped tip.
        // This makes the appendages physically connected from every viewing angle.
        let attachment = h.footprint.min {
            hypot(Double($0.x - first.x), Double($0.y - first.y)) < hypot(Double($1.x - first.x), Double($1.y - first.y))
        } ?? first
        let surfaceAnchor = point(Double(attachment.x), Double(attachment.y))
        let start = baseHead + (surfaceAnchor - baseHead) * 0.92
        let end = point(Double(last.x), Double(last.y), z: 0.05)
        let length = simd_distance(start, end)
        guard length > 0.045 else { return }
        let joint = Entity(); joint.name = part.id; joint.position = start
        let angle = atan2(end.y - start.y, end.x - start.x) - Float.pi / 2
        joint.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
        let radius = min(0.12, max(0.045, Float(part.pixels.count) * pixel * pixel / max(length, 0.01) * 0.38))
        tube(from: .zero, to: [0, length * 0.52, 0.05], radius: radius, color: skin, parent: joint)
        let bend = Entity(); bend.position = [0, length * 0.52, 0.05]
        tube(from: .zero, to: [0, length * 0.48, 0.03], radius: radius * 0.8, color: skin, parent: bend)
        _ = ball(skin, scale: [radius * 1.22, radius, radius * 1.3], at: [0, length * 0.48, 0.03], parent: bend)
        joint.addChild(bend); root.addChild(joint); limbs.append((joint, bend, angle))
    }
}
#endif
