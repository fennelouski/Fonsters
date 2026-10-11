import Foundation

/// Portable resolved appearance, never a private seed or user identifier.
/// v1 deliberately preserves the exact legacy raster, including clipping and draw order.
struct CreatureAppearanceDescriptor: Codable, Equatable {
    static let currentVersion = 1
    let version: Int
    let legacyRendererVersion: String
    let palette: [String]
    let rgbaPalette: [[UInt8]]
    let raster: [Int8]
    let silhouette: [Pixel]
    let head: Head
    let parts: [Part]
    let clippingMask: String
    let supported: Bool
    let fallbackReason: String?
    /// Additive, versioned resolved geometry for families outside the original
    /// articulated rig. Existing v1 visit descriptors decode with nil here.
    var volume: Volume? = nil
    struct Volume: Codable, Equatable {
        let version: Int
        let family: String
        let pixels: [Pixel]
    }

    struct Pixel: Codable, Hashable { let x: Int; let y: Int }
    struct Head: Codable, Equatable {
        let shape: String
        let centerX: Double
        let centerY: Double
        let radius: Double
        let ellipseX: Double
        let ellipseY: Double
        let footprint: [Pixel]
    }
    struct Part: Codable, Equatable, Identifiable {
        let id: String
        let kind: String
        let style: String
        let pixels: [Pixel]
        let clippedPixels: [Pixel]
        let paletteIndices: [Int8]
        // Resolved visible extent is used for the joint, not the unbounded config length.
        var centerX: Double { Double(pixels.map(\.x).reduce(0, +)) / Double(max(1, pixels.count)) }
        var centerY: Double { Double(pixels.map(\.y).reduce(0, +)) / Double(max(1, pixels.count)) }
    }

    static func resolve(seed: String) -> Self {
        let effective = seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
        let config = resolveConfig(seed: effective)
        let raster = generateCreatureGrid(seed: effective)
        let trace = traceResolvedCreature(seed: effective)
        let familySupported = config.avatarMode == .creature && config.complexityTier >= 4 &&
            config.symmetryAxis == .vertical && config.symmetricVertical && !config.upsideDown
        let supported = familySupported && trace.pixels == raster
        let skin: Int8 = config.hasOpaqueBackground ? 1 : 0
        var groups: [String: [Pixel]] = [:], clipped: [String: [Pixel]] = [:]
        var headFootprint: [Pixel] = []
        var silhouette: [Pixel] = []
        for y in 0..<32 {
            for x in 0..<32 {
                let pixel = Pixel(x: x, y: y)
                if trace.headPixels.contains(y * 32 + x), raster[y][x] != -1 { headFootprint.append(pixel) }
                let role = trace.roles[y][x]
                guard role != "background", raster[y][x] >= 0 else {
                    if trace.beforeClipping.count == 32 {
                        let previous = trace.beforeClipping[y][x]
                        if previous != "background" { clipped[previous, default: []].append(pixel) }
                    }
                    continue
                }
                silhouette.append(pixel)
                // In a three-colour palette the legacy mouth/brows can collapse to skin.
                // Those flags do not create visible features; never invent them in 3D.
                let invisibleMark = ["mouth", "brow", "beard", "hair", "nose", "eyeL", "eyeR"].contains(role) && raster[y][x] == skin
                let visibleRole = invisibleMark ? "head" : (role == "brow" ? (x < 16 ? "browL" : "browR") : role)
                groups[visibleRole, default: []].append(pixel)
            }
        }
        let parts = groups.keys.sorted().map { role in
            let kind: String
            if role.hasPrefix("limb") { kind = "appendage" }
            else if role.hasPrefix("eye") { kind = "eye" }
            else if role.hasPrefix("ear") { kind = "ear" }
            else if role.hasPrefix("brow") { kind = "brow" }
            else { kind = role }
            return Part(id: role, kind: kind, style: kind == "appendage" ? config.appendageStyle : (kind == "eye" ? config.eyeShape.rawValue : kind),
                        pixels: groups[role]!, clippedPixels: clipped[role] ?? [],
                        paletteIndices: groups[role]!.map { raster[$0.y][$0.x] })
        }
        let mask: String
        switch config.shapeMask { case .rect: mask = "canvas"; case .shape(let shape): mask = shape.rawValue }
        let paletteRGBA = (0..<6).map { index -> [UInt8] in
            let testGrid: Grid = Array(repeating: Array(repeating: Int8(index), count: 32), count: 32)
            return Array(gridToRgbaBuffer(grid: testGrid, palette: config.palette, false).prefix(4))
        }
        var result = Self(version: currentVersion, legacyRendererVersion: "legacy-6e34657", palette: config.palette,
                    rgbaPalette: paletteRGBA, raster: raster.flatMap { $0 }, silhouette: silhouette,
                    head: Head(shape: mask == "canvas" ? "circle" : mask, centerX: 15.5,
                               centerY: (config.hasBody ? 12.0 : 16.0) - 0.5,
                               radius: config.creatureType == "alien" ? 13 : 11,
                               ellipseX: config.ellipseAspect.0, ellipseY: config.ellipseAspect.1, footprint: headFootprint),
                    parts: parts, clippingMask: mask, supported: supported,
                    fallbackReason: supported ? nil : "This appearance stays in its original 2D form. The first 3D family supports upright, vertically mirrored creatures with visible features.")
        if !supported {
            // Trace semantics are trustworthy only when they match the raster.
            // Other generator modes have their own actual foreground mask.
            let pixels: [Pixel]
            if config.avatarMode == .creature && trace.pixels == raster {
                pixels = silhouette
            } else {
                pixels = (0..<32).flatMap { y in (0..<32).compactMap { x in
                    raster[y][x] >= 0 && (!config.hasOpaqueBackground || raster[y][x] != 0) ? Pixel(x: x, y: y) : nil
                } }
            }
            result.volume = .init(version: 1, family: config.avatarMode.rawValue, pixels: pixels)
        }
        return result
    }
}

