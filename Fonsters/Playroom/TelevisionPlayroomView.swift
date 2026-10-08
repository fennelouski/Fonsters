#if os(tvOS)
import SwiftUI
import SwiftData
import RealityKit

@available(tvOS 26.0, *)
struct TelevisionFonstersHome: View {
    var body: some View {
        TabView {
            TelevisionWorldView().tabItem { Image(systemName: "person.3").accessibilityLabel("Fuzzy world") }
            ParentOnlyArea(purpose: "Review the original gallery and seed links before sharing.") { ContentView() }.tabItem { Image(systemName: "square.grid.2x2").accessibilityLabel("Original gallery") }
        }
    }
}

/// Remote focus stays on native buttons. Camera navigation is explicit, so a
/// direction on the remote can always move focus without accidentally petting.
@available(tvOS 26.0, *)
struct TelevisionWorldView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Fonster.createdAt, order: .reverse) private var saved: [Fonster]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lobby = LocalLobbyController()
    @State private var controlHistory = FonsterControlHistory<LocalLobbyController.ControlState>()
    private let ink = Color(red: 0.30, green: 0.23, blue: 0.43)
    private var roster: [LocalLobbyController.SavedAppearance] { PersonalFonsterLibrary.canonical(saved).map { .init(id: $0.id, name: $0.name, seed: $0.seed, biography: $0.biography) } }
    var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.94, blue: 0.87).ignoresSafeArea()
            LobbyStageView(lobby: lobby).id(lobby.roomRevision).ignoresSafeArea()
            if let error = lobby.error { Text(error).font(.callout).padding().background(.regularMaterial) }
            VStack(spacing: 18) {
            HStack(spacing: 24) {

                Spacer()
                FonsterControlPanel(title: "World areas", symbol: "map", tone: .world) {
                    FonsterControlGroup(title: "World areas", tone: .world) {
                        ForEach(LobbyWorld.Area.allCases, id: \.rawValue) { area in
                            control(area.title, area.symbol, selected: lobby.focusArea == area,
                                    detail: "Walk into this area and look around. Undo restores the preceding camera view; Stop activity ends the walk. Locked areas open as local companions join.") { lobby.explore(area) }
                                .disabled(!lobby.world.areas.contains(area) || !lobby.ready || lobby.paused || lobby.backgrounded || lobby.lowPower)
                        }
                    }
                }
                FonsterControlPanel(title: "Companions", symbol: "person.2", tone: .company) {
                    FonsterControlGroup(title: "Companions", tone: .company) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(90)), count: 4), spacing: 24) {
                            ForEach(Array(lobby.members.enumerated()), id: \.element.id) { index, member in
                                Button { lobby.selected = index; lobby.lookAtSelected() } label: {
                                    if let fixture = member.localCompanion { CreatureAvatarView(seed: fixture.seed, size: 54).padding(6) }
                                }.buttonStyle(.bordered).tint(index == lobby.selected ? ink : Color.gray.opacity(0.25))
                                    .fonsterHelp("Meet " + member.name, symbol: "person.crop.circle", detail: "Choose this companion. A border marks the selected portrait. Choose another or Undo to return.")
                                    .accessibilityLabel("Meet " + member.name).accessibilityAddTraits(index == lobby.selected ? .isSelected : [])
                            }
                        }
                    }
                    FonsterControlPanel(title: "Add a companion", symbol: "person.badge.plus", tone: .company) {
                        FonsterControlGroup(title: "New companions", tone: .company) {
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(90)), count: 4), spacing: 24) {
                                ForEach(lobby.availableCompanions) { companion in
                                    FonsterPortraitChoice(name: "Add " + companion.name, selected: false,
                                        detail: "Adds a local companion. Undo returns to the previous selection; the companion stays in this world.",
                                        portrait: { CreatureAvatarView(seed: companion.seed, size: 48) }, action: { lobby.addCompanion(companion) })
                                }
                            }
                        }
                    }.disabled(lobby.availableCompanions.isEmpty)
                }
                FonsterControlPanel(title: "Camera controls", symbol: "rotate.3d", tone: .world) {
                    FonsterControlGroup(title: "Camera", tone: .world) {
                        VStack(spacing: 24) {
                            HStack {
                                control("World overview", "map") { lobby.showOverview() }
                                control("Follow selected", "scope") { lobby.lookAtSelected() }
                                control("Turn left", "arrow.counterclockwise") { lobby.rotateCamera(-.pi / 6) }
                                control("Turn right", "arrow.clockwise") { lobby.rotateCamera(.pi / 6) }
                            }
                            HStack {
                                control("Closer", "plus.magnifyingglass") { lobby.zoomCamera(0.8) }
                                control("Further", "minus.magnifyingglass") { lobby.zoomCamera(1.2) }
                                control("Tilt up", "arrow.up") { lobby.rotateCamera(0, vertical: 0.12) }
                                control("Tilt down", "arrow.down") { lobby.rotateCamera(0, vertical: -0.12) }
                            }
                            HStack {
                                control("Pan left", "arrow.left") { _ = lobby.cameraKey("a", modifiers: []) }
                                control("Pan right", "arrow.right") { _ = lobby.cameraKey("d", modifiers: []) }
                                control("Pan forward", "arrow.up.forward") { _ = lobby.cameraKey("w", modifiers: []) }
                                control("Pan back", "arrow.down.backward") { _ = lobby.cameraKey("s", modifiers: []) }
                                control("Raise camera", "arrow.up.to.line") { lobby.panCamera([0, 0.3, 0]) }
                                control("Lower camera", "arrow.down.to.line") { lobby.panCamera([0, -0.3, 0]) }
                            }
                        }
                    }
                }
                FonsterControlPanel(title: "Motion and sound", symbol: "slider.horizontal.3") {
                    FonsterControlGroup(title: "Motion and sound") {
                        control("Wander", "figure.walk", selected: lobby.wander) { lobby.setWander(!lobby.wander) }
                        control("Still mode", "snowflake", selected: lobby.still) { lobby.still.toggle() }
                        control("Sounds", "speaker.wave.2", selected: lobby.sounds) { lobby.sounds.toggle() }
                    }
                }

            }
            Spacer()
            HStack(spacing: 24) {
                FonsterControlGroup(title: "Friends", tone: .company) {
                    control("Wave to a friend", "hand.wave") { lobby.waveToFriend() }
                    control("Pass a ball", "tennisball") { lobby.pair(quiet: false) }
                    FonsterControlPanel(title: "More activities", symbol: "ellipsis", tone: .play) {
                        FonsterControlGroup(title: "Shared activities", tone: .play) {
                            control("Dance together", "sparkles") { lobby.playTogether() }
                            control("Sit on a bench", "chair.lounge") { lobby.sitOnBench() }
                        }
                    }
                    control("Stop activity", "stop.fill") { lobby.stopActivity() }
                }
                Spacer()
                control("Undo last control change", "arrow.uturn.backward") { if let state = controlHistory.undo() { lobby.restoreControls(state) } }.disabled(!controlHistory.canUndo)
                control(lobby.paused ? "Resume" : "Pause", lobby.paused ? "play.fill" : "pause.fill", selected: lobby.paused) { lobby.paused.toggle() }
            }.disabled(!lobby.ready).focusSection()
            }.padding(48)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(ink).preferredColorScheme(.light)
            .onPlayPauseCommand { lobby.paused.toggle() }
            .onKeyPress(phases: [.down, .repeat]) { press in
                let direction = [KeyEquivalent.leftArrow, .rightArrow, .upArrow, .downArrow].contains(press.key)
                // Remote directions continue moving native focus. A physical
                // keyboard can orbit with Shift-arrow and pan with W A S D Q E.
                guard !direction || press.modifiers.contains(.shift) else { return .ignored }
                return lobby.cameraKey(press.key, modifiers: press.modifiers) ? .handled : .ignored
            }
            .task { await verifyRuntimeIfRequested() }
            .task { try? await PersonalFonsterLibrary.ensureStarters(in: modelContext) }
            .onChange(of: roster, initial: true) { lobby.showSaved(roster) }
            .task(id: lobby.shouldAnimate) { if lobby.shouldAnimate { await lobby.animate() } else { lobby.refreshGates() } }
            .onChange(of: scenePhase, initial: true) { lobby.backgrounded = scenePhase != .active; lobby.refreshGates() }
            .onChange(of: reduceMotion, initial: true) { lobby.reduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"); lobby.refreshGates() }
            .onChange(of: lobby.paused) { lobby.refreshGates() }
            .onChange(of: lobby.still) { lobby.refreshGates() }
            .onChange(of: lobby.sounds) { lobby.refreshGates() }
            .onChange(of: lobby.controls) { old, new in controlHistory.record(old: old, new: new) }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lobby.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled; lobby.refreshGates() }
            .onAppear { lobby.backgrounded = scenePhase != .active; lobby.refreshGates() }
            .onDisappear { lobby.backgrounded = true; lobby.refreshGates() }
    }
    /// Opt-in runtime smoke test within this app's own view. It uses the same
    /// handlers as the controls; remote focus and physical remote input still
    /// need independent hardware/UI testing.
    private func verifyRuntimeIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--tv-verification-file"), index + 1 < args.count else { return }
        for _ in 0..<600 {
            if lobby.ready { break }
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        var checks: [String: Bool] = ["rendererReady": lobby.ready]
        let originalLearning = lobby.members.map { $0.controller.personality?.interactionCount ?? 0 }
        for area in lobby.world.areas {
            lobby.explore(area); lobby.rotateCamera(.pi / 12); lobby.zoomCamera(0.9)
            lobby.perform(.greet)
            try? await Task.sleep(for: .milliseconds(450))
        }
        for _ in 0..<30 { lobby.perform(.play) }
        lobby.pair(quiet: false)
        try? await Task.sleep(for: .seconds(1))
        checks["finiteTransforms"] = lobby.containers.allSatisfy { e in [e.position.x, e.position.y, e.position.z].allSatisfy(\.isFinite) }
        for gate in ["pause", "still", "reduceMotion", "background", "lowPower"] {
            lobby.paused = gate == "pause"; lobby.still = gate == "still"; lobby.reduceMotion = gate == "reduceMotion"
            lobby.backgrounded = gate == "background"; lobby.lowPower = gate == "lowPower"; lobby.refreshGates()
            let frame = lobby.frames, positions = lobby.simulation.agents.map(\.position)
            try? await Task.sleep(for: .milliseconds(180))
            checks[gate] = lobby.frames == frame && lobby.simulation.agents.map(\.position) == positions && !lobby.shouldAnimate
        }
        lobby.paused = false; lobby.still = false; lobby.reduceMotion = false; lobby.backgrounded = false; lobby.lowPower = false; lobby.refreshGates()
        let frame = lobby.frames
        try? await Task.sleep(for: .milliseconds(300))
        checks["resume"] = lobby.frames > frame
        checks["separateAppearanceState"] = lobby.members.map { $0.descriptor.version }.allSatisfy { $0 == 1 }
        checks["deliberateLearningBounded"] = zip(originalLearning, lobby.members).allSatisfy { old, member in (member.controller.personality?.interactionCount ?? 0) - old < 10 }
        lobby.showOverview()
        let result: [String: Any] = ["platform": "tvOS", "checks": checks, "passed": checks.values.allSatisfy { $0 }, "remoteInputVerified": false]
        let requested = args[index + 1]
        let url = requested.hasPrefix("/") ? URL(fileURLWithPath: requested) : FileManager.default.temporaryDirectory.appendingPathComponent(requested)
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: url, options: .atomic) }
    }
    private func control(_ title: String, _ symbol: String, selected: Bool = false, detail: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 25, weight: .medium)).frame(width: 48, height: 36) }
            .buttonStyle(.bordered).tint(Color(red: 0.84, green: 0.81, blue: 0.91))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? ink : .clear, lineWidth: 3))
            .fonsterHelp(title, symbol: symbol, detail: detail)
            .accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
