#if os(macOS) || os(iOS)
import SwiftUI
import SwiftData

struct FonsterEditorTarget: Identifiable {
    let id = UUID()
    let record: Fonster?
}

/// Intentional one-time draft: typing never mutates the saved model. Cancel
/// discards it; Save changes the name/profile without changing the appearance.
@available(macOS 15.0, iOS 18.0, *)
struct FonsterProfileEditor: View {
    let record: Fonster?
    let onSave: (UUID) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var biography: FonsterBiography
    @State private var choices: [PlayroomCompanion]
    @State private var chosenSeed: String
    @State private var chapter = Chapter.story
    @State private var error: String?
    @State private var saving = false
    private let originalName: String
    private let originalBiography: FonsterBiography
    private var companion: PlayroomCompanion { .init(name: name.isEmpty ? "Your Fonster" : name, seed: chosenSeed) }
    private var dirty: Bool { name != originalName || biography != originalBiography }

    init(record: Fonster?, onSave: @escaping (UUID) -> Void) {
        self.record = record; self.onSave = onSave
        let name = record?.name ?? ""
        let biography = record?.biography ?? .init()
        originalName = name; originalBiography = biography
        _name = State(initialValue: name); _biography = State(initialValue: biography)
        let choices = record.map { [PlayroomCompanion(name: $0.name, seed: $0.seed)] } ?? Self.newChoices()
        _choices = State(initialValue: choices); _chosenSeed = State(initialValue: choices[0].seed)
    }
    private static func newChoices() -> [PlayroomCompanion] {
        let entropy = UUID().uuidString
        return (0..<8).map { .init(name: "Fuzzy friend \($0 + 1)", seed: PersonalFonsterLibrary.friendlySeed(entropy: entropy + "-" + String($0))) }
    }
    enum Chapter: String, CaseIterable, Identifiable {
        case story, likes, screen, people, music, places
        var id: String { rawValue }
        var title: String { switch self { case .story: "Backstory"; case .likes: "Likes and dislikes"; case .screen: "Movies and shows"; case .people: "Creators and celebrities"; case .music: "Music"; case .places: "Places" } }
        var symbol: String { switch self { case .story: "book.closed"; case .likes: "heart"; case .screen: "tv"; case .people: "star"; case .music: "music.note"; case .places: "mappin.and.ellipse" } }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                FonsterIconButton(title: "Cancel profile changes", symbol: "xmark", detail: "Discard this draft and return to your Fonster.") { dismiss() }.accessibilityIdentifier("cancelProfile")
                Spacer()
                FonsterInfo(title: record == nil ? "Create a Fonster" : "Your Fonster's story", detail: "Choose a fuzzy appearance when creating, then give your Fonster a name. The book is its backstory; the heart holds likes and dislikes; the screen holds movies and shows; the star holds creators and celebrities. Type interests and use the plus badge to review source records. The music note holds music; the pin holds places. Save with the checkmark. X discards this draft. The curved arrow resets unsaved name and profile changes. Your typed drafts and backstory stay private. New visits can include only selected source records. The camera on the preview can imitate you after a grown-up review.")
                FonsterIconButton(title: "Reset unsaved profile changes", symbol: "arrow.uturn.backward") { name = originalName; biography = originalBiography }.disabled(!dirty)
                FonsterIconButton(title: record == nil ? "Save new Fonster" : "Save profile", symbol: "checkmark", tone: .company) { save() }
                    .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("saveProfile")
            }.padding(16)
            ScrollView {
                VStack(spacing: 18) {
                    if companion.descriptor.supported {
                        FonsterDraftStage(companion: companion).id(chosenSeed).frame(height: 230)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                    } else { LobbyPortrait(appearance: companion.descriptor).frame(width: 200, height: 200) }
                    if record == nil { appearanceChoices }
                    HStack(spacing: 12) {
                        Image(systemName: "pencil").foregroundStyle(FonsterTone.company.ink).accessibilityHidden(true)
                        TextField("Name your Fonster", text: $name, prompt: Text("Name your Fonster").foregroundStyle(FonsterChrome.secondary)).textFieldStyle(.plain)
                            .font(.title2.weight(.semibold)).accessibilityLabel("Fonster name").accessibilityIdentifier("profileName")
                            .onChange(of: name) { _, value in if value.count > 32 { name = String(value.prefix(32)) } }
                    }.padding(16).background(FonsterTone.company.wash, in: RoundedRectangle(cornerRadius: 18))
                    FonsterControlGroup(title: "Your Fonster's profile", tone: .company) {
                        ScrollView(.horizontal) {
                            HStack(spacing: 6) {
                                ForEach(Chapter.allCases) { chapter in
                                    FonsterIconButton(title: chapter.title, symbol: chapter.symbol, tone: .company, selected: self.chapter == chapter) { self.chapter = chapter }
                                        .accessibilityIdentifier("profileTab_" + chapter.rawValue)
                                }
                            }
                        }.scrollIndicators(.hidden).frame(height: 50)
                    }
                    chapterFields
                    if let error { Text(error).foregroundStyle(Theme.accent).font(.callout).accessibilityIdentifier("profileError") }
                }.padding(.horizontal, 20).padding(.bottom, 24)
            }
        }.background(FonsterChrome.background).foregroundStyle(FonsterChrome.primary).fontDesign(.rounded)
        #if os(macOS)
        .frame(width: 560, height: 760)
        #else
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        #endif
        .interactiveDismissDisabled(saving)
    }
    private var appearanceChoices: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(choices) { choice in
                        FonsterPortraitChoice(name: choice.name, selected: chosenSeed == choice.seed,
                            detail: "Preview this appearance. It is saved only when you tap the checkmark.",
                            portrait: { LobbyPortrait(appearance: choice.descriptor).frame(width: 44, height: 44) }, action: { chosenSeed = choice.seed })
                    }
                }.padding(4)
            }.scrollIndicators(.hidden)
            FonsterIconButton(title: "Discover more fuzzy appearances", symbol: "dice", tone: .play,
                detail: "Show eight new original appearances. Keep the previewed one until you choose another.") { choices = Self.newChoices() }
                .accessibilityIdentifier("moreAppearances")
        }
    }
    @ViewBuilder private var chapterFields: some View {
        switch chapter {
        case .story:
            VStack(alignment: .leading, spacing: 8) {
                Text("Backstory").font(.headline)
                TextField("Where did your Fonster come from?", text: $biography.background,
                          prompt: Text("Where did your Fonster come from?").foregroundStyle(FonsterChrome.secondary), axis: .vertical)
                    .lineLimit(4...8).textFieldStyle(.plain).padding(16)
                    .background(FonsterChrome.surface, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("profileBackground")
                    .onChange(of: biography.background) { _, value in if value.count > 600 { biography.background = String(value.prefix(600)) } }
            }
        case .likes:
            favoriteField("Likes", "heart.fill", $biography.likes, "profileLikes", .likes)
            favoriteField("Dislikes", "hand.thumbsdown", $biography.dislikes, "profileDislikes", .dislikes)
        case .screen:
            favoriteField("Favorite movies", "film", $biography.movies, "profileMovies", .movies)
            favoriteField("Favorite shows", "tv", $biography.shows, "profileShows", .shows)
        case .people:
            favoriteField("Favorite creators", "paintbrush", $biography.creators, "profileCreators", .creators)
            favoriteField("Favorite celebrities", "star", $biography.celebrities, "profileCelebrities", .celebrities)
        case .music:
            favoriteField("Favorite music", "music.note", Binding(get: { biography.music ?? [] }, set: { biography.music = $0 }), "profileMusic", .music)
        case .places:
            favoriteField("Favorite places", "mappin.and.ellipse", Binding(get: { biography.places ?? [] }, set: { biography.places = $0 }), "profilePlaces", .places)
        }
    }
    private func favoriteField(_ title: String, _ symbol: String, _ values: Binding<[String]>, _ identifier: String, _ category: FonsterInterestCategory) -> some View {
        FonsterInterestField(title: title, symbol: symbol, values: values, selections: $biography.interests, category: category, identifier: identifier).id(identifier)
    }
    private func save() {
        saving = true
        let record = record ?? Fonster(name: "", seed: chosenSeed, createdAtISO8601: Fonster.currentCreatedAtISO8601())
        let oldName = record.name; let oldData = record.biographyData; let oldDate = record.profileModifiedAt
        record.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
        record.biography = biography; record.profileModifiedAt = Date()
        if self.record == nil { context.insert(record) }
        do { try context.save(); onSave(record.id); dismiss() }
        catch {
            // Only discard the newly inserted, unsaved draft. Existing records
            // and other pending edits are never rolled back or deleted.
            if self.record == nil { context.delete(record) }
            else { record.name = oldName; record.biographyData = oldData; record.profileModifiedAt = oldDate }
            self.error = "Your changes couldn't be saved. Your previous profile is still here. Try again."; saving = false
        }
    }
}

