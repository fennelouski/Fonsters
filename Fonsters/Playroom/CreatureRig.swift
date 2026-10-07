#if os(macOS)
import SwiftUI
import RealityKit
import AppKit
import Metal
import simd

@available(macOS 15.0, *)
@MainActor
final class CreatureRig {
    enum FurDetail: String { case portrait, lobby, world }
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
    private(set) var furStrands = 0
    private(set) var furTriangles = 0
    private(set) var furSurfaces = 0
    private(set) var groomedFaceStrands = 0
    private lazy var outlineRadii = headRadii()
    private lazy var furMaterials = CreatureFur.materials(for: descriptor)
    private lazy var furSeed = CreatureFur.seed(for: descriptor)
    private lazy var coatKey = CreatureFur.appearanceKey(descriptor) + ":fur-v\(CreatureFur.styleVersion):" + furDetail.rawValue
    let furDetail: FurDetail
    private var skinIndex = 0
    struct TouchHit {
        var distance: Float
        var point: SIMD2<Float>
        var zone: CreatureTouchDynamics.Zone
        func sample(at time: Double) -> CreatureTouchDynamics.Sample { .init(point: point, zone: zone, time: time) }
    }
    struct TouchSurface {
        let entity: Entity
        let center: SIMD3<Float>
        let radii: SIMD3<Float>
        let zone: CreatureTouchDynamics.Zone
    }
    private var touchSurfaces: [TouchSurface] = []
    private var touchHeadRadius = SIMD2<Float>(repeating: 1)

    static func touchRay(at point: CGPoint, size: CGSize, camera: PerspectiveCamera) -> (origin: SIMD3<Float>, direction: SIMD3<Float>)? {
        guard size.width > 0, size.height > 0, point.x.isFinite, point.y.isFinite else { return nil }
        let x = Float(point.x / size.width * 2 - 1), y = Float(1 - point.y / size.height * 2)
        let tangent = tan(Float(camera.camera.fieldOfViewInDegrees) * .pi / 360)
        return (camera.position(relativeTo: nil), camera.orientation(relativeTo: nil).act(simd_normalize([x * Float(size.width / size.height) * tangent, y * tangent, -1])))
    }
    /// Analytic volumes follow the live head, eyes and limbs, including lobby scale/orbit.
    /// No per-strand collision meshes or geometry rebuilds are needed for a stroke.
    func touchHit(origin: SIMD3<Float>, direction: SIMD3<Float>) -> TouchHit? {
        guard origin.x.isFinite, origin.y.isFinite, origin.z.isFinite,
              direction.x.isFinite, direction.y.isFinite, direction.z.isFinite,
              simd_length_squared(direction) > 0.0001 else { return nil }
        let direction = simd_normalize(direction)
        var closest: TouchHit?
        for surface in touchSurfaces {
            let localOrigin = surface.entity.convert(position: origin, from: nil)
            let localNext = surface.entity.convert(position: origin + direction, from: nil)
            let o = (localOrigin - surface.center) / surface.radii
            let d = (localNext - localOrigin) / surface.radii
            let a = simd_dot(d, d), b = simd_dot(o, d), c = simd_dot(o, o) - 1
            let discriminant = b * b - a * c
            guard a > 0, discriminant >= 0 else { continue }
            let near = (-b - sqrt(discriminant)) / a, far = (-b + sqrt(discriminant)) / a
            let distance = near > 0 ? near : far
            guard distance > 0, distance.isFinite, distance < (closest?.distance ?? .greatestFiniteMagnitude) else { continue }
            let location = head.convert(position: origin + direction * distance, from: nil)
            let point = SIMD2<Float>(location.x, location.y) / touchHeadRadius
            let zone = surface.zone == .cheek && point.y > 0.45 ? CreatureTouchDynamics.Zone.crown : surface.zone
            closest = .init(distance: distance, point: point, zone: zone)
        }
        return closest
    }

