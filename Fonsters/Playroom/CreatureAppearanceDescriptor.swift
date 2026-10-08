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
        return Self(version: currentVersion, legacyRendererVersion: "legacy-6e34657", palette: config.palette,
                    rgbaPalette: paletteRGBA, raster: raster.flatMap { $0 }, silhouette: silhouette,
                    head: Head(shape: mask == "canvas" ? "circle" : mask, centerX: 15.5,
                               centerY: (config.hasBody ? 12.0 : 16.0) - 0.5,
                               radius: config.creatureType == "alien" ? 13 : 11,
                               ellipseX: config.ellipseAspect.0, ellipseY: config.ellipseAspect.1, footprint: headFootprint),
                    parts: parts, clippingMask: mask, supported: supported,
                    fallbackReason: supported ? nil : "This appearance stays in its original 2D form. The first 3D family supports upright, vertically mirrored creatures with visible features.")
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
