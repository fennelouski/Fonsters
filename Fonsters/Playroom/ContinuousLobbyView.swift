#if os(macOS) || os(iOS)
import SwiftUI
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

nonisolated struct LobbyVisitExport: Transferable, Sendable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .json) { $0.data } }
}

/// One scene owns browsing, spatial search and care. HUD changes never replace
/// its native renderer; other creatures retain their simulation routes.
@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
struct ContinuousLobbyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var pendingImportURL: PendingImportURLHolder
    @Query(sort: \Fonster.createdAt, order: .reverse) private var saved: [Fonster]
    @State private var lobby = LocalLobbyController()
    @State private var interpreter = TypedActionInterpreter()
    @State private var inputs = CreatureInputs()
    @State private var parentGate = ParentActionGate()
    @State private var inputParentGate = ParentActionGate()
    @State private var privacy = false
    @State private var lesson: CreatureImitationLesson?
    @State private var learnedUndo: CreatureMovementStyle?
    @State private var canUndoLearning = false
    @State private var fixtureTask: Task<Void, Never>?
    @State private var didPreviewDance = false
    @State private var searching = false
    @State private var query = ""
    @State private var gallery = false
    @State private var sharing = false
    @State private var agents = false
    @State private var profiles = false
    @State private var command = false
    @State private var typing = false
    @State private var editor: FonsterEditorTarget?
    @State private var focusAfterSave: UUID?
    @State private var libraryError: String?
    @State private var availableStageHeight: CGFloat = 1
    @State private var history = FonsterControlHistory<LocalLobbyController.ControlState>()
    @FocusState private var searchFocused: Bool
    @FocusState private var stageFocused: Bool
    private var library: [Fonster] { PersonalFonsterLibrary.canonical(saved) }
    private var roster: [LocalLobbyController.SavedAppearance] { library.map { .init(id: $0.id, name: $0.name, seed: $0.seed, biography: $0.biography) } }
    private var blocked: Bool { !lobby.ready || lobby.paused || lobby.backgrounded || lobby.lowPower || lobby.reviewingControls }
    private var reviewing: Bool { gallery || sharing || agents || profiles || editor != nil || privacy || parentGate.challenge != nil || inputParentGate.challenge != nil }
    private var inputsSuspended: Bool { blocked || !lobby.inCare || typing || searchFocused }

    var body: some View {
        presentations
            .parentActions(parentGate)
            #if os(iOS)
            .phoneOrientation(lobby.inCare || reviewing ? .details : .lobby)
            #endif
    }
    private var stageAndKeyboard: some View {
        ZStack {
            (lobby.danceMode == .daylight ? Color(red: 0.91, green: 0.94, blue: 0.87) : Color(red: 0.075, green: 0.07, blue: 0.14)).ignoresSafeArea()
            LobbyStageView(lobby: lobby).id(lobby.roomRevision).ignoresSafeArea()
                .accessibilityIdentifier("continuousStage")
            hud
            if let error = lobby.error { Text(error).padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
        }
        .fontDesign(.rounded)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in availableStageHeight = height; updateVisibleStage() }
        .onChange(of: searchFocused) { updateVisibleStage() }
        .onChange(of: lobby.searchQuery) { _, value in
            // A delayed model observation during rotation must not restore a
            // query the owner just cleared.
            guard value == lobby.searchQuery else { return }
            if query != value { query = value; searching = !value.isEmpty }
        }
        .focusable().focused($stageFocused)
        .onKeyPress(phases: [.down, .repeat]) { press in
            guard !searchFocused && !typing && !gallery && !sharing && !agents && !profiles && editor == nil else { return .ignored }
            if press.key == .escape { if lobby.inCare { lobby.returnToLobby() } else { closeSearch() }; return .handled }
            if press.key == .return, !lobby.inCare, let first = lobby.searchMatches.first { lobby.openCare(first); return .handled }
            if press.key == .tab { return .ignored }
            return lobby.cameraKey(press.key, modifiers: press.modifiers) ? .handled : .ignored
        }
    }
    private var lifecycle: some View {
        stageAndKeyboard
        .onChange(of: roster, initial: true) { lobby.continuousGallery = true; lobby.showSaved(roster); lobby.search(query) }
        .task { await openPersonalLibrary() }
        .task(id: lobby.ready) {
            let arguments = ProcessInfo.processInfo.arguments
            if lobby.ready, !didPreviewDance, let index = arguments.firstIndex(of: "--dance-preview"), index + 1 < arguments.count,
               let mode = FonsterDanceMode(rawValue: arguments[index + 1]) {
                didPreviewDance = true
                if arguments.contains("--dance-preview-care") { lobby.openCare(0) }
                lobby.setDanceMode(mode)
            }
            if lobby.ready, let id = focusAfterSave,
               let record = roster.firstIndex(where: { $0.id == id }) {
                focusAfterSave = nil; lobby.openCare(record)
            }
        }
        .task(id: lobby.shouldAnimate) { if lobby.shouldAnimate { await lobby.animate() } else { lobby.refreshGates() } }
        .onChange(of: reduceMotion, initial: true) { lobby.reduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"); lobby.refreshGates() }
        .onChange(of: scenePhase, initial: true) { lobby.backgrounded = scenePhase != .active; lobby.refreshGates() }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lobby.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled; lobby.refreshGates() }
        .onChange(of: lobby.controls) { old, new in history.record(old: old, new: new); lobby.refreshGates() }
        .onChange(of: query) { lobby.search(query) }
    }
    private var inputLifecycle: some View {
        lifecycle
        .onChange(of: lobby.inCare) { searchFocused = false; stageFocused = true; command = false; interpreter.cancel(); stopLiveActivity() }
        .onChange(of: lobby.selected) { stopLiveActivity(); canUndoLearning = false }
        .onChange(of: inputsSuspended, initial: true) { inputs.setSuspended(inputsSuspended); if inputsSuspended { cancelLesson(); lobby.selectedMember.controller.clearMirror() } }
        .onChange(of: inputs.microphoneEnabled) { if inputs.microphoneEnabled { for member in lobby.members { member.controller.silence() } }; lobby.listening = inputs.microphoneEnabled; lobby.refreshGates() }
        .onChange(of: inputs.cameraEnabled) { if !inputs.cameraEnabled { lobby.selectedMember.controller.clearMirror(); if lesson?.kind != .voice { cancelLesson() } } }
        .onAppear { connectInputs() }
        .onChange(of: pendingImportURL.url, initial: true) { if pendingImportURL.url != nil { gallery = true } }
        .onChange(of: reviewing) { _, showing in
            lobby.reviewingControls = showing
            if showing { lobby.takeOwnerControl(); interpreter.cancel() }
            lobby.refreshGates()
        }
    }
    private var presentations: some View {
        inputLifecycle
        .sheet(item: $editor) { target in
            FonsterProfileEditor(record: target.record) { id in if target.record == nil { focusAfterSave = id } }
                #if os(iOS)
                .phoneOrientation(.details)
                #endif
        }
        .sheet(isPresented: $gallery) {
            VStack(spacing: 0) {
                HStack { Spacer(); FonsterIconButton(title: "Back to lobby", symbol: "xmark") { gallery = false } }.padding(12)
                ParentOnlyArea(purpose: "Review original seed links, imports and portrait exports before sharing outside Fonsters.") {
                    ContentView(initialSelectionID: lobby.inCare ? lobby.selectedSavedID : nil)
                }
            }
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
            #endif
        }
        .sheet(isPresented: $sharing) {
            LobbyVisitShare(lobby: lobby)
                #if os(iOS)
                .phoneOrientation(.details)
                #endif
        }
        .sheet(isPresented: $privacy) { FamilyPrivacyView() }
        #if os(macOS)
        .sheet(isPresented: $agents) { FonsterAgentStudio(lobby: lobby) }
        .sheet(isPresented: $profiles) { FonsterSocialStudio(lobby: lobby) }
        #endif
        #if os(macOS)
        .task { await verifyCameraKeyboardIfRequested() }
        #endif
        .onDisappear { stopLiveActivity(); lobby.backgrounded = true; lobby.cancelContact(); lobby.refreshGates(); interpreter.cancel() }
    }
    private func openPersonalLibrary() async {
        do { try await PersonalFonsterLibrary.ensureStarters(in: modelContext); libraryError = nil }
        catch { libraryError = error.localizedDescription }
    }

    #if os(macOS)
    private func verifyCameraKeyboardIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--camera-ui-verification-file"), i + 1 < args.count else { return }
        for _ in 0..<600 {
            if lobby.ready { break }
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        stageFocused = true
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
    #endif
    private var hud: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                if lobby.inCare {
                    FonsterIconButton(title: "Back to lobby", symbol: "chevron.left", tone: .world,
                        detail: "Bring everyone back and resume their previous activities in this same world.") { lobby.returnToLobby() }
                        .accessibilityIdentifier("backToLobby")
                } else {
                    HStack(spacing: 10) {
                    FonsterIconButton(title: "Create a Fonster", symbol: "plus", tone: .company, detail: "Choose a fuzzy appearance and a name. Save adds it to your library; X cancels.") { editor = .init(record: nil) }
                        .accessibilityIdentifier("createFonster")
                    FonsterControlPanel(title: "Lobby", symbol: "person.3", tone: .company) {
                        companionChoices
                        FonsterControlGroup(title: "Library and company", tone: .company) {
                            FonsterIconButton(title: "Original portrait gallery and exports", symbol: "square.grid.2x2") { gallery = true }
                            FonsterIconButton(title: "Play together", symbol: "tennisball", tone: .play) { lobby.playTogether() }.disabled(blocked)
                            #if os(macOS)
                            if ProtectedPlayPolicy.allowsPublicSocialProfiles {
                                FonsterIconButton(title: "Local profiles", symbol: "sparkles.rectangle.stack", tone: .company) { profiles = true }
                            }
                            #endif
                        }
                        if let libraryError {
                            Text(libraryError).font(.callout)
                            FonsterIconButton(title: "Retry iCloud library", symbol: "arrow.clockwise") { Task { await openPersonalLibrary() } }
                        }
                    }
                    }
                }
                Spacer(minLength: 8)
                if lobby.inCare {
                    FonsterIconButton(title: "Share Fonster", symbol: "square.and.arrow.up", tone: .company,
                        detail: "A grown-up reviews the snapshot before sharing. Recipients can keep a copy.") {
                        parentGate.request("Review this Fonster snapshot before sharing. Backstory and feelings are optional; recipients can keep a copy.") { sharing = true }
                    }
                        .accessibilityIdentifier("shareFonster")
                } else { searchControl }
            }
            HStack {
                if lobby.inCare { aspects }
                Spacer(minLength: 0)
                if lobby.inCare { reactions }
            }
            Spacer(minLength: 0)
            if command {
                CreatureCommandBar(interpreter: interpreter, selected: lobby.selectedMember.name, names: lobby.names, revision: lobby.userRevision,
                    enabled: !blocked, currentRevision: { lobby.userRevision }, apply: { lobby.execute($0) },
                    onFocusChange: { typing = $0; if $0 { lobby.takeOwnerControl() } })
            }
            HStack(alignment: .bottom) {
                FonsterIconButton(title: "Privacy and family", symbol: "hand.raised", tone: .quiet,
                    detail: "Read the privacy policy for this protected play experience. No account is needed.") { privacy = true }
                    .accessibilityIdentifier("familyPrivacyButton")
                FonsterControlPanel(title: "World and camera", symbol: "rotate.3d", tone: .world) { cameraControls }
                FonsterControlPanel(title: "Dance world", symbol: "music.note", tone: .play) { danceControls }
                Spacer(minLength: 4)
                if lobby.inCare {
                    Text(lobby.selectedMember.name).font(.headline).padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule()).accessibilityIdentifier("careName")
                } else if !query.isEmpty {
                    Image(systemName: lobby.searchMatches.isEmpty ? "questionmark.circle" : "scope")
                        .foregroundStyle(FonsterTone.company.ink).padding(12).background(.regularMaterial, in: Circle())
                        .accessibilityLabel(lobby.searchMatches.isEmpty ? "No matching Fonsters" : "Front match: " + lobby.names[lobby.searchMatches[0]])
                        .accessibilityValue(lobby.searchMatches.map { lobby.names[$0] }.joined(separator: ", "))
                        .accessibilityIdentifier("searchResults")
                }
                Spacer(minLength: 4)
                FonsterIconButton(title: "Undo last control change", symbol: "arrow.uturn.backward") { if let state = history.undo() { lobby.restoreControls(state) } }
                    .disabled(!history.canUndo).accessibilityIdentifier("undoLobbyControls")
                FonsterIconButton(title: lobby.paused ? "Resume" : "Pause", symbol: lobby.paused ? "play.fill" : "pause.fill", selected: lobby.paused) { lobby.takeOwnerControl(); lobby.paused.toggle() }
                    .accessibilityIdentifier("pauseLobby")
            }
        }.padding(16)
    }

    private var searchControl: some View {
        HStack(spacing: 6) {
            if searching {
                TextField("Find a Fonster", text: $query).textFieldStyle(.plain).focused($searchFocused)
                    .frame(maxWidth: 230).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel("Find a Fonster").accessibilityIdentifier("lobbySearchField")
                    .onSubmit { searchFocused = false; stageFocused = true; if let first = lobby.searchMatches.first { lobby.openCare(first) } }
                FonsterIconButton(title: "Clear and close search", symbol: "xmark", tone: .company) { closeSearch() }
            }
            FonsterIconButton(title: "Search Fonsters", symbol: "magnifyingglass", tone: .company, selected: searching,
                detail: "Matching Fonsters line up in the center. Others wait at the sides. Clear search to restore the lobby.") {
                if searching { closeSearch() } else { searching = true; searchFocused = true }
            }.accessibilityIdentifier("searchFonsters")
        }.animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: searching)
    }
    private func updateVisibleStage() {
        lobby.visibleStageFraction = searchFocused ? min(1, max(0.25, Float(availableStageHeight) / max(1, lobby.viewportHeight))) : 1
        lobby.updateCamera()
    }
    private func closeSearch() { query = ""; searching = false; searchFocused = false; stageFocused = true; lobby.search("") }

    private var companionChoices: some View {
        FonsterControlGroup(title: "Meet a Fonster", tone: .company) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 68))], spacing: 12) {
                ForEach(Array(lobby.members.enumerated()), id: \.element.id) { index, member in
                    FonsterPortraitChoice(name: "Meet " + member.name, selected: false,
                        detail: "Center this Fonster and open its care controls. Back brings everyone into the lobby again.",
                        portrait: { LobbyPortrait(appearance: member.descriptor).frame(width: 48, height: 48) }, action: { lobby.openCare(index) })
                        .accessibilityIdentifier("meet_" + member.name)
                }
            }.frame(minWidth: 240)
        }
    }
    private var aspects: some View {
        VStack(spacing: 10) {
            LobbyPortrait(appearance: lobby.selectedMember.descriptor).frame(width: 48, height: 48)
                .padding(6).background(FonsterTone.company.wash, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement().accessibilityLabel("Original portrait of " + lobby.selectedMember.name)
            FonsterControlPanel(title: "Mirror and voice", symbol: inputs.cameraEnabled || inputs.microphoneEnabled ? "person.crop.circle.badge.checkmark" : "hand.draw", tone: .company) { liveControls.parentActions(inputParentGate) }
            if let id = lobby.selectedSavedID, let record = library.first(where: { $0.id == id }) {
                FonsterIconButton(title: "Name and backstory", symbol: "book.closed", tone: .company,
                    detail: "Name this Fonster and choose its backstory, likes, dislikes and favorites. Save keeps your changes; X leaves them as they were.") { editor = .init(record: record) }
                    .accessibilityIdentifier("editFonsterProfile")
            } else if !lobby.selectedBiography.isEmpty {
                FonsterControlPanel(title: "Backstory and favorites", symbol: "book.closed", tone: .company) {
                    FonsterBiographySummary(biography: lobby.selectedBiography)
                }
            }
            FonsterControlPanel(title: "Appearance and personality", symbol: "person.crop.circle", tone: .company) {
                HStack(spacing: 20) {
                    LobbyPortrait(appearance: lobby.selectedMember.descriptor).frame(width: 90, height: 90)
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                    Image(systemName: "sparkles").foregroundStyle(FonsterTone.company.ink).accessibilityHidden(true)
                }.accessibilityLabel("Exact original portrait beside the living 3D Fonster")
                if let reason = lobby.selectedMember.descriptor.fallbackReason { Text(reason).font(.callout) }
                if let personality = lobby.selectedMember.controller.personality { VStack(spacing: 12) {
                    HStack { Image(systemName: "heart.fill").foregroundStyle(FonsterTone.company.ink); ProgressView(value: personality.greetingWarmth).tint(FonsterTone.company.ink); FonsterInfo(title: "Greeting warmth", detail: personality.naturalQuirk) }.accessibilityLabel("Greeting warmth").accessibilityValue("\(Int(personality.greetingWarmth * 100)) percent")
                    HStack { Image(systemName: "tennisball.fill").foregroundStyle(FonsterTone.play.ink); ProgressView(value: personality.playEnergy).tint(FonsterTone.play.ink); FonsterInfo(title: "Shared rituals", detail: personality.observations(name: lobby.selectedMember.name).joined(separator: "\n")) }.accessibilityLabel("Play energy").accessibilityValue("\(Int(personality.playEnergy * 100)) percent")
                } }
                FonsterIconButton(title: "Original portrait gallery and exports", symbol: "square.grid.2x2") { gallery = true }
            }
            FonsterControlPanel(title: "Feelings", symbol: lobby.selectedMember.controller.feeling.symbol, tone: .company) {
                FonsterControlGroup(title: "Chosen feeling", tone: .company) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                        ForEach(CreatureFeeling.allCases, id: \.rawValue) { feeling in
                            FonsterIconButton(title: feeling.title, symbol: feeling.symbol, tone: .company, selected: lobby.selectedMember.controller.feeling == feeling) { lobby.chooseFeeling(feeling) }
                                .disabled(lobby.selectedMember.isVisitor)
                        }
                    }.frame(minWidth: 240)
                }
            }
            #if os(macOS)
            if ProtectedPlayPolicy.allowsExternalAgents || ProtectedPlayPolicy.allowsPublicSocialProfiles {
            FonsterControlPanel(title: "Profiles and agents", symbol: "sparkles.rectangle.stack", tone: .company) {
                FonsterControlGroup(title: "Profiles and agents", tone: .company) {
                    FonsterIconButton(title: "Local profiles", symbol: "sparkles.rectangle.stack") { profiles = true }
                    FonsterIconButton(title: "Agent controls", symbol: "sparkles") { agents = true }
                }
            }
            }
            #endif
            FonsterInfo(title: "Care aspects", detail: "The book opens name, backstory and favorites. The portrait opens appearance and learned personality. The feeling icon changes the emotion you choose. Your backstory stays private unless you include it when sharing.")
        }.padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
    private var reactions: some View {
        VStack(spacing: 10) {
            reaction(.greet, "hand.wave", .company)
            reaction(.play, "sparkles", .play)
            reaction(.rest, "moon", .quiet)
            FonsterControlPanel(title: "More interactions", symbol: "ellipsis", tone: .play) {
                FonsterControlGroup(title: "Reactions", tone: .play) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                        reaction(.hop, "arrow.up", .play); reaction(.highFive, "hand.raised", .company)
                        reaction(.rub, "heart", .company); reaction(.spin, "arrow.trianglehead.2.clockwise.rotate.90", .play)
                        reaction(.stretch, "figure.flexibility", .quiet); reaction(.blink, "eye", .quiet)
                    }.frame(minWidth: 240)
                }
                FonsterControlGroup(title: "Intent and activity") {
                    FonsterIconButton(title: "Type a request", symbol: "text.bubble", tone: .world) { command.toggle() }
                    FonsterIconButton(title: "Stop activity", symbol: "stop.fill") { lobby.stopActivity() }
                }
            }
            FonsterInfo(title: "Interact with your Fonster", detail: "Wave, play or rest. Stroke the face, belly or paws for different responses. More opens other reactions, typed requests and Stop. A new action interrupts the current one. Back brings companions into the lobby again.")
        }.padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
    private func reaction(_ action: PlayroomController.Reaction, _ symbol: String, _ tone: FonsterTone) -> some View {
        FonsterIconButton(title: action.rawValue.capitalized, symbol: symbol, tone: tone, detail: "Starts this reaction now. Another reaction replaces it; Stop activity ends it.") { stopLiveActivity(); lobby.perform(action) }
            .disabled(blocked || !lobby.selectedMember.descriptor.supported).accessibilityIdentifier("care_" + action.rawValue)
    }
    private func connectInputs() {
        inputs.onMirror = { sample in
            guard !inputsSuspended, !lobby.selectedMember.isVisitor else { return }
            let now = ProcessInfo.processInfo.systemUptime
            lobby.selectedMember.controller.receiveMirror(sample, time: now)
            if var rehearsal = lesson {
                rehearsal.observe(sample, time: now); lesson = rehearsal
                if rehearsal.ready { lobby.selectedMember.controller.movementPreview = rehearsal.draft }
            }
        }
        inputs.onCommand = { action in
            guard !inputsSuspended else { return }
            if var rehearsal = lesson, rehearsal.kind == .voice, action == .dance {
                rehearsal.observeVoice(time: ProcessInfo.processInfo.systemUptime); lesson = rehearsal
                if rehearsal.ready { lobby.selectedMember.controller.movementPreview = rehearsal.draft }
            }
            lobby.spoken(action)
        }
    }
    private func stopLiveActivity() { fixtureTask?.cancel(); fixtureTask = nil; inputs.stopAll(); cancelLesson(); lobby.selectedMember.controller.clearMirror() }
    private func cancelLesson() {
        if lesson != nil { lobby.selectedMember.controller.dancingContinuously = false }
        lesson = nil; lobby.selectedMember.controller.movementPreview = nil
    }
    private func startLesson(_ kind: CreatureImitationLesson.Kind) {
        guard !blocked, !lobby.selectedMember.isVisitor else { return }
        lobby.takeOwnerControl(); cancelLesson(); lesson = .init(kind: kind)
        lobby.selectedMember.controller.perform(kind == .wave ? .greet : .play, name: lobby.selectedMember.name, learn: false, audible: false)
        if kind != .wave { lobby.selectedMember.controller.dancingContinuously = true }
    }
    private var liveControls: some View {
        VStack(spacing: 16) {
            FonsterControlGroup(title: "Opt-in senses", tone: .company) {
                FonsterIconButton(title: inputs.cameraEnabled ? "Turn camera off" : "Enable camera mirror", symbol: inputs.cameraEnabled ? "video.fill" : "video", tone: .company, selected: inputs.cameraEnabled,
                    detail: "A grown-up enables this. Mirror blinks, head tilts and raised-hand waves. Camera frames stay on this device. Tap again to turn off.") {
                    if inputs.cameraEnabled { inputs.toggleCamera() }
                    else { inputParentGate.request("Enable camera mirroring on this device. No camera frames are saved or uploaded. You can turn it off at any time.") { lobby.takeOwnerControl(); inputs.toggleCamera(parentApproved: true) } }
                }
                    .disabled(blocked || lobby.selectedMember.isVisitor).accessibilityIdentifier("liveCamera")
                FonsterIconButton(title: inputs.microphoneEnabled ? "Turn microphone off" : "Enable spoken commands", symbol: inputs.microphoneEnabled ? "mic.fill" : "mic", tone: .company, selected: inputs.microphoneEnabled,
                    detail: "A grown-up enables this. Say wave, dance, sleep, jump, blink, spin, stretch or stop in English. Requires local speech support and device permission. No audio or words are saved or uploaded. Tap again to turn off.") {
                    if inputs.microphoneEnabled { inputs.toggleMicrophone() }
                    else { inputParentGate.request("Enable short spoken commands on this device. No audio or recognized words are saved or uploaded. Local English speech support is required.") { lobby.takeOwnerControl(); inputs.toggleMicrophone(parentApproved: true) } }
                }
                    .disabled(blocked || lobby.selectedMember.isVisitor).accessibilityIdentifier("liveMicrophone")
                FonsterIconButton(title: "Stop camera, microphone and practice", symbol: "stop.fill", tone: .quiet) { stopLiveActivity(); lobby.stopActivity() }.accessibilityIdentifier("stopLiveInputs")
            }
            if inputs.cameraEnabled || inputs.microphoneEnabled {
                HStack {
                    Image(systemName: inputs.cameraEnabled ? "video.fill" : "mic.fill").foregroundStyle(FonsterTone.company.ink)
                    if inputs.microphoneEnabled { ProgressView(value: Double(inputs.level)).tint(FonsterTone.company.ink) }
                    if let action = inputs.lastAction { Image(systemName: action.symbol).accessibilityLabel("Heard " + action.rawValue).accessibilityIdentifier("heardAction") }
                }.accessibilityElement(children: .contain).accessibilityLabel("Active inputs").accessibilityValue(inputs.status)
            }
            Text(inputs.status).font(.caption).foregroundStyle(.secondary).frame(maxWidth: 280).accessibilityIdentifier("liveInputStatus")
            FonsterControlGroup(title: "Learn together", tone: .play) {
                FonsterIconButton(title: "Practice a wave", symbol: "hand.wave", tone: .play, selected: lesson?.kind == .wave,
                    detail: "Enable the camera, then hold a hand above your shoulder and wave. The ring fills as your Fonster watches. Checkmark keeps the new wave; X discards it.") { startLesson(.wave) }.disabled(!inputs.cameraEnabled || blocked)
                    .accessibilityIdentifier("lessonWave")
                FonsterIconButton(title: "Practice a sway", symbol: "figure.dance", tone: .play, selected: lesson?.kind == .sway,
                    detail: "Enable the camera, then sway gently. The ring fills while you are in view. Checkmark keeps a bounded bounce and rhythm; X discards it.") { startLesson(.sway) }.disabled(!inputs.cameraEnabled || blocked)
                    .accessibilityIdentifier("lessonSway")
                FonsterIconButton(title: "Practice a voice rhythm", symbol: "waveform", tone: .play, selected: lesson?.kind == .voice,
                    detail: "Enable spoken commands, then say dance three times, with a pause between each. Your Fonster learns that rhythm. Only the timing is kept; no recording or voice imitation.") { startLesson(.voice) }.disabled(!inputs.microphoneEnabled || blocked)
                    .accessibilityIdentifier("lessonVoice")
            }
            if let lesson {
                HStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(FonsterTone.play.wash, lineWidth: 6)
                        Circle().trim(from: 0, to: lesson.progress).stroke(FonsterTone.play.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                        Image(systemName: lesson.kind == .wave ? "hand.wave" : lesson.kind == .sway ? "figure.dance" : "waveform")
                    }.frame(width: 48, height: 48).accessibilityLabel("Practice progress").accessibilityValue("\(Int(lesson.progress * 100)) percent").accessibilityIdentifier("lessonProgress")
                    FonsterIconButton(title: "Keep learned movement", symbol: "checkmark", tone: .play) {
                        learnedUndo = lobby.selectedMember.controller.personality?.learnedMoves; canUndoLearning = true
                        lobby.selectedMember.controller.keepMovementStyle(lesson.draft); self.lesson = nil
                    }.disabled(!lesson.ready).accessibilityIdentifier("keepLesson")
                    FonsterIconButton(title: "Discard practice", symbol: "xmark", tone: .quiet) { cancelLesson() }.accessibilityIdentifier("discardLesson")
                }
            }
            FonsterControlGroup(title: "Movement memory", tone: .quiet) {
                FonsterIconButton(title: "Undo learned movement", symbol: "arrow.uturn.backward", tone: .quiet) {
                    lobby.selectedMember.controller.keepMovementStyle(learnedUndo); canUndoLearning = false; cancelLesson()
                }.disabled(!canUndoLearning).accessibilityIdentifier("undoLesson")
                FonsterIconButton(title: "Reset learned movement", symbol: "arrow.counterclockwise", tone: .quiet) {
                    learnedUndo = lobby.selectedMember.controller.personality?.learnedMoves; canUndoLearning = true
                    lobby.selectedMember.controller.keepMovementStyle(nil); cancelLesson()
                }.disabled(lobby.selectedMember.controller.personality?.learnedMoves == nil).accessibilityIdentifier("resetLesson")
            }
            if ProcessInfo.processInfo.arguments.contains("--verify-live-inputs") { fixtureControls }
        }
    }
    private var fixtureControls: some View {
        FonsterControlGroup(title: "Synthetic fixtures · no capture") {
            FonsterIconButton(title: "Fixture sleep", symbol: "moon.zzz") { inputs.verifyCommand("sleep") }.accessibilityIdentifier("fixtureSleep")
            FonsterIconButton(title: "Fixture dance", symbol: "music.note") { inputs.verifyCommand("dance") }.accessibilityIdentifier("fixtureDance")
            FonsterIconButton(title: "Fixture open eyes", symbol: "eye") { inputs.verifyMirror(.init(eyeOpenness: 1)) }.accessibilityIdentifier("fixtureEyes")
            FonsterIconButton(title: "Fixture smile shape", symbol: "face.smiling") { faceFixture(smile: 0.9) }.accessibilityIdentifier("fixtureSmile")
            FonsterIconButton(title: "Fixture downturned mouth", symbol: "cloud") { faceFixture(smile: -0.65) }.accessibilityIdentifier("fixtureFrown")
            FonsterIconButton(title: "Fixture rehearsal", symbol: "hand.wave") {
                fixtureTask?.cancel()
                fixtureTask = Task { @MainActor in
                    for i in 0..<30 {
                        guard !Task.isCancelled else { return }
                        inputs.verifyMirror(.init(eyeOpenness: 1, tilt: 0.15, motion: 0.7, raisedHand: 0.85, handX: Float(i % 2) * 0.15))
                        do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                    }
                }
            }.accessibilityIdentifier("fixtureRehearsal")
        }
    }
    private func faceFixture(smile: Float) {
        guard ProcessInfo.processInfo.arguments.contains("--verify-live-inputs") else { return }
        fixtureTask?.cancel()
        fixtureTask = Task { @MainActor in
            for _ in 0..<32 {
                guard !Task.isCancelled else { return }
                inputs.verifyMirror(.init(eyeOpenness: smile > 0 ? 0.8 : 1, facialSmile: smile, smilingEyes: smile > 0 ? 0.6 : 0, viewerAttention: 0.95))
                do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            }
        }
    }
    private var danceControls: some View {
        VStack(spacing: 16) {
            FonsterControlGroup(title: "Set the world", tone: .play) {
                ForEach(FonsterDanceMode.allCases, id: \.rawValue) { mode in
                    FonsterIconButton(title: mode.title, symbol: mode.symbol, tone: .play, selected: lobby.danceMode == mode,
                        detail: "Daylight restores the world. Spotlight starts a solo dance; Disco adds a DJ, speakers, mirror ball and dance floor. Undo restores the previous set. Static and Reduce Motion keep lights steady.") { lobby.setDanceMode(mode) }
                        .disabled(blocked).accessibilityIdentifier("dance_" + mode.rawValue)
                }
            }
            FonsterControlGroup(title: "Celebrate", tone: .play) {
                FonsterIconButton(title: "Confetti burst", symbol: "party.popper", tone: .play, detail: "One short confetti burst. Repeated taps replace it. Pause freezes it; leaving dance clears it.") { lobby.celebrate(balloons: false) }.disabled(!lobby.shouldAnimate || lobby.danceMode == .daylight).accessibilityIdentifier("danceConfetti")
                FonsterIconButton(title: "Balloon drop", symbol: "balloon.2", tone: .play, detail: "One gentle balloon drop. Repeated taps replace it. Static and Reduce Motion suppress falling effects.") { lobby.celebrate(balloons: true) }.disabled(!lobby.shouldAnimate || lobby.danceMode == .daylight).accessibilityIdentifier("danceBalloons")
                FonsterIconButton(title: "End dance and restore daylight", symbol: "stop.fill", tone: .quiet) { lobby.setDanceMode(.daylight); lobby.stopActivity() }.accessibilityIdentifier("endDance")
            }
        }
    }
    private var cameraControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            FonsterControlGroup(title: "Camera", tone: .world) {
                FonsterIconButton(title: "Turn left", symbol: "arrow.counterclockwise", tone: .world) { lobby.rotateCamera(-0.3) }
                FonsterIconButton(title: "Turn right", symbol: "arrow.clockwise", tone: .world) { lobby.rotateCamera(0.3) }
                FonsterIconButton(title: "Closer", symbol: "plus.magnifyingglass", tone: .world) { lobby.zoomCamera(0.85) }
                FonsterIconButton(title: "Further", symbol: "minus.magnifyingglass", tone: .world) { lobby.zoomCamera(1.15) }
            }
            FonsterControlGroup(title: "Camera movement", tone: .world) {
                VStack {
                    HStack {
                        FonsterIconButton(title: "Tilt up", symbol: "arrow.up", tone: .world) { lobby.rotateCamera(0, vertical: 0.12) }
                        FonsterIconButton(title: "Tilt down", symbol: "arrow.down", tone: .world) { lobby.rotateCamera(0, vertical: -0.12) }
                        FonsterIconButton(title: "Raise camera", symbol: "arrow.up.to.line", tone: .world) { lobby.panCamera([0, 0.3, 0]) }
                        FonsterIconButton(title: "Lower camera", symbol: "arrow.down.to.line", tone: .world) { lobby.panCamera([0, -0.3, 0]) }
                    }
                    HStack {
                        FonsterIconButton(title: "Pan left", symbol: "arrow.left", tone: .world) { lobby.panCamera([-0.3, 0, 0]) }
                        FonsterIconButton(title: "Pan right", symbol: "arrow.right", tone: .world) { lobby.panCamera([0.3, 0, 0]) }
                        FonsterIconButton(title: "Pan forward", symbol: "arrow.up.forward", tone: .world) { lobby.panCamera([0, 0, -0.3]) }
                        FonsterIconButton(title: "Pan backward", symbol: "arrow.down.backward", tone: .world) { lobby.panCamera([0, 0, 0.3]) }
                    }
                }
            }
            FonsterControlGroup(title: "Sound and motion") {
                FonsterIconToggle(title: "Sounds", symbol: "speaker.wave.2", isOn: Binding(get: { lobby.sounds }, set: { lobby.sounds = $0 }))
                FonsterIconToggle(title: "Still mode", symbol: "snowflake", isOn: Binding(get: { lobby.still }, set: { lobby.still = $0 }))
                FonsterIconButton(title: "Reset camera", symbol: "scope", tone: .world) { lobby.showOverview() }
            }
        }
    }
}