@available(macOS 15.0, iOS 18.0, *)
private struct FonsterDraftStage: View {
    let companion: PlayroomCompanion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = PlayroomController()
    @State private var inputs = CreatureInputs()
    @State private var gate = ParentActionGate()
    private var suspended: Bool { !controller.shouldAnimate || gate.challenge != nil }
    var body: some View {
        CreatureStageView(companion: companion, controller: controller)
            .overlay(alignment: .topTrailing) {
                FonsterIconButton(title: inputs.cameraEnabled ? "Turn editor camera off" : "Imitate me with the camera",
                    symbol: inputs.cameraEnabled ? "video.fill" : "video", tone: .company, selected: inputs.cameraEnabled,
                    detail: "A grown-up enables this camera preview. Your Fonster mirrors facial movements and raised hands on this device. Turn it off here; closing the editor stops it.") {
                    if inputs.cameraEnabled { inputs.toggleCamera() }
                    else { gate.request("Enable camera mirroring for this draft. Frames and measurements stay on this device and are not saved or uploaded.") { inputs.toggleCamera(parentApproved: true) } }
                }.padding(12).accessibilityIdentifier("editorCamera")
            }
            .parentActions(gate)
            .onAppear { inputs.onMirror = { controller.receiveMirror($0, time: ProcessInfo.processInfo.systemUptime) } }
            .onChange(of: suspended, initial: true) { inputs.setSuspended(suspended); if suspended { controller.clearMirror() } }
            .onChange(of: inputs.cameraEnabled) { if !inputs.cameraEnabled { controller.clearMirror() } }
            .task(id: controller.shouldAnimate) { if controller.shouldAnimate { await controller.animate() } else { controller.refreshStillPose() } }
            .onChange(of: reduceMotion, initial: true) { controller.systemReduceMotion = reduceMotion || ProcessInfo.processInfo.arguments.contains("--verify-reduce-motion") }
            .onChange(of: scenePhase, initial: true) { controller.backgrounded = scenePhase != .active }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in controller.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
            .onDisappear { inputs.stopAll(); inputs.onMirror = nil; gate.cancel(); controller.clearMirror(); controller.backgrounded = true; controller.cancelTouch(); controller.silence() }
    }
}

struct FonsterBiographySummary: View {
    let biography: FonsterBiography
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !biography.background.isEmpty { Text(biography.background).font(.callout) }
                items("Likes", "heart", biography.likes); items("Dislikes", "hand.thumbsdown", biography.dislikes)
                items("Movies", "film", biography.movies); items("Shows", "tv", biography.shows)
                items("Creators", "paintbrush", biography.creators); items("Celebrities", "star", biography.celebrities)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxHeight: 190)
    }
    @ViewBuilder private func items(_ title: String, _ symbol: String, _ values: [String]) -> some View {
        if !values.isEmpty { Label(values.joined(separator: " · "), systemImage: symbol).font(.callout).accessibilityLabel(title + ": " + values.joined(separator: ", ")) }
    }
}
#endif
