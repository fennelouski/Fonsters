#if os(iOS)
import SwiftUI
import RealityKit

/// The original gallery remains in its existing model container. The 3D preview
/// uses its separate local memory namespace and never rewrites saved appearances.
@available(iOS 18.0, *)
struct MobileFonstersHome: View {
    @EnvironmentObject private var pendingImportURL: PendingImportURLHolder
    @State private var tab = ProcessInfo.processInfo.arguments.contains("--original-gallery") ? 1 : 0
    var body: some View {
        TabView(selection: $tab) {
            MobilePlayroomView()
                .tabItem { Image(systemName: "sparkles").accessibilityLabel("Fuzzy companions") }.tag(0)
            ContentView()
                .tabItem { Image(systemName: "square.grid.2x2").accessibilityLabel("Original portrait gallery") }.tag(1)
        }.tint(FonsterTone.world.ink)
            .onChange(of: pendingImportURL.url, initial: true) { if pendingImportURL.url != nil { tab = 1 } }
    }
}

@available(iOS 18.0, *)
struct MobilePlayroomView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = PlayroomController()
    @State private var selection = 0
    @State private var showWorld = false
    private let companions = PlayroomCompanion.fixtures
    private var selected: PlayroomCompanion { companions[selection] }
    private var sceneID: String { selected.id.uuidString + controller.environment.rawValue }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(selected.name).font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
                CreatureAvatarView(seed: selected.seed, size: 44)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(false).accessibilityLabel("Original portrait of \(selected.name)")
                FonsterIconButton(title: "Explore with friends", symbol: "person.3", tone: .world) { showWorld = true }
                    .accessibilityIdentifier("openWorld")
            }.frame(minHeight: 50).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 16)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(companions.enumerated()), id: \.element.id) { i, companion in
                        FonsterPortraitChoice(name: companion.name, selected: i == selection, portrait: {
                            CreatureAvatarView(seed: companion.seed, size: 48)
                        }, action: { controller.rendererReady = false; controller.rig = nil; controller.rendererError = nil; selection = i })
                    }
                }.padding(.horizontal, 16).padding(.vertical, 3)
            }.scrollIndicators(.hidden).frame(height: 76)
            ZStack {
                Color(red: 0.92, green: 0.91, blue: 0.94)
                if let error = controller.rendererError {
                    Text(error).font(.callout).padding()
                } else {
                    CreatureStageView(companion: selected, controller: controller).id(sceneID)
                    if !controller.rendererReady {
                        ProgressView().accessibilityLabel("Opening the companion environment").allowsHitTesting(false)
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 26)).padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("fuzzyStage")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    action("Say hello", "hand.wave", .greet, .company)
                    action("Gentle rub", "heart", .rub, .company)
                    action("Play", "sparkles", .play, .play)
                    action("Hop", "hare", .hop, .play)
                    action("Rest", "moon", .rest, .world)
                    Menu {
                        Button("High five", systemImage: "hand.raised") { controller.perform(.highFive, name: selected.name) }
                        Button("Fetch", systemImage: "tennisball") { controller.perform(.fetch, name: selected.name) }
                        Button("Twirl", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") { controller.perform(.spin, name: selected.name) }
                        Button("Stretch", systemImage: "figure.flexibility") { controller.perform(.stretch, name: selected.name) }
                    } label: { FonsterIcon(symbol: "ellipsis", tone: .play) }.accessibilityLabel("More reactions")
                }.padding(.horizontal, 16)
            }.scrollIndicators(.hidden).frame(height: 50)
            HStack(spacing: 8) {
                ForEach(CompanionEnvironment.allCases) { environment in
                    FonsterIconButton(title: environment.title, symbol: environment.symbol, tone: .world, selected: controller.environment == environment) {
                        controller.cancelTouch(); controller.rendererReady = false; controller.environment = environment
                    }.accessibilityIdentifier("environment_" + environment.rawValue)
                }
                Spacer(minLength: 0)
                FonsterIconButton(title: controller.paused ? "Resume" : "Pause", symbol: controller.paused ? "play.fill" : "pause.fill", selected: controller.paused) { controller.paused.toggle() }
                    .accessibilityIdentifier("pauseMotion")
                Menu {
                    Toggle("Wander", isOn: Binding(get: { controller.roaming }, set: { controller.setRoaming($0) }))
                    Toggle("Still mode", isOn: $controller.staticMode)
                    Toggle("Sounds", isOn: $controller.soundEnabled)
                    Slider(value: $controller.orbit, in: -180...180) { Text("Turn") }
                } label: { FonsterIcon(symbol: "slider.horizontal.3") }.accessibilityLabel("Motion and sound")
            }.padding(.horizontal, 16)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 8).padding(.bottom, 8)
            .background(Color(red: 0.98, green: 0.97, blue: 0.95))
            .foregroundStyle(Color(red: 0.19, green: 0.15, blue: 0.27)).preferredColorScheme(.light)
            .fullScreenCover(isPresented: $showWorld) { MobileLobbyView() }
            .task { controller.enablePersonalityLearning(PersonalityMemoryStore.localPreview()) }
            .task(id: controller.shouldAnimate) {
                if controller.shouldAnimate { await controller.animate() } else { controller.refreshStillPose() }
            }
            .onChange(of: reduceMotion, initial: true) { controller.systemReduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"); controller.refreshStillPose() }
            .onChange(of: scenePhase, initial: true) { controller.backgrounded = scenePhase != .active || showWorld; controller.refreshStillPose() }
            .onAppear { controller.backgrounded = scenePhase != .active || showWorld; controller.refreshStillPose() }
            .onChange(of: controller.lowPower) { controller.refreshStillPose() }
            .onChange(of: showWorld) { controller.backgrounded = showWorld || scenePhase != .active; controller.refreshStillPose() }
            .onChange(of: controller.paused) { controller.refreshStillPose() }
            .onChange(of: controller.staticMode) { controller.refreshStillPose() }
            .onChange(of: controller.orbit) { controller.refreshStillPose() }
            .onChange(of: controller.soundEnabled) { if !controller.soundEnabled { controller.silence() } }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                controller.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled; controller.refreshStillPose()
            }
            .onDisappear { controller.cancelTouch(); controller.silence(); controller.backgrounded = true }
    }
    private func action(_ title: String, _ icon: String, _ reaction: PlayroomController.Reaction, _ tone: FonsterTone) -> some View {
        FonsterIconButton(title: title, symbol: icon, tone: tone, selected: controller.reaction == reaction) { controller.perform(reaction, name: selected.name) }
            .disabled(!controller.rendererReady).accessibilityIdentifier("reaction_" + reaction.rawValue)
    }
}