struct LobbyPortrait: View {
    let appearance: CreatureAppearanceDescriptor
    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 32
            for (offset, index) in appearance.raster.enumerated() where index >= 0 && Int(index) < appearance.rgbaPalette.count {
                let c = appearance.rgbaPalette[Int(index)]
                if c.count == 4 { context.fill(Path(CGRect(x: Double(offset % 32) * unit, y: Double(offset / 32) * unit, width: unit, height: unit)), with: .color(Color(.sRGB, red: Double(c[0])/255, green: Double(c[1])/255, blue: Double(c[2])/255, opacity: Double(c[3])/255))) }
            }
        }.accessibilityHidden(true)
    }
}

@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
private struct LobbyVisitShare: View {
    let lobby: LocalLobbyController
    @Environment(\.dismiss) private var dismiss
    @State private var feeling = false
    @State private var biography = false
    var body: some View {
        VStack(spacing: 20) {
            HStack { LobbyPortrait(appearance: lobby.selectedMember.descriptor).frame(width: 84, height: 84); Spacer(); FonsterIconButton(title: "Close sharing", symbol: "xmark") { dismiss() } }
            Toggle("Include chosen feeling", isOn: $feeling)
            if !lobby.selectedBiography.isEmpty {
                Toggle("Include backstory and favorites", isOn: $biography).accessibilityIdentifier("shareBiography")
                if biography { FonsterBiographySummary(biography: lobby.selectedBiography.publicSnapshot) }
            }
            FonsterInfo(title: "Portable visit", detail: "Shares a snapshot with a random public identifier, appearance and personality tendencies. Backstory and favorites are private until you turn them on here. Email addresses are omitted. No original seed, private learned memories or live connection. Recipients can keep their copy.")
            if let data = try? lobby.card(for: lobby.selectedMember, includeFeeling: feeling, includeBiography: biography).encoded() {
                ShareLink(item: LobbyVisitExport(data: data), preview: SharePreview(lobby.card(for: lobby.selectedMember, includeFeeling: feeling).name, image: Image(systemName: "heart"))) {
                    FonsterIcon(symbol: "square.and.arrow.up", tone: .company)
                }.buttonStyle(.plain).fonsterHelp("Share visit snapshot", symbol: "square.and.arrow.up").accessibilityLabel("Share visit snapshot")
            }
        }.padding(24)
        #if os(macOS)
        .frame(width: 380)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }
}
#endif
