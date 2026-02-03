//
//  CreatureEnvironmentView.swift
//  Fonsters
//
//  Environment behind the creature is algorithmically generated from the
//  Fonster seed: which layers appear is determined by segmentRoll(seed, "env_*", p).
//  Keywords in the seed also control layers: "cloud" → 1 cloud, "clouds" → multiple,
//  "3 birds" → 3 birds (up to 20). Same seed = same environment.
//
//  Supported platforms: iOS, tvOS, visionOS, macOS (SwiftUI + Foundation only).
//  Not used on watchOS (separate app target).
//

import SwiftUI
import Foundation

// MARK: - Keyword/count hints from seed (e.g. "clouds", "5 birds")

private struct EnvKeywordHints {
    static let maxCount = 20

    let sun: Bool
    let moon: Bool
    let clouds: Bool
    let cloudCount: Int?
    let birds: Bool
    let birdCount: Int?
    let butterflies: Bool
    let butterflyCount: Int?
    let flowers: Bool
    let flowerCount: Int?
    let clovers: Bool
    let cloverCount: Int?
    let fireworks: Bool
    let fireworkCount: Int?
    let leaves: Bool
    let leafCount: Int?
    let snow: Bool
    let snowCount: Int?
    let christmasLights: Bool
    let christmasLightsCount: Int?

    static func parse(seed: String) -> EnvKeywordHints {
        let s = seed.trimmingCharacters(in: .whitespaces)
        let lower = s.lowercased()

        func numberBefore(word: String, plural: String) -> Int? {
            // e.g. "3 clouds" or "10 birds" -> 3, 10 (capped at maxCount)
            let pattern = "(\\d+)\\s*" + word
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                  let range = Range(match.range(at: 1), in: lower),
                  let n = Int(lower[range]) else { return nil }
            return min(max(1, n), maxCount)
        }

        func singularPlural(singular: String, plural: String, multipleCount: Int) -> (Bool, Int?) {
            if let n = numberBefore(word: "(?:" + singular + "|" + plural + ")", plural: plural) {
                return (true, n)
            }
            if lower.contains(plural) { return (true, multipleCount) }
            if lower.contains(singular) { return (true, 1) }
            return (false, nil)
        }

        let (cloudsOn, cloudCount) = singularPlural(singular: "cloud", plural: "clouds", multipleCount: 6)
        let (birdsOn, birdCount) = singularPlural(singular: "bird", plural: "birds", multipleCount: 6)
        let (butterfliesOn, butterflyCount) = singularPlural(singular: "butterfly", plural: "butterflies", multipleCount: 6)
        let (flowersOn, flowerCount) = singularPlural(singular: "flower", plural: "flowers", multipleCount: 6)
        let (cloversOn, cloverCount) = singularPlural(singular: "clover", plural: "clovers", multipleCount: 5)
        let (fireworksOn, fireworkCount) = singularPlural(singular: "firework", plural: "fireworks", multipleCount: 5)
        let (leavesOn, leafCount) = singularPlural(singular: "leaf", plural: "leaves", multipleCount: 8)

        var snowCount: Int? = nil
        if let n = numberBefore(word: "snow", plural: "snow") { snowCount = n }
        let snowOn = lower.contains("snow") || snowCount != nil

        var christmasLightsCount: Int? = nil
        if let n = numberBefore(word: "(?:light|lights)", plural: "lights") { christmasLightsCount = n }
        let lightsOn = lower.contains("christmas") || lower.contains("lights") || christmasLightsCount != nil

        return EnvKeywordHints(
            sun: lower.contains("sun"),
            moon: lower.contains("moon"),
            clouds: cloudsOn,
            cloudCount: cloudCount,
            birds: birdsOn,
            birdCount: birdCount,
            butterflies: butterfliesOn,
            butterflyCount: butterflyCount,
            flowers: flowersOn,
            flowerCount: flowerCount,
            clovers: cloversOn,
            cloverCount: cloverCount,
            fireworks: fireworksOn,
            fireworkCount: fireworkCount,
            leaves: leavesOn,
            leafCount: leafCount,
            snow: snowOn,
            snowCount: snowCount,
            christmasLights: lightsOn,
            christmasLightsCount: christmasLightsCount
        )
    }
}

// MARK: - Seed-derived environment config (deterministic + keyword overrides)

