#if os(macOS) || os(iOS)
import SwiftUI
import SceneKit
#if os(iOS)
import UIKit
#endif

@available(macOS 15.0, iOS 18.0, *)
struct FonsterWelcome: View {
    enum Destination { case explore, personality }
    let save: (String, Destination) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var entropy = UUID().uuidString
    @State private var controller = PlayroomController()
    @State private var choosingDestination = false
    @State private var visible = false
    private var seed: String { PersonalFonsterLibrary.friendlySeed(entropy: entropy) }
    private var companion: PlayroomCompanion { .init(name: "Your Fonster", seed: seed) }
    var body: some View {
        VStack(spacing: 22) {
            Text(choosingDestination ? "Where to first?" : "Meet your Fonster").font(.title2.bold())
            CreatureStageView(companion: companion, controller: controller).id(seed)
                .frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 26))
            HStack(spacing: 28) {
                if choosingDestination {
                    FonsterIconButton(title: "Explore the world", symbol: "globe.americas.fill", tone: .world) { save(seed, .explore) }.accessibilityIdentifier("welcomeExplore")
                    FonsterIconButton(title: "Add personality", symbol: "heart.fill", tone: .company) { save(seed, .personality) }.accessibilityIdentifier("welcomePersonality")
                } else {
                    FonsterIconButton(title: "Try another Fonster", symbol: "shuffle", tone: .play) { entropy = UUID().uuidString }.accessibilityIdentifier("welcomeShuffle")
                    FonsterIconButton(title: "This is my Fonster", symbol: "checkmark", tone: .company) { withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) { choosingDestination = true } }.accessibilityIdentifier("welcomeChoose")
                }
            }
        }.padding(24).frame(maxWidth: 460).foregroundStyle(FonsterChrome.primary)
            .background(FonsterChrome.background, in: RoundedRectangle(cornerRadius: 30))
            .scaleEffect(visible ? 1 : 0.94).opacity(visible ? 1 : 0)
            .onAppear { controller.soundEnabled = false; withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.82)) { visible = true } }
            .task(id: controller.shouldAnimate) { if controller.shouldAnimate { await controller.animate() } }
            .onChange(of: reduceMotion, initial: true) { controller.systemReduceMotion = reduceMotion }
            .onChange(of: scenePhase, initial: true) { controller.backgrounded = scenePhase != .active }
            .onDisappear { controller.backgrounded = true; controller.silence() }
    }
}

@available(macOS 15.0, iOS 18.0, *)
struct FonsterLaunch: View {
    let worldReady: Bool
    let finished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var assembled = false
    @State private var fallen = false
    @State private var creatures: FonsterLaunchScene?
    @State private var faded = false
    @State private var phase = "logo"
    @State private var returning = UserDefaults.standard.bool(forKey: "Fonsters.hasLaunched.v1")
    private var verification: Bool { ProcessInfo.processInfo.arguments.contains("--verify-manual") }
    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - 24, 780)
            ZStack {
                if let creatures {
                    FonsterLaunchViewport(scene: creatures.scene)
                        .frame(width: width, height: width * 0.4)
                        .opacity(assembled ? 1 : 0)
                }
                Image("LaunchIcon").resizable().scaledToFit()
                    .frame(width: width * 0.17, height: width * 0.17)
                    .rotation3DEffect(.degrees(fallen ? 88 : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom)
                    .offset(x: assembled ? -width * 0.4 : 0, y: fallen ? width * 0.07 : 0)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).opacity(faded ? 0 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fonsters is opening")
        .accessibilityValue(phase)
        .accessibilityIdentifier("fonsterLaunch")
        .task(id: worldReady) {
            guard worldReady else { return }
            if verification {
                if ProcessInfo.processInfo.arguments.contains("--launch-first") { returning = false }
                if ProcessInfo.processInfo.arguments.contains("--launch-returning") { returning = true }
            }
            let still = reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled || (verification && ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"))
            let quick = returning || ProcessInfo.processInfo.isLowPowerModeEnabled
            do {
                // Let the static logo actually paint before changing its state.
                try await Task.sleep(for: .milliseconds(still ? 180 : 300))
                if !still {
                    if creatures == nil { creatures = FonsterLaunchScene() }
                    guard let creatures else { return }
                    phase = "emerging"
                    withAnimation(.spring(response: quick ? 0.45 : 0.65, dampingFraction: 0.74)) { assembled = true }
                    creatures.emerge(quick: quick)
                    try await Task.sleep(for: .milliseconds(quick ? 550 : 850))
                    phase = "forming letters"
                    creatures.formLetters(quick: quick)
                    try await Task.sleep(for: .milliseconds(quick ? 550 : 850))
                    if verification && ProcessInfo.processInfo.arguments.contains("--launch-hold") {
                        try await Task.sleep(for: .seconds(6))
                    }
                    guard scenePhase == .active else { finished(); return }
                    phase = "falling"
                    withAnimation(.easeIn(duration: 0.38)) { fallen = true }
                    try await Task.sleep(for: .milliseconds(380))
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
                    #endif
                    phase = "scattering"
                    creatures.scatter(quick: quick)
                    try await Task.sleep(for: .milliseconds(quick ? 480 : 700))
                }
                phase = "finished"
                withAnimation(still ? nil : .easeOut(duration: 0.25)) { faded = true }
                try await Task.sleep(for: .milliseconds(still ? 0 : 250))
            } catch { return }
            // A canceled/abandoned launch must not mark onboarding as seen.
            if !verification { UserDefaults.standard.set(true, forKey: "Fonsters.hasLaunched.v1") }
            finished()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { creatures?.stop(); finished() }
        }
        .onDisappear { creatures?.stop() }
    }
}
#endif
