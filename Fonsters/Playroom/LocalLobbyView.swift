#if os(macOS)
import SwiftUI
import RealityKit
import AppKit
import UniformTypeIdentifiers

@available(macOS 15.0, *)
struct LocalLobbyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var lobby = LocalLobbyController()
    @State private var interpreter = TypedActionInterpreter()
    @State private var typingRequest = false
    @FocusState private var cameraFocused: Bool
    @State private var controlHistory = FonsterControlHistory<LocalLobbyController.ControlState>()
    @State private var showsCommand = false
    @State private var agentStudio = false
    @State private var initialAgentStudioShown = false
    @State private var socialStudio = false
    @State private var initialSocialStudioShown = false
    @State private var sharing = false
    @State private var importing = false
    @State private var reviewing = false
    @State private var pendingCard: FonsterVisitCard?
    @State private var importError: String?
    private let ink = FonsterChrome.primary
    private let accent = Color(red: 0.45, green: 0.32, blue: 0.62)

    var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.94, blue: 0.87).ignoresSafeArea()
            LobbyStageView(lobby: lobby).id(lobby.roomRevision).ignoresSafeArea()
                .accessibilityIdentifier("worldStage")
            if let error = lobby.error { Text(error).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
            VStack(spacing: 12) {
            HStack(spacing: 12) {
                FonsterControlPanel(title: "Companions and feelings", symbol: "person.2", tone: .company) { companionRail }
                LobbyWorldToolbar(lobby: lobby, typing: typingRequest)
                Spacer()
                FonsterControlPanel(title: "World notebook", symbol: "person.crop.circle.badge.plus", tone: .company) {
                    FonsterControlGroup(title: "Profiles, agents and visits", tone: .company) {
                        VStack(alignment: .leading, spacing: 12) {
                FonsterAgentStatus(lobby: lobby) { agentStudio = true }
                FonsterIconButton(title: "Local Fonster profiles and moments", symbol: "sparkles.rectangle.stack", tone: .company) { socialStudio = true }
                FonsterControlPanel(title: "Add a local Fonster", symbol: "plus", tone: .world) {
                    FonsterControlGroup(title: "New companions", tone: .company) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(68)), count: 3), spacing: 12) {
                            ForEach(lobby.availableCompanions) { fixture in
                                FonsterPortraitChoice(name: "Add " + fixture.name, selected: false,
                                    detail: "Adds a local companion to this world. Undo returns to your previous selection; the companion stays in the world.",
                                    portrait: { CreatureAvatarView(seed: fixture.seed, size: 48) }, action: { interpreter.cancel(); lobby.addCompanion(fixture) })
                            }
                        }
                    }
                }.disabled(lobby.availableCompanions.isEmpty || !lobby.ready)
                FonsterIconButton(title: "Save a Fonster visit file", symbol: "square.and.arrow.up", tone: .world) { sharing = true }.disabled(lobby.selectedMember.isVisitor)
                FonsterIconButton(title: "Invite a Fonster from a visit file", symbol: "person.crop.circle.badge.plus", tone: .world) { importing = true }
                if lobby.hasVisitor { FonsterIconButton(title: "End the local visit", symbol: "person.crop.circle.badge.minus") { interpreter.cancel(); lobby.endVisit() } }
                        }
                    }
                }
            }.background(VerificationHUDMarker())
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                FonsterControlGroup(title: "Friends", tone: .company) {
                    roomButton("Wave to a friend", "hand.wave", .company) { lobby.waveToFriend() }
                    roomButton("Pass the ball with your chosen friend", "tennisball", .play) { lobby.pair(quiet: false) }
                    roomButton("Stop activity", "stop.fill", .quiet) { lobby.stopActivity() }
                }
                FonsterControlPanel(title: "More activities", symbol: "ellipsis", tone: .play) {
                    FonsterControlGroup(title: "Shared activities", tone: .play) {
                        roomButton("Come closer", "person.3.sequence", .company) { lobby.gather() }
                        roomButton("Play together", "sparkles", .play) { lobby.playTogether() }
                        roomButton("Sit with your chosen friend", "heart", .company) { lobby.pair(quiet: true) }
                        roomButton("Rest on a bench", "chair.lounge", .world) { lobby.sitOnBench() }
                    }
                }
                FonsterIconButton(title: "Type a request", symbol: "text.bubble", tone: .world, selected: showsCommand) { showsCommand.toggle() }
                FonsterControlPanel(title: "Sound and motion", symbol: "slider.horizontal.3") {
                    FonsterControlGroup(title: "Sound and motion") {
                        FonsterIconToggle(title: "Sounds", symbol: "speaker.wave.2", isOn: $lobby.sounds)
                        FonsterIconToggle(title: "Wander and mingle", symbol: "figure.walk", isOn: Binding(get: { lobby.wander }, set: { lobby.setWander($0) }))
                        FonsterIconToggle(title: "Still mode", symbol: "snowflake", isOn: Binding(get: { lobby.still }, set: { lobby.takeOwnerControl(); lobby.still = $0 }))
                    }
                }
                Spacer(minLength: 0)
                FonsterIconButton(title: "Undo last control change", symbol: "arrow.uturn.backward") { if let state = controlHistory.undo() { lobby.restoreControls(state) } }
                    .disabled(!controlHistory.canUndo).keyboardShortcut("z", modifiers: .command).accessibilityIdentifier("undoWorldControls")
                FonsterIconButton(title: lobby.paused ? "Resume" : "Pause", symbol: lobby.paused ? "play.fill" : "pause.fill", selected: lobby.paused) { lobby.takeOwnerControl(); lobby.paused.toggle() }
                    .keyboardShortcut(typingRequest ? nil : KeyboardShortcut(.space, modifiers: []))
            }.background(VerificationHUDMarker())
            if showsCommand {
                CreatureCommandBar(interpreter: interpreter, selected: lobby.selectedMember.name, names: lobby.names, revision: lobby.userRevision,
                    enabled: lobby.ready && !lobby.paused && !lobby.backgrounded && !lobby.lowPower,
                    currentRevision: { lobby.userRevision }, apply: { lobby.execute($0) },
                    onFocusChange: { typingRequest = $0; if $0 { lobby.takeOwnerControl() } }).background(VerificationHUDMarker())
            }
            HStack(spacing: 8) {
                FonsterStatus(symbol: "heart", detail: lobby.message, tone: .company)
                if lobby.presence.running {
                    FonsterIconButton(title: "Pause local profile agent: \(lobby.presence.message)", symbol: "sparkles", tone: .company, selected: true) { lobby.presence.stop(lobby: lobby) }
                }
                Spacer()
                FonsterStatus(symbol: lobby.shouldAnimate ? "waveform.path" : "pause.circle", detail: lobby.motionStatus)
                FonsterInfo(title: "About this world", detail: lobby.growthDescription + "\nStroke a Fonster or click a path to walk. Drag empty space to orbit in both directions; Shift-drag pans and Option-drag orbits even over a Fonster. Pinch zooms. Arrow keys orbit; W A S D pan, Q E move vertically, + / − zoom, and 0 restores the overview. Hold Shift for faster keyboard travel.\n" + (lobby.worldTemporaryReason ?? lobby.social.status) + "\nProfiles, feelings, and friendship memories stay local. No public platform or external agent is connected.")
            }.background(VerificationHUDMarker())
            }.padding(16).padding(.top, 24)
        }
        .frame(minWidth: 760, maxWidth: .infinity, minHeight: 540, maxHeight: .infinity)
        .foregroundStyle(ink)
        .focusable().focusEffectDisabled().focused($cameraFocused)
        .onKeyPress(phases: [.down, .repeat]) { press in
            guard !typingRequest, !(agentStudio || socialStudio || sharing || reviewing || importing) else { return .ignored }
            return lobby.cameraKey(press.key, modifiers: press.modifiers) ? .handled : .ignored
        }
        .onAppear { cameraFocused = true }
        .task { await verifyCameraKeyboardIfRequested() }
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .background(VerificationWindowCapture(label: "lobby").frame(width: 0, height: 0))
        .sheet(isPresented: $agentStudio) { FonsterAgentStudio(lobby: lobby) }
        .sheet(isPresented: $socialStudio) { FonsterSocialStudio(lobby: lobby) }
        .sheet(isPresented: $sharing) { VisitShareSheet(lobby: lobby, member: lobby.selectedMember) }
        .sheet(isPresented: $reviewing) {
            if let card = pendingCard { VisitReviewSheet(card: card) { interpreter.cancel(); try lobby.invite(card) } }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                pendingCard = try FonsterVisitDocument.readSelectedFile(url); reviewing = true
            } catch {
                if (error as NSError).code != NSUserCancelledError {
                    importError = (error as? VisitCardError)?.localizedDescription ?? "The selected visit file couldn't be opened."
                }
            }
        }
        .alert("Couldn't invite this Fonster", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") { importError = nil }
        } message: { Text(importError ?? "") }
        .task(id: lobby.shouldAnimate) {
            if lobby.shouldAnimate { await lobby.animate() } else { lobby.refreshGates() }
        }
        .onChange(of: reduceMotion, initial: true) { lobby.reduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"); lobby.refreshGates() }
        .onChange(of: scenePhase, initial: true) { lobby.backgrounded = scenePhase != .active; lobby.refreshGates() }
        .onChange(of: lobby.paused) { lobby.refreshGates() }
        .onChange(of: lobby.still) { lobby.refreshGates() }
        .onChange(of: lobby.lowPower) { lobby.refreshGates() }
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
        .onChange(of: lobby.roomRevision) { interpreter.cancel() }
        .onChange(of: agentStudio || socialStudio || sharing || reviewing || importing) {
            lobby.reviewingControls = agentStudio || socialStudio || sharing || reviewing || importing
            lobby.refreshGates()
        }
        .onChange(of: lobby.ready) {
            if lobby.ready && !initialAgentStudioShown && ProcessInfo.processInfo.arguments.contains("--agent-studio") { initialAgentStudioShown = true; agentStudio = true }
            if lobby.ready && !initialSocialStudioShown && ProcessInfo.processInfo.arguments.contains("--presence-studio") { initialSocialStudioShown = true; socialStudio = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
            lobby.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onDisappear {
            interpreter.cancel(); lobby.presence.stop(lobby: lobby); lobby.agent.revoke(lobby: lobby); lobby.ready = false; lobby.containers = []; lobby.ball = nil; lobby.camera = nil; lobby.fountainDrops = []
            for member in lobby.members { member.controller.silence(); member.controller.rig = nil; member.controller.rendererReady = false }
        }
    }
    /// Opt-in verification sends events only to this app's own window. It does
    /// not change system accessibility permissions or control other applications.
    private func verifyCameraKeyboardIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--camera-ui-verification-file"), i + 1 < args.count else { return }
        for _ in 0..<600 {
            if lobby.ready { break }
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        cameraFocused = true
        try? await Task.sleep(for: .milliseconds(400))
        guard let window = NSApplication.shared.keyWindow else { return }
        var checks: [String: Bool] = ["ready": lobby.ready]
        let keys: [(String, UInt16)] = [("w", 13), ("a", 0), ("s", 1), ("d", 2), ("q", 12), ("e", 14), ("+", 24), ("-", 27), (String(UnicodeScalar(NSUpArrowFunctionKey)!), 126), (String(UnicodeScalar(NSDownArrowFunctionKey)!), 125), (String(UnicodeScalar(NSLeftArrowFunctionKey)!), 123), (String(UnicodeScalar(NSRightArrowFunctionKey)!), 124)]
        for (index, key) in keys.enumerated() {
            lobby.showOverview(); let before = lobby.controls
            if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: key.0, charactersIgnoringModifiers: key.0, isARepeat: false, keyCode: key.1) { window.sendEvent(event) }
            try? await Task.sleep(for: .milliseconds(100))
            checks["keyboard_" + String(index)] = lobby.controls != before
        }
        if let content = window.contentView {
            func findStage(_ view: NSView) -> NSView? {
                if view is VerificationSceneMarker.MarkerView { return view }
                for child in view.subviews { if let stage = findStage(child) { return stage } }
                return nil
            }
            if let stage = findStage(content) {
                let sceneRect = stage.convert(stage.bounds, to: content)
                checks["fullWindowViewport"] = sceneRect.width >= content.bounds.width - 2 && sceneRect.height >= content.bounds.height - 2
            } else { checks["fullWindowViewport"] = false }
        }
        lobby.showOverview()
        let result: [String: Any] = ["checks": checks, "passed": checks.values.allSatisfy { $0 }, "inputProvenance": "NSEvents delivered to this app's own native window; no physical keyboard assertion"]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: args[i + 1]), options: .atomic)
        }
    }
    private var companionRail: some View {
        VStack(spacing: 14) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.fixed(68)), GridItem(.fixed(68))], spacing: 12) {
                    ForEach(Array(lobby.members.enumerated()), id: \.element.id) { index, member in
                        FonsterPortraitChoice(name: "\(member.name), \(member.feelingLabel)", selected: lobby.selected == index,
                            portrait: { ResolvedPortrait(appearance: member.descriptor) }, action: { lobby.selected = index })
                    }
                }.padding(4)
            }.frame(maxHeight: 252)
            Divider()
            if lobby.selectedMember.isVisitor {
                FonsterStatus(symbol: "person.crop.circle.badge.checkmark", detail: lobby.selectedMember.feelingLabel, tone: .company)
            } else {
                FonsterControlPanel(title: "Choose a feeling", symbol: lobby.selectedMember.controller.feeling.symbol, tone: .company) {
                    FonsterControlGroup(title: "Feelings", tone: .company) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 3), spacing: 8) {
                            ForEach(CreatureFeeling.allCases) { feeling in
                                FonsterIconButton(title: "Choose \(feeling.title.lowercased())", symbol: feeling.symbol, tone: .company, selected: lobby.selectedMember.controller.feeling == feeling) { lobby.chooseFeeling(feeling) }
                            }
                        }.accessibilityLabel("Chosen Fonster feeling")
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ResolvedPortrait(appearance: lobby.selectedMember.descriptor).frame(width: 36, height: 36)
                FonsterStatus(symbol: "heart", detail: lobby.selectedFriendship.description, tone: .company)
                FonsterControlPanel(title: "Choose a friend", symbol: "person.2", tone: .company) {
                    FonsterControlGroup(title: "Chosen friend", tone: .company) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(68)), count: 3), spacing: 12) {
                            ForEach(lobby.members.indices.filter { $0 != lobby.selected }, id: \.self) { i in
                                FonsterPortraitChoice(name: lobby.names[i], selected: lobby.peerIndex == i,
                                    portrait: { ResolvedPortrait(appearance: lobby.members[i].descriptor) }, action: { lobby.buddy = i })
                            }
                        }
                    }
                }
            }
        }.padding(16).frame(width: 260, height: 440)
            .background(FonsterChrome.surface, in: RoundedRectangle(cornerRadius: 24))
    }
    private func roomButton(_ title: String, _ icon: String, _ tone: FonsterTone, action: @escaping () -> Void) -> some View {
        FonsterIconButton(title: title, symbol: icon, tone: tone, action: action).disabled(!lobby.ready)
    }

}