private struct EnvironmentConfig {
    let sun: Bool
    let moon: Bool
    let clouds: Bool
    let cloudCount: Int?
    let birds: Bool
    let birdCount: Int?
    let butterflies: Bool
    let butterflyCount: Int?
    let flowers: Bool
    let flowerCount: Int?
    let clovers: Bool
    let cloverCount: Int?
    let fireworks: Bool
    let fireworkCount: Int?
    let leaves: Bool
    let leafCount: Int?
    let snow: Bool
    let snowCount: Int?
    let christmasLights: Bool
    let christmasLightsCount: Int?

    init(seed: String) {
        let s = seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
        let hints = EnvKeywordHints.parse(seed: s)

        sun = segmentRoll(seed: s, segmentId: "env_sun", p: 0.25) || hints.sun
        moon = segmentRoll(seed: s, segmentId: "env_moon", p: 0.2) || hints.moon
        clouds = segmentRoll(seed: s, segmentId: "env_clouds", p: 0.4) || hints.clouds
        cloudCount = hints.cloudCount
        birds = segmentRoll(seed: s, segmentId: "env_birds", p: 0.2) || hints.birds
        birdCount = hints.birdCount
        butterflies = segmentRoll(seed: s, segmentId: "env_butterflies", p: 0.2) || hints.butterflies
        butterflyCount = hints.butterflyCount
        flowers = segmentRoll(seed: s, segmentId: "env_flowers", p: 0.2) || hints.flowers
        flowerCount = hints.flowerCount
        clovers = segmentRoll(seed: s, segmentId: "env_clovers", p: 0.15) || hints.clovers
        cloverCount = hints.cloverCount
        fireworks = segmentRoll(seed: s, segmentId: "env_fireworks", p: 0.15) || hints.fireworks
        fireworkCount = hints.fireworkCount
        leaves = segmentRoll(seed: s, segmentId: "env_leaves", p: 0.2) || hints.leaves
        leafCount = hints.leafCount
        snow = segmentRoll(seed: s, segmentId: "env_snow", p: 0.2) || hints.snow
        snowCount = hints.snowCount
        christmasLights = segmentRoll(seed: s, segmentId: "env_lights", p: 0.15) || hints.christmasLights
        christmasLightsCount = hints.christmasLightsCount
    }
}

// MARK: - Deterministic RNG for shapes (from seed)

private struct LinearCongruentialGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: Int) { self.state = UInt64(seed) }
    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}

private func seedToInt(_ seed: String, _ segmentId: String) -> Int {
    let h = segmentHash(seed: seed, segmentId: segmentId)
    return Int(h * 1_000_000)
}

// MARK: - Cloud shape (deterministic from seed int)

private struct EnvironmentCloudShape: Shape {
    var seed: Int = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 3

        var rng = LinearCongruentialGenerator(seed: seed)
        let randomOffset = { (range: ClosedRange<CGFloat>, generator: inout LinearCongruentialGenerator) -> CGFloat in
            CGFloat.random(in: range, using: &generator)
        }

        path.addEllipse(in: CGRect(x: center.x - radius * 1.0, y: center.y - radius * 0.4, width: radius * 0.7, height: radius * 0.7))
        path.addEllipse(in: CGRect(x: center.x - radius * 0.5, y: center.y - radius * 0.6, width: radius * 0.9, height: radius * 0.9))
        path.addEllipse(in: CGRect(x: center.x, y: center.y - radius * 0.5, width: radius * 1.0, height: radius * 1.0))
        path.addEllipse(in: CGRect(x: center.x + radius * 0.5, y: center.y - radius * 0.4, width: radius * 0.8, height: radius * 0.8))
        path.addEllipse(in: CGRect(x: center.x + radius * 0.3, y: center.y + radius * 0.1, width: radius * 0.6, height: radius * 0.6))

        for _ in 0..<3 {
            let rx = randomOffset(-0.8...0.8, &rng) * radius
            let ry = randomOffset(-0.5...0.5, &rng) * radius
            let rSize = randomOffset(0.6...0.9, &rng) * radius
            path.addEllipse(in: CGRect(x: center.x + rx, y: center.y + ry, width: rSize, height: rSize))
        }

        return path
    }
}

