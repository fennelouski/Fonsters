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
        HStack(spacing: 12) {
            Image(systemName: lobby.agent.running ? "sparkles" : "person.crop.circle").foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(lobby.agent.title).font(.system(size: 11, weight: .semibold, design: .rounded))
                Text(lobby.agent.running && !lobby.shouldAnimate ? "Automatic actions are held while the world is still or paused." : lobby.agent.message)
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if lobby.agent.running {
                Text("\(lobby.agent.cursor)/\(lobby.agent.program?.actions.count ?? 0)").monospacedDigit().font(.system(size: 11))
                if lobby.still || lobby.reduceMotion {
                    Button("Next static pose") {
                        do { try lobby.agent.performNext(lobby: lobby, manual: true) }
                        catch { self.error = error.localizedDescription }
                    }.disabled(lobby.paused || lobby.backgrounded || lobby.lowPower)
                }
                Button("Take over") { lobby.takeOwnerControl() }.keyboardShortcut(.escape, modifiers: [])
            }
            Button("Agent Studio", action: showStudio)
        }.padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
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
                    .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 5) {
                    Text("A little life, with a co-pilot.").font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Agent Studio · \(lobby.selectedMember.name)").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Let an agent help your Fonster explore, make friends, and find its own rhythm. Your next creature interaction always takes control back.")
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 20) {
                ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("ROOM TO INFLUENCE").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                    ForEach(FonsterAgentScope.allCases) { scope in
                        Toggle(scope.title, isOn: Binding(get: { agent.scopes.contains(scope) }, set: { agent.setScope(scope, enabled: $0, lobby: lobby) }))
                            .toggleStyle(.checkbox)
                    }
                    Text("Learning is gradual: one small ritual per minute, up to three this session and six a day. Agent contributions stay separate from your shared rituals.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Divider()
                    DisclosureGroup("Reflect something about me") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose broad cues yourself. These stay off until you enable each field. There is no location tracking or reading of your conversations.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            ForEach(HumanReflectionField.allCases) { field in
                                HumanReflectionControls(lobby: lobby, field: field)
                            }
                            Text("This Mac is private. Local companions can respond in this preview. These cues never enter visit files or a public feed.")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }.padding(.top, 10)
                    }.font(.system(size: 12, weight: .medium))
                    Button("Revoke agent control & reflections") { agent.revoke(lobby: lobby) }
                        .font(.system(size: 11)).buttonStyle(.bordered)
                    Text(agent.memories.status).font(.system(size: 10)).foregroundStyle(.secondary)
                }.frame(width: 315).padding(18)
                }.frame(width: 351, height: 430).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("A LITTLE PLAN").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                        Spacer()
                        Text(agent.source.title).font(.system(size: 10, weight: .medium)).foregroundStyle(.purple)
                    }
                    if let program = agent.program {
                        Text(program.agentLabel).font(.system(size: 16, weight: .semibold, design: .rounded))
                        ScrollView {
                            VStack(alignment: .leading, spacing: 9) {
                                ForEach(Array(program.actions.enumerated()), id: \.offset) { index, action in
                                    HStack(spacing: 10) {
                                        Text("\(index + 1)").font(.system(size: 10, weight: .bold)).frame(width: 23, height: 23)
                                            .background(Color.purple.opacity(0.10), in: Circle())
                                        Text(action.title).font(.system(size: 12))
                                        Spacer()
                                        if index < agent.cursor { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                    }
                                }
                            }
                        }.frame(height: 235)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles").font(.system(size: 34)).foregroundStyle(.purple.opacity(0.6))
                            Text("A hello. A little wander.\nA game, then a quiet moment.")
                                .font(.system(size: 16, weight: .medium, design: .rounded)).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).frame(height: 260)
                    }
                    HStack {
                        Button("Prepare a little plan") { attempt { try agent.prepareDemo(lobby: lobby) } }
                        Button("Import actions…") { importing = true }
                    }.font(.system(size: 11))
                    HStack {
                        Button("Save agent template…") { attempt { document = try .init(program: agent.program!); exporting = true } }
                            .disabled(agent.program == nil || agent.running)
                        Spacer()
                        Button(agent.running ? "Return to world" : "Let them explore") {
                            attempt {
                                if !agent.running { lobby.takeOwnerControl(); try agent.start(lobby: lobby) }
                                lobby.lookAtSelected(); dismiss()
                            }
                        }.buttonStyle(.borderedProminent).disabled(agent.program == nil || !lobby.ready || lobby.paused || lobby.selectedMember.isVisitor)
                    }.font(.system(size: 11))
                    Text("The pilot is simulated locally. File labels are unverified; no external agent is connected. Saved templates omit your private reflection steps.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(18).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
            }
            AgentMomentHistory(lobby: lobby)
            if let error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
        }.padding(24).frame(width: 850)
            .background(Color(red: 0.98, green: 0.97, blue: 0.95)).preferredColorScheme(.light)
            .background(VerificationWindowCapture().frame(width: 0, height: 0))
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                attempt { try agent.prepare(FonsterAgentDocument.read(result.get()), source: .localHandoff, lobby: lobby) }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "\(lobby.selectedMember.name).fonster-agent") { result in
                if case .failure = result { error = "The local action file couldn't be saved." }
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
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("LITTLE MOMENTS").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                Spacer()
                let rituals = lobby.selectedMember.controller.agentRituals
                Text("\(rituals.total) agent rituals · \(rituals.simulated) simulated · \(rituals.localHandoff) local file")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if lobby.agent.history.isEmpty { Text("Every agent action will appear here, with its source.").font(.system(size: 11)).foregroundStyle(.secondary) }
            else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(lobby.agent.history) { moment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(moment.title).font(.system(size: 11, weight: .medium))
                                Text("\(moment.source.title)\(moment.learned ? " · ritual learned" : "")").font(.system(size: 9)).foregroundStyle(.secondary)
                            }.padding(10).background(.white, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }
}
#endif
