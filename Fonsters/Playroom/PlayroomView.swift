#if os(macOS)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@available(macOS 15.0, *)
struct PlayroomView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @State private var controller = PlayroomController()
    @State private var inputs = CreatureInputs()
    @State private var companions = PlayroomCompanion.fixtures
    @State private var selection = 0
    @State private var exportMessage: String?
    @State private var showsPersonality = false
    @State private var showsCommand = false
    @State private var interpreter = TypedActionInterpreter()
    @State private var typingRequest = false
    private let ink = Color(red: 0.19, green: 0.15, blue: 0.27)
    private let accent = Color(red: 0.45, green: 0.32, blue: 0.62)
    private var selected: PlayroomCompanion { companions[selection] }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 104)
            Rectangle().fill(ink.opacity(0.09)).frame(width: 1)
            VStack(alignment: .leading, spacing: 14) {
                header
                stage
                controls
                footer
            }
            .padding(22)
        }
        .frame(minWidth: 950, minHeight: 700)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .foregroundStyle(ink)
        .preferredColorScheme(.light)
        .background(VerificationWindowCapture(label: "playroom").frame(width: 0, height: 0))
        .task(id: controller.shouldAnimate) {
            if controller.shouldAnimate { await controller.animate() }
            else { controller.refreshStillPose() }
        }
        .onChange(of: reduceMotion, initial: true) { controller.systemReduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion") }
        .onChange(of: scenePhase, initial: true) {
            controller.backgrounded = scenePhase != .active
            suspendInputsIfNeeded()
            controller.refreshStillPose()
        }
        .onChange(of: controller.paused) { suspendInputsIfNeeded(); controller.refreshStillPose() }
        .onChange(of: controller.lowPower) { suspendInputsIfNeeded(); controller.refreshStillPose() }
        .onChange(of: controller.staticMode) { controller.refreshStillPose() }
        .onChange(of: controller.systemReduceMotion) { controller.refreshStillPose() }
        .onChange(of: controller.soundEnabled) { if !controller.soundEnabled { controller.silence() } }
        .onChange(of: selection, initial: true) {
            if controller.personality == nil { controller.enablePersonalityLearning(PersonalityMemoryStore.localPreview()) }
            inputs.onVoiceActivity = { [weak current = controller, name = selected.name] in
                guard let current, !current.isSpeaking else { return }
                current.perform(.greet, name: name, learn: false)
            }
            inputs.onFace = { [weak current = controller] point in current?.look(point) }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
            controller.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onChange(of: controller.orbit) { controller.refreshStillPose() }
        .onDisappear { inputs.stopAll(); interpreter.cancel(); controller.silence(); controller.toyBall = nil; controller.touchCamera = nil; controller.rig = nil; controller.rendererReady = false }
    }

    private var sidebar: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkle").font(.system(size: 26, weight: .medium))
                .foregroundStyle(accent).padding(.top, 26).accessibilityLabel("Fonsters")
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(companions) { companion in
                        FonsterPortraitChoice(name: "Meet \(companion.name)", selected: selected.id == companion.id,
                            portrait: { CreatureAvatarView(seed: companion.seed, size: 48) }, action: {
                                if let index = companions.firstIndex(where: { $0.id == companion.id }) {
                                    if index == selection { controller.perform(.greet, name: companion.name) }
                                    else {
                                        controller.rendererReady = false; controller.rig = nil; controller.rendererError = nil
                                        selection = index; exportMessage = nil
                                    }
                                }
                            })
                    }
                }.padding(.horizontal, 14).padding(.vertical, 4)
            }
            FonsterInfo(title: "About the Playroom", detail: "Choose a portrait, then touch your Fonster. Stroke the fluff, hold for a cuddle, or tap a paw for a high five. The original portrait beside it stays unchanged. Your companion is always happy when you return.")
                .padding(.bottom, 16)
        }.background(Color(red: 0.95, green: 0.93, blue: 0.92))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(selected.name).font(.system(size: 28, weight: .bold, design: .rounded))
            Spacer()
            FonsterIconButton(title: "Open the local world", symbol: "person.3", tone: .world) {
                controller.paused = true; interpreter.cancel(); openWindow(id: "lobby")
            }
            FonsterIconButton(title: "\(selected.name)'s developing personality", symbol: "heart.text.square", tone: .company, selected: showsPersonality) { showsPersonality.toggle() }
                .popover(isPresented: $showsPersonality) { personalityCard }
        }
    }

    private var personalityCard: some View {
        VStack(spacing: 20) {
            CreatureAvatarView(seed: selected.seed, size: 72)
            Text(selected.name).font(.system(size: 24, weight: .semibold, design: .rounded))
            if let personality = controller.personality {
                HStack(spacing: 16) {
                    Image(systemName: "heart.fill").foregroundStyle(FonsterTone.company.ink)
                    ProgressView(value: personality.greetingWarmth).tint(FonsterTone.company.ink)
                        .accessibilityLabel("Greeting warmth").accessibilityValue("\(Int(personality.greetingWarmth * 100)) percent")
                    FonsterInfo(title: "Greeting warmth", detail: personality.naturalQuirk + " Your shared hellos gradually shape how warmly your Fonster greets you.")
                }
                HStack(spacing: 16) {
                    Image(systemName: "tennisball.fill").foregroundStyle(FonsterTone.play.ink)
                    ProgressView(value: personality.playEnergy).tint(FonsterTone.play.ink)
                        .accessibilityLabel("Play energy").accessibilityValue("\(Int(personality.playEnergy * 100)) percent")
                    FonsterInfo(title: "Shared rituals", detail: personality.observations(name: selected.name).joined(separator: "\n") + "\n" + controller.memoryStatus)
                }
                HStack(spacing: 24) {
                    Label("\(personality.hellos)", systemImage: "hand.wave")
                    Label("\(personality.games)", systemImage: "tennisball")
                    Label("\(personality.rests)", systemImage: "moon")
                }.font(.system(size: 13, weight: .medium)).accessibilityLabel("\(personality.hellos) shared hellos, \(personality.games) games, \(personality.rests) quiet moments")
            }
            Divider()
            HStack(spacing: 18) {
                ForEach(0..<3, id: \.self) { variant in
                    VStack(spacing: 8) {
                        FonsterIconButton(title: "Hear the \(CreaturePersonality.soundNames[variant].lowercased()) voice", symbol: ["waveform", "waveform.path", "waveform.path.ecg"][variant], tone: .play) { controller.auditionSound(variant) }
                            .disabled(!controller.soundEnabled || controller.paused || controller.backgrounded)
                        FonsterIconButton(title: "Prefer the \(CreaturePersonality.soundNames[variant].lowercased()) voice", symbol: "heart", tone: .company, selected: controller.personality?.favoriteSound == variant) { controller.likeSound(variant) }
                    }
                }
            }
            FonsterInfo(title: "Favorite voice", detail: "With sound enabled, hear each voice and give your favorite a heart. Hellos, games, and quiet moments slowly shape your companion; there are no chores or care penalties.")
        }.padding(24).frame(width: 320).foregroundStyle(ink)
    }

    private var stage: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 26)
                    .fill(LinearGradient(colors: [Color(red: 0.91, green: 0.88, blue: 0.95), Color(red: 0.98, green: 0.95, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
                if selected.descriptor.supported && controller.rendererError == nil {
                    CreatureStageView(companion: selected, controller: controller)
                        .id(selected.id.uuidString + controller.environment.rawValue)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                } else {
                    VStack(spacing: 15) {
                        CreatureAvatarView(seed: selected.seed, size: 180)
                        Text(controller.rendererError ?? selected.descriptor.fallbackReason ?? "Original portrait")
                            .font(.callout).multilineTextAlignment(.center).padding(.horizontal, 20)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 18) {
                Image(systemName: "square.grid.3x3").font(.system(size: 18)).foregroundStyle(ink.opacity(0.55))
                    .accessibilityLabel("Original two dimensional portrait")
                CreatureAvatarView(seed: selected.seed, size: 104)
                    .frame(width: 116, height: 116)
                    .background(Color(red: 0.94, green: 0.92, blue: 0.91), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel("Original 32 by 32 portrait of \(selected.name)")
                HStack(spacing: 6) {
                    ForEach(Array(selected.descriptor.rgbaPalette.prefix(selected.descriptor.palette.count).enumerated()), id: \.offset) { _, p in
                        Circle().fill(Color(red: Double(p[0]) / 255, green: Double(p[1]) / 255, blue: Double(p[2]) / 255)).frame(width: 12, height: 12)
                    }
                }.accessibilityLabel("Original color palette")
                Spacer(minLength: 0)
                Menu {
                    Button("Save original PNG…") { exportPNG() }
                    Button("Save evolution GIF…") { exportGIF() }
                } label: { FonsterIcon(symbol: "square.and.arrow.down", tone: .world) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .frame(width: 44, height: 44).background(FonsterTone.world.wash, in: RoundedRectangle(cornerRadius: 14))
                    .help("Save original PNG or evolution GIF").accessibilityLabel("Save original portrait")
            }.padding(14).frame(width: 144).frame(maxHeight: .infinity)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        }.frame(minHeight: 260, maxHeight: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                FonsterControlGroup(title: "Touch and company", tone: .company) {
                    reactionButton("Say hello", "hand.wave", .greet, "h", .company)
                    littleReaction("Gentle rub", "heart", .rub, .company)
                    littleReaction("High five", "hand.raised", .highFive, .company)
                }
                FonsterControlGroup(title: "Play", tone: .play) {
                    reactionButton("Play", "sparkles", .play, "p", .play)
                    littleReaction("Toss ball", "tennisball", .fetch, .play)
                    littleReaction("Hop", "hare", .hop, .play)
                    littleReaction("Twirl", "arrow.trianglehead.2.clockwise.rotate.90", .spin, .play)
                }
                FonsterControlGroup(title: "Quiet and curiosity", tone: .world) {
                    reactionButton("Rest", "moon", .rest, "r", .world)
                    littleReaction("Stretch", "figure.flexibility", .stretch, .world)
                    reactionButton("Blink", "eye", .blink, "b", .world)
                    reactionButton("Look", "eyes", .look, "l", .world)
                }
                Spacer(minLength: 0)
                FonsterIconButton(title: "Type a request", symbol: "text.bubble", tone: .world, selected: showsCommand) { showsCommand.toggle() }
            }
            HStack(spacing: 10) {
                Image(systemName: "rotate.3d").foregroundStyle(accent).accessibilityHidden(true)
                Slider(value: $controller.orbit, in: -180...180).tint(accent).frame(maxWidth: 150)
                    .accessibilityLabel("Turn \(selected.name) in three dimensions")
                FonsterIconButton(title: "Follow the pointer", symbol: "cursorarrow.rays", selected: controller.followingPointer) { controller.followPointer() }
                FonsterControlGroup(title: "Environments", tone: .world) {
                    ForEach(CompanionEnvironment.allCases) { environment in
                        FonsterIconButton(title: environment.title, symbol: environment.symbol, tone: .world, selected: controller.environment == environment) {
                            controller.cancelTouch(); controller.rendererReady = false; controller.environment = environment
                        }
                    }
                }
                Spacer(minLength: 0)
                inputControls
                FonsterControlGroup(title: "Motion") {
                    FonsterIconToggle(title: "Wander", symbol: "figure.walk", isOn: Binding(get: { controller.roaming }, set: { controller.setRoaming($0) }))
                    FonsterIconToggle(title: "Still mode", symbol: "snowflake", isOn: $controller.staticMode)
                    FonsterIconButton(title: controller.paused ? "Resume motion" : "Pause motion", symbol: controller.paused ? "play.fill" : "pause.fill", selected: controller.paused) { controller.paused.toggle() }
                        .keyboardShortcut(typingRequest ? nil : KeyboardShortcut(.space, modifiers: []))
                }
            }
            if showsCommand {
                CreatureCommandBar(interpreter: interpreter, selected: selected.name, names: [selected.name], revision: controller.userRevision,
                    enabled: controller.rendererReady && !controller.paused && !controller.backgrounded && !controller.lowPower,
                    currentRevision: { controller.userRevision }, apply: { controller.execute($0) }, onFocusChange: { typingRequest = $0 })
            }
        }
    }
    private func littleReaction(_ title: String, _ icon: String, _ action: PlayroomController.Reaction, _ tone: FonsterTone) -> some View {
        FonsterIconButton(title: title, symbol: icon, tone: tone, selected: controller.reaction == action) { controller.perform(action, name: selected.name) }
            .disabled(!controller.rendererReady)
    }
    private var inputControls: some View {
        FonsterControlGroup(title: "Sound, microphone and camera") {
            FonsterIconToggle(title: "Sounds", symbol: "speaker.wave.2", isOn: $controller.soundEnabled)
            FonsterIconButton(title: inputs.microphoneEnabled ? "Stop listening" : "Listen locally; audio is not recorded", symbol: "mic", selected: inputs.microphoneEnabled) { inputs.toggleMicrophone() }
            FonsterIconButton(title: inputs.cameraEnabled ? "Turn camera off" : "Follow a face locally; frames are not stored", symbol: "video", selected: inputs.cameraEnabled) { inputs.toggleCamera() }
            if inputs.microphoneEnabled {
                ProgressView(value: Double(inputs.level)).frame(width: 36).accessibilityLabel("Microphone activity")
            }
        }.help(inputs.status)
    }

    private func suspendInputsIfNeeded() {
        inputs.setSuspended(controller.backgrounded || controller.paused || controller.lowPower)
    }

    private func reactionButton(_ title: String, _ icon: String, _ reaction: PlayroomController.Reaction, _ key: KeyEquivalent, _ tone: FonsterTone) -> some View {
        FonsterIconButton(title: "\(title) (\(key.character.uppercased()))", symbol: icon, tone: tone, selected: controller.reaction == reaction) { controller.perform(reaction, name: selected.name) }
            .keyboardShortcut(typingRequest ? nil : KeyboardShortcut(key, modifiers: []))
            .disabled(!selected.descriptor.supported || controller.rendererError != nil)
    }
    private var footer: some View {
        HStack(spacing: 8) {
            FonsterStatus(symbol: exportMessage == nil ? "heart" : "square.and.arrow.down", detail: exportMessage ?? controller.message, tone: .company)
                .accessibilityIdentifier("reactionStatus")
            Spacer()
            FonsterStatus(symbol: controller.shouldAnimate ? "waveform.path" : "pause.circle", detail: controller.motionStatus)
                .accessibilityIdentifier("motionStatus")
            FonsterInfo(title: "Camera and microphone privacy", detail: inputs.status + "\nMicrophone activity triggers a hello; audio stays local and isn't recorded. Camera face detection stays local; frames aren't stored. Pause, background, and Low Power suspend both inputs.")
        }
    }

    private func exportPNG() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png]; panel.nameFieldStringValue = "\(selected.name).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportMessage = writeCreatureStickerPNG(seed: selected.seed, to: url, sideLength: 512) ? "Original portrait saved." : "Couldn’t save the portrait."
    }
    private func exportGIF() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.gif]; panel.nameFieldStringValue = "\(selected.name).gif"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let seeds = (1...selected.seed.count).map { String(selected.seed.prefix($0)) }
        do {
            guard let data = creatureGIFData(seeds: seeds) else { exportMessage = "Couldn’t render the GIF."; return }
            try data.write(to: url); exportMessage = "Original evolution GIF saved."
        } catch { exportMessage = "Couldn’t save the GIF." }
    }
}
#endif