// MARK: - Leaf shape (simple oval)

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let w = rect.width * 0.6
        let h = rect.height * 0.3
        path.addEllipse(in: CGRect(x: center.x - w/2, y: center.y - h/2, width: w, height: h))
        return path
    }
}

// MARK: - Simple flower (circle petals)

private struct SimpleFlowerShape: Shape {
    var petalCount: Int = 5
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 3
        for i in 0..<petalCount {
            let angle = Double(i) * 2 * .pi / Double(petalCount)
            let cx = center.x + CGFloat(cos(angle)) * r * 0.5
            let cy = center.y + CGFloat(sin(angle)) * r * 0.5
            path.addEllipse(in: CGRect(x: cx - r*0.4, y: cy - r*0.4, width: r*0.8, height: r*0.8))
        }
        path.addEllipse(in: CGRect(x: center.x - r*0.25, y: center.y - r*0.25, width: r*0.5, height: r*0.5))
        return path
    }
}

// MARK: - Shamrock (three circles)

private struct ShamrockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 3
        for i in 0..<3 {
            let angle = Double(i) * 2 * .pi / 3 - .pi / 2
            let cx = center.x + CGFloat(cos(angle)) * r * 0.4
            let cy = center.y + CGFloat(sin(angle)) * r * 0.4
            path.addEllipse(in: CGRect(x: cx - r*0.45, y: cy - r*0.45, width: r*0.9, height: r*0.9))
        }
        return path
    }
}

// MARK: - CreatureEnvironmentView (seed-driven)

struct CreatureEnvironmentView: View {
    let seed: String

    private var config: EnvironmentConfig { EnvironmentConfig(seed: effectiveSeed) }
    private var effectiveSeed: String {
        seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                // Base sky gradient (always; tint from seed)
                skyGradient(seed: effectiveSeed)

                if config.sun { SunLayer(seed: effectiveSeed, size: size) }
                if config.moon { MoonLayer(seed: effectiveSeed, size: size) }
                if config.clouds { CloudsLayer(seed: effectiveSeed, size: size, count: config.cloudCount) }
                if config.snow { SnowLayer(seed: effectiveSeed, size: size, count: config.snowCount) }
                if config.leaves { LeavesLayer(seed: effectiveSeed, size: size, count: config.leafCount) }
                if config.flowers { FlowersLayer(seed: effectiveSeed, size: size, count: config.flowerCount) }
                if config.clovers { CloversLayer(seed: effectiveSeed, size: size, count: config.cloverCount) }
                if config.butterflies { ButterfliesLayer(seed: effectiveSeed, size: size, count: config.butterflyCount) }
                if config.birds { BirdsLayer(seed: effectiveSeed, size: size, count: config.birdCount) }
                if config.fireworks { FireworksLayer(seed: effectiveSeed, size: size, count: config.fireworkCount) }
                if config.christmasLights { ChristmasLightsLayer(seed: effectiveSeed, size: size, count: config.christmasLightsCount) }

                // Subtle generic particles (low opacity, only if few other layers)
                ParticlesLayer(seed: effectiveSeed, size: size)
            }
        }
    }

    private func skyGradient(seed: String) -> some View {
        let h = segmentHash(seed: seed, segmentId: "env_sky")
        let top = Color(white: 0.5 + h * 0.12)
        let mid = Color(white: 0.4 + (1 - h) * 0.1)
        let bottom = Color(white: 0.32 + h * 0.08)
        return LinearGradient(colors: [top, mid, bottom], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Sun (single SF symbol or circle, slow movement)

private struct SunLayer: View {
    let seed: String
    let size: CGSize
    @State private var progress: CGFloat = 0

    var body: some View {
        let x = size.width * (0.2 + progress * 0.6)
        let y = size.height * (0.15 + 0.05 * sin(progress * .pi * 2))
        Image(systemName: "sun.max.fill")
            .font(.system(size: min(size.width, size.height) * 0.15))
            .foregroundStyle(.yellow.opacity(0.6))
            .position(x: x, y: y)
            .onAppear {
                let duration = 80.0 + Double(seedToInt(seed, "env_sun_dur") % 40)
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    progress = 1
                }
            }
    }
}

// MARK: - Moon (circle with gradient, slow movement)

private struct MoonLayer: View {
    let seed: String
    let size: CGSize
    @State private var progress: CGFloat = 0

    var body: some View {
        let x = size.width * (0.15 + progress * 0.7)
        let y = size.height * 0.12
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(white: 0.9), Color(white: 0.7)],
                    center: .center,
                    startRadius: 0,
                    endRadius: min(size.width, size.height) * 0.08
                )
            )
            .frame(width: min(size.width, size.height) * 0.12, height: min(size.width, size.height) * 0.12)
            .position(x: x, y: y)
            .onAppear {
                let duration = 100.0 + Double(seedToInt(seed, "env_moon_dur") % 50)
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    progress = 1
                }
            }
    }
}

