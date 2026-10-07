import Foundation
import ImageIO
import CryptoKit

@main struct VerifyAppearance {
    static func digest(_ data: [UInt8]) -> String {
        SHA256.hash(data: Data(data)).map { String(format: "%02x", $0) }.joined()
    }
    static func main() throws {
        let baselineURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let expected = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: baselineURL))
        let companions = PlayroomCompanion.fixtures
        var familyCount = 0
        for number in 0..<3000 {
            let seed = "little-fonster-\(number)"
            let config = resolveConfig(seed: seed)
            if config.avatarMode == .creature && config.complexityTier >= 4 && config.symmetryAxis == .vertical && config.symmetricVertical && !config.upsideDown {
                precondition(traceResolvedCreature(seed: seed).pixels == generateCreatureGrid(seed: seed), "Trace drift: \(number)")
                familyCount += 1
            }
        }
        for companion in companions {
            let descriptor = companion.descriptor
            precondition(descriptor.supported, "Unsupported fixture \(companion.name)")
            let grid = generateCreatureGrid(seed: companion.seed)
            let rgba = gridToRgbaBuffer(grid: grid, palette: descriptor.palette, false)
            precondition(digest(rgba) == expected[companion.seed], "Legacy pixels changed: \(companion.name)")
            precondition(descriptor.raster == grid.flatMap { $0 }, "Descriptor raster mismatch")
            precondition(traceResolvedCreature(seed: companion.seed).pixels == grid, "Semantic trace mismatch")
            precondition(!descriptor.head.footprint.isEmpty)
            precondition(descriptor.parts.filter { $0.kind == "eye" }.count == 2)
            for part in descriptor.parts {
                precondition(part.pixels.count == part.paletteIndices.count)
                for p in part.pixels { precondition(grid[p.y][p.x] >= 0) }
            }
            let json = try JSONEncoder().encode(descriptor)
            let text = String(decoding: json, as: UTF8.self)
            precondition(!text.contains(companion.seed) && !text.contains("email") && !text.contains("seed"))
            let decoded = try JSONDecoder().decode(CreatureAppearanceDescriptor.self, from: json)
            precondition(decoded == descriptor)
        }
        let tide = companions.first { $0.name == "Tide" }!
        precondition(resolveConfig(seed: tide.seed).hasMouth)
        precondition(!tide.descriptor.parts.contains { $0.kind == "mouth" }, "Invisible mouth must remain absent")
        let copy = PlayroomCompanion("Coral", 135, "fixture")
        precondition(copy.id != companions[0].id && copy.descriptor == companions[0].descriptor)
        let unsupported = CreatureAppearanceDescriptor.resolve(seed: " ")
        precondition(!unsupported.supported && unsupported.fallbackReason != nil)
        let seeds = companions.map(\.seed)
        let link = buildShareURL(seeds: Array(seeds.prefix(3)))!
        precondition(parseSeedsFromShareURL(link) == Array(seeds.prefix(3)))
        let png = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("legacy-portrait.png")
        precondition(writeCreatureStickerPNG(seed: companions[0].seed, to: png, sideLength: 512))
        let pngSource = CGImageSourceCreateWithURL(png as CFURL, nil)!
        precondition(CGImageSourceGetCount(pngSource) == 1)
        let image = CGImageSourceCreateImageAtIndex(pngSource, 0, nil)!
        precondition(image.width == 512 && image.height == 512)
        let gif = creatureGIFData(seeds: seeds)!
        let gifSource = CGImageSourceCreateWithData(gif as CFData, nil)!
        precondition(CGImageSourceGetCount(gifSource) == 12)
        try gif.write(to: URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("legacy-evolution.gif"))
        print("PASS: 12 frozen SHA-256 RGBA fixtures; exact descriptor/trace parity; resolved absent mouth; actual feature coordinates; Codable round-trip; random public IDs; no seed/email in descriptor; legacy share-link round-trip; 512px PNG; 12-frame GIF.")
        print("PASS: semantic trace matches the frozen renderer across \(familyCount) supported appearances from a 3,000-seed corpus.")
    }
}
