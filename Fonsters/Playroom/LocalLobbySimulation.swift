import Foundation
import simd

/// A walkable local world. No network, accounts or appearance seeds.
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
        var route: [SIMD2<Float>] = []
        var nextWalk: Float = 0
        var walking = false
        var blocked: Float = 0
        var seatRequested = false
        var seated = false
    }
    struct Event { let actor: Int; let peer: Int?; let action: String }
    let world: LobbyWorld
    private(set) var agents: [Agent]
    private(set) var socialEvents = 0
    private var elapsed: Float = 0
    private var nextSocial: Float = 6
    private var round = 0
    private var ballTime: Float?
    private(set) var pairGame: (actor: Int, peer: Int, time: Float)?
    var ballPosition: SIMD3<Float> = [0, 0.14, 0.65]

    init(names: [String], population: Int? = nil) {
        let layout = LobbyWorld(population: population ?? names.count)
        world = layout
        agents = Array(names.prefix(12).enumerated()).map { i, name in
            let home = layout.home(i)
            return .init(name: name, home: home, position: home, goal: home, nextWalk: Float(i) * 1.1 + 2)
        }
    }
    private mutating func setGoal(_ destination: SIMD2<Float>, actor: Int, hold: Float = 12) {
        agents[actor].seated = false; agents[actor].seatRequested = false
        var target = world.nearestWalkable(to: destination)
        if agents.indices.filter({ $0 != actor }).contains(where: { simd_distance(target, agents[$0].position) < 0.92 }) {
            search: for ring in 1...12 { for spoke in 0..<16 {
                let a = Float(spoke) / 16 * .pi * 2
                let p = target + SIMD2<Float>(sin(a), cos(a)) * Float(ring) * 0.25
                if world.walkable(p, clearance: 0.46) && agents.indices.filter({ $0 != actor }).allSatisfy({ simd_distance(p, agents[$0].position) >= 0.94 }) { target = p; break search }
            } }
        }
        agents[actor].goal = target
        agents[actor].route = world.route(from: agents[actor].position, to: agents[actor].goal, avoiding: agents.indices.filter { $0 != actor }.map { agents[$0].position })
        agents[actor].blocked = 0
        agents[actor].goalHold = hold
    }
    mutating func travel(to area: LobbyWorld.Area, actor: Int, peer: Int? = nil, instant: Bool = false) {
        guard world.areas.contains(area), agents.indices.contains(actor) else { return }
        interruptGame()
        let travelers = [actor] + (peer.flatMap { agents.indices.contains($0) && $0 != actor ? $0 : nil }.map { [$0] } ?? [])
        for (slot, i) in travelers.enumerated() {
            agents[i].reaction = "idle"; agents[i].remaining = 0
            setGoal(world.destination(in: area, slot: slot), actor: i, hold: 30)
            if instant { settleInstantly(actor: i) }
        }
        nextSocial = elapsed + 12
    }
    mutating func walk(to position: SIMD2<Float>, actor: Int, instant: Bool = false) {
        guard agents.indices.contains(actor) else { return }
        interruptGame(); agents[actor].reaction = "idle"; agents[actor].remaining = 0
        setGoal(position, actor: actor, hold: 30)
        if instant { settleInstantly(actor: actor) }
        nextSocial = elapsed + 10
    }
    private mutating func settleInstantly(actor: Int) {
        // Explicit navigation in Still/Reduce Motion uses a clear, static placement.
        let target = agents[actor].goal
        for ring in 0...12 { for spoke in 0..<16 {
            let a = Float(spoke) / 16 * .pi * 2
            let p = target + SIMD2<Float>(sin(a), cos(a)) * Float(ring) * 0.25
            if world.walkable(p, clearance: 0.46) && agents.indices.filter({ $0 != actor }).allSatisfy({ simd_distance(p, agents[$0].position) >= 0.90 }) {
                agents[actor].position = p; agents[actor].goal = p; agents[actor].route = []; agents[actor].walking = false; return
            }
        } }
    }
    mutating func sit(actor: Int, instant: Bool = false) {
        guard agents.indices.contains(actor), let bench = world.benches.min(by: { simd_distance($0, agents[actor].position) < simd_distance($1, agents[actor].position) }) else { return }
        interruptGame(); agents[actor].reaction = "idle"; agents[actor].remaining = 0
        let spots = [bench + SIMD2<Float>(-0.50, 0.78), bench + SIMD2<Float>(0.50, 0.78)]
        guard let spot = spots.first(where: { p in agents.indices.filter { $0 != actor }.allSatisfy { simd_distance(p, agents[$0].goal) >= 0.9 && simd_distance(p, agents[$0].position) >= 0.94 } }) else { return }
        setGoal(spot, actor: actor, hold: 1000); agents[actor].seatRequested = true
        if instant { settleInstantly(actor: actor); agents[actor].seated = true; agents[actor].reaction = "rest" }
        nextSocial = elapsed + 8
    }
    mutating func act(_ action: String, actor: Int) -> [Event] {
        guard agents.indices.contains(actor) else { return [] }
        interruptGame()
        agents[actor].reaction = action; agents[actor].remaining = action == "rest" ? 1000 : 4
        agents[actor].goal = agents[actor].position; agents[actor].route = []; agents[actor].seated = false; agents[actor].seatRequested = false
        nextSocial = elapsed + 7
        if action == "fetch" { ballTime = 0; setGoal([0, 1.1], actor: actor) }
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
        for i in [actor, peer] { agents[i].goal = agents[i].position; agents[i].route = []; agents[i].seatRequested = false; agents[i].seated = false }
        nextSocial = elapsed + 7; socialEvents += 1
        return [.init(actor: actor, peer: peer, action: "greet"), .init(actor: peer, peer: actor, action: "greet")]
    }
    mutating func playTogether() -> [Event] {
        interruptGame()
        nextSocial = elapsed + 8
        return agents.indices.map { i in
            agents[i].reaction = "play"; agents[i].remaining = 4; agents[i].seated = false; agents[i].seatRequested = false; agents[i].route = []; agents[i].goal = agents[i].position
            return .init(actor: i, peer: nil, action: "play")
        }
    }
    mutating func gather() {
        interruptGame()
        for i in agents.indices { agents[i].reaction = "idle"; agents[i].remaining = 0; setGoal(agents[i].home * 0.82, actor: i, hold: 10) }
        nextSocial = elapsed + 5
    }
    mutating func freezeGoals() { for i in agents.indices { agents[i].goal = agents[i].position; agents[i].route = []; agents[i].walking = false; agents[i].seatRequested = false } }
    mutating func setWandering(_ enabled: Bool, actor: Int) {
        guard agents.indices.contains(actor) else { return }
        interruptGame()
        agents[actor].wandering = enabled; agents[actor].reaction = "idle"; agents[actor].remaining = 0
        agents[actor].goal = agents[actor].position; agents[actor].route = []; agents[actor].walking = false; agents[actor].seatRequested = false; agents[actor].seated = false
    }
    mutating func stopAgentMotion(actor: Int) {
        guard agents.indices.contains(actor) else { return }
        interruptGame()
        agents[actor].goal = agents[actor].position; agents[actor].route = []; agents[actor].walking = false
        agents[actor].seatRequested = false; agents[actor].seated = false
        agents[actor].reaction = "idle"; agents[actor].remaining = 0; agents[actor].goalHold = 8
        agents[actor].nextWalk = elapsed + 8; nextSocial = elapsed + 8
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
    mutating func step(dt rawDT: Float, wander: Bool, heldActor: Int? = nil) -> [Event] {
        guard rawDT.isFinite && rawDT > 0 else { return [] }
        let dt = min(0.06, rawDT)
        elapsed += dt
        var arrivals: [Event] = []
        for i in agents.indices {
            agents[i].walking = false
            if i == heldActor { continue }
            if agents[i].reaction != "rest" { agents[i].remaining = max(0, agents[i].remaining - dt) }
            agents[i].goalHold = max(0, agents[i].goalHold - dt)
            if agents[i].remaining == 0 && !agents[i].seated {
                agents[i].reaction = "idle"
                if wander && agents[i].wandering && agents[i].goalHold == 0 && elapsed >= agents[i].nextWalk && agents[i].route.isEmpty {
                    let area = world.areas[(round + i + Int(elapsed / 9)) % world.areas.count]
                    let destination = world.destination(in: area, slot: i)
                    setGoal(destination, actor: i, hold: 0)
                    agents[i].nextWalk = elapsed + 12 + Float(i % 4) * 2
                }
            }
            guard agents[i].reaction != "rest", !agents[i].seated else { continue }
            if let waypoint = agents[i].route.first {
                let delta = waypoint - agents[i].position, distance = simd_length(delta)
                if distance < 0.001 { agents[i].position = waypoint; agents[i].route.removeFirst() }
                else {
                    let direction = delta / distance
                    let candidate = agents[i].position + direction * min(distance, dt * 0.65 * agents[i].feeling.energy)
                    let clear = agents.indices.filter { $0 != i }.allSatisfy { simd_distance(candidate, agents[$0].position) >= 0.90 }
                    if clear && world.segmentClear(agents[i].position, candidate) {
                        agents[i].position = candidate; agents[i].walking = true; agents[i].blocked = 0
                        let desired = atan2(direction.x, direction.y)
                        let difference = atan2(sin(desired - agents[i].heading), cos(desired - agents[i].heading))
                        agents[i].heading += difference * min(1, dt * 7)
                    } else {
                        agents[i].blocked += dt
                        // A small local side step lets approaching companions pass.
                        let side = SIMD2<Float>(direction.y, -direction.x) * (i % 2 == 0 ? 1 : -1)
                        let aside = agents[i].position + side * dt * 0.4
                        if world.segmentClear(agents[i].position, aside) && agents.indices.filter({ $0 != i }).allSatisfy({ simd_distance(aside, agents[$0].position) >= 0.90 }) {
                            agents[i].position = aside; agents[i].walking = true
                        }
                        if agents[i].blocked > 0.8 {
                            agents[i].route = world.route(from: agents[i].position, to: agents[i].goal, avoiding: agents.indices.filter { $0 != i }.map { agents[$0].position })
                            agents[i].blocked = 0
                        }
                    }
                }
            } else if simd_distance(agents[i].position, agents[i].goal) > 0.08 {
                agents[i].blocked += dt
                if agents[i].blocked > 1 {
                    let oldGoal = agents[i].goal, seat = agents[i].seatRequested, hold = agents[i].goalHold
                    if seat {
                        agents[i].route = world.route(from: agents[i].position, to: oldGoal, avoiding: agents.indices.filter { $0 != i }.map { agents[$0].position })
                        agents[i].blocked = 0
                    } else { setGoal(oldGoal, actor: i, hold: hold) }
                }
            } else if agents[i].seatRequested {
                agents[i].seated = true; agents[i].seatRequested = false; agents[i].reaction = "rest"; agents[i].remaining = 1000; agents[i].heading = 0
                arrivals.append(.init(actor: i, peer: nil, action: "rest"))
            } else if agents[i].reaction == "idle" {
                agents[i].heading *= max(0, 1 - dt * 0.6)
            }
        }
        var catches: [Event] = arrivals
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
        let free = agents.indices.filter { $0 != heldActor && agents[$0].reaction == "idle" && agents[$0].goalHold == 0 && !agents[$0].seatRequested }
        guard free.count >= 2 else { return catches }
        let actor = free[round % free.count]
        let peer = free.filter { $0 != actor }.min { simd_distance(agents[actor].position, agents[$0].position) < simd_distance(agents[actor].position, agents[$1].position) }!
        guard simd_distance(agents[actor].position, agents[peer].position) < 2.6 else { return catches }
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