// MARK: - Clouds (drifting, count/size from seed or keyword)

private struct CloudsLayer: View {
    let seed: String
    let size: CGSize
    let count: Int?
    @State private var clouds: [Cloud] = []
    @State private var timer: Timer?

    private struct Cloud: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var seed: Int
    }

    private var targetCount: Int {
        if let c = count { return min(c, EnvKeywordHints.maxCount) }
        return 2 + segmentPick(seed: seed, segmentId: "env_cloud_n", n: 3)
    }

    private var maxCount: Int { min(targetCount + 2, EnvKeywordHints.maxCount) }

    var body: some View {
        ZStack {
            ForEach(clouds) { cloud in
                EnvironmentCloudShape(seed: cloud.seed)
                    .fill(Color.white.opacity(0.55))
                    .blur(radius: 5)
                    .frame(width: cloud.size, height: cloud.size * 0.6)
                    .position(x: cloud.x, y: cloud.y)
            }
        }
        .onAppear { startClouds() }
        .onChange(of: size) { _, _ in startClouds() }
        .onDisappear { timer?.invalidate() }
    }

    private func startClouds() {
        timer?.invalidate()
        clouds = []
        let n = targetCount
        for i in 0..<n {
            addCloud(i: i)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 12, repeats: true) { _ in
            if clouds.count < maxCount { addCloud(i: clouds.count) }
        }
    }

    private func addCloud(i: Int) {
        let startX: CGFloat = segmentHash(seed: seed, segmentId: "env_cloud_x\(i)") < 0.5 ? -100 : size.width + 100
        let y = size.height * (0.1 + segmentHash(seed: seed, segmentId: "env_cloud_y\(i)") * 0.3)
        let cloudSize = 60 + CGFloat(segmentPick(seed: seed, segmentId: "env_cloud_sz\(i)", n: 80))
        let cloudSeed = seedToInt(seed, "env_cloud_seed\(i)")
        let cloud = Cloud(x: startX, y: y, size: cloudSize, seed: cloudSeed)
        clouds.append(cloud)
        let idx = clouds.count - 1
        let targetX: CGFloat = startX < size.width/2 ? size.width + 100 : -100
        let dur = 40.0 + Double(segmentPick(seed: seed, segmentId: "env_cloud_dur\(i)", n: 35))
        withAnimation(.linear(duration: dur).repeatForever(autoreverses: false)) {
            clouds[idx].x = targetX
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            clouds.removeAll { $0.id == cloud.id }
        }
    }
}

// MARK: - Snow (falling particles, count from seed or keyword)

private struct SnowLayer: View {
    let seed: String
    let size: CGSize
    let count: Int?
    @State private var flakes: [Flake] = []
    @State private var timer: Timer?

    private struct Flake: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
    }

    private var initialCount: Int {
        if let c = count { return min(c * 3, 60) }
        return 30
    }
    private var maxFlakes: Int {
        if let c = count { return min(c * 6, 120) }
        return 60
    }

    var body: some View {
        ZStack {
            ForEach(flakes) { f in
                Circle()
                    .fill(Color.white.opacity(f.opacity * 0.7))
                    .frame(width: f.size, height: f.size)
                    .position(x: f.x, y: f.y)
            }
        }
        .onAppear { startSnow() }
        .onChange(of: size) { _, _ in startSnow() }
        .onDisappear { timer?.invalidate() }
    }

    private func startSnow() {
        timer?.invalidate()
        flakes = []
        for _ in 0..<initialCount { addFlake() }
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            if flakes.count < maxFlakes { addFlake() }
        }
    }

    private func addFlake() {
        let i = flakes.count
        let x = CGFloat(segmentHash(seed: seed, segmentId: "env_snow_x\(i)")) * (size.width + 40) - 20
        let startY: CGFloat = -10
        let sz = 2 + CGFloat(segmentPick(seed: seed, segmentId: "env_snow_sz\(i)", n: 4))
        let op = 0.3 + segmentHash(seed: seed, segmentId: "env_snow_op\(i)") * 0.5
        let f = Flake(x: x, y: startY, size: sz, opacity: op)
        flakes.append(f)
        let idx = flakes.count - 1
        let dur = 10.0 + Double(segmentPick(seed: seed, segmentId: "env_snow_dur\(i)", n: 12))
        withAnimation(.linear(duration: dur)) {
            flakes[idx].y = size.height + 20
            flakes[idx].x += CGFloat((segmentHash(seed: seed, segmentId: "env_snow_dx\(i)") - 0.5) * 40)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            flakes.removeAll { $0.id == f.id }
        }
    }
}

