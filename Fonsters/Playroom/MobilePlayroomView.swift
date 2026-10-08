#if os(iOS)
import SwiftUI
import RealityKit

/// The original gallery remains in its existing model container. The 3D preview
/// uses its separate local memory namespace and never rewrites saved appearances.
@available(iOS 18.0, *)
struct MobileFonstersHome: View {
    @EnvironmentObject private var pendingImportURL: PendingImportURLHolder
    @State private var tab = ProcessInfo.processInfo.arguments.contains("--original-gallery") ? 1 : 0
    @State private var showWorld = false
    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                MobilePlayroomView(showWorld: $showWorld)
                    .tabItem { Image(systemName: "sparkles").accessibilityLabel("Fuzzy companions") }.tag(0)
                ContentView()
                    .tabItem { Image(systemName: "square.grid.2x2").accessibilityLabel("Original portrait gallery") }.tag(1)
            }.opacity(showWorld ? 0 : 1).allowsHitTesting(!showWorld).accessibilityHidden(showWorld)
            if showWorld { MobileLobbyView(onClose: { showWorld = false }).zIndex(1) }
        }.tint(FonsterTone.world.ink)
            .onChange(of: pendingImportURL.url, initial: true) {
                if pendingImportURL.url != nil { showWorld = false; tab = 1 }
            }
    }
}

