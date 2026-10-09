#if os(macOS) || os(iOS)
import SwiftUI
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
import RealityKit
import simd
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
    @State private var senseEducation: FonsterSenseEducation.Sense?
    @State private var senseApproval: FonsterSenseEducation.Sense?
    @State private var panelEducation: FonsterSenseEducation.Sense?
    @State private var panelApproval: FonsterSenseEducation.Sense?
    @State private var panelInputGate = ParentActionGate()
    @State private var launching = !ProcessInfo.processInfo.arguments.contains("--verify-manual") || ProcessInfo.processInfo.arguments.contains("--verify-launch")
    @State private var needsWelcome = false
    @State private var savingWelcome = false
    @State private var explorationGuide = false
    @State private var personalityGuide = false
    @State private var buttonDiscovery = FonsterButtonDiscovery()
    @State private var privacy = false
    @State private var panelPrivacy = false
    @State private var panelGallery = false
    @State private var lesson: CreatureImitationLesson?
    @State private var learnedUndo: CreatureMovementStyle?
    @State private var canUndoLearning = false
    @State private var fixtureTask: Task<Void, Never>?
    @State private var didPreviewDance = false
    @State private var searching = false
    @State private var query = ""
    @State private var gallery = false
    @State private var waypointsShowing = false
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
    private var reviewing: Bool { waypointsShowing || panelPrivacy || panelGallery || gallery || sharing || agents || profiles || editor != nil || senseEducation != nil || panelEducation != nil || panelInputGate.challenge != nil || needsWelcome || launching || explorationGuide || personalityGuide || privacy || parentGate.challenge != nil || inputParentGate.challenge != nil }
    private var inputsSuspended: Bool { blocked || !lobby.inCare || lobby.selectedMember.isVisitor || typing || searchFocused }

    var body: some View {
        presentations
            .environment(\.fonsterButtonDiscovery, buttonDiscovery)
            .parentActions(parentGate)
            .parentActions(inputParentGate)
            #if os(iOS)
            .phoneOrientation((lobby.inCare && !lobby.exploring) || reviewing ? .details : .lobby)
            #endif
    }
    private var stageAndKeyboard: some View {
        ZStack {
            (lobby.danceMode == .daylight ? Color(red: 0.91, green: 0.94, blue: 0.87) : Color(red: 0.075, green: 0.07, blue: 0.14)).ignoresSafeArea()
            LobbyStageView(lobby: lobby).id(lobby.roomRevision).ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    lobby.careViewportFrame = frame; lobby.updateCamera()
                }
                .accessibilityIdentifier("continuousStage")
            if !launching {
                WaypointWorldPins(lobby: lobby)
                if let map = lobby.mappedArea {
                    VStack(spacing: 2) {
                        Text(map.area.name + " · Offline mapped sample").font(.caption.weight(.semibold))
                        Link(map.source.attribution, destination: URL(string: "https://www.openstreetmap.org/copyright")!).font(.caption2)
                        Text("Incomplete coverage · Toy equipment and water widths · " + (map.isStale ? "Stale offline snapshot " : "Snapshot ") + String(map.fetchedAt.prefix(10))).font(.caption2).foregroundStyle(FonsterChrome.secondary)
                    }.foregroundStyle(FonsterChrome.primary).padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, 70)
                        .accessibilityElement(children: .contain).accessibilityIdentifier("mappedWorldAttribution")
                }
                hud
                OverheadFonsterName(lobby: lobby, record: library.first(where: { $0.id == lobby.selectedSavedID })) { record in
                    editor = .init(record: record)
                }.ignoresSafeArea()
            }
            if explorationGuide {
                VStack(spacing: 24) {
                    HStack(spacing: 28) { Image(systemName: "hand.draw"); Image(systemName: "arrow.up.and.down.and.arrow.left.and.right"); Image(systemName: "person.crop.circle") }.font(.largeTitle)
                    Text("Drag to explore. Tap a Fonster to say hello.").font(.headline)
                    FonsterIconButton(title: "Start exploring", symbol: "checkmark", tone: .world) { explorationGuide = false }
                }.padding(30).background(FonsterChrome.background, in: RoundedRectangle(cornerRadius: 28)).foregroundStyle(FonsterChrome.primary)
            }
            if personalityGuide {
                VStack(spacing: 24) {
                    Text("Grow together").font(.title2.bold())
                    HStack(spacing: 18) {
                        if !inputs.cameraDenied { FonsterIconButton(title: "Learn through movement", symbol: "video", tone: .company) { personalityGuide = false; activateCamera(panel: false) } }
                        if !inputs.microphoneDenied { FonsterIconButton(title: "Learn through voice", symbol: "mic", tone: .company) { personalityGuide = false; senseEducation = .microphone } }
                        FonsterIconButton(title: "Play together", symbol: "sparkles", tone: .play) { personalityGuide = false; lobby.perform(.play) }
                        FonsterIconButton(title: "Name and interests", symbol: "book.closed", tone: .company) {
                            personalityGuide = false
                            if let id = lobby.selectedSavedID, let record = library.first(where: { $0.id == id }) { editor = .init(record: record) }
                        }
                    }
                    FonsterIconButton(title: "Explore instead", symbol: "globe.americas", tone: .world) { personalityGuide = false; lobby.returnToLobby(); explorationGuide = true }
                }.padding(28).background(FonsterChrome.background, in: RoundedRectangle(cornerRadius: 28)).foregroundStyle(FonsterChrome.primary)
            }
            if needsWelcome && !launching {
                FonsterWelcome { seed, destination in finishWelcome(seed: seed, destination: destination) }.disabled(savingWelcome)
            }
            if let libraryError, needsWelcome { Text(libraryError).font(.callout).foregroundStyle(FonsterChrome.primary).padding().background(FonsterChrome.background).frame(maxHeight: .infinity, alignment: .bottom) }
            if launching { FonsterLaunch(worldReady: lobby.ready || lobby.error != nil) { launching = false } }
            if let error = lobby.error { Text(error).padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
        }
        .fontDesign(.rounded)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in availableStageHeight = height; updateVisibleStage() }
        .onChange(of: searchFocused) { if searchFocused { lobby.clearCameraKeys() }; updateVisibleStage() }
        .onChange(of: lobby.searchQuery) { _, value in
            // A delayed model observation during rotation must not restore a
            // query the owner just cleared.
            guard value == lobby.searchQuery else { return }
            // Keep spaces being typed between words; the model trims its query.
            if query.trimmingCharacters(in: .whitespacesAndNewlines) != value { query = value; searching = !value.isEmpty }
        }
        .focusable().focused($stageFocused)
        .onKeyPress(phases: [.down, .repeat, .up]) { press in
            guard !reviewing && !searchFocused && !typing && !gallery && !sharing && !agents && !profiles && editor == nil else { return .ignored }
            if press.key == .escape, press.phase == .down { if lobby.inCare { lobby.returnToLobby() } else { closeSearch() }; return .handled }
            if press.key == .return, press.phase == .down, !lobby.inCare, let first = lobby.searchMatches.first { lobby.openCare(first); return .handled }
            if press.key == .tab { return .ignored }
            return lobby.cameraKey(press.key, modifiers: press.modifiers, held: press.phase != .up) ? .handled : .ignored
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
                if arguments.contains("--exploration-preview") { lobby.toggleExploration() }
                lobby.setDanceMode(mode)
            }
            if lobby.ready, let id = focusAfterSave,
               let record = roster.firstIndex(where: { $0.id == id }) {
                focusAfterSave = nil; lobby.openCare(record)
            }
        }
        .task(id: lobby.shouldAnimate) { if lobby.shouldAnimate { await lobby.animate() } else { lobby.refreshGates() } }
        .onChange(of: reduceMotion, initial: true) { lobby.reduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion"); lobby.refreshGates() }
        .onChange(of: scenePhase, initial: true) { if scenePhase == .active { inputs.refreshPermissions() }; if scenePhase != .active { lobby.clearCameraKeys() }; lobby.backgrounded = scenePhase != .active; lobby.refreshGates() }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lobby.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled; lobby.refreshGates() }
        .onChange(of: lobby.controls) { old, new in history.record(old: old, new: new); lobby.refreshGates() }
        .onChange(of: query) { lobby.search(query) }
    }
    private var inputLifecycle: some View {
        lifecycle
        .onChange(of: lobby.inCare) { searchFocused = false; stageFocused = true; command = false; interpreter.cancel(); pauseLiveActivity(); inputs.setSuspended(inputsSuspended) }
        .onChange(of: lobby.selected) { pauseLiveActivity(); inputs.setSuspended(inputsSuspended); canUndoLearning = false }
        .onChange(of: inputsSuspended, initial: true) { inputs.setSuspended(inputsSuspended); if inputsSuspended { cancelLesson(); lobby.selectedMember.controller.clearMirror() } }
        .onChange(of: inputs.microphoneEnabled) { if inputs.microphoneEnabled { for member in lobby.members { member.controller.silence() } }; lobby.listening = inputs.microphoneEnabled; lobby.refreshGates() }
        .onChange(of: inputs.cameraEnabled) { if !inputs.cameraEnabled { lobby.clearGroup(); lobby.selectedMember.controller.clearMirror(); if lesson?.kind != .voice { cancelLesson() } } }
        .onChange(of: inputs.cameraReviewRequired) {
            if inputs.cameraReviewRequired {
                inputs.consumeCameraReviewRequest()
                if !inputs.cameraDenied { senseEducation = .camera }
            }
        }
        .onAppear { connectInputs(); inputs.setSuspended(inputsSuspended) }
        .onChange(of: pendingImportURL.url, initial: true) { if pendingImportURL.url != nil { gallery = true } }
        .onChange(of: reviewing) { _, showing in
            lobby.reviewingControls = showing
            if showing { lobby.clearCameraKeys(); lobby.takeOwnerControl(); interpreter.cancel() }
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
        .sheet(isPresented: $waypointsShowing) {
            LobbyWaypointsView(lobby: lobby) {
                query = lobby.searchQuery
                if query.isEmpty { searching = false }
                waypointsShowing = false
            }
                #if os(iOS)
                .phoneOrientation(.details)
                #endif
        }
        .sheet(isPresented: $gallery) { portraitGallery }
        .sheet(isPresented: $sharing) {
            LobbyVisitShare(lobby: lobby)
                #if os(iOS)
                .phoneOrientation(.details)
                #endif
        }
        .sheet(item: $senseEducation, onDismiss: {
            if let sense = senseApproval { senseApproval = nil; requestSense(sense, gate: inputParentGate) }
        }) { sense in FonsterSenseEducation(sense: sense) { senseApproval = sense } }
        .sheet(isPresented: $privacy) { FamilyPrivacyView() }
        #if os(macOS)
        .sheet(isPresented: $agents) { FonsterAgentStudio(lobby: lobby) }
        .sheet(isPresented: $profiles) { FonsterSocialStudio(lobby: lobby) }
        #endif
        #if os(macOS)
        .task { await resizeCarePreviewIfRequested(); await verifyCameraKeyboardIfRequested(); await verifyExplorationIfRequested(); await verifyCameraLifecycleIfRequested(); await verifyWaypointsIfRequested() }
        #endif
        .onDisappear { pauseLiveActivity(); lobby.backgrounded = true; lobby.cancelContact(); lobby.refreshGates(); interpreter.cancel() }
    }
    private var portraitGallery: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); FonsterIconButton(title: "Back to lobby", symbol: "xmark") { gallery = false; panelGallery = false } }.padding(12)
            ParentOnlyArea(purpose: "Review original seed links, imports and portrait exports before sharing outside Fonsters.") {
                ContentView(initialSelectionID: lobby.inCare ? lobby.selectedSavedID : nil)
            }
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }
    private func openPersonalLibrary() async {
        do {
            let existing = try modelContext.fetchCount(FetchDescriptor<Fonster>())
            if existing == 0 && !ProcessInfo.processInfo.arguments.contains("--verify-manual") { needsWelcome = true }
            else { try await PersonalFonsterLibrary.ensureStarters(in: modelContext) }
            libraryError = nil
        } catch { libraryError = error.localizedDescription }
    }

    #if os(macOS)
    /// Verification changes only this app's preview window, never device orientation.
    private func resizeCarePreviewIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--verify-manual"), let index = args.firstIndex(of: "--care-preview-size"), index + 1 < args.count else { return }
        let dimensions = args[index + 1].split(separator: "x").compactMap { Double($0) }
        guard dimensions.count == 2, dimensions.allSatisfy({ $0 >= 320 && $0 <= 1600 }) else { return }
        for _ in 0..<600 {
            if lobby.ready, let window = NSApplication.shared.windows.first(where: { $0.canBecomeKey && $0.contentView != nil }) {
                window.setContentSize(NSSize(width: dimensions[0], height: dimensions[1])); return
            }
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
    /// Native events target only this preview's own window; no system input control.
    private func verifyExplorationIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--verify-manual"), let i = args.firstIndex(of: "--exploration-ui-verification-file"), i + 1 < args.count else { return }
        for _ in 0..<600 {
            if lobby.ready { break }
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard lobby.ready, let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey && $0.contentView != nil }), let content = window.contentView else { return }
        func stage(_ view: NSView) -> VerificationSceneMarker.MarkerView? {
            if let marker = view as? VerificationSceneMarker.MarkerView { return marker }
            for child in view.subviews { if let found = stage(child) { return found } }
            return nil
        }
        guard let viewport = stage(content) else { return }
        NSApplication.shared.activate(); window.makeKeyAndOrderFront(nil)
        lobby.openCare(0); lobby.toggleExploration()
        for _ in 0..<240 {
            if !lobby.presentation.transitioning { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        func projected(_ point: SIMD3<Float>) -> NSPoint? {
            guard let camera = lobby.camera else { return nil }
            let local = camera.convert(position: point, from: nil)
            guard local.z < -0.001 else { return nil }
            let tangent = tan(Float(camera.camera.fieldOfViewInDegrees) * .pi / 360)
            let x = CGFloat((local.x / -local.z / tangent / lobby.viewportAspect + 1) * 0.5) * viewport.bounds.width
            let y = CGFloat((1 - local.y / -local.z / tangent) * 0.5) * viewport.bounds.height
            return viewport.convert(NSPoint(x: x, y: viewport.isFlipped ? y : viewport.bounds.height - y), to: nil)
        }
        func send(_ kind: NSEvent.EventType, at point: NSPoint) {
            if let event = NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: kind == .leftMouseUp ? 0 : 1) { window.sendEvent(event) }
        }
        var checks: [String: Bool] = ["explorationReady": lobby.exploring && !lobby.presentation.borrowingStage]
        checks["nameAppearsAboveCreature"] = lobby.overheadNameAnchor.map { $0.y < 0.5 } ?? false
        let before = lobby.simulation.agents[lobby.selected].position
        if let point = projected([0.2, 0, 2.2]) {
            send(.leftMouseDown, at: point); try? await Task.sleep(for: .milliseconds(80)); send(.leftMouseUp, at: point)
        }
        try? await Task.sleep(for: .milliseconds(300))
        checks["groundClickStartsRoute"] = lobby.walkDestination != nil
        let accepted = lobby.simulation.agents[lobby.selected].goal
        try? await Task.sleep(for: .seconds(2))
        checks["routeActuallyMoves"] = simd_distance(before, lobby.simulation.agents[lobby.selected].position) > 0.1
        let panBefore = lobby.cameraPan
        let nameBeforePan = lobby.overheadNameAnchor
        if let point = projected([-2, 0, 2.5]) {
            send(.leftMouseDown, at: point); try? await Task.sleep(for: .milliseconds(80))
            send(.leftMouseDragged, at: NSPoint(x: point.x + 80, y: point.y + 30)); try? await Task.sleep(for: .milliseconds(100))
            send(.leftMouseUp, at: NSPoint(x: point.x + 80, y: point.y + 30))
        }
        try? await Task.sleep(for: .milliseconds(200))
        checks["nameTracksCameraPan"] = nameBeforePan != nil && lobby.overheadNameAnchor != nil && lobby.overheadNameAnchor != nameBeforePan
        checks["emptyDragPans"] = simd_distance(panBefore, lobby.cameraPan) > 0.01
        checks["dragPreservesDestination"] = lobby.simulation.agents[lobby.selected].goal == accepted
        lobby.lookAtSelected(); checks["focusRestored"] = lobby.followSelected && lobby.cameraPan == .zero
        if let rig = lobby.selectedMember.controller.rig, let face = projected(rig.head.convert(position: .zero, to: nil)) {
            send(.leftMouseDown, at: face); try? await Task.sleep(for: .milliseconds(400))
            checks["faceCapturesContact"] = lobby.contactID != nil
            send(.leftMouseDragged, at: NSPoint(x: face.x + 8, y: face.y + 2)); try? await Task.sleep(for: .milliseconds(100))
            send(.leftMouseUp, at: NSPoint(x: face.x + 8, y: face.y + 2))
        }
        try? await Task.sleep(for: .milliseconds(200))
        checks["pettingStopsWalkWithoutPanning"] = lobby.simulation.agents[lobby.selected].route.isEmpty && lobby.cameraPan == .zero
        lobby.returnToLobby(); checks["nameHidesOnReturn"] = lobby.overheadNameAnchor == nil
        lobby.openCare(0)
        let result: [String: Any] = ["checks": checks, "passed": checks.values.allSatisfy { $0 }, "inputProvenance": "Mouse NSEvents delivered only to this preview's own native window"]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: args[i + 1]), options: .atomic) }
    }
    private func verifyWaypointsIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--verify-manual"), args.contains("--personality-file"), let i = args.firstIndex(of: "--waypoint-proof"), i + 1 < args.count else { return }
        let deadline = Date().addingTimeInterval(30)
        while !lobby.ready && Date() < deadline { try? await Task.sleep(for: .milliseconds(40)) }
        guard lobby.ready else { return }
        var checks: [String: Bool] = [:]
        // Other app-local proofs can finish in care. Waypoint UI is lobby-only.
        if lobby.inCare { lobby.returnToLobby() }
        lobby.search(""); lobby.showOverview()
        let start = lobby.controls
        lobby.panCamera([91, 1.1, -37]); lobby.rotateCamera(0.48, vertical: 0.16); lobby.zoomCamera(0.78)
        let view = lobby.waypointViewpoint
        let id = lobby.waypoints.save(name: "Hilltop lookout", viewpoint: view)!
        let saved = lobby.waypoints.waypoints.first { $0.id == id }!
        let transform = lobby.camera?.transform
        lobby.visitWaypoint(.home)
        checks["permanentStartRestoresInitialView"] = lobby.controls == start
        lobby.visitWaypoint(saved)
        checks["savedViewRestoresPositionAngleZoom"] = lobby.camera?.transform == transform
        let beforeDrag = lobby.controls
        lobby.beginCameraGesture(); lobby.dragCamera(CGSize(width: 70, height: 45), pan: true); lobby.endCameraGesture()
        lobby.restoreControls(beforeDrag)
        checks["dragAndUndoRestoreView"] = lobby.controls == beforeDrag
        if let map = lobby.mappedDemo, let mill = map.features.first(where: { $0.name == "De Kat" }) {
            lobby.visitMappedFeature(mill)
            checks["mappedWorldLoadsWithNineTiles"] = lobby.mappedAreaID == map.area.id && lobby.streamedWorld?.root.children.count == 9
            checks["mappedModeHidesGeneratedScenery"] = lobby.generatedScenery?.isEnabled == false
            let near = map.near(lobby.waypointViewpoint.position)
            lobby.waypoints.save(name: "De Kat · Mill walk", viewpoint: lobby.waypointViewpoint, landmarkNames: near.prefix(3).map(\.name), areaName: map.area.name, landmarkSymbol: map.symbol("windmill"))
            for index in 0..<5 { lobby.waypoints.save(name: "Trail \(index + 1)", viewpoint: .init(x: Float(index + 1) * 33, z: Float(index) * -21)) }
            checks["sevenSavedPlacesEnableSorting"] = lobby.waypoints.canSort
            let mapState = lobby.controls
            lobby.visitWaypoint(.home)
            checks["startReturnsToGeneratedWorld"] = lobby.mappedArea == nil && lobby.generatedScenery?.isEnabled == true
            lobby.restoreControls(mapState)
            checks["undoRestoresMappedWorld"] = lobby.mappedAreaID == map.area.id && lobby.generatedScenery?.isEnabled == false
        } else { checks["mappedSnapshotAvailable"] = false }
        if let data = try? JSONSerialization.data(withJSONObject: checks, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: args[i + 1]), options: .atomic) }
        if args.contains("--waypoint-panel-preview") { waypointsShowing = true }
    }
    private func verifyCameraLifecycleIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--verify-manual"), args.contains("--verify-live-inputs"),
              let i = args.firstIndex(of: "--camera-lifecycle-proof"), i + 1 < args.count else { return }
        for _ in 0..<600 { if lobby.ready { break }; try? await Task.sleep(for: .milliseconds(50)) }
        lobby.openCare(0); try? await Task.sleep(for: .seconds(2))
        inputs.completeCameraReview(); inputs.toggleCamera(parentApproved: true)
        try? await Task.sleep(for: .milliseconds(400))
        var checks = ["cameraActiveInOwnedCare": inputs.cameraActive, "recentReviewSkipsEducation": !inputs.needsCameraEducation()]
        lobby.returnToLobby(); try? await Task.sleep(for: .milliseconds(400))
        checks["lobbyPausesWithoutRevokingChoice"] = inputs.cameraEnabled && !inputs.cameraActive
        lobby.openCare(0); try? await Task.sleep(for: .seconds(2))
        checks["returnAutomaticallyResumes"] = inputs.cameraActive
        inputs.toggleCamera(); lobby.returnToLobby(); try? await Task.sleep(for: .milliseconds(400))
        lobby.openCare(0); try? await Task.sleep(for: .seconds(2))
        checks["manualOffSurvivesReturn"] = !inputs.cameraEnabled && !inputs.cameraActive
        activateCamera(panel: false); try? await Task.sleep(for: .milliseconds(400))
        checks["recentEnableHasNoEducationOrParentSheet"] = inputs.cameraActive && senseEducation == nil && inputParentGate.challenge == nil
        let result: [String: Any] = ["checks": checks, "passed": checks.values.allSatisfy { $0 }, "provenance": "Actual native view lifecycle with numeric synthetic input; no camera hardware opened"]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: args[i + 1]), options: .atomic) }
        guard args.contains("--camera-numeric-demo") else { return }
        for signs in [[CreatureHandSign.thumbsUp], [.thumbsUp, .thumbsUp], [.peace], [.peace, .peace], [.thumbsDown], [.thumbsDown, .thumbsDown], [.thumbsUp, .peace], [.thumbsUp, .thumbsDown], [.peace, .thumbsDown]] {
            for frame in 0..<24 {
                inputs.verifyMirror(.init(gaze: [sin(Float(frame) * 0.12) * 0.4, 0], eyeOpenness: 0.95, facialSmile: 0.6, viewerAttention: 1, hands: signs))
                try? await Task.sleep(for: .milliseconds(100))
            }
            for _ in 0..<5 { inputs.verifyMirror(.init()); try? await Task.sleep(for: .milliseconds(100)) }
        }
        inputs.toggleCamera()
    }
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
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first(where: { $0.canBecomeKey && $0.contentView != nil }) else { return }
        NSApplication.shared.activate(); window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(for: .milliseconds(200))
        var checks: [String: Bool] = ["ready": lobby.ready]
        let keys: [(String, UInt16)] = [("w", 13), ("a", 0), ("s", 1), ("d", 2), ("q", 12), ("e", 14), ("+", 24), ("-", 27), (String(UnicodeScalar(NSUpArrowFunctionKey)!), 126), (String(UnicodeScalar(NSDownArrowFunctionKey)!), 125), (String(UnicodeScalar(NSLeftArrowFunctionKey)!), 123), (String(UnicodeScalar(NSRightArrowFunctionKey)!), 124)]
        for (index, key) in keys.enumerated() {
            lobby.showOverview(); let before = lobby.controls
            if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: key.0, charactersIgnoringModifiers: key.0, isARepeat: false, keyCode: key.1) { window.sendEvent(event) }
            try? await Task.sleep(for: .milliseconds(260))
            if let event = NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: key.0, charactersIgnoringModifiers: key.0, isARepeat: false, keyCode: key.1) { window.sendEvent(event) }
            lobby.clearCameraKeys()
            checks["keyboard_" + String(index)] = lobby.controls != before
        }
        if let content = window.contentView {
            func findTooltip(_ view: NSView) -> NSView? {
                if view.identifier?.rawValue == "FonsterTooltipAnchor" { return view }
                for child in view.subviews { if let found = findTooltip(child) { return found } }
                return nil
            }
            if let anchor = findTooltip(content), let event = NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0) {
                func tipVisible() -> Bool { NSApplication.shared.windows.contains { $0.title == "Fonster tooltip" && $0.isVisible } }
                anchor.mouseEntered(with: event)
                try? await Task.sleep(for: .milliseconds(100)); checks["tooltipDelay"] = !tipVisible()
                try? await Task.sleep(for: .milliseconds(600)); checks["tooltipShown"] = tipVisible()
                checks["tooltipDoesNotStealFocus"] = NSApplication.shared.keyWindow == window
                anchor.mouseExited(with: event)
                try? await Task.sleep(for: .milliseconds(400)); checks["tooltipDismisses"] = !tipVisible()
                anchor.mouseEntered(with: event)
                if let option = NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: [.option], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 58) { NSApplication.shared.sendEvent(option) }
                try? await Task.sleep(for: .milliseconds(50)); checks["tooltipOptionImmediate"] = tipVisible()
                anchor.mouseExited(with: event)
            }
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
        GeometryReader { geometry in
            let short = geometry.size.height < 500
            let compact = geometry.size.width < 600 && !short
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
                        if lobby.exploring {
                            FonsterIconButton(title: "Focus on my Fonster", symbol: "scope", tone: .world,
                                detail: "Bring the camera back to your Fonster and follow its walk. Dragging empty ground pans; the walking button returns to solo care.") { lobby.lookAtSelected() }
                                .accessibilityIdentifier("focusExploringFonster")
                        }
                        FonsterIconButton(title: "Share Fonster", symbol: "square.and.arrow.up", tone: .company,
                            detail: "A grown-up reviews the snapshot before sharing. Recipients can keep a copy.") {
                            parentGate.request("Review this Fonster snapshot before sharing. Feelings and source references are optional. Typed drafts and backstory stay private; recipients can keep a copy.") { sharing = true }
                        }
                            .accessibilityIdentifier("shareFonster")
                    } else { searchControl }
                }
                if lobby.inCare {
                    HStack(alignment: .center) {
                        if !compact {
                            if short { liveSenseButtons(horizontal: false).padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22)) }
                            else { careRail }
                        }
                        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                                lobby.careClearFrame = frame; lobby.updateCamera()
                            }
                            .accessibilityElement().accessibilityLabel("Unobstructed Fonster area")
                            .accessibilityIdentifier("careClearArea")
                        if !compact {
                            if short { VStack(spacing: 10) { explorationButton; moreInteractions }.padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22)) }
                            else { reactions }
                        }
                    }.frame(maxHeight: .infinity)
                    if compact {
                        HStack(spacing: 12) {
                            reaction(.greet, "hand.wave", .company)
                            reaction(.play, "sparkles", .play)
                            reaction(.rest, "moon", .quiet)
                            explorationButton
                            moreInteractions
                        }.padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                    }
                } else { Spacer(minLength: 0) }
                if command {
                    CreatureCommandBar(interpreter: interpreter, selected: lobby.selectedMember.name, names: lobby.names, revision: lobby.userRevision,
                        enabled: !blocked, currentRevision: { lobby.userRevision }, apply: { lobby.execute($0) },
                        onFocusChange: { typing = $0; if $0 { lobby.clearCameraKeys(); lobby.takeOwnerControl() } })
                }
                HStack(alignment: .bottom, spacing: 8) {
                    if lobby.inCare && short { carePanel }
                    if lobby.inCare && compact {
                        carePanel
                        liveSenseButtons(horizontal: true)
                    } else { privacyButton }
                    if !lobby.inCare {
                        FonsterIconButton(title: "Saved places", symbol: "mappin.and.ellipse", tone: .world, detail: "Save this place, name a waypoint, or return to a saved place. Session start is always pinned.") { waypointsShowing = true }
                            .accessibilityIdentifier("savedPlacesButton")
                        FonsterIconButton(title: "Return to session start", symbol: "house.fill", tone: .world, detail: "Return to where this session began. Use Undo to return to your previous view.") { query = ""; searching = false; lobby.visitWaypoint(.home) }
                            .accessibilityIdentifier("returnToSessionStart")
                    }
                    FonsterControlPanel(title: "World and camera", symbol: "rotate.3d", tone: .world) {
                        cameraControls
                        if lobby.inCare && compact {
                            FonsterControlPanel(title: "Dance world", symbol: "music.note", tone: .play) { danceControls }
                            FonsterIconButton(title: "Privacy and family", symbol: "hand.raised", tone: .quiet) { panelPrivacy = true }
                                .accessibilityIdentifier("familyPrivacyButton")
                                .sheet(isPresented: $panelPrivacy) { FamilyPrivacyView() }
                        }
                    }
                    if !lobby.inCare || !compact {
                        FonsterControlPanel(title: "Dance world", symbol: "music.note", tone: .play) { danceControls }
                        Spacer(minLength: 4)
                    }
                    if !lobby.inCare && !query.isEmpty {
                        Image(systemName: lobby.searchMatches.isEmpty ? "questionmark.circle" : "scope")
                            .foregroundStyle(FonsterTone.company.ink).padding(12).background(.regularMaterial, in: Circle())
                            .accessibilityLabel(lobby.searchMatches.isEmpty ? "No matching Fonsters" : "Front match: " + lobby.names[lobby.searchMatches[0]])
                            .accessibilityValue(lobby.searchMatches.map { lobby.names[$0] }.joined(separator: ", "))
                            .accessibilityIdentifier("searchResults")
                    }
                    if !lobby.inCare || !compact { Spacer(minLength: 4) }
                    FonsterIconButton(title: "Undo last control change", symbol: "arrow.uturn.backward") { if let state = history.undo() { lobby.restoreControls(state) } }
                        .disabled(!history.canUndo).accessibilityIdentifier("undoLobbyControls")
                    FonsterIconButton(title: lobby.paused ? "Resume" : "Pause", symbol: lobby.paused ? "play.fill" : "pause.fill", selected: lobby.paused) { lobby.takeOwnerControl(); lobby.paused.toggle() }
                        .accessibilityIdentifier("pauseLobby")
                }.padding(lobby.inCare && compact ? 6 : 0)
                    .background { if lobby.inCare && compact { RoundedRectangle(cornerRadius: 22).fill(.regularMaterial) } }
            }.padding(16)
            .animation(reduceMotion || lobby.still ? nil : .spring(response: 0.5, dampingFraction: 0.82), value: lobby.inCare)
            .animation(reduceMotion || lobby.still ? nil : .spring(response: 0.5, dampingFraction: 0.82), value: lobby.exploring)
        }
    }

    private var privacyButton: some View {
        FonsterIconButton(title: "Privacy and family", symbol: "hand.raised", tone: .quiet,
            detail: "Read the privacy policy for this protected play experience. No account is needed.") { privacy = true }
            .accessibilityIdentifier("familyPrivacyButton")
    }
    private var carePanel: some View {
        FonsterControlPanel(title: "Care", symbol: "slider.horizontal.3", tone: .company, compact: true) { aspects }
    }
    private var careRail: some View {
        VStack(spacing: 10) {
            LobbyPortrait(appearance: lobby.selectedMember.descriptor).frame(width: 48, height: 48)
                .accessibilityElement().accessibilityLabel("Original portrait of " + lobby.selectedMember.name)
            carePanel
            liveSenseButtons(horizontal: false)
        }.padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
    private var searchControl: some View {
        HStack(spacing: 6) {
            if searching {
                TextField("Find a Fonster", text: $query, prompt: Text("Find a Fonster").foregroundStyle(FonsterChrome.secondary)).textFieldStyle(.plain).focused($searchFocused)
                    .foregroundStyle(FonsterChrome.primary)
                    .frame(maxWidth: 230).padding(12).background(FonsterChrome.surface, in: RoundedRectangle(cornerRadius: 14))
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52, maximum: 60), spacing: 8)], spacing: 8) {
            LobbyPortrait(appearance: lobby.selectedMember.descriptor).frame(width: 48, height: 48)
                .padding(6).background(FonsterTone.company.wash, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement().accessibilityLabel("Original portrait of " + lobby.selectedMember.name)
            FonsterControlPanel(title: "Mirror and voice", symbol: inputs.cameraEnabled || inputs.microphoneEnabled ? "person.crop.circle.badge.checkmark" : "hand.draw", tone: .company) { liveControls }
            if lobby.selectedSavedID == nil {
                FonsterControlPanel(title: "Shared interests", symbol: "heart", tone: .company) {
                    FonsterRecipientInterests(selections: lobby.selectedBiography.interests ?? [])
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
                FonsterIconButton(title: "Original portrait gallery and exports", symbol: "square.grid.2x2") { panelGallery = true }
                    .sheet(isPresented: $panelGallery) { portraitGallery }
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
            FonsterInfo(title: "Care aspects", detail: "Tap your Fonster’s name tag to edit its name, backstory and favorites. The portrait opens appearance and learned personality. The feeling icon changes the emotion you choose. Your backstory stays private unless you include it when sharing.")
        }.padding(8).background(FonsterTone.company.wash.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
    private var reactions: some View {
        VStack(spacing: 10) {
            reaction(.greet, "hand.wave", .company)
            reaction(.play, "sparkles", .play)
            reaction(.rest, "moon", .quiet)
            explorationButton
            moreInteractions
            FonsterInfo(title: "Interact with your Fonster", detail: "Wave, play or rest. Stroke the face, belly or paws for different responses. More opens other reactions, typed requests and Stop. A new action interrupts the current one. Back brings companions into the lobby again.")
        }.padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
    private var explorationButton: some View {
        FonsterIconButton(title: lobby.exploring ? "Return to solo care" : "Explore with my Fonster", symbol: "figure.walk", tone: .world, selected: lobby.exploring,
            detail: "Explore the neighborhood with this Fonster. Tap clear ground to walk, drag empty space to pan, and use the focus icon to find it. Tap again to return to solo care.") { lobby.toggleExploration() }
            .disabled(blocked).accessibilityIdentifier("exploreWithFonster")
    }
    private var moreInteractions: some View {
        FonsterControlPanel(title: "More interactions", symbol: "ellipsis", tone: .play) {
                FonsterControlGroup(title: "Reactions", tone: .play) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                        reaction(.greet, "hand.wave", .company); reaction(.play, "sparkles", .play); reaction(.rest, "moon", .quiet)
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
    }
    private func reaction(_ action: PlayroomController.Reaction, _ symbol: String, _ tone: FonsterTone) -> some View {
        FonsterIconButton(title: action.rawValue.capitalized, symbol: symbol, tone: tone, detail: "Starts this reaction now. Another reaction replaces it; Stop activity ends it.") { cancelLesson(); lobby.perform(action) }
            .disabled(blocked || !lobby.selectedMember.descriptor.supported).accessibilityIdentifier("care_" + action.rawValue)
    }
    private func connectInputs() {
        inputs.onGroup = { samples in lobby.receiveGroup(samples) }
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
    private func pauseLiveActivity() { fixtureTask?.cancel(); fixtureTask = nil; inputs.pauseForNavigation(); cancelLesson(); lobby.selectedMember.controller.clearMirror(); lobby.clearGroup() }
    private func activateCamera(panel: Bool) {
        inputs.refreshPermissions()
        guard !inputs.cameraDenied else { return }
        if inputs.needsCameraEducation() {
            if panel { panelEducation = .camera } else { senseEducation = .camera }
        } else { lobby.takeOwnerControl(); inputs.toggleCamera(parentApproved: true) }
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
    private func finishWelcome(seed: String, destination: FonsterWelcome.Destination) {
        guard !savingWelcome else { return }; savingWelcome = true
        Task { @MainActor in
            defer { savingWelcome = false }
            do {
                // Retain account-stable starter friends without treating them as
                // an existing owned friend when deciding whether to onboard.
                try await PersonalFonsterLibrary.ensureStarters(in: modelContext)
                let record = Fonster(name: "My Fonster", seed: seed, createdAtISO8601: Fonster.currentCreatedAtISO8601())
                modelContext.insert(record)
                do { try modelContext.save() } catch { modelContext.delete(record); throw error }
                needsWelcome = false; libraryError = nil
                if destination == .explore { explorationGuide = true }
                else { focusAfterSave = record.id; personalityGuide = true }
            } catch { libraryError = "Your Fonster couldn't be saved. Please try again." }
        }
    }
    private func requestSense(_ sense: FonsterSenseEducation.Sense, gate: ParentActionGate) {
        gate.request(sense == .camera ? "Enable camera mirroring. Frames stay on this device." : "Enable on-device spoken commands. Audio stays on this device.") {
            lobby.takeOwnerControl()
            if sense == .camera { inputs.completeCameraReview(); inputs.toggleCamera(parentApproved: true) }
            else { inputs.toggleMicrophone(parentApproved: true) }
        }
    }
    private func liveSenseButtons(horizontal: Bool) -> some View {
        let layout = horizontal ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 10))
        return layout {
            if !inputs.cameraDenied { FonsterIconButton(title: inputs.cameraEnabled ? "Turn camera off" : "Mirror me", symbol: inputs.cameraEnabled ? "video.fill" : "video", tone: .company, selected: inputs.cameraEnabled) { if inputs.cameraEnabled { inputs.toggleCamera() } else { activateCamera(panel: false) } }.accessibilityIdentifier("careCamera") }
            if !inputs.microphoneDenied { FonsterIconButton(title: inputs.microphoneEnabled ? "Turn microphone off" : "Talk to my Fonster", symbol: inputs.microphoneEnabled ? "mic.fill" : "mic", tone: .company, selected: inputs.microphoneEnabled) { if inputs.microphoneEnabled { inputs.toggleMicrophone() } else { senseEducation = .microphone } }.accessibilityIdentifier("careMicrophone") }
        }.disabled(blocked || lobby.selectedMember.isVisitor)
    }
    private var liveControls: some View {
        VStack(spacing: 16) {
            FonsterControlGroup(title: "Opt-in senses", tone: .company) {
                if !inputs.cameraDenied { FonsterIconButton(title: inputs.cameraEnabled ? "Turn camera off" : "Enable camera mirror", symbol: inputs.cameraEnabled ? "video.fill" : "video", tone: .company, selected: inputs.cameraEnabled,
                    detail: "A grown-up enables this. Mirror blinks, head tilts and raised-hand waves. Camera frames stay on this device. Tap again to turn off.") {
                    if inputs.cameraEnabled { inputs.toggleCamera() }
                    else { activateCamera(panel: true) }
                }
                    .disabled(blocked || lobby.selectedMember.isVisitor).accessibilityIdentifier("liveCamera") }
                if !inputs.microphoneDenied { FonsterIconButton(title: inputs.microphoneEnabled ? "Turn microphone off" : "Enable spoken commands", symbol: inputs.microphoneEnabled ? "mic.fill" : "mic", tone: .company, selected: inputs.microphoneEnabled,
                    detail: "A grown-up enables this. Say wave, dance, sleep, jump, blink, spin, stretch or stop in English. Requires local speech support and device permission. No audio or words are saved or uploaded. Tap again to turn off.") {
                    if inputs.microphoneEnabled { inputs.toggleMicrophone() }
                    else { panelEducation = .microphone }
                }
                    .disabled(blocked || lobby.selectedMember.isVisitor).accessibilityIdentifier("liveMicrophone") }
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
        .sheet(item: $panelEducation, onDismiss: {
            if let sense = panelApproval { panelApproval = nil; requestSense(sense, gate: panelInputGate) }
        }) { sense in FonsterSenseEducation(sense: sense) { panelApproval = sense } }
        .parentActions(panelInputGate)

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
                        FonsterIconButton(title: "Pan left", symbol: "arrow.left", tone: .world) { lobby.moveCamera([-1, 0]) }
                        FonsterIconButton(title: "Pan right", symbol: "arrow.right", tone: .world) { lobby.moveCamera([1, 0]) }
                        FonsterIconButton(title: "Pan forward", symbol: "arrow.up.forward", tone: .world) { lobby.moveCamera([0, -1]) }
                        FonsterIconButton(title: "Pan backward", symbol: "arrow.down.backward", tone: .world) { lobby.moveCamera([0, 1]) }
                    }
                }
            }
            if lobby.exploring || !lobby.inCare {
                FonsterControlGroup(title: "Walk", tone: .world) {
                    FonsterIconButton(title: "Walk forward", symbol: "arrow.up", tone: .world) { lobby.walkStep([0, -1]) }.disabled(blocked)
                    FonsterIconButton(title: "Walk backward", symbol: "arrow.down", tone: .world) { lobby.walkStep([0, 1]) }.disabled(blocked)
                    FonsterIconButton(title: "Walk left", symbol: "arrow.left", tone: .world) { lobby.walkStep([-1, 0]) }.disabled(blocked)
                    FonsterIconButton(title: "Walk right", symbol: "arrow.right", tone: .world) { lobby.walkStep([1, 0]) }.disabled(blocked)
                }
            }
            FonsterControlGroup(title: "Sound and motion") {
                FonsterIconToggle(title: "Sounds", symbol: "speaker.wave.2", isOn: Binding(get: { lobby.sounds }, set: { lobby.sounds = $0 }))
                FonsterIconToggle(title: "Still mode", symbol: "snowflake", isOn: Binding(get: { lobby.still }, set: { lobby.still = $0 }))
                FonsterIconButton(title: "Reset camera", symbol: "house.fill", tone: .world) { lobby.showOverview() }
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
            ScrollView {
                VStack(spacing: 20) {
                    FonsterControlGroup(title: "Visit contents", tone: .company) {
                        FonsterIconButton(title: "Include chosen feeling", symbol: "heart", tone: .company, selected: feeling,
                            detail: "Include your chosen feeling in this visit. Tap again to exclude it; changing this choice does not change your Fonster's feeling.") { feeling.toggle() }
                            .accessibilityValue(feeling ? "Included" : "Excluded")
                        if !(lobby.selectedBiography.interests ?? []).isEmpty {
                            FonsterIconButton(title: "Include selected source interests", symbol: "square.stack.3d.up", tone: .company, selected: biography,
                                detail: "Include only the source chips shown below. Your typed drafts and backstory stay private. Tap again to exclude all interest chips.") { biography.toggle() }
                                .accessibilityValue(biography ? "Included" : "Excluded").accessibilityIdentifier("shareBiography")
                        }
                    }
                    if biography { FonsterRecipientInterests(selections: lobby.selectedBiography.interests ?? []) }
                    FonsterInfo(title: "Portable visit", detail: "Shares a snapshot with a random public identifier, appearance and personality tendencies. Typed drafts and backstory stay private. Only selected source records can be included. No original seed, private learned memories or live connection. Recipients can keep their copy.")
                    if let data = try? lobby.card(for: lobby.selectedMember, includeFeeling: feeling, includeBiography: biography).encoded() {
                        ShareLink(item: LobbyVisitExport(data: data), preview: SharePreview(lobby.card(for: lobby.selectedMember, includeFeeling: feeling).name, image: Image(systemName: "heart"))) {
                            FonsterIcon(symbol: "square.and.arrow.up", tone: .company)
                        }.buttonStyle(.plain).fonsterHelp("Share visit snapshot", symbol: "square.and.arrow.up").accessibilityLabel("Share visit snapshot")
                    }
                }.frame(maxWidth: .infinity)
            }
        }.padding(24).foregroundStyle(FonsterChrome.primary).background(FonsterChrome.background)
        #if os(macOS)
        .frame(width: 380, height: 440)
        #else
        .presentationDetents([.medium, .large])
        .presentationBackground(FonsterChrome.background)
        #endif
    }
}
#endif
