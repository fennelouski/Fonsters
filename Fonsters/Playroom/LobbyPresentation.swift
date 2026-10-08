import Foundation
import simd

/// Presentation is separate from simulation and appearance identity. Search and
/// care borrow the stage without consuming other creatures' routes or memories.
struct LobbyPresentation {
    struct Pose: Equatable {
        var position: SIMD3<Float>
        var heading: Float
        var scale: Float = 0.55
    }
    private(set) var query = ""
    private(set) var caringFor: Int?
    private(set) var matches: [Int] = []
    private(set) var poses: [Pose] = []
    private var origins: [Pose] = []
    private var progress: Float = 1
    var sideDistance: Float = 5.5
    var borrowingStage: Bool { caringFor != nil || !query.isEmpty || progress < 1 }
    var transitioning: Bool { progress < 1 }

    static func ranked(_ query: String, names: [String]) -> [Int] {
        let term = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return Array(names.indices) }
        let normalized = names.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
        func rank(_ name: String) -> Int { name == term ? 0 : name.hasPrefix(term) ? 1 : 2 }
        return names.indices.filter { normalized[$0].contains(term) }.sorted {
            rank(normalized[$0]) == rank(normalized[$1]) ? $0 < $1 : rank(normalized[$0]) < rank(normalized[$1])
        }
    }
    mutating func change(query: String, care: Int?, names: [String], natural: [Pose], immediate: Bool) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        caringFor = care; matches = Self.ranked(self.query, names: names)
        origins = poses.count == natural.count ? poses : natural
        poses = origins; progress = 0
        if immediate { advance(dt: 1, natural: natural, immediate: true) }
    }
    mutating func advance(dt: Float, natural: [Pose], immediate: Bool = false) {
        guard dt.isFinite, dt >= 0 else { return }
        if poses.count != natural.count { poses = natural; origins = natural }
        progress = immediate ? 1 : min(1, progress + dt / 0.85)
        // A fresh transition starts from the currently visible poses, including
        // when a query changes or Back interrupts a departure.
        let t = progress * progress * (3 - 2 * progress)
        for i in natural.indices {
            let target = target(i, natural: natural[i])
            let start = origins.indices.contains(i) ? origins[i] : natural[i]
            poses[i].position = start.position + (target.position - start.position) * t
            poses[i].scale = start.scale + (target.scale - start.scale) * t
            let turn = atan2(sin(target.heading - start.heading), cos(target.heading - start.heading))
            poses[i].heading = start.heading + turn * t
            if progress == 1 { poses[i] = target }
            else if caringFor != i && simd_distance(start.position, target.position) > 0.3 {
                let delta = target.position - start.position
                poses[i].heading = atan2(delta.x, delta.z)
            }
        }
    }
    private func target(_ i: Int, natural: Pose) -> Pose {
        if let selected = caringFor {
            if selected == i { return .init(position: [0, 1.0, 2.7], heading: 0, scale: 0.93) }
            return .init(position: [i.isMultiple(of: 2) ? -18 : 18, 0.594, Float(i % 4) - 5], heading: i.isMultiple(of: 2) ? -.pi / 2 : .pi / 2)
        }
        guard !query.isEmpty else { return natural }
        if let rank = matches.firstIndex(of: i) {
            // Stagger the queue so faces remain visible behind the first match.
            return .init(position: [rank == 0 ? 0 : (rank.isMultiple(of: 2) ? -0.95 : 0.95), 0.72, 2.7 - Float(rank) * 1.45], heading: 0, scale: rank == 0 ? 0.69 : 0.55)
        }
        return .init(position: [i.isMultiple(of: 2) ? -sideDistance : sideDistance, 0.594, 2 - Float(i / 2) * 1.15], heading: i.isMultiple(of: 2) ? 0.35 : -0.35, scale: sideDistance < 3 ? 0.38 : 0.55)
    }
}