@available(iOS 18.0, *)
struct MobilePlayroomView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = PlayroomController()
    @State private var selection = 0
    @Binding var showWorld: Bool
    @State private var controlHistory = FonsterControlHistory<PlayroomController.ControlState>()
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
                } else if !showWorld {
                    CreatureStageView(companion: selected, controller: controller).id(sceneID)
                    if !controller.rendererReady {
                        ProgressView().accessibilityLabel("Opening the companion environment").allowsHitTesting(false)
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 26)).padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("fuzzyStage")
            HStack(spacing: 6) {
                FonsterControlGroup(title: "Reactions", tone: .company) {
                    action("Say hello", "hand.wave", .greet, .company)
                    action("Play", "sparkles", .play, .play)
                    action("Rest", "moon", .rest, .world)
                    FonsterIconButton(title: "Stop activity", symbol: "stop.fill") { controller.stopActivity() }
                        .accessibilityIdentifier("stopActivity")
                }
                FonsterIconButton(title: "Undo last control change", symbol: "arrow.uturn.backward") {
                    if let state = controlHistory.undo() {
                        if selection != state.selection { controller.rendererReady = false; controller.rig = nil }
                        controller.restoreControls(state); selection = state.selection
                    }
                }.disabled(!controlHistory.canUndo).accessibilityIdentifier("undoControls")
            }.padding(.horizontal, 12)
            HStack(spacing: 12) {
                FonsterControlPanel(title: "More reactions", symbol: "ellipsis", tone: .play) {
                    FonsterControlGroup(title: "Touch and play", tone: .play) {
                        action("Gentle rub", "heart", .rub, .company)
                        action("High five", "hand.raised", .highFive, .company)
                        action("Hop", "hare", .hop, .play)
                        action("Fetch", "tennisball", .fetch, .play)
                    }
                    FonsterControlGroup(title: "Curiosity", tone: .world) {
                        action("Twirl", "arrow.trianglehead.2.clockwise.rotate.90", .spin, .play)
                        action("Stretch", "figure.flexibility", .stretch, .world)
                        action("Blink", "eye", .blink, .world)
                        action("Look", "eyes", .look, .world)
                    }
                }
                FonsterControlPanel(title: "Environments", symbol: controller.environment.symbol, tone: .world) {
                    FonsterControlGroup(title: "Environments", tone: .world) {
                        ForEach(CompanionEnvironment.allCases) { environment in
                            FonsterIconButton(title: environment.title, symbol: environment.symbol, tone: .world, selected: controller.environment == environment) {
                                controller.cancelTouch(); controller.rendererReady = false; controller.environment = environment
                            }.accessibilityIdentifier("environment_" + environment.rawValue)
                        }
                    }
                }
                FonsterControlPanel(title: "Motion and sound", symbol: "slider.horizontal.3") {
                    FonsterControlGroup(title: "Motion and sound") {
                        FonsterIconToggle(title: "Wander", symbol: "figure.walk", isOn: Binding(get: { controller.roaming }, set: { controller.setRoaming($0) }))
                        FonsterIconToggle(title: "Still mode", symbol: "snowflake", isOn: $controller.staticMode)
                        FonsterIconToggle(title: "Sounds", symbol: "speaker.wave.2", isOn: $controller.soundEnabled)
                    }
                    Slider(value: $controller.orbit, in: -180...180) { Text("Turn") }
                        .fonsterHelp("Turn companion", symbol: "rotate.3d")
                }
                Spacer(minLength: 0)
                FonsterIconButton(title: controller.paused ? "Resume" : "Pause", symbol: controller.paused ? "play.fill" : "pause.fill", selected: controller.paused) { controller.paused.toggle() }
                    .accessibilityIdentifier("pauseMotion")
            }.padding(.horizontal, 16)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 8).padding(.bottom, 8)
            .background(FonsterChrome.background)
            .foregroundStyle(FonsterChrome.primary)
            .task { controller.enablePersonalityLearning(PersonalityMemoryStore.localPreview()) }
            .task(id: controller.shouldAnimate) {
                if controller.shouldAnimate { await controller.animate() } else { controller.refreshStillPose() }
            }
            .onChange(of: reduceMotion, initial: true) { controller.systemReduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"); controller.refreshStillPose() }
            .onChange(of: scenePhase, initial: true) { controller.backgrounded = scenePhase != .active || showWorld; controller.refreshStillPose() }
            .onAppear { controller.backgrounded = scenePhase != .active || showWorld; controller.refreshStillPose() }
            .onChange(of: controller.lowPower) { controller.refreshStillPose() }
            .onChange(of: showWorld) {
                controller.backgrounded = showWorld || scenePhase != .active
                if showWorld {
                    // The root world owns the display while the companion's
                    // selection and controls remain in the mounted tab. Release
                    // its hidden native scene and rebuild it when returning.
                    controller.cancelTouch(); controller.silence()
                    controller.touchCamera = nil; controller.toyBall = nil
                    controller.rig = nil; controller.rendererReady = false
                }
                controller.refreshStillPose()
            }
            .onChange(of: controller.paused) { controller.refreshStillPose() }
            .onChange(of: controller.staticMode) { controller.refreshStillPose() }
            .onChange(of: controller.orbit) { controller.refreshStillPose() }
            .onChange(of: controller.controls(selection: selection)) { old, new in controlHistory.record(old: old, new: new) }
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
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var cameraFocused: Bool
    @State private var lobby = LocalLobbyController()
    @State private var controlHistory = FonsterControlHistory<LocalLobbyController.ControlState>()
    var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.94, blue: 0.87).ignoresSafeArea()
            LobbyStageView(lobby: lobby).id(lobby.roomRevision).ignoresSafeArea()
                .accessibilityIdentifier("worldStage")
            if let error = lobby.error { Text(error).padding().background(.regularMaterial) }
            VStack(spacing: 10) {
            HStack {
                FonsterControlPanel(title: "Companions", symbol: "person.2", tone: .company) {
                    FonsterControlGroup(title: "Companions", tone: .company) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(68)), count: 3), spacing: 12) {
                            ForEach(Array(lobby.members.enumerated()), id: \.element.id) { index, member in
                                FonsterPortraitChoice(name: member.name, selected: index == lobby.selected, portrait: {
                                    if let fixture = member.localCompanion { CreatureAvatarView(seed: fixture.seed, size: 48) }
                                }, action: { lobby.selected = index; lobby.lookAtSelected() })
                            }
                        }
                    }
                }
                Spacer()
                FonsterControlPanel(title: "Add a companion", symbol: "person.badge.plus", tone: .company) {
                    FonsterControlGroup(title: "New companions", tone: .company) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(68)), count: 3), spacing: 12) {
                            ForEach(lobby.availableCompanions) { companion in
                                FonsterPortraitChoice(name: "Add " + companion.name, selected: false, detail: "Adds a local companion to this world. Undo returns to your previous selection; the companion stays in the world.", portrait: {
                                    CreatureAvatarView(seed: companion.seed, size: 48)
                                }, action: { lobby.addCompanion(companion) })
                            }
                        }
                    }
                }.disabled(lobby.availableCompanions.isEmpty).accessibilityIdentifier("addCompanion")
                FonsterIconButton(title: "Back to companion", symbol: "xmark") { if let onClose { onClose() } else { dismiss() } }.accessibilityIdentifier("closeWorld")
            }.padding(.horizontal, 16)
            HStack(spacing: 12) {
                FonsterControlPanel(title: "World areas", symbol: lobby.focusArea?.symbol ?? "map", tone: .world) {
                    FonsterControlGroup(title: "World areas", tone: .world) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ForEach(LobbyWorld.Area.allCases, id: \.rawValue) { area in
                                    FonsterIconButton(title: lobby.world.areas.contains(area) ? area.title : "\(area.title), opens at \(area.population) Fonsters", symbol: area.symbol, tone: .world, selected: lobby.focusArea == area,
                                                      detail: "Walk into this area and look around. Undo restores the preceding camera view; Stop activity ends the walk. Locked areas open as local companions join.") { lobby.explore(area) }
                                        .disabled(!lobby.world.areas.contains(area) || !lobby.ready || lobby.paused || lobby.backgrounded || lobby.lowPower).accessibilityIdentifier("area_" + area.rawValue)
                                }
                            }
                            FonsterIconButton(title: "World overview", symbol: "map", tone: .world) { lobby.showOverview() }
                        }
                    }
                }
                FonsterControlPanel(title: "World controls", symbol: "slider.horizontal.3") {
                    FonsterControlGroup(title: "Camera", tone: .world) {
                        FonsterIconButton(title: "Follow selected", symbol: "scope") { lobby.lookAtSelected() }
                        FonsterIconButton(title: "Turn camera", symbol: "rotate.3d") { lobby.rotateCamera(.pi / 4) }
                        FonsterIconButton(title: "Closer", symbol: "plus.magnifyingglass") { lobby.zoomCamera(0.8) }
                        FonsterIconButton(title: "Further", symbol: "minus.magnifyingglass") { lobby.zoomCamera(1.2) }
                    }
                    FonsterControlGroup(title: "Camera movement", tone: .world) {
                        VStack(spacing: 12) {
                            HStack {
                                FonsterIconButton(title: "Tilt up", symbol: "arrow.up") { lobby.rotateCamera(0, vertical: 0.12) }
                                FonsterIconButton(title: "Tilt down", symbol: "arrow.down") { lobby.rotateCamera(0, vertical: -0.12) }
                                FonsterIconButton(title: "Raise camera", symbol: "arrow.up.to.line") { lobby.panCamera([0, 0.3, 0]) }
                                FonsterIconButton(title: "Lower camera", symbol: "arrow.down.to.line") { lobby.panCamera([0, -0.3, 0]) }
                            }
                            HStack {
                                FonsterIconButton(title: "Pan left", symbol: "arrow.left") { _ = lobby.cameraKey("a", modifiers: []) }
                                FonsterIconButton(title: "Pan right", symbol: "arrow.right") { _ = lobby.cameraKey("d", modifiers: []) }
                                FonsterIconButton(title: "Pan forward", symbol: "arrow.up.forward") { _ = lobby.cameraKey("w", modifiers: []) }
                                FonsterIconButton(title: "Pan back", symbol: "arrow.down.backward") { _ = lobby.cameraKey("s", modifiers: []) }
                            }
                        }
                    }
                    FonsterControlGroup(title: "Motion and sound") {
                        FonsterIconToggle(title: "Wander", symbol: "figure.walk", isOn: Binding(get: { lobby.wander }, set: { lobby.setWander($0) }))
                        FonsterIconToggle(title: "Still mode", symbol: "snowflake", isOn: $lobby.still)
                        FonsterIconToggle(title: "Sounds", symbol: "speaker.wave.2", isOn: $lobby.sounds)
                    }
                }
                Spacer()
                FonsterIconButton(title: "Undo last control change", symbol: "arrow.uturn.backward") { if let state = controlHistory.undo() { lobby.restoreControls(state) } }
                    .disabled(!controlHistory.canUndo).accessibilityIdentifier("undoWorldControls")
                FonsterIconButton(title: lobby.paused ? "Resume" : "Pause", symbol: lobby.paused ? "play.fill" : "pause.fill", selected: lobby.paused) { lobby.paused.toggle() }.accessibilityIdentifier("pauseWorld")
            }.padding(.horizontal, 16)
            Spacer(minLength: 0)
            FonsterControlGroup(title: "Friends", tone: .company) {
                FonsterIconButton(title: "Wave to friend", symbol: "hand.wave", tone: .company) { lobby.waveToFriend() }
                FonsterIconButton(title: "Pass a ball", symbol: "tennisball", tone: .play) { lobby.pair(quiet: false) }.accessibilityIdentifier("pairBall")
                FonsterControlPanel(title: "More activities", symbol: "ellipsis", tone: .play) {
                    FonsterControlGroup(title: "Shared activities", tone: .play) {
                        FonsterIconButton(title: "Dance together", symbol: "sparkles", tone: .play) { lobby.playTogether() }
                        FonsterIconButton(title: "Sit on a bench", symbol: "chair.lounge", tone: .world) { lobby.sitOnBench() }
                    }
                }
                FonsterIconButton(title: "Stop activity", symbol: "stop.fill") { lobby.stopActivity() }.accessibilityIdentifier("stopWorldActivity")
            }.disabled(!lobby.ready).padding(.horizontal, 16)
            }.padding(.top, 8).padding(.bottom, 8)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusable().focusEffectDisabled().focused($cameraFocused)
            .onKeyPress(phases: [.down, .repeat]) { press in lobby.cameraKey(press.key, modifiers: press.modifiers) ? .handled : .ignored }
            .onAppear { cameraFocused = true }
            .foregroundStyle(FonsterChrome.primary)
            .task(id: lobby.shouldAnimate) { if lobby.shouldAnimate { await lobby.animate() } else { lobby.refreshGates() } }
            .onChange(of: reduceMotion, initial: true) { lobby.reduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"); lobby.refreshGates() }
            .onChange(of: scenePhase, initial: true) { lobby.backgrounded = scenePhase != .active; lobby.refreshGates() }
            .onChange(of: lobby.paused) { lobby.refreshGates() }
            .onChange(of: lobby.still) { lobby.refreshGates() }
            .onChange(of: lobby.sounds) { lobby.refreshGates() }
            .onChange(of: lobby.controls) { old, new in
                if lobby.cameraGestureOrigin == nil { controlHistory.record(old: old, new: new) }
            }
            .onChange(of: lobby.cameraGestureActive) { _, active in
                if !active, let origin = lobby.cameraGestureOrigin {
                    controlHistory.record(old: origin, new: lobby.controls); lobby.cameraGestureOrigin = nil
                    cameraFocused = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lobby.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled; lobby.refreshGates() }
            .onDisappear { lobby.cancelContact(); lobby.backgrounded = true; lobby.refreshGates() }
    }
}
#endif
