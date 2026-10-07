import Foundation
import simd

/// Population opens places, never changes a creature's appearance or care state.
struct LobbyWorld {
    enum Area: String, CaseIterable, Identifiable {
        case garden, benches, plaza, park, neighborhood
        var id: String { rawValue }
        var title: String {
            switch self { case .garden: "Gathering garden"; case .benches: "Bench walk"; case .plaza: "Fountain plaza"; case .park: "Willow park"; case .neighborhood: "Little neighborhood" }
        }
        var symbol: String {
            switch self { case .garden: "leaf"; case .benches: "chair.lounge"; case .plaza: "drop.circle"; case .park: "tree"; case .neighborhood: "house" }
        }
        var population: Int {
            switch self { case .garden: 1; case .benches: 3; case .plaza: 5; case .park: 8; case .neighborhood: 10 }
        }
        var center: SIMD2<Float> {
            switch self { case .garden: [0, 1.6]; case .benches: [-2.65, 0.5]; case .plaza: [0, -0.2]; case .park: [-4.35, -2.1]; case .neighborhood: [4.65, -1.1] }
        }
    }
    struct Obstacle {
        let center: SIMD2<Float>
        let halfSize: SIMD2<Float>
        let round: Bool
        func contains(_ p: SIMD2<Float>, clearance: Float) -> Bool {
            let d = p - center
            if round { return simd_length(d) < halfSize.x + clearance }
            return abs(d.x) < halfSize.x + clearance && abs(d.y) < halfSize.y + clearance
        }
        func intersects(_ a: SIMD2<Float>, _ b: SIMD2<Float>, clearance: Float) -> Bool {
            let delta = b - a
            if round {
                let squared = simd_length_squared(delta)
                let t = squared > 0.000001 ? min(1, max(0, simd_dot(center - a, delta) / squared)) : 0
                return simd_distance(a + delta * t, center) < halfSize.x + clearance
            }
            let lower = center - halfSize - SIMD2<Float>(repeating: clearance)
            let upper = center + halfSize + SIMD2<Float>(repeating: clearance)
            var entry: Float = 0, exit: Float = 1
            for axis in 0..<2 {
                if abs(delta[axis]) < 0.000001 {
                    if a[axis] <= lower[axis] || a[axis] >= upper[axis] { return false }
                } else {
                    let first = (lower[axis] - a[axis]) / delta[axis], last = (upper[axis] - a[axis]) / delta[axis]
                    entry = max(entry, min(first, last)); exit = min(exit, max(first, last))
                    if entry >= exit { return false }
                }
            }
            return entry < exit
        }
    }
    let population: Int
    var radius: Float { population >= 10 ? 8.2 : population >= 8 ? 6.8 : population >= 5 ? 5.2 : population >= 3 ? 4 : 3 }
    var areas: [Area] { Area.allCases.filter { $0.population <= population } }
    var nextArea: Area? { Area.allCases.first { $0.population > population } }
    var benches: [SIMD2<Float>] { population >= 3 ? [[-2.65, -0.8], [2.65, -0.8]] : [] }
    var trees: [SIMD2<Float>] {
        var points: [SIMD2<Float>] = [[-2.5, -2.25], [2.5, -2.25]]
        if population >= 8 { points += [[-5.1, -2.7], [-4.0, -3.7], [-5.7, -0.8], [-3.25, -4.1]] }
        return points
    }
    var buildings: [SIMD2<Float>] { population >= 10 ? [[4.3, -3.1], [6.25, -1.7], [5.75, 1.0]] : [] }
    var obstacles: [Obstacle] {
        var result = trees.map { Obstacle(center: $0, halfSize: [0.22, 0.22], round: true) }
        result += benches.map { Obstacle(center: $0, halfSize: [0.88, 0.24], round: false) }
        result += buildings.map { Obstacle(center: $0, halfSize: [0.72, 0.62], round: false) }
        if population >= 8 { result.append(.init(center: [-4.6, 0.6], halfSize: [0.8, 0.78], round: false)) }
        if population >= 5 { result.append(.init(center: [0, -1.65], halfSize: [0.72, 0.72], round: true)) }
        return result
    }
    func walkable(_ p: SIMD2<Float>, clearance: Float = 0.43) -> Bool {
        p.x.isFinite && p.y.isFinite && simd_length(p) <= radius - clearance && !obstacles.contains { $0.contains(p, clearance: clearance) }
    }
    func home(_ index: Int) -> SIMD2<Float> {
        let homes: [SIMD2<Float>] = [[-1.5, 0.8], [-0.5, 0.2], [0.5, 0.2], [1.5, 0.8],
                                  [-2.4, 1.8], [-1.2, 2.1], [0, 2.5], [1.2, 2.1], [2.4, 1.8],
                                  [-4.3, -1.5], [4.5, -1.0], [3.3, 2.1]]
        return homes[min(max(0, index), homes.count - 1)]
    }
    func destination(in area: Area, slot: Int) -> SIMD2<Float> {
        let offsets: [SIMD2<Float>] = [[-0.55, 0.35], [0.55, 0.35], [0, 1.2], [-1.0, 1.2], [1, 1.2], [0, -0.7]]
        let target = area.center + offsets[slot % offsets.count]
        if walkable(target) { return target }
        return nearestWalkable(to: target)
    }
    func nearestWalkable(to p: SIMD2<Float>) -> SIMD2<Float> {
        if walkable(p, clearance: 0.46) { return p }
        for ring in 1...20 {
            for spoke in 0..<24 {
                let angle = Float(spoke) / 24 * 2 * .pi
                let candidate = p + SIMD2<Float>(cos(angle), sin(angle)) * Float(ring) * 0.25
                if walkable(candidate, clearance: 0.46) { return candidate }
            }
        }
        return [0, 1.6]
    }
    func segmentClear(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Bool {
        walkable(a, clearance: 0.44) && walkable(b, clearance: 0.44) && !obstacles.contains { $0.intersects(a, b, clearance: 0.44) }
    }
    /// Small deterministic A* grid; calculated when a destination changes, not per frame.
    func route(from start: SIMD2<Float>, to requested: SIMD2<Float>, avoiding companions: [SIMD2<Float>] = []) -> [SIMD2<Float>] {
        let goal = nearestWalkable(to: requested)
        if companions.isEmpty && segmentClear(start, goal) { return [goal] }
        let step: Float = 0.45, extent = Int(ceil(radius / step)), width = extent * 2 + 1
        let barriers = obstacles + companions.map { Obstacle(center: $0, halfSize: [0.46, 0.46], round: true) }
        func free(_ p: SIMD2<Float>) -> Bool { simd_length(p) <= radius - 0.44 && !barriers.contains { $0.contains(p, clearance: 0.44) } }
        func clear(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Bool {
            free(a) && free(b) && !barriers.contains { $0.intersects(a, b, clearance: 0.44) }
        }
        if clear(start, goal) { return [goal] }
        func point(_ key: Int) -> SIMD2<Float> { [Float(key % width - extent) * step, Float(key / width - extent) * step] }
        func closest(_ p: SIMD2<Float>) -> Int {
            let x = Int(round(p.x / step)) + extent, y = Int(round(p.y / step)) + extent
            for ring in 0...6 {
                var candidates: [Int] = []
                for dy in -ring...ring { for dx in -ring...ring {
                    guard abs(dx) == ring || abs(dy) == ring,
                          (0..<width).contains(x + dx), (0..<width).contains(y + dy) else { continue }
                    let key = (y + dy) * width + x + dx
                    if free(point(key)) && clear(p, point(key)) { candidates.append(key) }
                } }
                if let result = candidates.min(by: { simd_distance(p, point($0)) < simd_distance(p, point($1)) }) { return result }
            }
            return -1
        }
        let first = closest(start), last = closest(goal)
        guard first >= 0, last >= 0 else { return [] }
        var open: Set<Int> = [first], previous: [Int: Int] = [:], costs = [first: Float(0)]
        var visited = Set<Int>()
        while let current = open.min(by: {
            let a = costs[$0, default: .infinity] + simd_distance(point($0), goal)
            let b = costs[$1, default: .infinity] + simd_distance(point($1), goal)
            return a == b ? $0 < $1 : a < b
        }) {
            if current == last {
                var keys = [last], cursor = last
                while let parent = previous[cursor] { keys.append(parent); cursor = parent }
                var path = keys.reversed().map(point) + [goal]
                // Remove redundant corners only when the swept segment stays clear.
                var result: [SIMD2<Float>] = [], origin = start
                while !path.isEmpty {
                    let farthest = path.indices.reversed().first { clear(origin, path[$0]) } ?? 0
                    origin = path[farthest]; result.append(origin); path.removeFirst(farthest + 1)
                }
                return result
            }
            open.remove(current); visited.insert(current)
            let x = current % width, y = current / width
            for dy in -1...1 { for dx in -1...1 where dx != 0 || dy != 0 {
                guard (0..<width).contains(x + dx), (0..<width).contains(y + dy) else { continue }
                let next = (y + dy) * width + x + dx
                guard !visited.contains(next), clear(point(current), point(next)) else { continue }
                let cost = costs[current, default: .infinity] + simd_distance(point(current), point(next))
                if cost < costs[next, default: .infinity] { costs[next] = cost; previous[next] = current; open.insert(next) }
            } }
        }
        return []
    }
}

/// This preview enrolls existing local gallery fixtures. It does not migrate pets.
struct LobbyWorldMemory {
    private struct Archive: Codable { let version: Int; let names: [String] }
    private let url: URL
    private(set) var names: [String]
    private var mayWrite = true
    private(set) var temporaryReason: String?
    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let initial = ["Coral", "Moss", "Iris", "Orbit"]
        if let i = arguments.firstIndex(of: "--personality-file"), i + 1 < arguments.count {
            url = URL(fileURLWithPath: arguments[i + 1]).appendingPathExtension("world.json")
        } else {
            url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("com.nathanfennel.Fonsters.Playroom/world-v1.json")
        }
        names = initial
        if let i = arguments.firstIndex(of: "--world-members"), i + 1 < arguments.count, let count = Int(arguments[i + 1]) {
            let rest = PlayroomCompanion.fixtures.map(\.name).filter { !initial.contains($0) }
            names = Array((initial + rest).prefix(min(12, max(2, count)))); mayWrite = false; return
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < 4096 else { throw CocoaError(.fileReadCorruptFile) }
            let saved = try JSONDecoder().decode(Archive.self, from: data)
            let allowed = Set(PlayroomCompanion.fixtures.map(\.name))
            guard saved.version == 1, (4...12).contains(saved.names.count), Array(saved.names.prefix(4)) == initial,
                  Set(saved.names).count == saved.names.count, saved.names.allSatisfy(allowed.contains) else { throw CocoaError(.fileReadCorruptFile) }
            names = saved.names
        } catch { mayWrite = false; temporaryReason = "Saved world preserved · this session is temporary." }
    }
    mutating func enroll(_ name: String) {
        guard names.count < 12, !names.contains(name), PlayroomCompanion.fixtures.contains(where: { $0.name == name }) else { return }
        names.append(name)
        guard mayWrite else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Archive(version: 1, names: names)).write(to: url, options: .atomic)
        } catch { mayWrite = false; temporaryReason = "This world couldn’t be saved · this session is temporary." }
    }
}
