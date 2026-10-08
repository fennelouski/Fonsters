#if os(macOS) || os(iOS)
import SwiftUI
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
    let finished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var assembled = false
    @State private var fallen = false
    @State private var faded = false
    private var returning: Bool { UserDefaults.standard.bool(forKey: "Fonsters.hasLaunched.v1") }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                FonsterChrome.background.ignoresSafeArea()
                HStack(spacing: 3) {
                    Image("LaunchIcon").resizable().scaledToFit().frame(width: 100, height: 100)
                        .rotation3DEffect(.degrees(fallen ? 85 : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom)
                    if geometry.size.width > geometry.size.height || !returning {
                        ForEach(Array("ONSTERS".enumerated()), id: \.offset) { index, letter in
                            ZStack {
                                Text(String(letter)).font(.system(size: 58, weight: .black, design: .rounded)).foregroundStyle(FonsterTone.company.ink)
                                LobbyPortrait(appearance: PlayroomCompanion.fixtures[index].descriptor).frame(width: 32, height: 32).offset(y: -24)
                            }.offset(x: fallen ? CGFloat(index + 1) * 90 : assembled ? 0 : -CGFloat(index + 1) * 58, y: fallen ? (index.isMultiple(of: 2) ? -300 : 300) : assembled ? 0 : 30)
                                .opacity(assembled ? 1 : 0)
                        }
                    } else {
                        ForEach(0..<3) { index in
                            LobbyPortrait(appearance: PlayroomCompanion.fixtures[index].descriptor).frame(width: 45, height: 45)
                                .offset(x: fallen ? CGFloat(index + 1) * 170 : -60, y: fallen ? -200 : 0)
                        }
                    }
                }.scaleEffect(min(1, geometry.size.width / 600))
            }.opacity(faded ? 0 : 1)
        }.accessibilityElement(children: .ignore).accessibilityLabel("Fonsters is opening")
        .task {
            let quick = returning || ProcessInfo.processInfo.isLowPowerModeEnabled
            defer { UserDefaults.standard.set(true, forKey: "Fonsters.hasLaunched.v1") }
            if !reduceMotion {
                withAnimation(.spring(response: quick ? 0.25 : 0.55, dampingFraction: 0.8)) { assembled = true }
                do { try await Task.sleep(for: .milliseconds(quick ? 280 : 850)) } catch { return }
                guard scenePhase == .active else { finished(); return }
                withAnimation(.easeIn(duration: quick ? 0.22 : 0.4)) { fallen = true }
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
                #endif
                do { try await Task.sleep(for: .milliseconds(quick ? 280 : 650)) } catch { return }
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { faded = true }
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 250)) } catch { return }
            finished()
        }
    }
}
#endif
