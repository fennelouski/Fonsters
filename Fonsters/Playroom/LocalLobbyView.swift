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
    @State private var sharing = false
    @State private var importing = false
    @State private var reviewing = false
    @State private var pendingCard: FonsterVisitCard?
    @State private var importError: String?
    private let ink = Color(red: 0.19, green: 0.15, blue: 0.27)
    private let accent = Color(red: 0.45, green: 0.32, blue: 0.62)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("A world that grows with you.").font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(lobby.growthDescription).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    ForEach(lobby.availableCompanions) { fixture in
                        Button("Add \(fixture.name)") { interpreter.cancel(); lobby.addCompanion(fixture) }
                    }
                } label: { Label("Add local Fonster", systemImage: "plus.circle") }
                    .disabled(lobby.availableCompanions.isEmpty || !lobby.ready)
                Button { sharing = true } label: { Label("Share Fonster", systemImage: "square.and.arrow.up") }
                    .disabled(lobby.selectedMember.isVisitor)
                Button { importing = true } label: { Label("Invite…", systemImage: "person.crop.circle.badge.plus") }
                if lobby.hasVisitor { Button("End visit") { interpreter.cancel(); lobby.endVisit() } }
            }
            LobbyWorldToolbar(lobby: lobby, typing: typingRequest)
            HStack(spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 26).fill(LinearGradient(colors: [Color(red: 0.90, green: 0.91, blue: 0.94), Color(red: 0.98, green: 0.95, blue: 0.91)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    if let error = lobby.error { Text(error).padding(30) }
                    else { LobbyStageView(lobby: lobby).id(lobby.roomRevision).clipShape(RoundedRectangle(cornerRadius: 26)) }
                    Text("Click a path to walk · Drag to turn the view")
                        .font(.system(size: 11)).foregroundStyle(ink.opacity(0.45)).padding(20).allowsHitTesting(false)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    Text("HERE TOGETHER · \(lobby.members.count)").font(.system(size: 10, weight: .bold)).tracking(1.3).foregroundStyle(.secondary)
                    ScrollView {
                    ForEach(Array(lobby.members.enumerated()), id: \.element.id) { index, member in
                        Button { lobby.selected = index } label: {
                            HStack(spacing: 10) {
                                ResolvedPortrait(appearance: member.descriptor).frame(width: 36, height: 36)
                                    .padding(4).background(.white, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(member.name).font(.system(size: 14, weight: .semibold, design: .rounded))
                                    Text(member.isVisitor ? "Visiting · \(member.visitCard!.name)" : member.feelingLabel)
                                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }.padding(4).background(lobby.selected == index ? accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain)
                            .accessibilityLabel("Choose \(member.name) in the local lobby, \(member.feelingLabel)")
                            .accessibilityAddTraits(lobby.selected == index ? .isSelected : [])
                    }
                    }.frame(maxHeight: 235)
                    Divider()
                    if lobby.selectedMember.isVisitor {
                        Label(lobby.selectedMember.feelingLabel, systemImage: "heart")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    } else {
                        Picker("Chosen feeling", selection: Binding(get: { lobby.selectedMember.controller.feeling }, set: { lobby.chooseFeeling($0) })) {
                            ForEach(CreatureFeeling.allCases) { feeling in Label(feeling.title, systemImage: feeling.symbol).tag(feeling) }
                        }.font(.system(size: 12))
                    }
                    Picker("With", selection: Binding(get: { lobby.peerIndex }, set: { lobby.buddy = $0 })) {
                        ForEach(lobby.members.indices.filter { $0 != lobby.selected }, id: \.self) { i in Text(lobby.names[i]).tag(i) }
                    }.font(.system(size: 12))
                    Text(lobby.selectedFriendship.description).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Button { lobby.pair(quiet: false) } label: { Label("Pass ball", systemImage: "circle.dotted") }
                        Button { lobby.pair(quiet: true) } label: { Label("Sit together", systemImage: "heart") }
                    }.font(.system(size: 11)).disabled(!lobby.ready)
                    Spacer(minLength: 0)
                    Text(lobby.worldTemporaryReason ?? lobby.social.status)
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(16).frame(width: 250).frame(maxHeight: .infinity)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
            }.frame(minHeight: 330, maxHeight: .infinity)
            HStack(spacing: 9) {
                roomButton("Wave to a friend", "hand.wave") { lobby.waveToFriend() }
                roomButton("Play together", "sparkles") { lobby.playTogether() }
                roomButton("Toss ball", "circle.dotted") { lobby.perform(.fetch) }
                roomButton("Come closer", "person.3.sequence") { lobby.gather() }
                roomButton("Quiet moment", "moon") { lobby.perform(.rest) }
            }
            HStack(spacing: 16) {
                Toggle("Wander & mingle", isOn: Binding(get: { lobby.wander }, set: { lobby.setWander($0) })).toggleStyle(.checkbox)
                Toggle("Sounds", isOn: $lobby.sounds).toggleStyle(.checkbox)
                Spacer()
                Toggle("Still mode", isOn: $lobby.still).toggleStyle(.checkbox)
                Button { lobby.paused.toggle() } label: { Label(lobby.paused ? "Resume" : "Pause", systemImage: lobby.paused ? "play.fill" : "pause.fill") }
                    .buttonStyle(.bordered).keyboardShortcut(typingRequest ? nil : KeyboardShortcut(.space, modifiers: []))
            }.font(.system(size: 12)).foregroundStyle(.secondary)
            CreatureCommandBar(interpreter: interpreter, selected: lobby.selectedMember.name,
                               names: lobby.names, revision: lobby.userRevision,
                               enabled: lobby.ready && !lobby.paused && !lobby.backgrounded && !lobby.lowPower,
                               currentRevision: { lobby.userRevision }, apply: { lobby.execute($0) },
                               onFocusChange: { typingRequest = $0 })
            HStack {
                Text(lobby.message).font(.system(size: 12, weight: .medium, design: .rounded))
                Spacer()
                Text(lobby.motionStatus).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(22).frame(minWidth: 1050, minHeight: 790)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95)).foregroundStyle(ink).preferredColorScheme(.light)
        .background(VerificationWindowCapture().frame(width: 0, height: 0))
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
            lobby.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onDisappear {
            interpreter.cancel(); lobby.ready = false; lobby.containers = []; lobby.ball = nil; lobby.camera = nil; lobby.fountainDrops = []
            for member in lobby.members { member.controller.silence(); member.controller.rig = nil; member.controller.rendererReady = false }
        }
    }
    private func roomButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 11) }
            .buttonStyle(.bordered).disabled(!lobby.ready)
    }
}

