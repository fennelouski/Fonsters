#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct FonsterAgentDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(program: FonsterAgentProgram) throws { data = try program.publicHandoff().encoded() }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw FonsterAgentError.invalid }
        _ = try FonsterAgentProgram.decode(data); self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
    static func read(_ url: URL) throws -> FonsterAgentProgram {
        guard url.isFileURL else { throw FonsterAgentError.invalid }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize else { throw FonsterAgentError.invalid }
        guard size <= FonsterAgentProgram.byteLimit else { throw FonsterAgentError.tooLarge }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        return try .decode(handle.read(upToCount: FonsterAgentProgram.byteLimit + 1) ?? Data())
    }
}

@available(macOS 15.0, *)
struct FonsterAgentStatus: View {
    let lobby: LocalLobbyController
    let showStudio: () -> Void
    @State private var error: String?
    var body: some View {
        HStack(spacing: 8) {
            FonsterIconButton(title: "Agent Studio: \(lobby.agent.title)", symbol: "sparkles", tone: .world, selected: lobby.agent.running, action: showStudio)
            if lobby.agent.running {
                ProgressView(value: Double(lobby.agent.cursor), total: Double(max(1, lobby.agent.program?.actions.count ?? 1)))
                    .frame(maxWidth: 90).tint(FonsterTone.world.ink)
                    .accessibilityLabel("Agent plan progress")
                    .help(lobby.agent.message)
                if lobby.still || lobby.reduceMotion {
                    FonsterIconButton(title: "Next static pose", symbol: "forward.end", tone: .world) {
                        do { try lobby.agent.performNext(lobby: lobby, manual: true) }
                        catch { self.error = error.localizedDescription }
                    }.disabled(lobby.paused || lobby.backgrounded || lobby.lowPower)
                }
                FonsterIconButton(title: "Take over from the agent", symbol: "hand.raised", tone: .company) { lobby.takeOwnerControl() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            Spacer(minLength: 0)
        }.accessibilityElement(children: .contain)
            .alert("Agent action held", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
    }
}

@available(macOS 15.0, *)
struct FonsterAgentStudio: View {
    let lobby: LocalLobbyController
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var exporting = false
    @State private var document: FonsterAgentDocument?
    @State private var error: String?
    private var agent: FonsterAgentDirector { lobby.agent }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 15) {
                ResolvedPortrait(appearance: lobby.selectedMember.descriptor).frame(width: 65, height: 65)
                    .padding(10).background(FonsterTone.world.wash, in: RoundedRectangle(cornerRadius: 22))
                Text(lobby.selectedMember.name).font(.system(size: 26, weight: .bold, design: .rounded))
                FonsterInfo(title: "Agent control and source", detail: "The pilot is simulated locally. File labels are unverified; no external agent is connected. Your next creature interaction takes control back. Saved templates omit your private reflection steps.")
                Spacer()
                FonsterIconButton(title: "Return to the world", symbol: "xmark", tone: .world) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack(alignment: .top, spacing: 20) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 3), spacing: 12) {
                            ForEach(FonsterAgentScope.allCases) { scope in
                                FonsterIconToggle(title: "Allow agent influence: \(scope.title)", symbol: scopeSymbol(scope), tone: .world,
                                    isOn: Binding(get: { agent.scopes.contains(scope) }, set: { agent.setScope(scope, enabled: $0, lobby: lobby) }))
                            }
                        }.accessibilityElement(children: .contain).accessibilityLabel("Agent influence choices")
                        FonsterInfo(title: "Personality learning limits", detail: "Learning is gradual: one small ritual per minute, up to three this session and six a day. Agent contributions stay separate from your shared rituals. " + agent.memories.status)
                        Divider()
                        DisclosureGroup("Reflect my cues") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Optional cues you choose. No location tracking or conversation reading. Cues never enter visit files or a public feed.")
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                                ForEach(HumanReflectionField.allCases) { field in HumanReflectionControls(lobby: lobby, field: field) }
                            }.padding(.top, 10)
                        }.font(.system(size: 12, weight: .medium))
                        FonsterIconButton(title: "Revoke agent control and all reflection choices", symbol: "hand.raised.slash", tone: .company) { agent.revoke(lobby: lobby) }
                    }.padding(18)
                }.frame(width: 250, height: 350).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24))
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        FonsterStatus(symbol: agent.source == .simulated ? "desktopcomputer" : "doc.badge.checkmark", detail: agent.source.title + ". No external agent is connected.", tone: .world)
                        Spacer()
                        if let program = agent.program { Text(program.agentLabel).font(.system(size: 12, weight: .medium, design: .rounded)) }
                    }
                    if let program = agent.program {
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                                ForEach(Array(program.actions.enumerated()), id: \.offset) { index, action in
                                    VStack(spacing: 8) {
                                        FonsterIcon(symbol: actionSymbol(action), tone: .world, selected: index < agent.cursor)
                                        Text("\(index + 1)").font(.system(size: 11, weight: .medium, design: .rounded))
                                    }.help(action.title).accessibilityElement(children: .ignore)
                                        .accessibilityLabel("Step \(index + 1): \(action.title)\(index < agent.cursor ? ", complete" : "")")
                                }
                            }.padding(8)
                        }.frame(height: 220)
                    } else {
                        HStack(spacing: 16) {
                            ForEach(Array(["hand.wave", "arrow.right", "leaf", "arrow.right", "tennisball", "arrow.right", "moon"].enumerated()), id: \.offset) { _, symbol in
                                Image(systemName: symbol).font(.system(size: symbol == "arrow.right" ? 12 : 28)).foregroundStyle(FonsterTone.world.ink)
                            }
                        }.frame(maxWidth: .infinity).frame(height: 220)
                            .accessibilityLabel("Prepare a plan: greet, explore, play, and rest")
                    }
                    HStack(spacing: 10) {
                        FonsterIconButton(title: "Prepare a local simulated plan", symbol: "wand.and.stars", tone: .world) { attempt { try agent.prepareDemo(lobby: lobby) } }
                        FonsterIconButton(title: "Import a reviewed action file", symbol: "square.and.arrow.down", tone: .world) { importing = true }
                        FonsterIconButton(title: "Save an agent template without private reflection", symbol: "square.and.arrow.up", tone: .world) {
                            attempt { guard let program = agent.program else { throw FonsterAgentError.invalid }; document = try .init(program: program); exporting = true }
                        }.disabled(agent.program == nil || agent.running)
                        Spacer()
                        FonsterIconButton(title: agent.running ? "Return to the world" : "Start the reviewed plan", symbol: "play.fill", tone: .company) {
                            attempt {
                                if !agent.running { lobby.takeOwnerControl(); try agent.start(lobby: lobby) }
                                lobby.lookAtSelected(); dismiss()
                            }
                        }.disabled(agent.program == nil || !lobby.ready || lobby.paused || lobby.selectedMember.isVisitor)
                    }
                }.frame(maxWidth: .infinity).padding(18).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24))
            }
            AgentMomentHistory(lobby: lobby)
            if let error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
        }.padding(24).frame(width: 850)
            .background(Color(red: 0.98, green: 0.97, blue: 0.95)).preferredColorScheme(.light)
            .background(VerificationWindowCapture(label: "agent").frame(width: 0, height: 0))
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                attempt { try agent.prepare(FonsterAgentDocument.read(result.get()), source: .localHandoff, lobby: lobby) }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "\(lobby.selectedMember.name).fonster-agent") { result in
                if case .failure = result { error = "The local action file couldn't be saved." }
            }
    }
    private func scopeSymbol(_ scope: FonsterAgentScope) -> String {
        switch scope { case .movement: "figure.walk"; case .reactions: "hand.wave"; case .feelings: "heart"; case .friendships: "person.2"; case .learning: "sparkle" }
    }
    private func actionSymbol(_ action: FonsterAgentAction) -> String {
        switch action.kind {
        case .react: ["greet": "hand.wave", "play": "sparkles", "rest": "moon", "blink": "eye", "look": "eyes", "hop": "hare", "spin": "arrow.clockwise", "stretch": "figure.flexibility", "highFive": "hand.raised", "rub": "heart", "fetch": "tennisball"][action.reaction ?? ""] ?? "sparkles"
        case .explore: "leaf"
        case .feeling: action.feeling?.symbol ?? "heart"
        case .greet: "hand.wave"
        case .playTogether: "tennisball"
        case .quietTogether: "person.2"
        case .bench: "chair.lounge"
        case .reflect: "person.crop.circle"
        }
    }
    private func attempt(_ action: () throws -> Void) {
        do { try action(); error = nil }
        catch { if (error as NSError).code != NSUserCancelledError { self.error = error.localizedDescription } }
    }
}