// MARK: - Leaves (falling, drifting)

private struct LeavesLayer: View {
    let seed: String
    let size: CGSize
    let count: Int?
    @State private var items: [Leaf] = []
    @State private var timer: Timer?

    private struct Leaf: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var color: Color
        var size: CGFloat
    }

    private static let leafColors: [Color] = [.orange, .red, .yellow, .brown]

    private var targetCount: Int {
        if let c = count { return min(c, EnvKeywordHints.maxCount) }
        return 8
    }
    private var maxCount: Int { min(targetCount + 10, 25) }

    var body: some View {
        ZStack {
            ForEach(items) { leaf in
                LeafShape()
                    .fill(leaf.color.opacity(0.65))
                    .frame(width: leaf.size, height: leaf.size * 0.6)
                    .rotationEffect(.degrees(leaf.rotation))
                    .position(x: leaf.x, y: leaf.y)
            }
        }
        .onAppear { startLeaves() }
        .onChange(of: size) { _, _ in startLeaves() }
        .onDisappear { timer?.invalidate() }
    }

    private func startLeaves() {
        timer?.invalidate()
        items = []
        for _ in 0..<targetCount { addLeaf() }
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            if items.count < maxCount { addLeaf() }
        }
    }

    private func addLeaf() {
        let i = items.count
        let x = CGFloat(segmentHash(seed: seed, segmentId: "env_leaf_x\(i)")) * (size.width + 30) - 15
        let startY: CGFloat = -15
        let color = Self.leafColors[segmentPick(seed: seed, segmentId: "env_leaf_c\(i)", n: Self.leafColors.count)]
        let sz = 10 + CGFloat(segmentPick(seed: seed, segmentId: "env_leaf_sz\(i)", n: 12))
        let rot = Double(segmentPick(seed: seed, segmentId: "env_leaf_r\(i)", n: 360))
        let leaf = Leaf(x: x, y: startY, rotation: rot, color: color, size: sz)
        items.append(leaf)
        let idx = items.count - 1
        let dur = 8.0 + Double(segmentPick(seed: seed, segmentId: "env_leaf_dur\(i)", n: 6))
        withAnimation(.linear(duration: dur)) {
            items[idx].y = size.height + 20
            items[idx].x += CGFloat((segmentHash(seed: seed, segmentId: "env_leaf_dx\(i)") - 0.5) * 60)
            items[idx].rotation += Double(segmentPick(seed: seed, segmentId: "env_leaf_rot\(i)", n: 360))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            items.removeAll { $0.id == leaf.id }
        }
    }
}

// MARK: - Flowers (simple growing dots at bottom)

private struct FlowersLayer: View {
    let seed: String
    let size: CGSize
    let count: Int?
    @State private var flowers: [Flower] = []
    @State private var timer: Timer?

