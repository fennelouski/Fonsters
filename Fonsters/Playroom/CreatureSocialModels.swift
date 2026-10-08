import Foundation
import CryptoKit

/// A chosen label, never inferred from the camera, microphone or text.
enum CreatureFeeling: String, Codable, CaseIterable, Identifiable {
    case neutral, bright, curious, cozy, quiet, low
    var id: String { rawValue }
    var title: String {
        switch self {
        case .neutral: "Just here"; case .bright: "Bright"; case .curious: "Curious"
        case .cozy: "Cozy"; case .quiet: "Quiet"; case .low: "A little low"
        }
    }
    var symbol: String {
        switch self {
        case .neutral: "circle"; case .bright: "sun.max"; case .curious: "sparkle.magnifyingglass"
        case .cozy: "cup.and.saucer"; case .quiet: "moon"; case .low: "cloud"
        }
    }
    var prefersQuietCompany: Bool { [.cozy, .quiet, .low].contains(self) }
    var energy: Float {
        switch self {
        case .neutral: 1; case .bright: 1.08; case .curious: 1.02
        case .cozy: 0.75; case .quiet: 0.65; case .low: 0.55
        }
    }
}

enum VisitCardError: LocalizedError {
    case invalid, unsupported, tooLarge, changedIdentity, alreadyHere
    var errorDescription: String? {
        switch self {
        case .invalid: "This isn't a valid Fonster visit snapshot."
        case .unsupported: "This snapshot uses an appearance or format this preview can't host yet."
        case .tooLarge: "This snapshot is larger than the preview's 128 KB limit."
        case .changedIdentity: "This public identity has a different appearance. The saved friendship was preserved."
        case .alreadyHere: "This Fonster is already in the room."
        }
    }
}