/// Closed colored volume with curved front/back and boundary walls. Unlike a
/// radial head, this preserves holes, asymmetry and disconnected islands.
struct ResolvedCreatureVolume {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    var materials: [UInt32] = []
    static func make(_ appearance: CreatureAppearanceDescriptor) -> Self {
        let pixels = appearance.volume?.pixels ?? appearance.silhouette
        let cells = Set(pixels.map { $0.y * 32 + $0.x })
        func filled(_ x: Int, _ y: Int) -> Bool { (0..<32).contains(x) && (0..<32).contains(y) && cells.contains(y * 32 + x) }
        var result = Self(), vertices: [Int: UInt32] = [:]
        func vertex(_ x: Int, _ y: Int, _ front: Bool, cellX: Int, cellY: Int) -> UInt32 {
            // Diagonal-only islands must not share the vertical boundary edge:
            // doing so would attach four wall faces to one non-manifold edge.
            let diagonal = (filled(x-1,y-1) && filled(x,y) && !filled(x,y-1) && !filled(x-1,y)) ||
                (filled(x,y-1) && filled(x-1,y) && !filled(x-1,y-1) && !filled(x,y))
            let sector = diagonal ? (cellX < x ? 1 : 2) : 0
            let key = ((y * 33 + x) * 2 + (front ? 1 : 0)) * 3 + sector
            if let saved = vertices[key] { return saved }
            // Distance to the nearest exposed cell determines rounded thickness.
            var edgeDistance: Float = 0
            for radius in 1...10 {
                let interior = (-radius..<radius).allSatisfy { dy in
                    (-radius..<radius).allSatisfy { dx in filled(x + dx, y + dy) }
                }
                if !interior { break }; edgeDistance = Float(radius)
            }
            let depth = 0.22 + 0.42 * sqrt(min(1, edgeDistance / 8))
            let index = UInt32(result.positions.count)
            result.positions.append([(Float(x) - 16) * 0.0625, (16 - Float(y)) * 0.0625, front ? depth : -depth])
            result.normals.append(.zero); vertices[key] = index; return index
        }
        func quad(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32, _ palette: UInt32) {
            result.indices += [a, b, c, a, c, d]; result.materials += [palette, palette]
        }
        for p in pixels {
            let x = p.x, y = p.y, palette = UInt32(max(0, appearance.raster[y * 32 + x]))
            let corners = [(x,y), (x+1,y), (x+1,y+1), (x,y+1)]
            let f = corners.map { vertex($0.0, $0.1, true, cellX: x, cellY: y) }
            let b = corners.map { vertex($0.0, $0.1, false, cellX: x, cellY: y) }
            quad(f[0], f[3], f[2], f[1], palette); quad(b[0], b[1], b[2], b[3], palette)
            for (edge, nx, ny) in [(0,x,y-1), (1,x+1,y), (2,x,y+1), (3,x-1,y)] where !filled(nx, ny) {
                let next = (edge + 1) % 4; quad(f[edge], f[next], b[next], b[edge], palette)
            }
        }
        for i in stride(from: 0, to: result.indices.count, by: 3) {
            let ids = (0..<3).map { Int(result.indices[i + $0]) }
            let a = result.positions[ids[1]] - result.positions[ids[0]], b = result.positions[ids[2]] - result.positions[ids[0]]
            let n = SIMD3<Float>(a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x)
            for id in ids { result.normals[id] += n }
        }
        result.normals = result.normals.map { n in n / max(0.000001, sqrt(n.x*n.x+n.y*n.y+n.z*n.z)) }
        return result
    }
}

/// A local demo fixture has a new, random public identity. Its legacy seed stays local.
/// Mutable play state lives in the controller, outside this appearance descriptor.
struct PlayroomCompanion: Identifiable {
    let id = UUID()
    let name: String
    let seed: String
    let note: String
    let descriptor: CreatureAppearanceDescriptor
    init(_ name: String, _ number: Int, _ note: String) {
        self.name = name; self.seed = "little-fonster-\(number)"; self.note = note
        self.descriptor = .resolve(seed: seed)
    }
    init(name: String, seed: String) { self.name = name; self.seed = seed; self.note = ""; self.descriptor = .resolve(seed: seed) }
    static let fixtures = [
        Self("Coral", 135, "A little wave goes a long way."),
        Self("Moss", 138, "Curious, wiggly, and a little shy."),
        Self("Iris", 233, "Small creature. Big feelings."),
        Self("Tide", 155, "Happy to just hang out."),
        Self("Orbit", 44, "Always up for one more bounce."),
        Self("Plum", 29, "An excellent listener."),
        Self("Poppy", 266, "Eight tiny reasons to dance."),
        Self("Inky", 19, "A very thoughtful little face."),
        Self("Pebble", 0, "Antlers, feet, and a warm hello."),
        Self("Nori", 18, "Slow afternoons are the best."),
        Self("Ember", 113, "A bright spot in your day."),
        Self("Wisp", 77, "Quiet company, whenever you like.")
    ]
}
