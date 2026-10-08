#if os(macOS) || os(iOS)
import SwiftUI
import Observation
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedCreatureCommand {
    @Guide(description: "One available physical action. Use unknown for unsupported, unclear, or multiple different actions.",
           .anyOf(["hello", "dance", "rest", "blink", "look", "hop", "spin", "stretch", "highFive", "rub", "fetch", "follow", "roam", "stop", "greetFriend", "unknown"]))
    var action: String
    @Guide(description: "The creature doing the action. Use selected unless the user explicitly names the actor.",
           .anyOf(["selected", "Coral", "Moss", "Iris", "Tide", "Orbit", "Plum", "Poppy", "Inky", "Pebble", "Nori", "Ember", "Wisp", "Visitor"]))
    var target: String
    @Guide(description: "For greetFriend only, the named neighbor receiving the greeting. Otherwise none.",
           .anyOf(["none", "Coral", "Moss", "Iris", "Tide", "Orbit", "Plum", "Poppy", "Inky", "Pebble", "Nori", "Ember", "Wisp", "Visitor"]))
    var peer: String
}

@available(macOS 15.0, iOS 18.0, *)
@MainActor @Observable
final class TypedActionInterpreter {
    private(set) var isBusy = false
    private(set) var status = "Try ‘do a little twirl’ or ‘take a nap’."
    private(set) var capability = "Known commands · on this device"
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private(set) var appliedCount = 0
    @ObservationIgnored private(set) var lastSource = "none"
    @ObservationIgnored private(set) var lastModelAction: String?
    @ObservationIgnored private(set) var lastErrorCode: String?

    init() { refreshCapability() }
    func refreshCapability() {
        if ProcessInfo.processInfo.arguments.contains("--verify-command-fallback") { capability = "Known commands · verification"; return }
        if #available(macOS 26.0, iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: capability = "Apple Intelligence · on this device"
            case .unavailable(.appleIntelligenceNotEnabled): capability = "Apple Intelligence is off · known commands work"
            case .unavailable(.deviceNotEligible): capability = "Known commands · Apple Intelligence isn’t supported here"
            case .unavailable(.modelNotReady): capability = "Apple Intelligence is getting ready · known commands work"
            @unknown default: capability = "Known commands · on this device"
            }
        }
    }
    func cancel() {
        guard isBusy else { return }
        generation += 1; pending?.cancel(); pending = nil; isBusy = false
        status = "That request was interrupted. Try another when you’re ready."
    }
    func submit(_ text: String, selected: String, allowed: [String], revision: Int,
                currentRevision: @escaping () -> Int, apply: @escaping (CreatureCommandIntent) -> Void) {
        cancel(); refreshCapability()
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty && input.count <= 400 else { status = "Try a short request, up to 400 characters."; return }
        guard !CreatureCommandIntent.mentionsAbsentCreature(input, allowed: allowed) else { status = "Choose a Fonster here in this room."; return }
        guard !CreatureCommandIntent.hasConflictingKnownActions(input) else { status = "Try one action at a time."; return }
        guard !CreatureCommandIntent.hasMultiplePeers(input, selected: selected, allowed: allowed) else { status = "Choose one friend for this little interaction."; return }
        generation += 1; let token = generation
        lastSource = "none"; lastModelAction = nil; lastErrorCode = nil
        isBusy = true; status = "Listening to your idea…"
        pending = Task { @MainActor [weak self] in
            guard let self else { return }
            var intent: CreatureCommandIntent?
            var usedModel = false
            if let known = CreatureCommandIntent.fallback(input, selected: selected, allowed: allowed) {
                intent = known
            } else if #available(macOS 26.0, iOS 26.0, *),
               !ProcessInfo.processInfo.arguments.contains("--verify-command-fallback"),
               SystemLanguageModel.default.availability == .available {
                do {
                    let session = LanguageModelSession(instructions: """
                    Interpret one small physical action in a Fonsters pet game. Return a supported action only.
                    spin includes twirling or a pirouette; dance is a rhythmic happy dance; rest includes lying down, a nap or shut-eye.
                    Current selected creature: \(selected). Creatures present: \(allowed.joined(separator: ", ")).
                    ‘Wave to Moss’ means the selected creature greets Moss: greetFriend, peer Moss.
                    ‘Moss, dance’ means Moss is the actor. Never invent an absent target or peer.
                    A friendly introduction to a neighbor means greetFriend. Visitor is a named guest when present.
                    A creature named at the start is the actor. ‘Coral, wave to Moss’ means actor Coral and peer Moss.
                    Return unknown for unsupported requests or several conflicting actions. Do not answer questions.
                    Do not generate dialog, code, plans, commands, or tool calls. Only classify the user's request.
                    """)
                    let result = try await session.respond(to: input, generating: GeneratedCreatureCommand.self,
                                                          options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 100))
                    usedModel = true
                    self.lastModelAction = result.content.action
                    let anchoredPeer = result.content.action == "greetFriend" ? CreatureCommandIntent.explicitPeer(in: input, allowed: allowed) : nil
                    let actor = CreatureCommandIntent.explicitActor(in: input, allowed: allowed) ?? (anchoredPeer != nil ? "selected" : result.content.target)
                    intent = CreatureCommandIntent.validate(action: result.content.action, target: actor,
                                                            peer: anchoredPeer ?? result.content.peer, selected: selected, allowed: allowed)
                } catch {
                    if Task.isCancelled { return }
                    let nativeError = error as NSError
                    self.lastErrorCode = "\(nativeError.domain):\(nativeError.code)"
                    // No raw prompt or model transcript is persisted or logged.
                    intent = CreatureCommandIntent.fallback(input, selected: selected, allowed: allowed)
                }
            } else { intent = CreatureCommandIntent.fallback(input, selected: selected, allowed: allowed) }
            guard !Task.isCancelled && token == self.generation else { return }
            self.isBusy = false; self.pending = nil
            self.lastSource = usedModel ? "apple_on_device_model" : "known_command_fallback"
            guard revision == currentRevision() else { self.status = "Your newer interaction took over. Try another request."; return }
            guard let intent else { self.status = "Try one action: hello, dance, nap, hop, twirl, stretch, high five, rub, fetch, follow, wander or stop."; return }
            self.appliedCount += 1; apply(intent)
            self.status = "\(intent.targetName) will \(intent.action.title). \(usedModel ? "Interpreted on this device." : "Known command, on this device.")"
        }
    }
}