/// Public snapshots are deliberately separate from access grants and private care state.
struct FonsterVisitCard: Codable, Equatable {
    static let byteLimit = 128 * 1024
    let format: String
    let version: Int
    let publicID: UUID
    let name: String
    let appearance: CreatureAppearanceDescriptor
    let temperament: Temperament
    let feeling: CreatureFeeling?
    let biography: FonsterBiography?
    struct Temperament: Codable, Equatable {
        let warmth: Double
        let energy: Double
    }
    init(publicID: UUID, name: String, appearance: CreatureAppearanceDescriptor,
         warmth: Double, energy: Double, feeling: CreatureFeeling? = nil, biography: FonsterBiography? = nil) {
        let publicBiography = biography?.publicSnapshot
        self.biography = publicBiography?.isEmpty == false ? publicBiography : nil
        format = "fonsters-visit"; version = self.biography == nil ? 1 : 2
        self.publicID = publicID; self.name = name; self.appearance = appearance
        temperament = .init(warmth: warmth, energy: energy); self.feeling = feeling
    }
    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.byteLimit else { throw VisitCardError.tooLarge }
        return data
    }
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= byteLimit else { throw VisitCardError.tooLarge }
        do {
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw VisitCardError.invalid }
            // Reject hidden metadata, rather than silently ignoring seeds or identifiers.
            try keys(root, allowed: ["format", "version", "publicID", "name", "appearance", "temperament", "feeling", "biography"])
            if let biography = root["biography"] as? [String: Any] {
                try keys(biography, allowed: ["background", "likes", "dislikes", "movies", "shows", "creators", "celebrities"])
            }
            guard let appearance = root["appearance"] as? [String: Any],
                  let head = appearance["head"] as? [String: Any],
                  let parts = appearance["parts"] as? [[String: Any]],
                  let temperament = root["temperament"] as? [String: Any] else { throw VisitCardError.invalid }
            try keys(appearance, allowed: ["version", "legacyRendererVersion", "palette", "rgbaPalette", "raster",
                "silhouette", "head", "parts", "clippingMask", "supported", "fallbackReason"])
            try keys(head, allowed: ["shape", "centerX", "centerY", "radius", "ellipseX", "ellipseY", "footprint"])
            try keys(temperament, allowed: ["warmth", "energy"])
            for part in parts {
                try keys(part, allowed: ["id", "kind", "style", "pixels", "clippedPixels", "paletteIndices"])
                try pixelKeys(part["pixels"]); try pixelKeys(part["clippedPixels"])
            }
            try pixelKeys(appearance["silhouette"]); try pixelKeys(head["footprint"])
            let card = try JSONDecoder().decode(Self.self, from: data)
            try card.validate()
            return card
        } catch let error as VisitCardError { throw error }
        catch { throw VisitCardError.invalid }
    }
    private static func keys(_ value: [String: Any], allowed: Set<String>) throws {
        guard Set(value.keys).isSubset(of: allowed) else { throw VisitCardError.invalid }
    }
    private static func pixelKeys(_ value: Any?) throws {
        guard let pixels = value as? [[String: Any]], pixels.count <= 1024 else { throw VisitCardError.invalid }
        for pixel in pixels { try keys(pixel, allowed: ["x", "y"]) }
    }
    func validate() throws {
        guard format == "fonsters-visit", (1...2).contains(version), appearance.version == 1,
              appearance.legacyRendererVersion == "legacy-6e34657", appearance.supported,
              appearance.fallbackReason == nil else { throw VisitCardError.unsupported }
        guard version == 1 ? biography == nil : biography?.isValidPublicSnapshot == true else { throw VisitCardError.invalid }
        guard (1...24).contains(name.count),
              name.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "-" }),
              [temperament.warmth, temperament.energy].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              (1...6).contains(appearance.palette.count), appearance.rgbaPalette.count == 6,
              appearance.rgbaPalette.allSatisfy({ $0.count == 4 }),
              appearance.palette.allSatisfy({ $0.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil }),
              appearance.raster.count == 1024, appearance.raster.allSatisfy({ (-1...5).contains($0) }),
              (1...40).contains(appearance.parts.count) else { throw VisitCardError.invalid }
        for index in 0..<6 {
            let grid: Grid = Array(repeating: Array(repeating: Int8(index), count: 32), count: 32)
            guard appearance.rgbaPalette[index] == Array(gridToRgbaBuffer(grid: grid, palette: appearance.palette, false).prefix(4)) else { throw VisitCardError.invalid }
        }
        let head = appearance.head
        let shapes = Set(CoreShape.allCases.map(\.rawValue))
        guard shapes.contains(head.shape), shapes.union(["canvas"]).contains(appearance.clippingMask),
              [head.centerX, head.centerY, head.radius, head.ellipseX, head.ellipseY].allSatisfy(\.isFinite),
              (0...31).contains(head.centerX), (0...31).contains(head.centerY),
              (2...16).contains(head.radius), (0.2...2.5).contains(head.ellipseX), (0.2...2.5).contains(head.ellipseY),
              (16...1024).contains(head.footprint.count) else { throw VisitCardError.invalid }
        func valid(_ pixels: [CreatureAppearanceDescriptor.Pixel]) -> Bool {
            pixels.count <= 1024 && Set(pixels).count == pixels.count &&
            pixels.allSatisfy { (0..<32).contains($0.x) && (0..<32).contains($0.y) }
        }
        guard valid(head.footprint), valid(appearance.silhouette), !appearance.silhouette.isEmpty else { throw VisitCardError.invalid }
        let basicIDs: [String: String] = ["head": "head", "body": "body", "mouth": "mouth", "nose": "nose",
            "horn": "horn", "antler": "antler", "hair": "hair", "beard": "beard", "marking": "marking",
            "eyeL": "eye", "eyeR": "eye", "earL": "ear", "earR": "ear", "browL": "brow", "browR": "brow"]
        var allPixels = Set<CreatureAppearanceDescriptor.Pixel>(), IDs = Set<String>(), clippedCount = 0
        for part in appearance.parts {
            let limb = part.id.range(of: "^limb[LR]([0-9]|1[0-5])$", options: .regularExpression) != nil
            guard IDs.insert(part.id).inserted, basicIDs[part.id] == part.kind || (limb && part.kind == "appendage"),
                  !part.pixels.isEmpty, valid(part.pixels), valid(part.clippedPixels),
                  part.paletteIndices.count == part.pixels.count,
                  part.paletteIndices.allSatisfy({ (0...5).contains($0) }) else { throw VisitCardError.invalid }
            if part.kind == "appendage" {
                guard ["arm", "leg", "tentacle"].contains(part.style) else { throw VisitCardError.invalid }
            } else if part.kind == "eye" {
                guard EyeShape.allCases.map(\.rawValue).contains(part.style) else { throw VisitCardError.invalid }
            } else { guard part.style == part.kind else { throw VisitCardError.invalid } }
            for (index, pixel) in part.pixels.enumerated() {
                guard allPixels.insert(pixel).inserted, appearance.raster[pixel.y * 32 + pixel.x] == part.paletteIndices[index] else { throw VisitCardError.invalid }
            }
            clippedCount += part.clippedPixels.count
            guard clippedCount <= 4096, Set(part.clippedPixels).isDisjoint(with: Set(appearance.silhouette)) else { throw VisitCardError.invalid }
        }
        guard allPixels == Set(appearance.silhouette) else { throw VisitCardError.invalid }
    }
    var appearanceDigest: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(appearance)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct CreatureFriendship: Codable, Equatable {
    let first: UUID
    let second: UUID
    var hellos = 0
    var games = 0
    var quietMoments = 0
    var meaningfulMoments: Int { hellos + games + quietMoments }
    var description: String {
        if meaningfulMoments < 3 { return "Getting acquainted, one little hello at a time." }
        if meaningfulMoments < 8 { return "Familiar faces. A shared rhythm is starting." }
        return "Little friends, with their own shared rituals."
    }
}