@available(macOS 15.0, *)
private struct LobbyWorldToolbar: View {
    let lobby: LocalLobbyController
    let typing: Bool
    var body: some View {
        HStack(spacing: 12) {
            FonsterControlPanel(title: "World areas", symbol: lobby.focusArea?.symbol ?? "map", tone: .world) {
                FonsterControlGroup(title: "World areas", tone: .world) {
                ForEach(LobbyWorld.Area.allCases) { area in
                    let unlocked = lobby.world.areas.contains(area)
                    FonsterIconButton(title: unlocked ? "Explore \(area.title) with your chosen friend" : "\(area.title) opens at \(area.population) Fonsters", symbol: area.symbol, tone: .world, selected: lobby.focusArea == area && unlocked,
                                      detail: unlocked ? "Walk into this area and look around. Undo restores the preceding camera view; Stop activity ends the walk." : "Add local companions to grow this world and open the area.") { lobby.explore(area) }
                        .overlay(alignment: .bottomTrailing) {
                            if !unlocked { Label("\(area.population)", systemImage: "lock.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(FonsterChrome.primary).padding(4).background(FonsterChrome.surface, in: Capsule()).allowsHitTesting(false) }
                        }
                        .disabled(!unlocked || !lobby.ready || lobby.paused || lobby.backgrounded || lobby.lowPower)
                }
            }
                }
            FonsterControlPanel(title: "Camera controls", symbol: "rotate.3d", tone: .world) {
                FonsterControlGroup(title: "Camera", tone: .world) {
                VStack(alignment: .leading, spacing: 10) {
                HStack {
                FonsterIconButton(title: "Whole world", symbol: "map", tone: .world) { lobby.showOverview() }
                FonsterIconButton(title: "Follow \(lobby.selectedMember.name)", symbol: "viewfinder", tone: .world) { lobby.lookAtSelected() }
                FonsterIconButton(title: "Rest on a bench", symbol: "chair.lounge", tone: .world) { lobby.sitOnBench() }
                    .disabled(lobby.world.benches.isEmpty || lobby.paused || lobby.backgrounded || lobby.lowPower)
                }
                HStack {
                FonsterIconButton(title: "Turn camera left", symbol: "arrow.counterclockwise", tone: .world) { lobby.rotateCamera(-0.30) }
                    .keyboardShortcut(typing ? nil : KeyboardShortcut("[", modifiers: []))
                FonsterIconButton(title: "Turn camera right", symbol: "arrow.clockwise", tone: .world) { lobby.rotateCamera(0.30) }
                    .keyboardShortcut(typing ? nil : KeyboardShortcut("]", modifiers: []))
                FonsterIconButton(title: "Zoom out", symbol: "minus.magnifyingglass", tone: .world) { lobby.zoomCamera(1.15) }
                FonsterIconButton(title: "Zoom in", symbol: "plus.magnifyingglass", tone: .world) { lobby.zoomCamera(0.85) }
                }
                HStack {
                    FonsterIconButton(title: "Tilt camera up", symbol: "arrow.up", tone: .world) { lobby.rotateCamera(0, vertical: 0.10) }
                    FonsterIconButton(title: "Tilt camera down", symbol: "arrow.down", tone: .world) { lobby.rotateCamera(0, vertical: -0.10) }
                    FonsterIconButton(title: "Raise camera", symbol: "arrow.up.to.line", tone: .world) { lobby.panCamera([0, 0.3, 0]) }
                    FonsterIconButton(title: "Lower camera", symbol: "arrow.down.to.line", tone: .world) { lobby.panCamera([0, -0.3, 0]) }
                }
                HStack {
                    FonsterIconButton(title: "Pan camera left", symbol: "arrow.left", tone: .world) { _ = lobby.cameraKey("a", modifiers: []) }
                    FonsterIconButton(title: "Pan camera right", symbol: "arrow.right", tone: .world) { _ = lobby.cameraKey("d", modifiers: []) }
                    FonsterIconButton(title: "Pan camera forward", symbol: "arrow.up.forward", tone: .world) { _ = lobby.cameraKey("w", modifiers: []) }
                    FonsterIconButton(title: "Pan camera back", symbol: "arrow.down.backward", tone: .world) { _ = lobby.cameraKey("s", modifiers: []) }
                }
                }
                }
            }.disabled(!lobby.ready)
        }

    }
}

#endif