@available(macOS 15.0, iOS 18.0, *)
struct CreatureCommandBar: View {
    let interpreter: TypedActionInterpreter
    let selected: String
    let names: [String]
    let revision: Int
    let enabled: Bool
    let currentRevision: () -> Int
    let apply: (CreatureCommandIntent) -> Void
    var onFocusChange: (Bool) -> Void = { _ in }
    @State private var text = ""
    @FocusState private var requestFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Image(systemName: "text.bubble").foregroundStyle(.secondary)
                TextField("Ask \(selected) to try something…", text: $text)
                    .textFieldStyle(.plain).focused($requestFocused).onSubmit(submit)
                    .accessibilityLabel("Tell \(selected) what to try")
                if interpreter.isBusy {
                    ProgressView().controlSize(.small)
                    FonsterIconButton(title: "Cancel request", symbol: "xmark") { interpreter.cancel() }
                } else { FonsterIconButton(title: "Try this request", symbol: "arrow.up", tone: .world, action: submit).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !enabled) }
            }.padding(.horizontal, 12).padding(.vertical, 9)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                FonsterInfo(title: interpreter.status, detail: interpreter.status + "\n" + interpreter.capability)
                Spacer()
            }

        }
        .onChange(of: revision) { interpreter.cancel() }
        .onChange(of: selected) { interpreter.cancel() }
        .onChange(of: enabled) { if !enabled { interpreter.cancel() } }
        .onChange(of: requestFocused) { onFocusChange(requestFocused) }
        .onDisappear { onFocusChange(false); interpreter.cancel() }
    }
    private func submit() {
        guard enabled else { return }
        interpreter.submit(text, selected: selected, allowed: names, revision: revision, currentRevision: currentRevision, apply: apply)
    }
}
#endif