@available(macOS 15.0, *)
private struct LobbyWorldToolbar: View {
    let lobby: LocalLobbyController
    let typing: Bool
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(LobbyWorld.Area.allCases) { area in
                    let unlocked = lobby.world.areas.contains(area)
                    Button { lobby.explore(area) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: unlocked ? area.symbol : "lock").font(.system(size: 17))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(area.title).font(.system(size: 11, weight: .semibold, design: .rounded))
                                Text(unlocked ? "Explore with a friend" : "At \(area.population) Fonsters").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }.padding(9).frame(maxWidth: .infinity)
                            .background(lobby.focusArea == area ? Color(red: 0.86, green: 0.91, blue: 0.80) : .white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                        .disabled(!unlocked || !lobby.ready || lobby.paused || lobby.backgrounded || lobby.lowPower)
                        .accessibilityLabel(unlocked ? "Explore \(area.title) with your chosen friend" : "\(area.title) opens at \(area.population) Fonsters")
                }
            }
            HStack(spacing: 9) {
                Button { lobby.showOverview() } label: { Label("Whole world", systemImage: "map") }
                Button { lobby.lookAtSelected() } label: { Label("Follow \(lobby.selectedMember.name)", systemImage: "viewfinder") }
                Button { lobby.sitOnBench() } label: { Label("Rest on a bench", systemImage: "chair.lounge") }
                    .disabled(lobby.world.benches.isEmpty || !lobby.ready || lobby.paused || lobby.backgrounded || lobby.lowPower)
                Spacer()
                Button { lobby.rotateCamera(-0.30) } label: { Image(systemName: "arrow.counterclockwise") }
                    .accessibilityLabel("Turn camera left").keyboardShortcut(typing ? nil : KeyboardShortcut("[", modifiers: []))
                Button { lobby.rotateCamera(0.30) } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Turn camera right").keyboardShortcut(typing ? nil : KeyboardShortcut("]", modifiers: []))
                Button { lobby.zoomCamera(1.15) } label: { Image(systemName: "minus.magnifyingglass") }.accessibilityLabel("Zoom out")
                Button { lobby.zoomCamera(0.85) } label: { Image(systemName: "plus.magnifyingglass") }.accessibilityLabel("Zoom in")
            }.font(.system(size: 11)).buttonStyle(.bordered).disabled(!lobby.ready)
        }
    }
}

@available(macOS 15.0, *)
private struct LobbyStageView: View {
    let lobby: LocalLobbyController
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
                    NativeSceneExport.verificationTask(entities: Array(content.entities), label: "lobby")
                } catch { lobby.error = "Couldn’t open this little room: \(error.localizedDescription)"; lobby.refreshGates() }
            }
            .onContinuousHover { phase in
                if case .active(let point) = phase {
                    lobby.selectedMember.controller.look([Float(point.x / geometry.size.width - 0.5) * 2, Float(0.5 - point.y / geometry.size.height) * 2])
                }
            }
             .contentShape(Rectangle())
            .onTapGesture { point in lobby.walk(at: point, size: geometry.size) }
            .gesture(DragGesture(minimumDistance: 6).onChanged { value in
                if lobby.dragOrbit == nil { lobby.dragOrbit = lobby.cameraOrbit }
                lobby.cameraOrbit = (lobby.dragOrbit ?? 0) - Float(value.translation.width) * 0.008
                lobby.updateCamera()
            }.onEnded { _ in lobby.dragOrbit = nil })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Explorable Fonster world with \(lobby.names.joined(separator: ", "))")
            .accessibilityValue(lobby.message)
            .accessibilityHint("Choose an area to explore with a friend. Camera buttons turn and zoom the view. Click a path to walk there.")
            .accessibilityAction(named: "Wave to a friend") { lobby.waveToFriend() }
            .accessibilityAction(named: "Play together") { lobby.playTogether() }
            .accessibilityAction(named: "Pass ball with chosen friend") { lobby.pair(quiet: false) }
            .accessibilityAction(named: "Sit with chosen friend") { lobby.pair(quiet: true) }
        }
    }
}
#endif