    private struct Flower: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var color: Color
        var scale: CGFloat
    }

    private static let colors: [Color] = [.pink, .purple, .yellow, .red, .orange]

    private var targetCount: Int {
        if let c = count { return min(c, EnvKeywordHints.maxCount) }
        return 5
    }
    private var maxCount: Int { min(targetCount + 5, 20) }

    var body: some View {
        ZStack {
            ForEach(flowers) { f in
                SimpleFlowerShape(petalCount: 5)
                    .fill(f.color.opacity(0.8))
                    .frame(width: 20, height: 20)
                    .scaleEffect(f.scale)
                    .position(x: f.x, y: f.y)
            }
        }
        .onAppear { startFlowers() }
        .onChange(of: size) { _, _ in startFlowers() }
        .onDisappear { timer?.invalidate() }
    }

    private func startFlowers() {
        timer?.invalidate()
        flowers = []
        for _ in 0..<targetCount { addFlower() }
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            if flowers.count < maxCount { addFlower() }
        }
    }

    private func addFlower() {
        let i = flowers.count
        let x = size.width * (0.1 + segmentHash(seed: seed, segmentId: "env_flower_x\(i)") * 0.8)
        let y = size.height - 15 - CGFloat(segmentPick(seed: seed, segmentId: "env_flower_y\(i)", n: 30))
        let color = Self.colors[segmentPick(seed: seed, segmentId: "env_flower_c\(i)", n: Self.colors.count)]
        let scale = 0.8 + segmentHash(seed: seed, segmentId: "env_flower_s\(i)") * 0.6
        let f = Flower(x: x, y: y, color: color, scale: scale)
        flowers.append(f)
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            flowers.removeAll { $0.id == f.id }
        }
    }
}

// MARK: - Clovers (small shamrocks at bottom)

private struct CloversLayer: View {
    let seed: String
    let size: CGSize
    let count: Int?
    @State private var items: [Clover] = []
    @State private var timer: Timer?

    private struct Clover: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
    }

    private var targetCount: Int {
        if let c = count { return min(c, EnvKeywordHints.maxCount) }
        return 3
    }
    private var maxCount: Int { min(targetCount + 3, 15) }

    var body: some View {
        ZStack {
            ForEach(items) { c in
                ShamrockShape()
                    .fill(Color.green.opacity(0.75))
                    .frame(width: 24, height: 24)
                    .scaleEffect(c.scale)
                    .position(x: c.x, y: c.y)
            }
        }
        .onAppear { startClovers() }
        .onChange(of: size) { _, _ in startClovers() }
        .onDisappear { timer?.invalidate() }
    }

    private func startClovers() {
        timer?.invalidate()
        items = []
        for _ in 0..<targetCount { addClover() }
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { _ in
            if items.count < maxCount { addClover() }
        }
    }

    private func addClover() {
        let i = items.count
        let x = size.width * (0.15 + segmentHash(seed: seed, segmentId: "env_clover_x\(i)") * 0.7)
        let y = size.height - 20 - CGFloat(segmentPick(seed: seed, segmentId: "env_clover_y\(i)", n: 25))
        let scale = 0.7 + segmentHash(seed: seed, segmentId: "env_clover_s\(i)") * 0.6
        let c = Clover(x: x, y: y, scale: scale)
        items.append(c)
        DispatchQueue.main.asyncAfter(deadline: .now() + 18) {
            items.removeAll { $0.id == c.id }
        }
    }
}

// MARK: - Butterflies (crossing, simple shape)

private struct ButterfliesLayer: View {
    let seed: String
    let size: CGSize
    let count: Int?
    @State private var items: [Butterfly] = []
    @State private var timer: Timer?

    private struct Butterfly: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var color: Color
    }

    private static let colors: [Color] = [.orange, .yellow, .pink, .purple]

    private var targetCount: Int {
        if let c = count { return min(c, EnvKeywordHints.maxCount) }
        return 2
    }
    private var maxCount: Int { min(targetCount + 2, EnvKeywordHints.maxCount) }

    var body: some View {
        ZStack {
            ForEach(items) { b in
                Image(systemName: "leaf.fill")
                    .font(.system(size: b.size))
                    .foregroundStyle(b.color.opacity(0.9))
                    .rotationEffect(.degrees(-45))
                    .position(x: b.x, y: b.y)
            }
        }
        .onAppear { start() }
        .onChange(of: size) { _, _ in start() }
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        timer?.invalidate()
        items = []
        for _ in 0..<targetCount { add() }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            if items.count < maxCount { add() }
        }
    }

    private func add() {
        let i = items.count
        let startX: CGFloat = segmentHash(seed: seed, segmentId: "env_bf_x\(i)") < 0.5 ? -30 : size.width + 30
        let y = size.height * (0.25 + segmentHash(seed: seed, segmentId: "env_bf_y\(i)") * 0.5)
        let targetX: CGFloat = startX < size.width/2 ? size.width + 30 : -30
        let sz = 12 + CGFloat(segmentPick(seed: seed, segmentId: "env_bf_sz\(i)", n: 16))
        let color = Self.colors[segmentPick(seed: seed, segmentId: "env_bf_c\(i)", n: Self.colors.count)]
        let b = Butterfly(x: startX, y: y, size: sz, color: color)
        items.append(b)
        let idx = items.count - 1
        let dur = 25.0 + Double(segmentPick(seed: seed, segmentId: "env_bf_dur\(i)", n: 20))
        withAnimation(.linear(duration: dur)) {
            items[idx].x = targetX
            items[idx].y = size.height * (0.3 + segmentHash(seed: seed, segmentId: "env_bf_ty\(i)") * 0.4)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            items.removeAll { $0.id == b.id }
        }
    }
}