@available(iOS 18.0, *)
struct MobileLobbyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var lobby = LocalLobbyController()
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(lobby.selectedMember.name).font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
                Menu {
                    ForEach(lobby.availableCompanions) { companion in
                        Button(companion.name) { lobby.addCompanion(companion) }
                    }
                } label: { FonsterIcon(symbol: "person.badge.plus", tone: .company) }.accessibilityLabel("Add a companion")
                    .disabled(lobby.availableCompanions.isEmpty).accessibilityIdentifier("addCompanion")
                FonsterIconButton(title: "Back to companion", symbol: "xmark") { dismiss() }.accessibilityIdentifier("closeWorld")
            }.padding(.horizontal, 16)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(LobbyWorld.Area.allCases, id: \.rawValue) { area in
                        FonsterIconButton(title: lobby.world.areas.contains(area) ? area.title : "\(area.title), opens at \(area.population) Fonsters", symbol: area.symbol, tone: .world, selected: lobby.focusArea == area) { lobby.explore(area) }
                            .disabled(!lobby.world.areas.contains(area))
                            .overlay(alignment: .bottomTrailing) {
                                if !lobby.world.areas.contains(area) { Text("\(area.population)").font(.caption2.bold()).padding(3).background(.white, in: Circle()).accessibilityHidden(true) }
                            }.accessibilityIdentifier("area_" + area.rawValue)
                    }
                    FonsterIconButton(title: "World overview", symbol: "map", tone: .world) { lobby.showOverview() }
                }.padding(.horizontal, 16)
            }.scrollIndicators(.hidden).frame(height: 50)
            ZStack {
                Color(red: 0.91, green: 0.94, blue: 0.87)
                LobbyStageView(lobby: lobby).id(lobby.roomRevision)
                if let error = lobby.error { Text(error).padding().background(.regularMaterial) }
            }.clipShape(RoundedRectangle(cornerRadius: 26)).padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("worldStage")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(lobby.members.enumerated()), id: \.element.id) { index, member in
                        FonsterPortraitChoice(name: member.name, selected: index == lobby.selected, portrait: {
                            if let fixture = member.localCompanion { CreatureAvatarView(seed: fixture.seed, size: 48) }
                        }, action: { lobby.selected = index; lobby.lookAtSelected() })
                    }
                }.padding(.horizontal, 16).padding(.vertical, 3)
            }.scrollIndicators(.hidden).frame(height: 76)
            HStack(spacing: 8) {
                FonsterIconButton(title: "Wave to friend", symbol: "hand.wave", tone: .company) { lobby.waveToFriend() }
                FonsterIconButton(title: "Pass a ball", symbol: "tennisball", tone: .play) { lobby.pair(quiet: false) }.accessibilityIdentifier("pairBall")
                FonsterIconButton(title: "Dance together", symbol: "sparkles", tone: .play) { lobby.playTogether() }
                FonsterIconButton(title: "Sit on a bench", symbol: "chair.lounge", tone: .world) { lobby.sitOnBench() }
                FonsterIconButton(title: lobby.paused ? "Resume" : "Pause", symbol: lobby.paused ? "play.fill" : "pause.fill", selected: lobby.paused) { lobby.paused.toggle() }.accessibilityIdentifier("pauseWorld")
                Menu {
                    Button("Follow selected", systemImage: "scope") { lobby.lookAtSelected() }
                    Button("Turn camera", systemImage: "rotate.3d") { lobby.rotateCamera(.pi / 4) }
                    Button("Closer", systemImage: "plus.magnifyingglass") { lobby.zoomCamera(0.8) }
                    Button("Further", systemImage: "minus.magnifyingglass") { lobby.zoomCamera(1.2) }
                    Toggle("Wander", isOn: Binding(get: { lobby.wander }, set: { lobby.setWander($0) }))
                    Toggle("Still mode", isOn: $lobby.still)
                    Toggle("Sounds", isOn: $lobby.sounds)
                } label: { FonsterIcon(symbol: "slider.horizontal.3") }.accessibilityLabel("World controls")
            }.padding(.horizontal, 16).disabled(!lobby.ready)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 8).padding(.bottom, 8).background(Color(red: 0.98, green: 0.97, blue: 0.95))
            .foregroundStyle(Color(red: 0.19, green: 0.15, blue: 0.27)).preferredColorScheme(.light)
            .task(id: lobby.shouldAnimate) { if lobby.shouldAnimate { await lobby.animate() } else { lobby.refreshGates() } }
            .onChange(of: reduceMotion, initial: true) { lobby.reduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"); lobby.refreshGates() }
            .onChange(of: scenePhase, initial: true) { lobby.backgrounded = scenePhase != .active; lobby.refreshGates() }
            .onChange(of: lobby.paused) { lobby.refreshGates() }
            .onChange(of: lobby.still) { lobby.refreshGates() }
            .onChange(of: lobby.sounds) { lobby.refreshGates() }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lobby.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled; lobby.refreshGates() }
            .onDisappear { lobby.cancelContact(); lobby.backgrounded = true; lobby.refreshGates() }
    }
}
#endif
