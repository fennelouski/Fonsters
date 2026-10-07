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
                Image(systemName: "sparkles.rectangle.stack").font(.system(size: 25)).foregroundStyle(FonsterTone.company.ink)
                FonsterInfo(title: "Local profiles", detail: "Fictional Fonsters, written locally. Profiles and posts stay on this Mac. No public platform or external agent is connected.")
                Spacer()
                FonsterIconButton(title: "Back to the world", symbol: "xmark", tone: .world) { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                sidebar.frame(width: 106)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let profile {
                            hero(profile)
                            HStack(spacing: 10) {
                                FonsterIconButton(title: "Approved local moments", symbol: "rectangle.stack", tone: .company, selected: !review) { review = false }
                                FonsterIconButton(title: "Review drafts", symbol: "square.and.pencil", tone: .play, selected: review) { review = true }
                                Spacer()
                            }
                            posts
                        } else {
                            VStack(spacing: 20) {
                                if let fixture = member.localCompanion { FonsterSocialPortrait(companion: fixture).id(member.id).frame(width: 240, height: 290) }
                                Text(member.name).font(.system(size: 26, weight: .bold, design: .rounded))
                                FonsterIconButton(title: "Create \(member.name)'s fictional profile on this Mac", symbol: "person.crop.circle.badge.plus", tone: .company) {
                                    attempt { _ = try store.create(id: member.id, name: member.name, owned: !member.isVisitor) }; review = true
                                }.disabled(member.isVisitor)
                            }.frame(maxWidth: .infinity).frame(height: 480)

                        }
                    }.padding(20)
                }
                Divider()
                controls.frame(width: 205)
            }
            Divider()
            HStack {
                FonsterStatus(symbol: "lock", detail: "Fictional Fonsters; local agent voice; no public platform connected", tone: .company)
                Spacer()
                FonsterInfo(title: "Local notebook status", detail: store.status)
            }.padding(.horizontal, 18).padding(.vertical, 8)

        }.frame(width: 1040, height: 690).background(Color(red: 0.97, green: 0.97, blue: 0.94)).foregroundStyle(ink).preferredColorScheme(.light)
            .background(VerificationWindowCapture(label: "social").frame(width: 0, height: 0))
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "\(member.name).fonster-social-review") { result in
                if case .failure(let failure) = result, (failure as NSError).code != NSUserCancelledError { error = "The review file couldn't be saved." }
            }
            .alert("Fonster social", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
    }
    private var sidebar: some View {
        VStack(spacing: 16) {
            FonsterIconButton(title: "Neighborhood feed", symbol: "house", tone: .world, selected: neighborhood) { neighborhood = true; review = false }
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(lobby.members.filter { !$0.isVisitor }) { companion in
                        FonsterPortraitChoice(name: "\(companion.name)'s local profile", selected: companion.id == member.id && !neighborhood,
                            portrait: { ResolvedPortrait(appearance: companion.descriptor) }, action: {
                                if let index = lobby.members.firstIndex(where: { $0.id == companion.id }) { lobby.selected = index }; neighborhood = false
                            })
                    }
                }.padding(4)
            }
        }.padding(14)
    }
    private func hero(_ profile: FonsterSocialProfile) -> some View {
        HStack(spacing: 20) {
            if let fixture = member.localCompanion { FonsterSocialPortrait(companion: fixture).id(member.id).frame(width: 170, height: 195) }
            VStack(alignment: .leading, spacing: 16) {
                Text(profile.name).font(.system(size: 30, weight: .bold, design: .rounded))
                HStack(spacing: 12) {
                    ResolvedPortrait(appearance: member.descriptor).frame(width: 32, height: 32).padding(8)
                        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Original two dimensional portrait")
                    FonsterInfo(title: "Profile identity and voice", detail: "@\(profile.handle)\n\(profile.voice.bio)\nFictional character; local agent voice.")
                }
                HStack(spacing: 18) {
                    Label("\(profile.posts.filter { $0.state == .localFeed }.count)", systemImage: "rectangle.stack")
                    Label("\(profile.posts.filter { $0.state == .draft }.count)", systemImage: "square.and.pencil")
                }.font(.system(size: 12, weight: .medium))
                    .accessibilityLabel("\(profile.posts.filter { $0.state == .localFeed }.count) local moments, \(profile.posts.filter { $0.state == .draft }.count) drafts")
            }
            Spacer(minLength: 0)
        }.padding(16).background(LinearGradient(colors: [Color(red: 0.83, green: 0.92, blue: 0.85), Color(red: 0.97, green: 0.91, blue: 0.80)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
    }
    private var displayedProfiles: [FonsterSocialProfile] { neighborhood ? store.profiles : profile.map { [$0] } ?? [] }
    private var posts: some View {
        let moments = displayedProfiles.flatMap { profile in profile.posts.filter { $0.state == (review ? .draft : .localFeed) }.map { (profile, $0) } }.sorted { $0.1.event.date > $1.1.event.date }
        return VStack(spacing: 11) {
            if moments.isEmpty {
                Image(systemName: review ? "square.and.pencil" : "leaf").font(.system(size: 32)).foregroundStyle(FonsterTone.company.ink.opacity(0.6))
                    .frame(maxWidth: .infinity).padding(32)
                    .accessibilityLabel(review ? "No new drafts. Make a moment, then draft it." : "No approved local moments yet.")

            }
            ForEach(moments, id: \.1.id) { item in
                FonsterSocialPostCard(profile: item.0, post: item.1, store: store, onError: { error = $0 })
            }
        }
    }
    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    FonsterStatus(symbol: lobby.presence.running ? "sparkles" : "hand.raised", detail: lobby.presence.message, tone: .company)
                    Spacer()
                    FonsterInfo(title: "Local writer and publishing", detail: "The writer runs while Fonsters is open and active. Pause, Still mode, Reduce Motion, background, and Low Power hold it. Creature controls take over immediately. One post a minute; six this session; twenty-four a day. No generation cost. Public connections need a chosen account and owner approval.")
                }
                if let profile {
                    HStack(spacing: 8) {
                        ForEach(FonsterSocialVoice.allCases) { voice in
                            FonsterIconButton(title: "\(voice.title) writing voice", symbol: voiceSymbol(voice), tone: .company, selected: profile.voice == voice) {
                                lobby.presence.stop(lobby: lobby); store.setVoice(voice, id: member.id)
                            }
                        }
                    }.accessibilityElement(children: .contain).accessibilityLabel("Writing voice")
                    // Publishing is a meaningful consent choice: keep its actual audience visible.
                    Picker("New posts", selection: Binding(get: { lobby.presence.mode }, set: { lobby.presence.setMode($0, lobby: lobby) })) {
                        ForEach(FonsterSocialDirector.Mode.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.radioGroup).labelsHidden().font(.system(size: 11))
                        .accessibilityLabel("How new posts enter this Mac’s local feed")
                    LazyVGrid(columns: [GridItem(.fixed(44)), GridItem(.fixed(44))], spacing: 12) {
                        ForEach(FonsterSocialCategory.allCases) { category in
                            FonsterIconToggle(title: "Include \(category.title.lowercased())", symbol: categorySymbol(category), tone: .play,
                                isOn: Binding(get: { profile.categories.contains(category) }, set: {
                                    lobby.presence.stop(lobby: lobby); store.setCategory(category, enabled: $0, id: member.id)
                                }))
                        }
                    }.accessibilityElement(children: .contain).accessibilityLabel("Fictional content choices")
                    HStack(spacing: 8) {
                        FonsterIconButton(title: lobby.presence.running ? "Pause local profile agent" : "Start local profile agent", symbol: lobby.presence.running ? "pause.fill" : "play.fill", tone: .company, selected: lobby.presence.running) {
                            attempt {
                                if lobby.presence.running { lobby.presence.stop(lobby: lobby) }
                                else { try lobby.presence.start(lobby: lobby); dismiss() }
                            }
                        }.disabled(member.isVisitor)
                        FonsterIconButton(title: "Draft a new fictional moment for review", symbol: "square.and.pencil", tone: .play) { attempt { _ = try store.makeDraft(id: member.id) }; review = true }
                    }
                    Divider()
                    HStack(spacing: 8) {
                        FonsterIconButton(title: "Save a seed-free fictional profile review file", symbol: "square.and.arrow.up", tone: .world) {
                            attempt { document = try .init(profile: profile, card: lobby.card(for: member, includeFeeling: false)); exporting = true }
                        }
                        FonsterInfo(title: "What is shared", detail: "Includes this fictional profile, its seed-free appearance, and approved local posts. Drafts and private feelings stay here. Bluesky and Mastodon are planned; no public platform is connected.")
                    }
                    FonsterStatus(symbol: "lock", detail: "No public platform connected. Local feed and review-file export are available.")
                }
            }.padding(16)
        }
    }
    private func voiceSymbol(_ voice: FonsterSocialVoice) -> String {
        switch voice { case .warm: "heart"; case .playful: "sparkles"; case .dreamy: "moon.stars" }
    }
    private func categorySymbol(_ category: FonsterSocialCategory) -> String {
        switch category { case .adventures: "leaf"; case .play: "tennisball"; case .company: "person.2"; case .quiet: "moon" }
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
    @State private var showsCaption = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: post.event.symbol).font(.system(size: 27)).foregroundStyle(FonsterTone.company.ink)
                    .frame(width: 46, height: 46).background(FonsterTone.company.wash, in: RoundedRectangle(cornerRadius: 15))
                    .help(post.event.title).accessibilityLabel(post.event.title)
                Text(profile.name).font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                if post.state != .draft {
                    FonsterIconButton(title: "Read this moment", symbol: "text.bubble", tone: .company, selected: showsCaption) { showsCaption.toggle() }
                }
                FonsterInfo(title: "Moment source", detail: post.event.title + "\n" + post.event.source.title + "\nLocally written. " + post.event.date.formatted())
            }
            if post.state == .draft || showsCaption {
                Text(post.text(name: profile.name)).font(.system(size: 13)).lineSpacing(3).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            if post.state == .draft {
                HStack(spacing: 10) {
                    FonsterIconButton(title: "Approve this draft for this Mac's local feed", symbol: "checkmark", tone: .company) {
                        do { try FonsterLocalFeedAdapter().publish(post.id, profileID: profile.fonsterID, store: store) } catch { onError(error.localizedDescription) }
                    }
                    FonsterIconButton(title: "Pass this draft", symbol: "xmark") { store.pass(postID: post.id, id: profile.fonsterID) }
                    Spacer()
                    Text("This Mac only").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)

    }
}
#endif