    init(_ descriptor: CreatureAppearanceDescriptor, furDetail: FurDetail = .portrait) throws {
        self.descriptor = descriptor
        self.furDetail = furDetail
        root.name = "companion"
        root.addChild(head)
        let h = descriptor.head
        baseHead = point(h.centerX, h.centerY)
        head.position = baseHead
        skinIndex = Int(descriptor.parts.first(where: { $0.kind == "head" })?.paletteIndices.first ?? 0)
        let skin = color(skinIndex)
        var surface = material(skin)
        surface.roughness = .init(floatLiteral: 0.96); surface.clearcoat = .init(floatLiteral: 0)
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
        let bounds = model.visualBounds(relativeTo: head)
        let radii = simd_max(bounds.extents * 0.5, SIMD3<Float>(repeating: 0.03))
        touchHeadRadius = [radii.x, radii.y]
        touchSurfaces.append(.init(entity: head, center: bounds.center, radii: radii, zone: .cheek))
        let coat = try CreatureFur.surface(key: coatKey + ":head", name: "fuzzy-head") {
            CreatureFur.head(descriptor, radii: outlineRadii, pixel: pixel, depth: depth, skinIndex: skinIndex,
                             count: furDetail == .portrait ? 12_000 : (furDetail == .lobby ? 6_000 : 2_800), toneVariation: furDetail == .portrait)
        }
        addCoat(coat, to: head, name: "fuzzy-head")
        groomedFaceStrands = coat.trimmedStrands
        for part in descriptor.parts {
            switch part.kind {
            case "eye": addEye(part)
            case "body": addBody(part, skin: skin)
            case "appendage": addLimb(part, skin: skin)
            case "ear": addEar(part, skin: skin)
            case "horn": addHorn(part, skin: skin)
            case "antler": addAntlers(part, skin: skin)
            case "brow": addBrow(part)
            case "nose": addNose(part)
            default: break // Texture carries hair, beard and markings; the happy mouth is added below.
            }
        }
        try addMouth()
        if let furError { throw furError }
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
    func ball(_ color: NSColor, radius: Float = 1, scale: SIMD3<Float>, at position: SIMD3<Float>, parent: Entity, furry: Bool = false) -> ModelEntity {
        var surface = material(color, roughness: furry ? 0.96 : 0.52)
        if furry { surface.clearcoat = .init(floatLiteral: 0) }
        let model = ModelEntity(mesh: .generateSphere(radius: radius), materials: [surface])
        model.scale = scale; model.position = position; parent.addChild(model)
        if furry {
            do {
                let coat = try CreatureFur.surface(key: coatKey + ":surface:\(furSurfaces)", name: "fuzzy-surface-\(furSurfaces)") {
                    CreatureFur.ellipsoid(axes: scale * radius, palette: skinIndex, seed: furSeed ^ UInt64(furSurfaces + 1),
                                          density: furDetail == .portrait ? 1 : (furDetail == .lobby ? 0.5 : 0.24), toneVariation: furDetail == .portrait)
                }
                addCoat(coat, to: model, name: "fuzzy-surface-\(furSurfaces)")
            }
            catch { furError = error }
        }
        return model
    }
    private var furError: Error?
    private func addCoat(_ surface: CreatureFur.Surface, to parent: Entity, name: String) {
        let model = ModelEntity(mesh: surface.mesh, materials: furMaterials)
        model.name = name; parent.addChild(model)
        furStrands += surface.strands; furTriangles += surface.triangles; furSurfaces += 1
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
    private func headRadii() -> [Float] {
        let h = descriptor.head
        let cells = Set(h.footprint.map { $0.y * 32 + $0.x })
        let around = 96
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
        return radii
    }
    func headMesh() throws -> MeshResource {
        let h = descriptor.head, radii = outlineRadii
        let around = radii.count - 1, rings = 40
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
        touchSurfaces.append(.init(entity: eye, center: [0, 0, 0.035], radii: [w * 0.74, h * 0.74, 0.18], zone: .eye))
    }
    struct SmileLayout {
        let centerX: Double, centerY: Double
        let width: Float, height: Float
        let paletteIndex: Int
        let hasLegacyMouth: Bool
        /// Clockwise outline with raised corners and a gentle upper curve.
        var outline: [SIMD2<Float>] {
            let steps = 32
            func point(_ i: Int, lower: Bool) -> SIMD2<Float> {
                let t = Float(i) / Float(steps) * 2 - 1
                let y: Float = lower ? -0.48 + 0.66 * t * t : -0.04 + 0.22 * t * t
                return [t * width / 2, y * height]
            }
            return (0...steps).map { point($0, lower: false) } +
                (1..<steps).reversed().map { point($0, lower: true) }
        }
    }
    /// A render-only expression. The descriptor retains the exact original mouth,
    /// including absence; no identity, portrait, visit format or saved feeling changes.
    static func smileLayout(for descriptor: CreatureAppearanceDescriptor) -> SmileLayout {
        let pixel: Float = 0.0625
        if let part = descriptor.parts.first(where: { $0.kind == "mouth" }) {
            let w = Float((part.pixels.map(\.x).max() ?? 0) - (part.pixels.map(\.x).min() ?? 0) + 1) * pixel
            let h = Float((part.pixels.map(\.y).max() ?? 0) - (part.pixels.map(\.y).min() ?? 0) + 1) * pixel
            return .init(centerX: part.centerX, centerY: part.centerY,
                         width: max(0.32, min(0.65, w * 1.05)), height: max(0.24, min(0.38, h * 0.85)),
                         paletteIndex: Int(part.paletteIndices.first ?? 3), hasLegacyMouth: true)
        }
        let h = descriptor.head
        let obstacles = descriptor.parts.filter { $0.kind == "eye" || $0.kind == "nose" }
            .flatMap(\.pixels).map(\.y).max().map { Double($0) + 1.6 } ?? h.centerY
        let y = min(h.centerY + h.radius * 0.72, max(h.centerY + h.radius * 0.40, obstacles))
        return .init(centerX: h.centerX, centerY: y, width: 0.40, height: 0.27,
                     paletteIndex: 3, hasLegacyMouth: false)
    }
    func addMouth() throws {
        let layout = Self.smileLayout(for: descriptor), outline = layout.outline
        let group = Entity(); group.name = "happy-smile"
        group.position = point(layout.centerX, layout.centerY, z: faceDepth(layout.centerX, layout.centerY) + 0.025) - baseHead
        let count = outline.count
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], indices: [UInt32] = []
        // This point sees the complete crescent without crossing its curved boundary.
        let center = SIMD2<Float>(0, -layout.height * 0.26)
        for (z, normal) in [(Float(0.052), SIMD3<Float>(0, 0, 1)), (Float(0.016), SIMD3<Float>(0, 0, -1))] {
            positions.append([center.x, center.y, z]); normals.append(normal)
            for p in outline { positions.append([p.x, p.y, z]); normals.append(normal) }
        }
        for i in 0..<count {
            let next = (i + 1) % count
            indices += [0, UInt32(next + 1), UInt32(i + 1),
                        UInt32(count + 1), UInt32(count + 2 + i), UInt32(count + 2 + next)]
            let delta = outline[next] - outline[i]
            let normal = simd_normalize(SIMD3<Float>(-delta.y, delta.x, 0))
            let start = UInt32(positions.count)
            positions += [[outline[i].x, outline[i].y, 0.052], [outline[next].x, outline[next].y, 0.052],
                          [outline[i].x, outline[i].y, 0.016], [outline[next].x, outline[next].y, 0.016]]
            normals += Array(repeating: normal, count: 4)
            indices += [start, start + 1, start + 2, start + 1, start + 3, start + 2]
        }
        func mesh(_ name: String) throws -> MeshResource {
            var descriptor = MeshDescriptor(name: name)
            descriptor.positions = MeshBuffers.Positions(positions); descriptor.normals = MeshBuffers.Normals(normals)
            descriptor.primitives = .triangles(indices)
            return try MeshResource.generate(from: [descriptor])
        }
        var cavityMaterial = material(NSColor(srgbRed: 0.085, green: 0.045, blue: 0.075, alpha: 1), roughness: 0.85)
        cavityMaterial.clearcoat = .init(floatLiteral: 0)
        let cavity = ModelEntity(mesh: try mesh("rounded-smile-cavity"), materials: [cavityMaterial])
        cavity.name = "smile-cavity"; group.addChild(cavity)
        positions = []; normals = []; indices = []
        let sides = 8, radius = min(0.023, layout.width * 0.032)
        for i in 0..<count {
            let tangent = simd_normalize(outline[(i + 1) % count] - outline[(i + count - 1) % count])
            let outward = SIMD3<Float>(-tangent.y, tangent.x, 0)
            for side in 0..<sides {
                let angle = Float(side) / Float(sides) * 2 * .pi
                let normal = outward * cos(angle) + SIMD3<Float>(0, 0, sin(angle))
                positions.append(SIMD3<Float>(outline[i].x, outline[i].y, 0.057) + normal * radius)
                normals.append(normal)
            }
        }
        for i in 0..<count {
            for side in 0..<sides {
                let a = UInt32(i * sides + side), b = UInt32(i * sides + (side + 1) % sides)
                let c = UInt32(((i + 1) % count) * sides + side), d = UInt32(((i + 1) % count) * sides + (side + 1) % sides)
                indices += [a, b, c, b, d, c]
            }
        }
        let rim = ModelEntity(mesh: try mesh("soft-smile-rim"), materials: [material(color(layout.paletteIndex), roughness: 0.72)])
        rim.name = "smile-rim"; group.addChild(rim)
        _ = ball(color(layout.paletteIndex), scale: [layout.width * 0.18, layout.height * 0.047, 0.012],
                 at: [0, -layout.height * 0.38, 0.061], parent: group)
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
        let body = ball(skin, scale: [w * 0.52, h * 0.52, 0.4], at: point(part.centerX, part.centerY, z: -0.10), parent: root, furry: true)
        body.name = "body"
        touchSurfaces.append(.init(entity: body, center: .zero, radii: .init(repeating: 1), zone: .belly))
    }
    func addEar(_ part: CreatureAppearanceDescriptor.Part, skin: NSColor) {
        let (w, h) = extent(part)
        let ear = ball(skin, scale: [w * 0.55, h * 0.55, 0.20], at: point(part.centerX, part.centerY, z: 0.02) - baseHead, parent: head, furry: true)
        touchSurfaces.append(.init(entity: ear, center: .zero, radii: .init(repeating: 1.05), zone: .crown))
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
        let sphere = ball(color, scale: [radius, length / 2 + radius, radius], at: (from + to) / 2, parent: parent, furry: true)
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
        let paw = ball(skin, scale: [radius * 1.22, radius, radius * 1.3], at: [0, length * 0.48, 0.03], parent: bend, furry: true)
        touchSurfaces.append(.init(entity: paw, center: .zero, radii: .init(repeating: 1.15), zone: .paw))
        joint.addChild(bend); root.addChild(joint); limbs.append((joint, bend, angle))
    }
}
#endif
