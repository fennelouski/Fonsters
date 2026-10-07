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
    private let ink = Color(red: 0.19, green: 0.15, blue: 0.27)
    private let accent = Color(red: 0.45, green: 0.32, blue: 0.62)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.3").font(.system(size: 24)).foregroundStyle(accent)
                Text("\(lobby.members.count)").font(.system(size: 22, weight: .semibold, design: .rounded))
                    .accessibilityLabel("\(lobby.members.count) Fonsters in this local world")
                FonsterAgentStatus(lobby: lobby) { agentStudio = true }
                FonsterIconButton(title: "Local Fonster profiles and moments", symbol: "sparkles.rectangle.stack", tone: .company) { socialStudio = true }
                Menu {
                    ForEach(lobby.availableCompanions) { fixture in Button("Add \(fixture.name)") { interpreter.cancel(); lobby.addCompanion(fixture) } }
                } label: { FonsterIcon(symbol: "plus", tone: .world) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 44, height: 44).background(FonsterTone.world.wash, in: RoundedRectangle(cornerRadius: 14)).help("Add a local Fonster").accessibilityLabel("Add a local Fonster")
                    .disabled(lobby.availableCompanions.isEmpty || !lobby.ready)
                FonsterIconButton(title: "Save a Fonster visit file", symbol: "square.and.arrow.up", tone: .world) { sharing = true }.disabled(lobby.selectedMember.isVisitor)
                FonsterIconButton(title: "Invite a Fonster from a visit file", symbol: "person.crop.circle.badge.plus", tone: .world) { importing = true }
                if lobby.hasVisitor { FonsterIconButton(title: "End the local visit", symbol: "person.crop.circle.badge.minus") { interpreter.cancel(); lobby.endVisit() } }
            }
            LobbyWorldToolbar(lobby: lobby, typing: typingRequest)
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26).fill(LinearGradient(colors: [Color(red: 0.90, green: 0.91, blue: 0.94), Color(red: 0.98, green: 0.95, blue: 0.91)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    if let error = lobby.error { Text(error).padding(30) }
                    else { LobbyStageView(lobby: lobby).id(lobby.roomRevision).clipShape(RoundedRectangle(cornerRadius: 26)) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                companionRail
            }.frame(minHeight: 360, maxHeight: .infinity)
            HStack(spacing: 12) {
                FonsterControlGroup(title: "Company", tone: .company) {
                    roomButton("Wave to a friend", "hand.wave", .company) { lobby.waveToFriend() }
                    roomButton("Come closer", "person.3.sequence", .company) { lobby.gather() }
                    roomButton("Quiet moment", "moon", .company) { lobby.perform(.rest) }
                }
                FonsterControlGroup(title: "Play", tone: .play) {
                    roomButton("Play together", "sparkles", .play) { lobby.playTogether() }
                    roomButton("Toss ball", "tennisball", .play) { lobby.perform(.fetch) }
                }
                Spacer(minLength: 0)
                FonsterIconButton(title: "Type a request", symbol: "text.bubble", tone: .world, selected: showsCommand) { showsCommand.toggle() }
                FonsterControlGroup(title: "Sound and motion") {
                    FonsterIconToggle(title: "Sounds", symbol: "speaker.wave.2", isOn: $lobby.sounds)
                    FonsterIconToggle(title: "Wander and mingle", symbol: "figure.walk", isOn: Binding(get: { lobby.wander }, set: { lobby.setWander($0) }))
                    FonsterIconToggle(title: "Still mode", symbol: "snowflake", isOn: Binding(get: { lobby.still }, set: { lobby.takeOwnerControl(); lobby.still = $0 }))
                    FonsterIconButton(title: lobby.paused ? "Resume" : "Pause", symbol: lobby.paused ? "play.fill" : "pause.fill", selected: lobby.paused) { lobby.takeOwnerControl(); lobby.paused.toggle() }
                        .keyboardShortcut(typingRequest ? nil : KeyboardShortcut(.space, modifiers: []))
                }
            }
            if showsCommand {
                CreatureCommandBar(interpreter: interpreter, selected: lobby.selectedMember.name, names: lobby.names, revision: lobby.userRevision,
                    enabled: lobby.ready && !lobby.paused && !lobby.backgrounded && !lobby.lowPower,
                    currentRevision: { lobby.userRevision }, apply: { lobby.execute($0) },
                    onFocusChange: { typingRequest = $0; if $0 { lobby.takeOwnerControl() } })
            }
            HStack(spacing: 8) {
                FonsterStatus(symbol: "heart", detail: lobby.message, tone: .company)
                if lobby.presence.running {
                    FonsterIconButton(title: "Pause local profile agent: \(lobby.presence.message)", symbol: "sparkles", tone: .company, selected: true) { lobby.presence.stop(lobby: lobby) }
                }
                Spacer()
                FonsterStatus(symbol: lobby.shouldAnimate ? "waveform.path" : "pause.circle", detail: lobby.motionStatus)
                FonsterInfo(title: "About this world", detail: lobby.growthDescription + "\nStroke a Fonster, click a path to walk, or drag the world to turn.\n" + (lobby.worldTemporaryReason ?? lobby.social.status) + "\nProfiles, feelings, and friendship memories stay local. No public platform or external agent is connected.")
            }
        }
        .padding(22).frame(minWidth: 1050, minHeight: 740)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95)).foregroundStyle(ink).preferredColorScheme(.light)
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
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 3), spacing: 8) {
                    ForEach(CreatureFeeling.allCases) { feeling in
                        FonsterIconButton(title: "Choose \(feeling.title.lowercased())", symbol: feeling.symbol, tone: .company, selected: lobby.selectedMember.controller.feeling == feeling) { lobby.chooseFeeling(feeling) }
                    }
                }.accessibilityElement(children: .contain).accessibilityLabel("Chosen Fonster feeling")
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ResolvedPortrait(appearance: lobby.selectedMember.descriptor).frame(width: 36, height: 36)
                FonsterStatus(symbol: "heart", detail: lobby.selectedFriendship.description, tone: .company)
                Menu {
                    ForEach(lobby.members.indices.filter { $0 != lobby.selected }, id: \.self) { i in Button(lobby.names[i]) { lobby.buddy = i } }
                } label: {
                    ResolvedPortrait(appearance: lobby.members[lobby.peerIndex].descriptor).frame(width: 36, height: 36)
                        .padding(5).background(FonsterTone.company.wash, in: RoundedRectangle(cornerRadius: 12))
                }.menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .help("Choose a friend; currently \(lobby.names[lobby.peerIndex])").accessibilityLabel("Choose a friend; currently \(lobby.names[lobby.peerIndex])")
            }
            FonsterControlGroup(title: "Time with your chosen friend", tone: .company) {
                roomButton("Pass the ball with your chosen friend", "tennisball", .play) { lobby.pair(quiet: false) }
                roomButton("Sit with your chosen friend", "heart", .company) { lobby.pair(quiet: true) }
            }
        }.padding(16).frame(width: 184).frame(maxHeight: .infinity)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
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
            FonsterControlGroup(title: "World areas", tone: .world) {
                ForEach(LobbyWorld.Area.allCases) { area in
                    let unlocked = lobby.world.areas.contains(area)
                    FonsterIconButton(title: unlocked ? "Explore \(area.title) with your chosen friend" : "\(area.title) opens at \(area.population) Fonsters", symbol: area.symbol, tone: .world, selected: lobby.focusArea == area && unlocked) { lobby.explore(area) }
                        .overlay(alignment: .bottomTrailing) {
                            if !unlocked { Label("\(area.population)", systemImage: "lock.fill").font(.system(size: 9, weight: .bold)).padding(4).background(.white, in: Capsule()).allowsHitTesting(false) }
                        }
                        .disabled(!unlocked || !lobby.ready || lobby.paused || lobby.backgrounded || lobby.lowPower)
                }
            }
            Spacer(minLength: 0)
            FonsterControlGroup(title: "Camera and benches", tone: .world) {
                FonsterIconButton(title: "Whole world", symbol: "map", tone: .world) { lobby.showOverview() }
                FonsterIconButton(title: "Follow \(lobby.selectedMember.name)", symbol: "viewfinder", tone: .world) { lobby.lookAtSelected() }
                FonsterIconButton(title: "Rest on a bench", symbol: "chair.lounge", tone: .world) { lobby.sitOnBench() }
                    .disabled(lobby.world.benches.isEmpty || lobby.paused || lobby.backgrounded || lobby.lowPower)
                FonsterIconButton(title: "Turn camera left", symbol: "arrow.counterclockwise", tone: .world) { lobby.rotateCamera(-0.30) }
                    .keyboardShortcut(typing ? nil : KeyboardShortcut("[", modifiers: []))
                FonsterIconButton(title: "Turn camera right", symbol: "arrow.clockwise", tone: .world) { lobby.rotateCamera(0.30) }
                    .keyboardShortcut(typing ? nil : KeyboardShortcut("]", modifiers: []))
                FonsterIconButton(title: "Zoom out", symbol: "minus.magnifyingglass", tone: .world) { lobby.zoomCamera(1.15) }
                FonsterIconButton(title: "Zoom in", symbol: "plus.magnifyingglass", tone: .world) { lobby.zoomCamera(0.85) }
            }.disabled(!lobby.ready)
        }

    }
}

