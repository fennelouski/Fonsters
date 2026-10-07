#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct FonsterSocialDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(profile: FonsterSocialProfile, card: FonsterVisitCard) throws { data = try FonsterReviewFileAdapter().prepare(profile: profile, appearance: card) }
    init(configuration: ReadConfiguration) throws { throw FonsterSocialError.invalid }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { .init(regularFileWithContents: data) }
}

@available(macOS 15.0, *)
struct FonsterSocialStudio: View {
    let lobby: LocalLobbyController
    @Environment(\.dismiss) private var dismiss
    @State private var review = false
    @State private var neighborhood = false
    @State private var exporting = false
    @State private var document: FonsterSocialDocument?
    @State private var error: String?
    private var store: FonsterSocialStore { lobby.presence.store }
    private var member: LocalLobbyController.Member { lobby.selectedMember }
    private var profile: FonsterSocialProfile? { store.profile(member.id) }
    private let ink = Color(red: 0.20, green: 0.22, blue: 0.27)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("fonsters social", systemImage: "sparkles").font(.system(size: 21, weight: .bold, design: .rounded))
                Text("THIS MAC").font(.system(size: 9, weight: .bold)).tracking(1).padding(6).background(.white, in: Capsule())
                Spacer()
                Button("Back to the world") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                sidebar.frame(width: 175)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let profile {
                            hero(profile)
                            HStack {
                                Text(neighborhood ? "Around the neighborhood" : "Little moments").font(.system(size: 19, weight: .bold, design: .rounded))
                                Spacer()
                                Picker("Posts", selection: $review) { Text("Local feed").tag(false); Text("Review drafts").tag(true) }.pickerStyle(.segmented).frame(width: 240)
                            }
                            posts
                        } else {
                            ContentUnavailableView {
                                Label("A little life to share.", systemImage: "leaf")
                            } description: {
                                Text("Give \(member.name) a local profile. Their agent can turn small Fonster adventures into little posts.")
                            } actions: {
                                Button("Create \(member.name)'s profile") { attempt { _ = try store.create(id: member.id, name: member.name, owned: !member.isVisitor) }; review = true }
                                    .buttonStyle(.borderedProminent).disabled(member.isVisitor)
                            }.frame(height: 430)
                        }
                    }.padding(20)
                }
                Divider()
                controls.frame(width: 225)
            }
            Divider()
            HStack {
                Label("Fictional Fonsters · locally written · no public platform connected", systemImage: "lock")
                Spacer()
                Text(store.status)
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(14)
        }.frame(width: 1040, height: 690).background(Color(red: 0.97, green: 0.97, blue: 0.94)).foregroundStyle(ink).preferredColorScheme(.light)
            .background(VerificationWindowCapture().frame(width: 0, height: 0))
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "\(member.name).fonster-social-review") { result in
                if case .failure(let failure) = result, (failure as NSError).code != NSUserCancelledError { error = "The review file couldn't be saved." }
            }
            .alert("Fonster social", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { neighborhood = true; review = false } label: { Label("Neighborhood", systemImage: "house") }.font(.system(size: 11, weight: .semibold)).accessibilityLabel("Neighborhood feed")
            Text("LITTLE PRESENCES").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(lobby.members.filter { !$0.isVisitor }) { companion in
                        Button {
                            if let index = lobby.members.firstIndex(where: { $0.id == companion.id }) { lobby.selected = index }; neighborhood = false
                        } label: {
                            HStack(spacing: 9) {
                                ResolvedPortrait(appearance: companion.descriptor).frame(width: 29, height: 29).padding(5).background(.white, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(companion.name).font(.system(size: 12, weight: .semibold, design: .rounded))
                                    Text(store.profile(companion.id) == nil ? "Create a profile" : "Local Fonster").font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }.padding(5).background(companion.id == member.id && !neighborhood ? Color.green.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 13))
                        }.buttonStyle(.plain).accessibilityLabel("\(companion.name)'s local social profile")
                            .accessibilityAddTraits(companion.id == member.id && !neighborhood ? .isSelected : [])
                    }
                }
            }
        }.padding(14)
    }
    private func hero(_ profile: FonsterSocialProfile) -> some View {
        HStack(spacing: 14) {
            if let fixture = member.localCompanion { FonsterSocialPortrait(companion: fixture).id(member.id).frame(width: 140, height: 160) }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(profile.name).font(.system(size: 29, weight: .bold, design: .rounded))
                    ResolvedPortrait(appearance: member.descriptor).frame(width: 25, height: 25).padding(5).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
                        .accessibilityLabel("Original two dimensional portrait")
                }
                Text("@\(profile.handle)").font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                Text(profile.voice.bio).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                Label("Fictional character · local agent voice", systemImage: "sparkles").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Text("\(profile.posts.filter { $0.state == .localFeed }.count) local moments · \(profile.posts.filter { $0.state == .draft }.count) drafts")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(12).background(LinearGradient(colors: [Color(red: 0.83, green: 0.92, blue: 0.85), Color(red: 0.97, green: 0.91, blue: 0.80)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
    }
    private var displayedProfiles: [FonsterSocialProfile] { neighborhood ? store.profiles : profile.map { [$0] } ?? [] }
    private var posts: some View {
        let moments = displayedProfiles.flatMap { profile in profile.posts.filter { $0.state == (review ? .draft : .localFeed) }.map { (profile, $0) } }.sorted { $0.1.event.date > $1.1.event.date }
        return VStack(spacing: 11) {
            if moments.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: review ? "square.and.pencil" : "leaf").font(.system(size: 28)).foregroundStyle(.green.opacity(0.65))
                    Text(review ? "New moments will wait here." : "A small world, a fresh page.").font(.system(size: 16, weight: .medium, design: .rounded))
                    Text(review ? "Review a draft, then choose Add to local feed." : "Try a hello or a little game, then let the writer make a draft.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(28)
            }
            ForEach(moments, id: \.1.id) { item in
                FonsterSocialPostCard(profile: item.0, post: item.1, store: store, onError: { error = $0 })
            }
        }
    }
    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("THE LITTLE WRITER").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                Label(lobby.presence.running ? "Agent on" : "You're in control", systemImage: lobby.presence.running ? "sparkles" : "hand.raised")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(lobby.presence.message).font(.system(size: 11)).foregroundStyle(.secondary)
                if let profile {
                    Picker("Voice", selection: Binding(get: { profile.voice }, set: { lobby.presence.stop(lobby: lobby); store.setVoice($0, id: member.id) })) {
                        ForEach(FonsterSocialVoice.allCases) { Text($0.title).tag($0) }
                    }.font(.system(size: 11))
                    Picker("New posts", selection: Binding(get: { lobby.presence.mode }, set: { lobby.presence.setMode($0, lobby: lobby) })) {
                        ForEach(FonsterSocialDirector.Mode.allCases) { Text($0.title).tag($0) }
                    }.font(.system(size: 11))
                    Text("CONTENT CHOICES").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                    ForEach(FonsterSocialCategory.allCases) { category in
                        Toggle(category.title, isOn: Binding(get: { profile.categories.contains(category) }, set: {
                            lobby.presence.stop(lobby: lobby); store.setCategory(category, enabled: $0, id: member.id)
                        })).toggleStyle(.checkbox).font(.system(size: 11))
                    }
                    Button(lobby.presence.running ? "Pause profile agent" : "Start local profile agent") {
                        attempt {
                            if lobby.presence.running { lobby.presence.stop(lobby: lobby) }
                            else { try lobby.presence.start(lobby: lobby); dismiss() }
                        }
                    }.buttonStyle(.borderedProminent).font(.system(size: 11)).disabled(member.isVisitor)
                    Button("Draft a new moment") { attempt { _ = try store.makeDraft(id: member.id) }; review = true }
                        .font(.system(size: 10))
                    Text("Runs while Fonsters is open and active. Pause, Still mode, Reduce Motion, background, and Low Power hold the agent. Creature controls take over immediately.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Text("One post a minute · six this session · twenty-four a day. No generation cost.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Divider()
                    Text("DESTINATIONS").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                    ForEach(FonsterSocialDestination.allCases) { destination in
                        HStack {
                            Image(systemName: destination.implemented ? "checkmark.circle" : "circle.dashed").foregroundStyle(destination.implemented ? .green : .secondary)
                            Text(destination.title).font(.system(size: 10))
                            Spacer(minLength: 0)
                        }
                    }
                    Text("Bluesky and Mastodon are planned connections. Public posting needs a chosen account, content policy, and owner approval.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Button("Save profile review file…") {
                        attempt { document = try .init(profile: profile, card: lobby.card(for: member, includeFeeling: false)); exporting = true }
                    }.font(.system(size: 10))
                    Text("Includes this fictional profile, its seed-free appearance, and approved local posts. Drafts and private feelings stay here.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(16)
        }
    }
    private func attempt(_ action: () throws -> Void) {
        do { try action(); error = nil } catch { self.error = error.localizedDescription }
    }
}

@available(macOS 15.0, *)
private struct FonsterSocialPortrait: View {
    let companion: PlayroomCompanion
    @State private var controller = PlayroomController()
    @State private var portrait: NSImage?
    @State private var snapshotTask: Task<Void, Never>?
    var body: some View {
        Group {
            if let portrait {
                Image(nsImage: portrait).resizable().scaledToFit()
                    .accessibilityLabel("\(companion.name)'s smiling fuzzy three dimensional portrait")
            } else {
                CreatureStageView(companion: companion, controller: controller, onSceneReady: { entities in
                    // One genuine native GPU render: a profile photo needs no continuing renderer.
                    snapshotTask = Task { @MainActor in
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fonster-profile-\(UUID().uuidString).png")
                        defer { try? FileManager.default.removeItem(at: url) }
                        do {
                            try await NativeSceneExport.capture(entities, width: 320, height: 380, to: url)
                            guard !Task.isCancelled, let image = NSImage(contentsOf: url) else { return }
                            portrait = image
                        } catch { /* the native 3D view remains available */ }
                    }
                })
            }
        }.clipShape(RoundedRectangle(cornerRadius: 18))
            .onAppear { controller.staticMode = true; controller.autonomyEnabled = false; controller.roaming = false; controller.writesProbe = false; controller.refreshStillPose() }
            .onDisappear { snapshotTask?.cancel(); controller.silence(); controller.rig = nil; controller.rendererReady = false }
    }
}

@available(macOS 15.0, *)
private struct FonsterSocialPostCard: View {
    let profile: FonsterSocialProfile
    let post: FonsterSocialPost
    let store: FonsterSocialStore
    let onError: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: post.event.symbol).foregroundStyle(.green)
                Text(profile.name).font(.system(size: 12, weight: .bold, design: .rounded))
                Text(post.event.title).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Text(post.event.date, style: .time).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Text(post.text(name: profile.name)).font(.system(size: 13)).lineSpacing(3).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            Text("Locally written · \(post.event.source.title)").font(.system(size: 9)).foregroundStyle(.secondary)
            if post.state == .draft {
                HStack {
                    Button("Add to local feed") {
                        do { try FonsterLocalFeedAdapter().publish(post.id, profileID: profile.fonsterID, store: store) } catch { onError(error.localizedDescription) }
                    }.buttonStyle(.borderedProminent)
                    Button("Pass this one") { store.pass(postID: post.id, id: profile.fonsterID) }
                    Spacer()
                }.font(.system(size: 10))
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .contain)
    }
}
#endif