// MARK: - Birds (simple V or line crossing)

private struct BirdsLayer: View {
    let seed: String
    let size: CGSize
    let count: Int?
    @State private var items: [Bird] = []
    @State private var timer: Timer?

    private struct Bird: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
    }

    private var targetCount: Int {
        if let c = count { return min(c, EnvKeywordHints.maxCount) }
        return 2
    }
    private var maxCount: Int { min(targetCount + 2, EnvKeywordHints.maxCount) }

    var body: some View {
        ZStack {
            ForEach(items) { b in
                Image(systemName: "bird.fill")
                    .font(.system(size: b.size))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .position(x: b.x, y: b.y)
            }
        }
        .onAppear { start() }
        .onChange(of: size) { _, _ in start() }
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        timer?.invalidate()
        items = []
        for _ in 0..<targetCount { add() }
        timer = Timer.scheduledTimer(withTimeInterval: 18, repeats: true) { _ in
            if items.count < maxCount { add() }
        }
    }

    private func add() {
        let i = items.count
        let startX: CGFloat = -25
        let y = size.height * (0.1 + segmentHash(seed: seed, segmentId: "env_bird_y\(i)") * 0.25)
        let sz = 14 + CGFloat(segmentPick(seed: seed, segmentId: "env_bird_sz\(i)", n: 10))
        let b = Bird(x: startX, y: y, size: sz)
        items.append(b)
        let idx = items.count - 1
        let dur = 20.0 + Double(segmentPick(seed: seed, segmentId: "env_bird_dur\(i)", n: 15))
        withAnimation(.linear(duration: dur)) {
            items[idx].x = size.width + 25
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            items.removeAll { $0.id == b.id }
        }
    }
}

// MARK: - Fireworks (occasional burst)

private struct FireworkParticle {
    let angle: Double
    let dist: CGFloat
    let color: Color
}

private struct FireworksLayer: View {
    let seed: String
    let size: CGSize
    let count: Int?
    @State private var bursts: [FireworkBurst] = []
    @State private var timer: Timer?

    private struct FireworkBurst: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var progress: CGFloat
        var particles: [FireworkParticle]
    }

    private static let colors: [Color] = [.red, .blue, .yellow, .green, .orange, .purple]

    private var maxBursts: Int {
        if let c = count { return min(c, EnvKeywordHints.maxCount) }
        return 5
    }

    var body: some View {
        ZStack {
            ForEach(bursts) { b in
                ForEach(Array(b.particles.enumerated()), id: \.offset) { _, p in
                    Circle()
                        .fill(p.color.opacity(0.9 * (1 - b.progress)))
                        .frame(width: 4, height: 4)
                        .position(
                            x: b.x + cos(p.angle) * p.dist * b.progress,
                            y: b.y + sin(p.angle) * p.dist * b.progress
                        )
                }
            }
        }
        .onAppear { start() }
        .onChange(of: size) { _, _ in start() }
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        timer?.invalidate()
        bursts = []
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            if bursts.count < maxBursts { addBurst() }
        }
    }

    private func addBurst() {
        let i = bursts.count
        let x = size.width * (0.2 + segmentHash(seed: seed, segmentId: "env_fw_x\(i)") * 0.6)
        let y = size.height * (0.2 + segmentHash(seed: seed, segmentId: "env_fw_y\(i)") * 0.4)
        var particles: [FireworkParticle] = []
        for j in 0..<12 {
            let angle = Double(j) * 2 * .pi / 12 + segmentHash(seed: seed, segmentId: "env_fw_a\(i)_\(j)") * 0.5
            let dist = 30 + CGFloat(segmentPick(seed: seed, segmentId: "env_fw_d\(i)_\(j)", n: 40))
            let color = Self.colors[segmentPick(seed: seed, segmentId: "env_fw_c\(i)_\(j)", n: Self.colors.count)]
            particles.append(FireworkParticle(angle: angle, dist: dist, color: color))
        }
        let b = FireworkBurst(x: x, y: y, progress: 0, particles: particles)
        bursts.append(b)
        let idx = bursts.count - 1
        withAnimation(.easeOut(duration: 2.5)) {
            bursts[idx].progress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            bursts.removeAll { $0.id == b.id }
        }
    }
}

