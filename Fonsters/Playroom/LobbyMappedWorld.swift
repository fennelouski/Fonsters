import Foundation
import simd

/// Offline public-area snapshots; no GPS, account, or runtime provider requests.
struct LobbyMappedWorld: Decodable {
    struct Area: Decodable { let id: String; let name: String; let bounds: Bounds; let anchor: Anchor }
    struct Bounds: Decodable { let south: Double; let west: Double; let north: Double; let east: Double }
    struct Anchor: Decodable { let latitude: Double; let longitude: Double }
    struct Coverage: Decodable { let status: String; let exhaustive: Bool; let surveyedAbsence: Bool; let note: String }
    struct Source: Decodable { let attribution: String; let license: String; let licenseURL: String; let dataURL: String }
    struct Geometry: Decodable {
        let type: String
        let lines: [[[Double]]]
        enum CodingKeys: CodingKey { case type, coordinates }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            type = try values.decode(String.self, forKey: .type)
            switch type {
            case "Point": lines = [[try values.decode([Double].self, forKey: .coordinates)]]
            case "LineString": lines = [try values.decode([[Double]].self, forKey: .coordinates)]
            case "Polygon", "MultiLineString": lines = try values.decode([[[Double]]].self, forKey: .coordinates)
            default: throw DecodingError.dataCorruptedError(forKey: .type, in: values, debugDescription: "Unsupported map geometry")
            }
        }
    }
    struct Feature: Decodable, Identifiable { let id: String; let kind: String; let name: String; let geometry: Geometry; let sourceURL: String; let widthMeters: Double?; let waterwayType: String? }
    let schemaVersion: Int
    let area: Area
    let fetchedAt: String
    let coverage: Coverage
    let source: Source
    let features: [Feature]
    var isStale: Bool {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: fetchedAt) ?? ISO8601DateFormatter().date(from: fetchedAt)
        return date.map { Date().timeIntervalSince($0) > 7 * 86_400 } ?? true
    }
    static let unitsPerMeter: Double = 0.1
    func project(_ coordinate: [Double]) -> SIMD2<Float> {
        [Float((coordinate[0] - area.anchor.longitude) * 111_320 * cos(area.anchor.latitude * .pi / 180) * Self.unitsPerMeter),
         Float(-(coordinate[1] - area.anchor.latitude) * 111_320 * Self.unitsPerMeter)]
    }
    var minPoint: SIMD2<Float> { project([area.bounds.west, area.bounds.north]) }
    var maxPoint: SIMD2<Float> { project([area.bounds.east, area.bounds.south]) }
    func center(_ feature: Feature) -> SIMD2<Float> {
        if feature.kind == "waterway" {
            var longest: Float = -1; var result = (minPoint + maxPoint) / 2
            for line in feature.geometry.lines {
                let points = line.map(project)
                for (a, b) in zip(points, points.dropFirst()) {
                    if let (a, b) = clip(a, b), simd_distance_squared(a, b) > longest {
                        longest = simd_distance_squared(a, b); result = (a + b) / 2
                    }
                }
            }
            return result
        }
        let points = feature.geometry.lines.flatMap { $0 }.map(project)
        guard !points.isEmpty else { return .zero }
        let min = points.reduce(SIMD2<Float>(repeating: .infinity)) { simd_min($0, $1) }
        let max = points.reduce(SIMD2<Float>(repeating: -.infinity)) { simd_max($0, $1) }
        return (min + max) / 2
    }
    func near(_ position: SIMD2<Float>) -> [Feature] {
        guard position.x >= minPoint.x && position.x <= maxPoint.x && position.y >= minPoint.y && position.y <= maxPoint.y else { return [] }
        return features.filter { feature in
            if feature.kind != "waterway" { return simd_distance(center(feature), position) < 8 }
            return feature.geometry.lines.contains { line in
                let points = line.map(project)
                return zip(points, points.dropFirst()).contains { a, b in
                    guard let (a, b) = clip(a, b) else { return false }
                    let delta = b - a, length = simd_length_squared(delta)
                    let t = length > 0 ? max(0, min(1, simd_dot(position - a, delta) / length)) : 0
                    return simd_distance(position, a + delta * t) < 6
                }
            }
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func symbol(_ kind: String?) -> String { switch kind { case "windmill": "fanblades.fill"; case "playground": "figure.play"; case "waterway": "water.waves"; default: "map.fill" } }
    static func load(data: Data) throws -> Self {
        guard data.count < 2_000_000 else { throw CocoaError(.fileReadCorruptFile) }
        let value = try JSONDecoder().decode(Self.self, from: data)
        let bounds = value.area.bounds, anchor = value.area.anchor
        guard value.schemaVersion == 1, value.area.id == "zaanse-schans", value.features.count <= 2000,
              [bounds.south, bounds.west, bounds.north, bounds.east, anchor.latitude, anchor.longitude].allSatisfy(\.isFinite),
              (-85...85).contains(bounds.south), (-85...85).contains(bounds.north), (-180...180).contains(bounds.west), (-180...180).contains(bounds.east),
              bounds.south < bounds.north, bounds.west < bounds.east, bounds.north - bounds.south < 0.1, bounds.east - bounds.west < 0.1,
              anchor.latitude >= bounds.south, anchor.latitude <= bounds.north, anchor.longitude >= bounds.west, anchor.longitude <= bounds.east,
              ISO8601DateFormatter().date(from: value.fetchedAt.replacingOccurrences(of: #"\.\d+Z$"#, with: "Z", options: .regularExpression)) != nil,
              value.coverage.status == "mapped_partial", !value.coverage.exhaustive, !value.coverage.surveyedAbsence,
              (-85...85).contains(anchor.latitude), (-180...180).contains(anchor.longitude),
              value.source.licenseURL == "https://www.openstreetmap.org/copyright", value.source.dataURL == "https://www.openstreetmap.org",
              value.source.license == "ODbL-1.0", !value.source.attribution.isEmpty,
              value.features.reduce(0, { $0 + $1.geometry.lines.reduce(0, { $0 + $1.count }) }) <= 50_000,
              value.features.allSatisfy({ f in ["windmill", "playground", "waterway"].contains(f.kind) && f.name.count <= 160 && f.sourceURL.hasPrefix("https://www.openstreetmap.org/") &&
                !f.geometry.lines.isEmpty && f.geometry.lines.count <= 256 && f.geometry.lines.allSatisfy({ !$0.isEmpty && $0.count <= 5000 }) &&
                (f.widthMeters == nil || (f.widthMeters!.isFinite && f.widthMeters! > 0 && f.widthMeters! <= 1000)) && f.geometry.lines.flatMap({ $0 }).allSatisfy { $0.count == 2 && $0.allSatisfy(\.isFinite) && (-180...180).contains($0[0]) && (-85...85).contains($0[1]) } }) else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
    static func bundled() -> Self? {
        guard let url = Bundle.main.url(forResource: "MappedWorldDemo", withExtension: "json") ?? Bundle.main.url(forResource: "MappedWorldDemo", withExtension: "json", subdirectory: "Resources"), let data = try? Data(contentsOf: url) else { return nil }
        return try? load(data: data)
    }
    /// Liang–Barsky clip preserves real line direction at the snapshot edge.
    func clip(_ a: SIMD2<Float>, _ b: SIMD2<Float>, lower: SIMD2<Float>? = nil, upper: SIMD2<Float>? = nil) -> (SIMD2<Float>, SIMD2<Float>)? {
        let lower = lower ?? minPoint, upper = upper ?? maxPoint
        let d = b - a; var low: Float = 0, high: Float = 1
        for (p, q) in [(-d.x, a.x - lower.x), (d.x, upper.x - a.x), (-d.y, a.y - lower.y), (d.y, upper.y - a.y)] {
            if abs(p) < 0.00001 { if q < 0 { return nil }; continue }
            let r = q / p
            if p < 0 { low = max(low, r) } else { high = min(high, r) }
            if low > high { return nil }
        }
        return (a + low * d, a + high * d)
    }
}
