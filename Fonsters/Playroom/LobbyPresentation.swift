import Foundation
import simd

/// Presentation is separate from simulation and appearance identity. Search and
/// care borrow the stage without consuming other creatures' routes or memories.
struct LobbyPresentation {
    struct Pose: Equatable {
        var position: SIMD3<Float>
        var heading: Float
        var scale: Float = 0.55
        var walking = false
    }
    private(set) var query = ""
    private(set) var caringFor: Int?
    private(set) var matches: [Int] = []
    private(set) var poses: [Pose] = []
    private var origins: [Pose] = []
    private var progress: Float = 1
    private var transitionTime: Float = 0
    private var durations: [Float] = []
    private var delays: [Float] = []
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
        poses = origins; progress = 0; transitionTime = 0
        durations = natural.indices.map { i in
            guard care != nil || origins[i].position.x.magnitude > sideDistance else { return 0.95 }
            if care == i { return 1.3 }
            let distance = simd_distance(origins[i].position, target(i, natural: natural[i]).position)
            return min(7.5, max(1.3, distance / 1.1))
        }
        delays = natural.indices.map { care != nil && care != $0 ? Float($0 % 5) * 0.07 : 0 }
        if immediate { advance(dt: 1, natural: natural, immediate: true) }
    }
    mutating func advance(dt: Float, natural: [Pose], immediate: Bool = false) {
        guard dt.isFinite, dt >= 0 else { return }
        if poses.count != natural.count { poses = natural; origins = natural }
        if durations.count != natural.count { durations = natural.map { _ in 0.95 }; delays = natural.map { _ in 0 } }
        transitionTime += dt
        let end = zip(durations, delays).map(+).max() ?? 0.95
        progress = immediate ? 1 : min(1, transitionTime / max(0.01, end))
        // A fresh transition starts from the currently visible poses, including
        // when a query changes or Back interrupts a departure.
        for i in natural.indices {
            let fraction = immediate ? Float(1) : min(1, max(0, (transitionTime - delays[i]) / max(0.01, durations[i])))
            let t = fraction * fraction * fraction * (fraction * (fraction * 6 - 15) + 10)
            let target = target(i, natural: natural[i])
            let start = origins.indices.contains(i) ? origins[i] : natural[i]
            let before = poses[i].position
            poses[i].position = start.position + (target.position - start.position) * t
            poses[i].scale = start.scale + (target.scale - start.scale) * t
            let turn = atan2(sin(target.heading - start.heading), cos(target.heading - start.heading))
            poses[i].heading = start.heading + turn * t
            poses[i].walking = caringFor != i && simd_distance(before, poses[i].position) > 0.0001
            if fraction == 1 { poses[i] = target }
            else if caringFor != i && simd_distance(start.position, target.position) > 0.3 {
                let delta = target.position - start.position
                poses[i].heading = atan2(delta.x, delta.z)
            }
        }
    }
    private func target(_ i: Int, natural: Pose) -> Pose {
        if let selected = caringFor {
            if selected == i { return .init(position: [0, 1.0, 2.7], heading: 0, scale: 0.93) }
            let edge = max(4, sideDistance + 1.3)
            return .init(position: [i.isMultiple(of: 2) ? -edge : edge, 0.594, Float(i % 4) - 3], heading: i.isMultiple(of: 2) ? -.pi / 2 : .pi / 2)
        }
        guard !query.isEmpty else { return natural }
        if let rank = matches.firstIndex(of: i) {
            // Stagger the queue so faces remain visible behind the first match.
            return .init(position: [rank == 0 ? 0 : (rank.isMultiple(of: 2) ? -0.95 : 0.95), 0.72, 2.7 - Float(rank) * 1.45], heading: 0, scale: rank == 0 ? 0.69 : 0.55)
        }
        return .init(position: [i.isMultiple(of: 2) ? -sideDistance : sideDistance, 0.594, 2 - Float(i / 2) * 1.15], heading: i.isMultiple(of: 2) ? 0.35 : -0.35, scale: sideDistance < 3 ? 0.38 : 0.55)
    }
}

/// Held keys change a target velocity; OS key-repeat never moves the camera.
/// Numeric state is independently testable and runs while the world is paused.
struct LobbyCameraMotion {
    struct Step { var translation: SIMD3<Float>; var turn: SIMD2<Float>; var zoom: Float }
    private(set) var keys: Set<String> = []
    var fast = false
    private(set) var translation = SIMD3<Float>.zero
    private(set) var turn = SIMD2<Float>.zero
    private(set) var zoom: Float = 0
    static let supported: Set<String> = ["w", "a", "s", "d", "q", "e", "left", "right", "up", "down", "[", "]", "+", "=", "-"]
    var active: Bool { !keys.isEmpty || simd_length(translation) + simd_length(turn) + abs(zoom) > 0.002 }
    mutating func press(_ key: String, down: Bool, fast: Bool) {
        self.fast = fast
        if down { keys.insert(key) } else { keys.remove(key) }
    }
    mutating func reset() { keys.removeAll(); translation = .zero; turn = .zero; zoom = 0; fast = false }
    mutating func advance(dt: Float) -> Step {
        guard dt.isFinite, dt > 0, dt <= 0.1 else { return .init(translation: .zero, turn: .zero, zoom: 0) }
        func on(_ key: String) -> Float { keys.contains(key) ? 1 : 0 }
        var direction = SIMD3<Float>(on("d") - on("a"), on("e") - on("q"), on("s") - on("w"))
        if simd_length(direction) > 1 { direction = simd_normalize(direction) }
        var rotation = SIMD2<Float>(on("right") + on("]") - on("left") - on("["), on("up") - on("down"))
        if simd_length(rotation) > 1 { rotation = simd_normalize(rotation) }
        let boost: Float = fast ? 3 : 1
        let blend = 1 - exp(-dt * (keys.isEmpty ? 18 : 10))
        translation += (direction * 2.4 * boost - translation) * blend
        turn += (rotation * 0.85 * boost - turn) * blend
        zoom += ((on("-") - max(on("+"), on("="))) * 0.7 * boost - zoom) * blend
        if keys.isEmpty && !active { reset() }
        return .init(translation: translation * dt, turn: turn * dt, zoom: zoom * dt)
    }
}
