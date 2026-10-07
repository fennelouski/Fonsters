#if os(tvOS)
import SwiftUI
import RealityKit

@available(tvOS 26.0, *)
struct TelevisionFonstersHome: View {
    var body: some View {
        TabView {
            TelevisionWorldView().tabItem { Image(systemName: "person.3").accessibilityLabel("Fuzzy world") }
            ContentView().tabItem { Image(systemName: "square.grid.2x2").accessibilityLabel("Original gallery") }
        }
    }
}

/// Remote focus stays on native buttons. Camera navigation is explicit, so a
/// direction on the remote can always move focus without accidentally petting.
@available(tvOS 26.0, *)
struct TelevisionWorldView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lobby = LocalLobbyController()
    @State private var choosingCompanion = false
    private let ink = Color(red: 0.30, green: 0.23, blue: 0.43)
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 24) {
                Text(lobby.selectedMember.name).font(.system(.title, design: .rounded, weight: .bold))
                Spacer()
                ForEach(LobbyWorld.Area.allCases, id: \.rawValue) { area in
                    control(area.title, area.symbol, selected: lobby.focusArea == area) { lobby.explore(area) }
                        .disabled(!lobby.world.areas.contains(area))
                }
                control("Add a companion", "person.badge.plus") { choosingCompanion = true }.disabled(lobby.availableCompanions.isEmpty)
            }
            ZStack {
                Color(red: 0.91, green: 0.94, blue: 0.87)
                LobbyStageView(lobby: lobby).id(lobby.roomRevision)
                if let error = lobby.error { Text(error).font(.callout).padding().background(.regularMaterial) }
            }.clipShape(RoundedRectangle(cornerRadius: 30)).frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 16) {
                ForEach(Array(lobby.members.enumerated()), id: \.element.id) { index, member in
                    Button {
                        lobby.selected = index; lobby.lookAtSelected()
                    } label: {
                        if let fixture = member.localCompanion { CreatureAvatarView(seed: fixture.seed, size: 54).padding(6) }
                    }.buttonStyle(.bordered).tint(index == lobby.selected ? ink : Color.gray.opacity(0.25))
                        .accessibilityLabel("Meet " + member.name).accessibilityAddTraits(index == lobby.selected ? .isSelected : [])
                }
            }.frame(height: 80).focusSection()
            HStack(spacing: 14) {
                control("Wave to a friend", "hand.wave") { lobby.waveToFriend() }
                control("Pass a ball", "tennisball") { lobby.pair(quiet: false) }
                control("Dance together", "sparkles") { lobby.playTogether() }
                control("Sit on a bench", "chair.lounge") { lobby.sitOnBench() }
                control("World overview", "map") { lobby.showOverview() }
                control("Follow selected", "scope") { lobby.lookAtSelected() }
                control("Turn left", "arrow.counterclockwise") { lobby.rotateCamera(-.pi / 6) }
                control("Turn right", "arrow.clockwise") { lobby.rotateCamera(.pi / 6) }
                control("Closer", "plus.magnifyingglass") { lobby.zoomCamera(0.8) }
                control("Further", "minus.magnifyingglass") { lobby.zoomCamera(1.2) }
                control(lobby.paused ? "Resume" : "Pause", lobby.paused ? "play.fill" : "pause.fill", selected: lobby.paused) { lobby.paused.toggle() }
                control("Still mode", "snowflake", selected: lobby.still) { lobby.still.toggle() }
                control("Sounds", "speaker.wave.2", selected: lobby.sounds) { lobby.sounds.toggle() }
            }.frame(height: 80).disabled(!lobby.ready).focusSection()
        }.padding(36).background(Color(red: 0.98, green: 0.97, blue: 0.95))
            .foregroundStyle(ink).preferredColorScheme(.light)
            .confirmationDialog("Invite a companion", isPresented: $choosingCompanion) {
                ForEach(lobby.availableCompanions) { companion in Button(companion.name) { lobby.addCompanion(companion) } }
            }
            .onPlayPauseCommand { lobby.paused.toggle() }
            .task { await verifyRuntimeIfRequested() }
            .task(id: lobby.shouldAnimate) { if lobby.shouldAnimate { await lobby.animate() } else { lobby.refreshGates() } }
            .onChange(of: scenePhase, initial: true) { lobby.backgrounded = scenePhase != .active; lobby.refreshGates() }
            .onChange(of: reduceMotion, initial: true) { lobby.reduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"); lobby.refreshGates() }
            .onChange(of: lobby.paused) { lobby.refreshGates() }
            .onChange(of: lobby.still) { lobby.refreshGates() }
            .onChange(of: lobby.sounds) { lobby.refreshGates() }
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
    private func control(_ title: String, _ symbol: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 25, weight: .medium)).frame(width: 48, height: 36) }
            .buttonStyle(.bordered).tint(Color(red: 0.84, green: 0.81, blue: 0.91))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? ink : .clear, lineWidth: 3))
            .accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
