import Foundation
import simd

/// Private exploration state. Coordinates are toy-world units, never GPS.
struct LobbyWaypoint: Codable, Identifiable, Equatable {
    struct Viewpoint: Codable, Equatable {
        var x: Float = 0
        var y: Float = 0
        var z: Float = 0
        var orbit: Float = 0
        var pitch: Float = 0
        var zoom: Float = 1
        var worldID: String?
        var focusX: Float?
        var focusZ: Float?
        var valid: Bool {
            [x, y, z, orbit, pitch, zoom].allSatisfy(\.isFinite) && abs(x) <= 100_000 && abs(z) <= 100_000 && (-0.25...10).contains(y) && (-0.42...0.8).contains(pitch) && (0.45...2.5).contains(zoom)
                && ((focusX == nil && focusZ == nil) || (focusX?.isFinite == true && focusZ?.isFinite == true && abs(focusX!) <= 100_000 && abs(focusZ!) <= 100_000))
        }
        var position: SIMD2<Float> { [x + (focusX ?? 0), z + (focusZ ?? -0.25)] }
    }
    let id: UUID
    var name: String
    let createdAt: Date
    let viewpoint: Viewpoint
    var landmarkNames: [String]?
    var areaName: String?
    var landmarkSymbol: String?
    var tileX: Int { Int(floor(viewpoint.position.x / 28)) }
    var tileZ: Int { Int(floor(viewpoint.position.y / 28)) }
    var pattern: UInt64 { UInt64(bitPattern: Int64(tileX &* 73_856_093 ^ tileZ &* 19_349_663)) }
    var symbol: String { if id == Self.home.id { return "house.fill" }; if let landmarkSymbol { return landmarkSymbol }; return tileX == 0 && tileZ == 0 ? "house.fill" : ["mountain.2.fill", "building.2.fill", "tree.fill", "tree.fill"][Int(pattern % 4)] }
    var terrain: String { if id == Self.home.id { return "Gathering garden" }; if let areaName { return areaName }; return tileX == 0 && tileZ == 0 ? "Gathering garden" : ["Rolling hills", "Little neighborhood", "Woodland", "Grove"][Int(pattern % 4)] }
    var metadata: String { if let areaName { return "Mapped · " + areaName + (landmarkNames?.isEmpty == false ? " · " + landmarkNames!.joined(separator: ", ") : " · Coverage incomplete") }; return "Generated scenery · \(terrain) · Tile \(tileX), \(tileZ)" }
    static let home = LobbyWaypoint(id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, name: "Session start", createdAt: .distantPast, viewpoint: .init())
}

struct LobbyWaypointMemory {
    enum Order: String, CaseIterable { case newest, nearest, name
        var title: String { switch self { case .newest: "Newest first"; case .nearest: "Nearest first"; case .name: "Name" } }
        var symbol: String { switch self { case .newest: "clock"; case .nearest: "location"; case .name: "textformat.abc" } }
    }
    private struct Archive: Codable { let version: Int; let waypoints: [LobbyWaypoint] }
    private let url: URL
    private(set) var waypoints: [LobbyWaypoint] = []
    private(set) var error: String?
    private var mayWrite = true
    var canSort: Bool { waypoints.count >= 7 }
    init(url: URL? = nil, arguments: [String] = ProcessInfo.processInfo.arguments) {
        if let url { self.url = url }
        else if let index = arguments.firstIndex(of: "--personality-file"), index + 1 < arguments.count {
            self.url = URL(fileURLWithPath: arguments[index + 1]).appendingPathExtension("waypoints.json")
        } else {
            self.url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("com.nathanfennel.Fonsters.Playroom/waypoints-v1.json")
        }
        guard FileManager.default.fileExists(atPath: self.url.path) else { return }
        do {
            let data = try Data(contentsOf: self.url)
            guard data.count <= 8_000_000 else { throw CocoaError(.fileReadCorruptFile) }
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            guard archive.version == 1, Set(archive.waypoints.map(\.id)).count == archive.waypoints.count,
                  archive.waypoints.allSatisfy({ $0.id != LobbyWaypoint.home.id && $0.viewpoint.valid && !$0.name.isEmpty && $0.name.count <= 80 && $0.createdAt.timeIntervalSince1970.isFinite }) else { throw CocoaError(.fileReadCorruptFile) }
            waypoints = archive.waypoints
        } catch { mayWrite = false; self.error = "Saved waypoints were preserved. New pins are temporary this session." }
    }
    func sorted(_ order: Order, from position: SIMD2<Float>, worldID: String? = nil) -> [LobbyWaypoint] {
        waypoints.sorted { a, b in
            switch canSort ? order : .newest {
            case .newest: if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            case .nearest:
                if (a.viewpoint.worldID == worldID) != (b.viewpoint.worldID == worldID) { return a.viewpoint.worldID == worldID }
                let da = simd_distance_squared(a.viewpoint.position, position), db = simd_distance_squared(b.viewpoint.position, position)
                if da != db { return da < db }
            case .name:
                let comparison = a.name.localizedStandardCompare(b.name)
                if comparison != .orderedSame { return comparison == .orderedAscending }
            }
            return a.id.uuidString < b.id.uuidString
        }
    }
    @discardableResult mutating func save(name: String, viewpoint: LobbyWaypoint.Viewpoint, date: Date = .now, landmarkNames: [String]? = nil, areaName: String? = nil, landmarkSymbol: String? = nil) -> UUID? {
        guard viewpoint.valid, date.timeIntervalSince1970.isFinite else { return nil }
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        let waypoint = LobbyWaypoint(id: UUID(), name: trimmed.isEmpty ? "New place" : trimmed, createdAt: date, viewpoint: viewpoint, landmarkNames: landmarkNames, areaName: areaName, landmarkSymbol: landmarkSymbol)
        waypoints.append(waypoint); persist(); return waypoint.id
    }
    mutating func rename(_ id: UUID, name: String) {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !name.isEmpty, let index = waypoints.firstIndex(where: { $0.id == id }) else { return }
        waypoints[index].name = name; persist()
    }
    private mutating func persist() {
        guard mayWrite else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Archive(version: 1, waypoints: waypoints)).write(to: url, options: .atomic)
        } catch { self.error = "This pin is temporary. Waypoints couldn’t be saved." }
    }
}
