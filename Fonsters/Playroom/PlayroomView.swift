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
    @State private var interpreter = TypedActionInterpreter()
    @State private var typingRequest = false
    private let ink = Color(red: 0.19, green: 0.15, blue: 0.27)
    private let accent = Color(red: 0.45, green: 0.32, blue: 0.62)
    private var selected: PlayroomCompanion { companions[selection] }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 206)
            Rectangle().fill(ink.opacity(0.09)).frame(width: 1)
            VStack(alignment: .leading, spacing: 14) {
                header
                stage
                controls
                footer
            }
            .padding(22)
        }
        .frame(minWidth: 950, minHeight: 740)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .foregroundStyle(ink)
        .preferredColorScheme(.light)
        .background(VerificationWindowCapture().frame(width: 0, height: 0))
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
        .onDisappear { inputs.stopAll(); interpreter.cancel(); controller.silence(); controller.toyBall = nil; controller.rig = nil; controller.rendererReady = false }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Label("FONSTERS", systemImage: "sparkle")
                    .font(.system(size: 13, weight: .black, design: .rounded)).tracking(2)
                Text("Fuzzy monsters")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("Fluffy little friends, in 3D.")
                    .font(.system(size: 12)).foregroundStyle(ink.opacity(0.55))
            }.padding(.horizontal, 18).padding(.top, 22)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(companions) { companion in
                        Button {
                            if let index = companions.firstIndex(where: { $0.id == companion.id }) {
                                if index == selection { controller.perform(.greet, name: companion.name) }
                                else {
                                    controller.rendererReady = false; controller.rig = nil
                                    controller.rendererError = nil
                                    selection = index; exportMessage = nil
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                CreatureAvatarView(seed: companion.seed, size: 42)
                                    .padding(4).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(companion.name).font(.system(size: 14, weight: .semibold, design: .rounded))
                                    Text(selection == companions.firstIndex(where: { $0.id == companion.id }) ? "Here with you" : "Come say hello")
                                        .font(.system(size: 10)).foregroundStyle(ink.opacity(0.48))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(selected.id == companion.id ? accent.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Meet \(companion.name)")
                        .accessibilityAddTraits(selected.id == companion.id ? .isSelected : [])
                    }
                }.padding(.horizontal, 10)
            }
            Text("Just company.\nNo chores, no clocks.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ink.opacity(0.45)).lineSpacing(4)
                .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .background(Color(red: 0.95, green: 0.93, blue: 0.92))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Meet \(selected.name).")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(selected.note).font(.system(size: 14)).foregroundStyle(ink.opacity(0.55))
            }
            Spacer()
            Button {
                controller.paused = true; interpreter.cancel()
                openWindow(id: "lobby")
            } label: { Label("Lobby", systemImage: "person.3") }
                .buttonStyle(.bordered).help("A local hangout for four preview Fonsters.")
            Button { showsPersonality.toggle() } label: {
                Label("Personality", systemImage: "heart.text.square")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showsPersonality) { personalityCard }
            Label("THE PLAYROOM", systemImage: "cube.transparent")
                .font(.system(size: 10, weight: .bold)).tracking(1.3)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(accent.opacity(0.09), in: Capsule())
                .padding(.top, 6)
        }
    }

    private var personalityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Getting to know \(selected.name)")
                .font(.system(size: 23, weight: .semibold, design: .rounded))
            Text(controller.personality?.naturalQuirk ?? selected.note)
                .foregroundStyle(.secondary)
            ForEach(controller.personality?.observations(name: selected.name) ?? [], id: \.self) { observation in
                Label(observation, systemImage: "sparkle")
                    .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Text("Find a favorite voice")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text("Hear a chirp, then give one a heart. It becomes part of your shared hello.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            ForEach(0..<3, id: \.self) { variant in
                HStack {
                    Text(CreaturePersonality.soundNames[variant]).font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button { controller.auditionSound(variant) } label: { Label("Hear", systemImage: "speaker.wave.2") }
                        .disabled(!controller.soundEnabled || controller.paused || controller.backgrounded)
                        .help("Turn Sounds on to hear this chirp.")
                    Button { controller.likeSound(variant) } label: {
                        Image(systemName: controller.personality?.favoriteSound == variant ? "heart.fill" : "heart")
                    }.accessibilityLabel("Prefer the \(CreaturePersonality.soundNames[variant].lowercased()) voice")
                }.buttonStyle(.bordered).controlSize(.small)
            }
            Text("Hellos, games and quiet moments slowly shape your companion. It’s always happy when you return.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text(controller.memoryStatus).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(24).frame(width: 390).foregroundStyle(ink)
    }

    private var stage: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 26)
                    .fill(LinearGradient(colors: [Color(red: 0.91, green: 0.88, blue: 0.95), Color(red: 0.98, green: 0.95, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
                if selected.descriptor.supported && controller.rendererError == nil {
                    CreatureStageView(companion: selected, controller: controller)
                        .id(selected.id)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                } else {
                    VStack(spacing: 15) {
                        CreatureAvatarView(seed: selected.seed, size: 180)
                        Text(controller.rendererError ?? selected.descriptor.fallbackReason ?? "Original portrait")
                            .font(.callout).multilineTextAlignment(.center).padding(.horizontal, 20)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Label("A LITTLE MORE ALIVE", systemImage: "cube.fill")
                    .font(.system(size: 9, weight: .bold)).tracking(1.5)
                    .foregroundStyle(ink.opacity(0.48)).padding(20)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Tap hello · double tap high five · drag gently for a rub")
                            .font(.system(size: 11)).foregroundStyle(ink.opacity(0.47))
                        Spacer()
                    }.padding(.bottom, 16)
                }.allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 16) {
                Text("THE ORIGINAL").font(.system(size: 9, weight: .bold)).tracking(1.6).foregroundStyle(ink.opacity(0.45))
                CreatureAvatarView(seed: selected.seed, size: 140)
                    .frame(width: 156, height: 156)
                    .background(Color(red: 0.94, green: 0.92, blue: 0.91), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(false)
                    .accessibilityLabel("Original 32 by 32 portrait of \(selected.name)")
                Text("Same little soul.")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("The familiar silhouette, colors and tiny details, given a little depth.")
                    .font(.system(size: 12)).foregroundStyle(ink.opacity(0.58)).lineSpacing(3)
                Spacer(minLength: 4)
                HStack(spacing: 7) {
                    ForEach(Array(selected.descriptor.rgbaPalette.prefix(selected.descriptor.palette.count).enumerated()), id: \.offset) { _, p in
                        Circle().fill(Color(red: Double(p[0]) / 255, green: Double(p[1]) / 255, blue: Double(p[2]) / 255))
                            .frame(width: 16, height: 16)
                    }
                }.accessibilityLabel("Original color palette")
                Menu {
                    Button("Save original PNG…") { exportPNG() }
                    Button("Save evolution GIF…") { exportGIF() }
                } label: {
                    Label("Save portrait", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Save original two dimensional portrait")
                Text("32 × 32 · legacy appearance")
                    .font(.system(size: 9)).foregroundStyle(ink.opacity(0.4))
            }
            .padding(20).frame(width: 196)
            .frame(maxHeight: .infinity)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        }.frame(minHeight: 260, maxHeight: .infinity)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                reactionButton("Say hello", "hand.wave", .greet, "h")
                reactionButton("Play", "sparkles", .play, "p")
                reactionButton("Rest", "moon", .rest, "r")
                reactionButton("Blink", "eye", .blink, "b")
                reactionButton("Look", "eyes", .look, "l")
            }
            HStack(spacing: 7) {
                littleReaction("Hop", "hare", .hop)
                littleReaction("Twirl", "arrow.trianglehead.2.clockwise.rotate.90", .spin)
                littleReaction("Stretch", "figure.flexibility", .stretch)
                littleReaction("High five", "hand.raised", .highFive)
                littleReaction("Gentle rub", "heart", .rub)
                littleReaction("Toss ball", "circle.dotted", .fetch)
                Button { controller.followPointer() } label: {
                    Label(controller.followingPointer ? "Following" : "Follow", systemImage: "cursorarrow.rays")
                }.buttonStyle(.bordered).tint(controller.followingPointer ? accent : nil)
            }.font(.system(size: 11)).controlSize(.small)
            HStack(spacing: 10) {
                Image(systemName: "rotate.3d").font(.system(size: 14))
                Text("Turn").font(.system(size: 12, weight: .medium))
                Slider(value: $controller.orbit, in: -180...180)
                    .tint(accent).frame(maxWidth: 190)
                    .accessibilityLabel("Turn \(selected.name) in three dimensions")
                Text("\(Int(controller.orbit))°").font(.system(size: 10, design: .monospaced)).frame(width: 36)
                Spacer()
                Toggle("Wander", isOn: Binding(get: { controller.roaming }, set: { controller.setRoaming($0) }))
                    .toggleStyle(.checkbox).font(.system(size: 12))
                Toggle("Still mode", isOn: $controller.staticMode)
                    .toggleStyle(.checkbox).font(.system(size: 12))
                Button {
                    controller.paused.toggle()
                } label: {
                    Label(controller.paused ? "Resume" : "Pause", systemImage: controller.paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered).keyboardShortcut(typingRequest ? nil : KeyboardShortcut(.space, modifiers: []))
                .accessibilityLabel(controller.paused ? "Resume motion" : "Pause motion")
            }.foregroundStyle(ink.opacity(0.65))
            inputControls
            CreatureCommandBar(interpreter: interpreter, selected: selected.name, names: [selected.name],
                               revision: controller.userRevision,
                               enabled: controller.rendererReady && !controller.paused && !controller.backgrounded && !controller.lowPower,
                               currentRevision: { controller.userRevision }, apply: { controller.execute($0) },
                               onFocusChange: { typingRequest = $0 })
        }
    }
    private func littleReaction(_ title: String, _ icon: String, _ action: PlayroomController.Reaction) -> some View {
        Button { controller.perform(action, name: selected.name) } label: { Label(title, systemImage: icon) }
            .buttonStyle(.bordered).disabled(!controller.rendererReady)
    }

    private var inputControls: some View {
        HStack(spacing: 12) {
            Toggle("Sounds", isOn: $controller.soundEnabled).toggleStyle(.checkbox)
                .help("Original prototype chirps. ElevenLabs clips can replace these later.")
            Button { inputs.toggleMicrophone() } label: {
                Label(inputs.microphoneEnabled ? "Stop listening" : "Listen", systemImage: inputs.microphoneEnabled ? "mic.fill" : "mic")
            }.buttonStyle(.bordered)
                .help("Microphone levels trigger a hello. Audio stays local and isn’t recorded.")
            Button { inputs.toggleCamera() } label: {
                Label(inputs.cameraEnabled ? "Camera off" : "Camera look", systemImage: inputs.cameraEnabled ? "video.fill" : "video")
            }.buttonStyle(.bordered)
                .help("Follow a detected face locally. Frames aren’t stored or sent anywhere.")
            Spacer(minLength: 4)
            if inputs.microphoneEnabled {
                ProgressView(value: Double(inputs.level)).frame(width: 48)
                    .accessibilityLabel("Microphone activity")
            }
            Text(inputs.status).foregroundStyle(ink.opacity(0.45)).lineLimit(1)
        }.font(.system(size: 10)).controlSize(.small)
    }

    private func suspendInputsIfNeeded() {
        inputs.setSuspended(controller.backgrounded || controller.paused || controller.lowPower)
    }

    private func reactionButton(_ title: String, _ icon: String, _ reaction: PlayroomController.Reaction, _ key: KeyEquivalent) -> some View {
        Button { controller.perform(reaction, name: selected.name) } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(controller.reaction == reaction ? accent : .white,
                            in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(controller.reaction == reaction ? .white : ink)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ink.opacity(0.08)))
        }
        .buttonStyle(.plain).keyboardShortcut(typingRequest ? nil : KeyboardShortcut(key, modifiers: []))
        .help("\(title) (\(key.character.uppercased()))")
        .disabled(!selected.descriptor.supported || controller.rendererError != nil)
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Circle().fill(controller.shouldAnimate ? Color(red: 0.42, green: 0.62, blue: 0.42) : ink.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(exportMessage ?? controller.message).font(.system(size: 12, weight: .medium, design: .rounded))
                .accessibilityIdentifier("reactionStatus")
            Spacer()
            Text(controller.motionStatus).font(.system(size: 10)).foregroundStyle(ink.opacity(0.45))
                .accessibilityIdentifier("motionStatus")
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