// MARK: - Christmas lights (along top; brightness from phase)

private struct ChristmasLightsLayer: View {
    let seed: String
    let size: CGSize
    let count: Int?
    @State private var lights: [ChristmasLight] = []
    @State private var phase: Double = 0
    @State private var phaseTimer: Timer?

    private struct ChristmasLight: Identifiable {
        let id = UUID()
        let index: Int
        let color: Color
    }

    private static let colors: [Color] = [.red, .green, .blue, .yellow, .orange, .purple]

    private var lightCount: Int {
        if let c = count { return min(max(1, c), EnvKeywordHints.maxCount) }
        return 8 + segmentPick(seed: seed, segmentId: "env_light_n", n: 12)
    }

    var body: some View {
        let spacing = size.width / CGFloat(max(1, lights.count) + 1)
        ZStack(alignment: .top) {
            ForEach(lights) { l in
                Circle()
                    .fill(l.color.opacity(0.3 + 0.5 * sin(phase + Double(l.index) * 0.5)))
                    .frame(width: 8, height: 8)
                    .position(x: spacing * CGFloat(l.index + 1), y: 12)
            }
        }
        .onAppear {
            let n = lightCount
            lights = (0..<n).map { i in
                ChristmasLight(
                    index: i,
                    color: Self.colors[segmentPick(seed: seed, segmentId: "env_light_c\(i)", n: Self.colors.count)]
                )
            }
            phaseTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase += 0.1
            }
            if let t = phaseTimer { RunLoop.main.add(t, forMode: .common) }
        }
        .onChange(of: size) { _, newSize in
            let n = lightCount
            if lights.count != n {
                lights = (0..<n).map { i in
                    ChristmasLight(
                        index: i,
                        color: Self.colors[segmentPick(seed: seed, segmentId: "env_light_c\(i)", n: Self.colors.count)]
                    )
                }
            }
        }
        .onDisappear {
            phaseTimer?.invalidate()
        }
    }
}

// MARK: - Generic particles (subtle; only when few other layers)

private struct ParticlesLayer: View {
    let seed: String
    let size: CGSize
    @State private var particles: [Particle] = []
    @State private var timer: Timer?

    private struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(Color.white.opacity(p.opacity))
                    .frame(width: p.size, height: p.size)
                    .position(x: p.x, y: p.y)
            }
        }
        .onAppear { start() }
        .onChange(of: size) { _, _ in start() }
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        timer?.invalidate()
        particles = []
        for _ in 0..<10 { add() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if particles.count < 20 { add() }
        }
    }

    private func add() {
        let i = particles.count
        let x = CGFloat(segmentHash(seed: seed, segmentId: "env_part_x\(i)")) * (size.width + 20) - 10
        let startY: CGFloat = -5
        let sz = 1.5 + segmentHash(seed: seed, segmentId: "env_part_sz\(i)") * 2.5
        let op = 0.1 + segmentHash(seed: seed, segmentId: "env_part_op\(i)") * 0.25
        let p = Particle(x: x, y: startY, size: sz, opacity: op)
        particles.append(p)
        let idx = particles.count - 1
        let dur = 12.0 + Double(segmentPick(seed: seed, segmentId: "env_part_dur\(i)", n: 8))
        withAnimation(.linear(duration: dur)) {
            particles[idx].y = size.height + 10
            particles[idx].x += CGFloat((segmentHash(seed: seed, segmentId: "env_part_dx\(i)") - 0.5) * 25)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            particles.removeAll { $0.id == p.id }
        }
    }
}

#Preview {
    CreatureEnvironmentView(seed: "hello world")
        .frame(width: 400, height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