@available(macOS 15.0, *)
private struct LobbyStageView: View {
    let lobby: LocalLobbyController
    @State private var sceneEntities: [Entity] = []
    @State private var gestureStarted = false
    @State private var creatureCaptured = false
    @GestureState private var gestureActive = false
    var body: some View {
        GeometryReader { geometry in
            RealityView { content in
                do {
                    let revision = lobby.roomRevision
                    lobby.containers = []
                    for member in lobby.members {
                        let rig = try CreatureRig(member.descriptor, furDetail: lobby.members.count > 6 ? .world : .lobby)
                        member.controller.install(rig, name: member.name)
                        member.controller.orbit = 0
                        let container = Entity(); container.scale = .init(repeating: 0.55)
                        container.addChild(rig.root); content.add(container); lobby.containers.append(container)
                    }
                    let neighborhood = try LobbyWorldScene.make(lobby.world)
                    content.add(neighborhood.root); lobby.fountainDrops = neighborhood.fountainDrops
                    let ball = ModelEntity(mesh: .generateSphere(radius: 0.14), materials: [SimpleMaterial(color: NSColor(srgbRed: 0.96, green: 0.62, blue: 0.42, alpha: 1), roughness: 0.4, isMetallic: false)])
                    lobby.ball = ball; content.add(ball)
                    let camera = PerspectiveCamera(); camera.camera.fieldOfViewInDegrees = 42
                    camera.name = "preview-camera"; lobby.camera = camera
                    content.add(camera); content.camera = .virtual; lobby.updateCamera()
                    let key = DirectionalLight(); key.light.intensity = 2400
                    key.light.color = NSColor(srgbRed: 1, green: 0.9, blue: 0.8, alpha: 1)
                    key.look(at: [0, 0, 0], from: [-3, 5, 4], relativeTo: nil)
                    key.shadow = .init(maximumDistance: 30, depthBias: 1); content.add(key)
                    let fill = PointLight(); fill.light.intensity = 11000; fill.light.attenuationRadius = 20
                    fill.light.color = NSColor(srgbRed: 0.88, green: 0.91, blue: 1, alpha: 1); fill.position = [0, 2, 4]; content.add(fill)
                    content.add(try await CreatureSceneLighting.studio(for: Array(content.entities)))
                    guard !Task.isCancelled, lobby.roomRevision == revision else { return }
                    lobby.applyLayout(); lobby.ready = true; lobby.refreshGates()
                    sceneEntities = Array(content.entities)
                    NativeSceneExport.verificationTask(entities: Array(content.entities), label: "lobby")
                } catch { lobby.error = "Couldn’t open this little room: \(error.localizedDescription)"; lobby.refreshGates() }
            }
            .background(VerificationSceneMarker(entities: sceneEntities))
            .onContinuousHover { phase in
                if case .active(let point) = phase {
                    lobby.selectedMember.controller.look([Float(point.x / geometry.size.width - 0.5) * 2, Float(0.5 - point.y / geometry.size.height) * 2])
                }
            }
             .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).updating($gestureActive) { _, active, _ in active = true }
                .onChanged { value in
                    if !gestureStarted {
                        gestureStarted = true
                        creatureCaptured = lobby.beginContact(at: value.startLocation, size: geometry.size)
                        if !creatureCaptured { lobby.dragOrbit = lobby.cameraOrbit }
                    } else if creatureCaptured { lobby.moveContact(at: value.location, size: geometry.size) }
                    if !creatureCaptured && hypot(value.translation.width, value.translation.height) > 6 {
                        lobby.cameraOrbit = (lobby.dragOrbit ?? lobby.cameraOrbit) - Float(value.translation.width) * 0.008
                        lobby.updateCamera()
                    }
                }.onEnded { value in
                    if creatureCaptured { lobby.endContact() }
                    else if hypot(value.translation.width, value.translation.height) <= 6 { lobby.walk(at: value.location, size: geometry.size) }
                    lobby.dragOrbit = nil; gestureStarted = false; creatureCaptured = false
                })
            .onChange(of: gestureActive) { _, active in
                if !active && gestureStarted { lobby.cancelContact(); lobby.dragOrbit = nil; gestureStarted = false; creatureCaptured = false }
            }
            .onDisappear { lobby.cancelContact() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Explorable Fonster world with \(lobby.names.joined(separator: ", "))")
            .accessibilityValue(lobby.message)
            .accessibilityHint("Stroke a Fonster for a gentle rub, or touch a paw for a high five. Choose an area to explore with a friend. Camera buttons turn and zoom the view. Click a path to walk there.")
            .accessibilityAction(named: "Wave to a friend") { lobby.waveToFriend() }
            .accessibilityAction(named: "Play together") { lobby.playTogether() }
            .accessibilityAction(named: "Pass ball with chosen friend") { lobby.pair(quiet: false) }
            .accessibilityAction(named: "Sit with chosen friend") { lobby.pair(quiet: true) }
        }
    }
}
#endif
