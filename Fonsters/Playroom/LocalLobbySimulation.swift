import Foundation
import simd

/// A bounded local room. No network, accounts or appearance seeds.
struct LocalLobbySimulation {
    struct Agent {
        let name: String
        let home: SIMD2<Float>
        var position: SIMD2<Float>
        var goal: SIMD2<Float>
        var heading: Float = 0
        var reaction = "idle"
        var remaining: Float = 0
        var goalHold: Float = 0
        var wandering = true
        var feeling = CreatureFeeling.neutral
    }
    struct Event { let actor: Int; let peer: Int?; let action: String }
    private(set) var agents: [Agent]
    private(set) var socialEvents = 0
    private var elapsed: Float = 0
    private var nextSocial: Float = 6
    private var round = 0
    private var ballTime: Float?
    private(set) var pairGame: (actor: Int, peer: Int, time: Float)?
    var ballPosition: SIMD3<Float> = [0, 0.14, 0.65]

    init(names: [String]) {
        let homes: [SIMD2<Float>] = [[-1.42, 0.30], [-0.48, -0.30], [0.48, -0.30], [1.42, 0.30]]
        agents = Array(names.prefix(4).enumerated()).map { i, name in
            .init(name: name, home: homes[i], position: homes[i], goal: homes[i])
        }
    }
    mutating func act(_ action: String, actor: Int) -> [Event] {
        guard agents.indices.contains(actor) else { return [] }
        interruptGame()
        agents[actor].reaction = action; agents[actor].remaining = action == "rest" ? 1000 : 4
        agents[actor].goal = agents[actor].position
        nextSocial = elapsed + 7
        if action == "fetch" { ballTime = 0; agents[actor].goal = [0, 0.45] }
        return [.init(actor: actor, peer: nil, action: action)]
    }
    mutating func greet(actor: Int, peer: Int) -> [Event] {
        guard actor != peer && agents.indices.contains(actor) && agents.indices.contains(peer) else { return [] }
        interruptGame()
        let delta = agents[peer].position - agents[actor].position
        agents[actor].heading = atan2(delta.x, delta.y)
        agents[peer].heading = atan2(-delta.x, -delta.y)
        agents[actor].reaction = "greet"; agents[peer].reaction = "greet"
        agents[actor].remaining = 3; agents[peer].remaining = 3
        agents[actor].goal = agents[actor].position; agents[peer].goal = agents[peer].position
        nextSocial = elapsed + 7; socialEvents += 1
        return [.init(actor: actor, peer: peer, action: "greet"), .init(actor: peer, peer: actor, action: "greet")]
    }
    mutating func playTogether() -> [Event] {
        interruptGame()
        nextSocial = elapsed + 8
        return agents.indices.map { i in
            agents[i].reaction = "play"; agents[i].remaining = 4
            return .init(actor: i, peer: nil, action: "play")
        }
    }
    mutating func gather() {
        interruptGame()
        for i in agents.indices { agents[i].goal = agents[i].home * 0.82; agents[i].goalHold = 5 }
        nextSocial = elapsed + 5
    }
    mutating func freezeGoals() { for i in agents.indices { agents[i].goal = agents[i].position } }
    mutating func setWandering(_ enabled: Bool, actor: Int) {
        guard agents.indices.contains(actor) else { return }
        interruptGame()
        agents[actor].wandering = enabled; agents[actor].reaction = "idle"; agents[actor].remaining = 0
        agents[actor].goal = agents[actor].position
    }
    mutating func setFeeling(_ feeling: CreatureFeeling, actor: Int) {
        guard agents.indices.contains(actor) else { return }
        agents[actor].feeling = feeling
    }
    mutating func interruptGame() {
        if let game = pairGame {
            for i in [game.actor, game.peer] { agents[i].remaining = 0; agents[i].reaction = "idle"; agents[i].goalHold = 0 }
        }
        pairGame = nil; ballTime = nil; ballPosition = [0, 0.14, 0.65]
    }
    mutating func together(actor: Int, peer: Int, quiet: Bool) -> [Event] {
        guard actor != peer && agents.indices.contains(actor) && agents.indices.contains(peer) else { return [] }
        _ = greet(actor: actor, peer: peer)
        let action = quiet ? "rub" : "highFive"
        for i in [actor, peer] {
            agents[i].reaction = action; agents[i].remaining = quiet ? 5 : 8
            agents[i].goalHold = quiet ? 5 : 8
        }
        if !quiet { pairGame = (actor, peer, 0); updatePairBall() }
        nextSocial = elapsed + (quiet ? 7 : 10)
        return [.init(actor: actor, peer: peer, action: action), .init(actor: peer, peer: actor, action: action)]
    }
    private mutating func updatePairBall() {
        guard let game = pairGame else { return }
        let trip = Int(game.time / 1.1), fraction = (game.time / 1.1).truncatingRemainder(dividingBy: 1)
        let a = agents[trip % 2 == 0 ? game.actor : game.peer].position
        let b = agents[trip % 2 == 0 ? game.peer : game.actor].position
        let position = a + (b - a) * fraction
        ballPosition = [position.x, 0.50 + sin(fraction * .pi) * 0.65, position.y]
    }
    mutating func step(dt rawDT: Float, wander: Bool) -> [Event] {
        guard rawDT.isFinite && rawDT > 0 else { return [] }
        let dt = min(0.06, rawDT)
        elapsed += dt
        for i in agents.indices {
            if agents[i].reaction != "rest" { agents[i].remaining = max(0, agents[i].remaining - dt) }
            agents[i].goalHold = max(0, agents[i].goalHold - dt)
            if agents[i].remaining == 0 {
                agents[i].reaction = "idle"
                agents[i].heading *= max(0, 1 - dt * 2)
                if wander && agents[i].wandering && agents[i].goalHold == 0 {
                    agents[i].goal = agents[i].home + [sin(elapsed * 0.29 + Float(i) * 1.7) * 0.32,
                                                      cos(elapsed * 0.23 + Float(i) * 2) * 0.20]
                }
            }
            if agents[i].reaction != "rest" {
                let delta = agents[i].goal - agents[i].position, length = simd_length(delta)
                if length > 0.001 {
                    let candidate = agents[i].position + delta / length * min(length, dt * 0.20 * agents[i].feeling.energy)
                    let clear = agents.indices.filter { $0 != i }.allSatisfy { simd_distance(candidate, agents[$0].position) >= 0.88 }
                    if clear { agents[i].position = [min(1.5, max(-1.5, candidate.x)), min(0.88, max(-0.88, candidate.y))] }
                }
            }
        }
        var catches: [Event] = []
        if var game = pairGame {
            let previousTrip = Int(game.time / 1.1)
            game.time += dt; pairGame = game
            if game.time >= 8 { interruptGame() }
            else {
                updatePairBall()
                if Int(game.time / 1.1) != previousTrip {
                    let catcher = previousTrip % 2 == 0 ? game.peer : game.actor
                    catches = [.init(actor: catcher, peer: nil, action: "highFive")]
                }
            }
        } else if let time = ballTime {
            let t = time + dt; ballTime = t < 5 ? t : nil
            if t < 1.2 { ballPosition = [sin(t * 2) * 0.8, 0.14 + sin(t / 1.2 * .pi) * 0.85, 0.65 - t * 0.5] }
            else { ballPosition = [0.3 * cos(t), 0.14, 0.3] }
        } else { ballPosition = [0, 0.14, 0.65] }
        guard wander && elapsed >= nextSocial && agents.count > 1 else { return catches }
        round += 1; nextSocial = elapsed + 8
        let free = agents.indices.filter { agents[$0].reaction == "idle" }
        guard free.count >= 2 else { return catches }
        let actor = free[round % free.count]
        let peer = free.filter { $0 != actor }.min { simd_distance(agents[actor].position, agents[$0].position) < simd_distance(agents[actor].position, agents[$1].position) }!
        if agents[actor].feeling.prefersQuietCompany || agents[peer].feeling.prefersQuietCompany {
            return together(actor: actor, peer: peer, quiet: true)
        }
        if round % 3 == 0 {
            socialEvents += 1
            return [actor, peer].map { i in
                agents[i].reaction = "hop"; agents[i].remaining = 3
                return .init(actor: i, peer: i == actor ? peer : actor, action: "hop")
            }
        }
        return greet(actor: actor, peer: peer)
    }
}