@available(macOS 15.0, *)
private struct HumanReflectionControls: View {
    let lobby: LocalLobbyController
    let field: HumanReflectionField
    private var rule: HumanReflectionRule { lobby.agent.reflections[field]! }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Reflect my \(field.title.lowercased())", isOn: Binding(get: { rule.enabled }, set: { var next = rule; next.enabled = $0; lobby.agent.setReflection(field, rule: next, lobby: lobby) })).toggleStyle(.checkbox)
            if rule.enabled {
                Picker("Cue I choose", selection: Binding(get: { rule.cue }, set: { var next = rule; next.cue = $0; lobby.agent.setReflection(field, rule: next, lobby: lobby) })) {
                    ForEach(field.choices) { cue in Text(cue.title).tag(cue) }
                }
                Picker("Audience", selection: Binding(get: { rule.audience }, set: { var next = rule; next.audience = $0; lobby.agent.setReflection(field, rule: next, lobby: lobby) })) {
                    ForEach(HumanReflectionAudience.allCases) { audience in Text(audience.title).tag(audience) }
                }
            }
        }.font(.system(size: 11))
    }
}

@available(macOS 15.0, *)
private struct AgentMomentHistory: View {
    let lobby: LocalLobbyController
    var body: some View {
        HStack(spacing: 10) {
            let rituals = lobby.selectedMember.controller.agentRituals
            Label("\(rituals.total)", systemImage: "sparkle").font(.system(size: 12))
                .help("\(rituals.simulated) simulated rituals; \(rituals.localHandoff) from reviewed local files")
                .accessibilityLabel("\(rituals.total) learned agent rituals")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(lobby.agent.history) { moment in
                        FonsterStatus(symbol: moment.learned ? "sparkle" : "checkmark.circle", detail: moment.title + " · " + moment.source.title + (moment.learned ? " · ritual learned" : ""), tone: .world)
                    }
                }
            }
        }

    }
}
#endif
