//
//  ContentView.swift
//  Fonsters
//
//  Main UI: Master–Detail list of Fonsters and detail view with name, seed,
//  creature preview, and actions.
//
//  Implemented:
//  - Master: list with preview + name, Add, Share (URL), Import (paste URL), delete.
//  - Detail: name and seed fields, Load random (with local fallback), Prepend random,
//    Play (evolution animation), PNG / GIF / JPEG (macOS) export (share/save), Add, Refresh/Undo/Redo.
//  - PNG/GIF hidden on tvOS; Share/Import; open from URL via fonsters:// (and universal links if configured).
//  - visionOS: 3D voxel creature in detail (CreatureVoxelView); watchOS has separate target (Fonsters Watch App).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ImageIO
#if os(tvOS)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var pendingImportURL: PendingImportURLHolder
    @Query(sort: \Fonster.createdAt, order: .reverse) private var fonsters: [Fonster]
    @State private var selectedId: Fonster.ID?
    @State private var showImportSheet = false
    @State private var shareURLWarning = false
    @State private var shareURLToShow: String?
    @State private var showShareURLAlert = false
    @State private var hasPerformedLaunchSelectionCheck = false
    @State private var pendingDeleteOffsets: IndexSet?
    @State private var showDeleteConfirmation = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @StateObject private var uprightCreatureState = UprightCreatureState()

    var body: some View {
        uprightContent
            .environmentObject(uprightCreatureState)
    }

    @ViewBuilder
    private var uprightContent: some View {
        #if os(iOS)
        navigationContent
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                uprightCreatureState.toggle()
            }
        #else
        navigationContent
        #endif
    }

    private var navigationContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 0) {
                // Sidebar branding header
                HStack(spacing: 10) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                    Text("Fonsters")
                        .font(.title2.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                List(selection: $selectedId) {
                    ForEach(fonsters) { fonster in
                        NavigationLink(value: fonster.id) {
                            HStack(spacing: 12) {
                                CreatureAvatarView(seed: fonster.seed, size: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(displayName(for: fonster))
                                    .lineLimit(1)
                                if fonster.isBirthdayToday {
                                    Text("Birthday!")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        #if os(macOS)
                        .contextMenu {
                            Button {
                                shareFonster(fonster)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                if let index = fonsters.firstIndex(where: { $0.id == fonster.id }) {
                                    deleteFonsters(offsets: IndexSet(integer: index))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        #endif
                    }
                    .onDelete(perform: deleteFonsters)
                }
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                #endif
                ToolbarItem {
                    Button(action: addFonster) {
                        Label("Add Fonster", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button(action: shareFonsters) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem {
                    Button(action: { showImportSheet = true }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
                #if os(macOS) || os(iOS)
                ToolbarItem {
                    Button {
                        columnVisibility = columnVisibility == .doubleColumn ? .detailOnly : .doubleColumn
                    } label: {
                        Label("Toggle Sidebar", systemImage: "sidebar.left")
                    }
                    .keyboardShortcut(KeyEquivalent("`"), modifiers: [.command, .option])
                }
                #endif
            }
            .navigationTitle("Fonsters")
            .sheet(isPresented: $showImportSheet) {
                ImportSheet(onImport: { _ = importSeeds($0) }, onDismiss: { showImportSheet = false })
            }
            .alert("Share link too long", isPresented: $shareURLWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Try fewer or shorter seeds so the URL stays under 2,000 characters.")
            }
            #if os(tvOS)
            .alert("Share URL", isPresented: $showShareURLAlert) {
                Button("OK", role: .cancel) { shareURLToShow = nil }
            } message: {
                Text(shareURLToShow ?? "")
            }
            #endif
            .confirmationDialog(deleteConfirmationTitle, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Cancel", role: .cancel) {
                    pendingDeleteOffsets = nil
                }
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDeleteOffsets {
                        performDeleteFonsters(offsets: offsets)
                        pendingDeleteOffsets = nil
                    }
                }
            } message: {
                Text("This cannot be undone.")
            }
            .onChange(of: pendingImportURL.url) { _, url in
                guard let url = url else { return }
                if let seeds = parseSeedsFromShareURL(url.absoluteString) {
                    if let firstId = importSeeds(seeds) {
                        selectedId = firstId
                    }
                }
                pendingImportURL.url = nil
            }
            .task {
                await seedInitialCreaturesIfNeeded()
                await ensureSelectionOnLaunch()
            }
        } detail: {
            if let id = selectedId, let fonster = fonsters.first(where: { $0.id == id }) {
                FonsterDetailView(fonster: fonster)
            } else {
                ContentUnavailableView("Select a Fonster", systemImage: "sparkles")
            }
        }
        #if os(macOS) || os(iOS)
        .background {
            Group {
                ForEach(1...10, id: \.self) { position in
                    let keyChar = Character(Unicode.Scalar(48 + (position == 10 ? 0 : position))!)
                    Button("") { selectFonsterAt(position: position) }
                        .keyboardShortcut(KeyEquivalent(keyChar), modifiers: .command)
                }
                Button("") { selectPreviousFonster() }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("") { selectNextFonster() }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("") { addFonster() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("") {
                    if let id = selectedId, let fonster = fonsters.first(where: { $0.id == id }) {
                        shareFonster(fonster)
                    }
                }
                .keyboardShortcut("p", modifiers: .command)
            }
            .hidden()
        }
        #endif
    }

    private func displayName(for fonster: Fonster) -> String {
        if !fonster.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return fonster.name
        }
        if !fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty {
            let s = fonster.seed.trimmingCharacters(in: .whitespaces)
            return s.count > 30 ? String(s.prefix(27)) + "..." : s
        }
        return "Untitled"
    }

    private func addFonster() {
        withAnimation {
            let f = Fonster(name: "", seed: "", createdAtISO8601: Fonster.currentCreatedAtISO8601())
            modelContext.insert(f)
            selectedId = f.id
        }
    }

    #if os(macOS) || os(iOS)
    private func selectFonsterAt(position: Int) {
        guard position >= 1, position <= fonsters.count else { return }
        selectedId = fonsters[position - 1].id
    }

    private func selectPreviousFonster() {
        guard let id = selectedId, let idx = fonsters.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        selectedId = fonsters[idx - 1].id
    }

    private func selectNextFonster() {
        guard let id = selectedId, let idx = fonsters.firstIndex(where: { $0.id == id }), idx < fonsters.count - 1 else { return }
        selectedId = fonsters[idx + 1].id
    }
    #endif

    private var deleteConfirmationTitle: String {
        guard let offsets = pendingDeleteOffsets else { return "Delete Fonster?" }
        return offsets.count == 1 ? "Delete Fonster?" : "Delete \(offsets.count) Fonsters?"
    }

    private func deleteFonsters(offsets: IndexSet) {
        pendingDeleteOffsets = offsets
        showDeleteConfirmation = true
    }

    private func performDeleteFonsters(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let f = fonsters[index]
                modelContext.delete(f)
                if selectedId == f.id {
                    selectedId = nil
                }
            }
        }
    }

    private func shareFonster(_ fonster: Fonster) {
        let seeds = [fonster.seed]
        if isShareURLTooLong(seeds: seeds) {
            shareURLWarning = true
            return
        }
        guard let urlString = buildShareURL(seeds: seeds) else { return }
        #if os(iOS)
        guard let url = URL(string: urlString) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            top.present(av, animated: true)
        }
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        #endif
    }

    private func shareFonsters() {
        let seeds = fonsters.map(\.seed)
        if isShareURLTooLong(seeds: seeds) {
            shareURLWarning = true
            return
        }
        guard let urlString = buildShareURL(seeds: seeds), let url = URL(string: urlString) else { return }
        #if os(iOS)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            top.present(av, animated: true)
        }
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        #elseif os(visionOS)
        UIPasteboard.general.string = urlString
        #else
        shareURLToShow = urlString
        showShareURLAlert = true
        #endif
    }

    private func importSeeds(_ seeds: [String]) -> Fonster.ID? {
        showImportSheet = false
        var firstId: Fonster.ID?
        withAnimation {
            for seed in seeds {
                let f = Fonster(name: "", seed: seed, createdAtISO8601: Fonster.currentCreatedAtISO8601())
                modelContext.insert(f)
                if firstId == nil { firstId = f.id }
            }
        }
        return firstId
    }

    private func seedInitialCreaturesIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: InstallationSeeds.hasSeededKey) else { return }
        let seeds = InstallationSeeds.seeds()
        guard !seeds.isEmpty else { return }
        var premadeShuffle = InitialCreatureNames.shuffledPremade()
        var premadeIndex = 0
        withAnimation {
            for seed in seeds {
                let name = InitialCreatureNames.nextName(premadeShuffle: &premadeShuffle, premadeIndex: &premadeIndex)
                let f = Fonster(name: name, seed: seed, createdAtISO8601: Fonster.currentCreatedAtISO8601())
                modelContext.insert(f)
            }
        }
        UserDefaults.standard.set(true, forKey: InstallationSeeds.hasSeededKey)
    }

    /// Runs once per app launch: ensures a Fonster is selected. If store is empty, creates one with current time.
    private func ensureSelectionOnLaunch() async {
        guard !hasPerformedLaunchSelectionCheck else { return }
        hasPerformedLaunchSelectionCheck = true
        await Task.yield()
        if fonsters.isEmpty {
            withAnimation {
                let f = Fonster(name: "", seed: InstallationSeeds.currentTimeSeed(), createdAtISO8601: Fonster.currentCreatedAtISO8601())
                modelContext.insert(f)
                selectedId = f.id
            }
        } else if selectedId == nil {
            selectedId = fonsters.first!.id
        }
    }
}

// MARK: - Import Sheet
// Paste a share URL; parses ?cards= base64url and creates Fonsters from the seeds.

struct ImportSheet: View {
    @State private var pastedText = ""
    @FocusState private var urlFocused: Bool
    let onImport: ([String]) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste a Fonsters share URL (with ?cards=...) to import those creatures.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("URL", text: $pastedText, axis: .vertical)
                    #if os(tvOS)
                    .textFieldStyle(.plain)
                    #else
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .lineLimit(3...6)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                    .focused($urlFocused)
                    .onKeyPress(keys: [.escape]) { _ in urlFocused = false; return .handled }
                    #if os(macOS) || os(tvOS)
                    .onExitCommand { urlFocused = false }
                    #endif
                Spacer()
            }
            .padding()
            .navigationTitle("Import")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        if let seeds = parseSeedsFromShareURL(pastedText.trimmingCharacters(in: .whitespaces)) {
                            onImport(seeds)
                        }
                        onDismiss()
                    }
                    .disabled(parseSeedsFromShareURL(pastedText.trimmingCharacters(in: .whitespaces)) == nil)
                }
            }
        }
    }
}

// MARK: - Detail View

struct FonsterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var uprightCreatureState: UprightCreatureState
    @Bindable var fonster: Fonster
    @State private var seedText: String = ""
    @State private var isPlaying = false
    @State private var playFrameIndex = 0
    @State private var gifLoading = false
    @State private var randomLoading: String?
    @State private var randomMessage: String?
    @State private var showRandomMessageAlert = false
    @FocusState private var nameFocused: Bool
    @FocusState private var seedFocused: Bool
    @State private var playTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Birthday banner when today is this Fonster's birthday
            if fonster.isBirthdayToday {
                HStack(spacing: 8) {
                    Image(systemName: "birthday.cake")
                    Text("It's \(displayName)'s birthday!")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.quaternary.opacity(0.6))
            }

            // Form: scrollable so it doesn't push creature off on small windows
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Fonster name", text: $fonster.name)
                        #if os(tvOS)
                        .textFieldStyle(.plain)
                        #else
                        .textFieldStyle(.roundedBorder)
                        #endif
                        .focused($nameFocused)
                        .onKeyPress(keys: [.escape]) { _ in nameFocused = false; return .handled }
                        #if os(macOS) || os(tvOS)
                        .onExitCommand { nameFocused = false }
                        #endif
                    }

                    // Seed / source
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Seed (source text)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Type anything...", text: $seedText, axis: .vertical)
                            #if os(tvOS)
                            .textFieldStyle(.plain)
                            #else
                            .textFieldStyle(.roundedBorder)
                            #endif
                            .lineLimit(3...8)
                            .focused($seedFocused)
                            .onKeyPress(keys: [.escape]) { _ in seedFocused = false; return .handled }
                            #if os(macOS) || os(tvOS)
                            .onExitCommand { seedFocused = false }
                            #endif
                            .onChange(of: seedText) { _, newValue in
                                fonster.seed = newValue
                            }
                        if let usedLen = usedPrefixLength, usedLen < trimmedSeed.count {
                            let prefix = String(trimmedSeed.prefix(usedLen))
                            HStack(alignment: .top, spacing: 8) {
                                Text("Using for creature:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(prefix)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .lineLimit(2)
                                Button("Use as seed") {
                                    let newSeed = String(trimmedSeed.prefix(usedLen))
                                    fonster.seed = newSeed
                                    seedText = newSeed
                                    playFrameIndex = newSeed.count
                                    isPlaying = false
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        // Load random: label wraps; buttons scroll so nothing is cut off on small windows
                        randomButtonRow(
                            label: "Load random:",
                            sources: ["quote", "words", "uuid", "lorem"],
                            action: { source in Task { await loadRandom(source: source) } },
                            disabled: randomLoading != nil
                        )
                        // Prepend random
                        randomButtonRow(
                            label: "Prepend random:",
                            sources: ["quote", "words", "uuid", "lorem"],
                            action: { source in Task { await prependRandom(source: source) } },
                            disabled: randomLoading != nil
                        )
                    }

                    // Created / Birthday
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(createdDateDisplayString(for: fonster))
                            .font(.subheadline)
                    }
                }
                .padding()
            }
            .frame(minHeight: 0)

            // Creature area: environment + preview + play; expands to fill remaining space
            VStack(spacing: 12) {
                creatureSection
                actionButtons
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 280)
        }
        .navigationTitle(displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            }
        }
        #if !os(visionOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .onKeyPress(keys: [.space]) { _ in
            if nameFocused || seedFocused {
                return .ignored
            }
            if fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty {
                return .ignored
            }
            isPlaying.toggle()
            return .handled
        }
        #if os(tvOS)
        .background(PlayPauseHandlerView(onPlayPause: {
            if !nameFocused && !seedFocused && !fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty {
                isPlaying.toggle()
            }
        }))
        #endif
        .onAppear {
            seedText = fonster.seed
        }
        .onChange(of: fonster.seed) { _, newValue in
            if seedText != newValue { seedText = newValue }
            let s = newValue.trimmingCharacters(in: .whitespaces)
            if !s.isEmpty && playFrameIndex > s.count {
                playFrameIndex = s.count
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if !playing {
                playTask?.cancel()
                playTask = nil
            } else {
                let s = fonster.seed.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty && playFrameIndex >= s.count {
                    playFrameIndex = 0
                }
                playTask = Task { @MainActor in
                    while !Task.isCancelled && isPlaying {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        guard !Task.isCancelled else { break }
                        advancePlayFrame()
                    }
                }
            }
        }
        .alert("Random text", isPresented: $showRandomMessageAlert) {
            Button("OK", role: .cancel) { randomMessage = nil }
        } message: {
            Text(randomMessage ?? "")
        }
    }

    private var displayName: String {
        if !fonster.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return fonster.name
        }
        return "Fonster"
    }

    /// Formatted creation date for display (user's locale).
    private func createdDateDisplayString(for fonster: Fonster) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.timeZone = TimeZone.current
        return f.string(from: fonster.createdAt)
    }

    private var trimmedSeed: String {
        fonster.seed.trimmingCharacters(in: .whitespaces)
    }

    /// When stopped (playFrameIndex >= count) or not playing and at full length, show full seed; otherwise show prefix for current frame.
    private var effectiveSeedForDisplay: String {
        let s = trimmedSeed
        if s.isEmpty { return " " }
        if !isPlaying && playFrameIndex >= s.count {
            return fonster.seed
        }
        let prefixes = (1...s.count).map { i in String(s.prefix(i)) }
        let idx = min(playFrameIndex % max(1, prefixes.count), prefixes.count - 1)
        return prefixes[idx]
    }

    /// Number of characters used for the creature when playing or paused; nil when stopped (full) or empty seed.
    private var usedPrefixLength: Int? {
        let s = trimmedSeed
        if s.isEmpty { return nil }
        if !isPlaying && playFrameIndex >= s.count { return nil }
        return min(playFrameIndex + 1, s.count)
    }

    /// Random button row: label wraps; buttons in horizontal scroll so nothing is cut off on small windows.
    private func randomButtonRow(
        label: String,
        sources: [String],
        action: @escaping (String) -> Void,
        disabled: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sources, id: \.self) { source in
                        Button(source.capitalized) { action(source) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(disabled)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    /// Creature area that fills available space and sizes the creature to fit (min 200, max 600).
    private var creatureSection: some View {
        GeometryReader { geo in
            let padding: CGFloat = 32
            let availableW = max(0, geo.size.width - padding)
            let availableH = max(0, geo.size.height - padding - 60) // leave room for play button
            let size = min(availableW, availableH, 600)
            let creatureSize = max(200, size)
            ZStack(alignment: .bottomTrailing) {
                CreatureEnvironmentView(seed: fonster.seed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(false)
                creaturePreviewWithUpright(size: creatureSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                playStopButtons
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(minHeight: 280)
    }

    @ViewBuilder
    private func creaturePreviewWithUpright(size: CGFloat) -> some View {
        creaturePreview(size: size)
            .rotationEffect(
                uprightCreatureState.isEnabled ? Angle(radians: uprightCreatureState.gravityAngle) : .zero,
                anchor: .center
            )
    }

    @ViewBuilder
    private func creaturePreview(size: CGFloat) -> some View {
        #if os(visionOS)
        CreatureVoxelView(seed: effectiveSeedForDisplay, size: size)
        #else
        TappableCreatureView(seed: effectiveSeedForDisplay, size: size)
        #endif
    }

    private var playStopButtons: some View {
        HStack(spacing: 4) {
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(trimmedSeed.isEmpty)
            Button {
                isPlaying = false
                if !trimmedSeed.isEmpty {
                    playFrameIndex = trimmedSeed.count
                }
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(trimmedSeed.isEmpty || (!isPlaying && playFrameIndex >= trimmedSeed.count))
        }
        .padding(8)
    }

    private func advancePlayFrame() {
        let s = fonster.seed.trimmingCharacters(in: .whitespaces)
        if s.isEmpty {
            isPlaying = false
            return
        }
        let count = s.count
        playFrameIndex += 1
        if playFrameIndex >= count {
            playFrameIndex = 0
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
            #if !os(tvOS)
            Button {
                exportPNG()
            } label: {
                Label("PNG", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)

            Button {
                Task { await exportGIF() }
            } label: {
                if gifLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Label("GIF", systemImage: "photo")
                }
            }
            .buttonStyle(.bordered)
            .disabled(gifLoading || fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty)
            #if os(macOS)
            Button {
                exportJPEG()
            } label: {
                Label("JPEG", systemImage: "photo")
            }
            .buttonStyle(.bordered)
            #endif
            #endif

            Button {
                addNewFonster()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            if fonster.randomSource != nil {
                Button {
                    Task { await refreshRandom() }
                } label: {
                    if randomLoading != nil {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(randomLoading != nil)

                Button {
                    _ = fonster.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(fonster.history.isEmpty)

                Button {
                    _ = fonster.redo()
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .buttonStyle(.bordered)
                .disabled(fonster.future.isEmpty)
            }
            }
            .padding(.horizontal, 4)
        }
    }

    private func exportPNG() {
        guard let cgImage = creatureImage(for: fonster.seed) else { return }
        let filename = safeFilename(seed: exportFilenameSeed(fonster: fonster), ext: "png")
        let metadata = seedMetadata(seed: fonster.seed, createdAtISO8601: fonster.createdAtISO8601, createdAt: fonster.createdAt)
        guard let pngData = pngData(from: cgImage, metadata: metadata) else { return }
        #if os(iOS)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? pngData.write(to: tempURL)
        let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            top.present(av, animated: true)
        }
        #elseif os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = filename
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? pngData.write(to: url)
            }
        }
        #endif
    }

    private func exportGIF() async {
        gifLoading = true
        defer { gifLoading = false }
        let seed = fonster.seed.trimmingCharacters(in: .whitespaces)
        let effective = seed.isEmpty ? " " : seed
        let frames = (1...effective.count).map { i in String(effective.prefix(i)) }
        let metadata = seedMetadata(seed: fonster.seed, createdAtISO8601: fonster.createdAtISO8601, createdAt: fonster.createdAt)
        guard !frames.isEmpty,
              let gifData = creatureGIFData(seeds: frames, frameDelaySeconds: 0.3, metadata: metadata) else { return }
        #if os(iOS)
        let filename = safeFilename(seed: exportFilenameSeed(fonster: fonster), ext: "gif")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? gifData.write(to: tempURL)
        let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            top.present(av, animated: true)
        }
        #elseif os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.nameFieldStringValue = safeFilename(seed: exportFilenameSeed(fonster: fonster), ext: "gif")
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? gifData.write(to: url)
            }
        }
        #endif
    }

    #if os(macOS)
    private func exportJPEG() {
        guard let cgImage = creatureImage(for: fonster.seed) else { return }
        let filename = safeFilename(seed: exportFilenameSeed(fonster: fonster), ext: "jpg")
        let metadata = seedMetadata(seed: fonster.seed, createdAtISO8601: fonster.createdAtISO8601, createdAt: fonster.createdAt)
        guard let jpegData = jpegData(from: cgImage, metadata: metadata) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg]
        panel.nameFieldStringValue = filename
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? jpegData.write(to: url)
            }
        }
    }
    #endif

    private func addNewFonster() {
        let f = Fonster(name: "", seed: "", createdAtISO8601: Fonster.currentCreatedAtISO8601())
        modelContext.insert(f)
        // Selection will be updated by parent if we use navigation
    }

    private func loadRandom(source: String) async {
        randomLoading = source
        defer { randomLoading = nil }
        let (text, usedFallback) = await fetchRandomTextWithFallback(source: source)
        if let text = text {
            fonster.randomSource = source
            fonster.pushHistoryAndSetSeed(text)
            if usedFallback { randomMessage = "Used local fallback (server unavailable)."; showRandomMessageAlert = true }
        } else {
            randomMessage = "Couldn’t load random text. Try again or check your connection."
            showRandomMessageAlert = true
        }
    }

    private func refreshRandom() async {
        guard let source = fonster.randomSource else { return }
        randomLoading = source
        defer { randomLoading = nil }
        let (text, usedFallback) = await fetchRandomTextWithFallback(source: source)
        if let text = text {
            fonster.pushHistoryAndSetSeed(text)
            if usedFallback { randomMessage = "Used local fallback (server unavailable)."; showRandomMessageAlert = true }
        } else {
            randomMessage = "Couldn’t load random text. Try again or check your connection."
            showRandomMessageAlert = true
        }
    }

    private func prependRandom(source: String) async {
        randomLoading = source
        defer { randomLoading = nil }
        let (text, usedFallback) = await fetchRandomTextWithFallback(source: source)
        if let text = text {
            fonster.randomSource = source
            let newSeed = text.trimmingCharacters(in: .whitespaces) + " " + fonster.seed
            fonster.pushHistoryAndSetSeed(newSeed)
            seedText = fonster.seed
            if usedFallback { randomMessage = "Used local fallback (server unavailable)."; showRandomMessageAlert = true }
        } else {
            randomMessage = "Couldn’t load random text. Try again or check your connection."
            showRandomMessageAlert = true
        }
    }
}

// MARK: - Helpers (file-private; used by ContentView and FonsterDetailView)

/// Sanitizes seed for use as a file name (strip/replace invalid chars, cap length).
private func safeFilename(seed: String, ext: String) -> String {
    let trimmed = seed.trimmingCharacters(in: .whitespaces)
    let safe = trimmed
        .replacingOccurrences(of: "[\\s\\\\/:*?\"<>|]+", with: "_", options: .regularExpression)
        .replacingOccurrences(of: "_+", with: "_")
        .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    let base = String(safe.prefix(80))
    return (base.isEmpty ? "creature-avatar" : base) + "." + ext
}

private func exportFilenameSeed(fonster: Fonster) -> String {
    let trimmedName = fonster.name.trimmingCharacters(in: .whitespaces)
    if !trimmedName.isEmpty { return trimmedName }
    return fonster.seed
}

/// TIFF DateTime format: "yyyy:MM:dd HH:mm:ss"
private func tiffDateTime(from date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy:MM:dd HH:mm:ss"
    f.timeZone = TimeZone.current
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.string(from: date)
}

private func seedMetadata(seed: String, createdAtISO8601: String?, createdAt: Date) -> [String: Any] {
    let trimmed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
    var tiffDict: [String: Any] = [
        kCGImagePropertyTIFFDateTime as String: tiffDateTime(from: createdAt),
    ]
    if let iso = createdAtISO8601 {
        tiffDict[kCGImagePropertyTIFFImageDescription as String] = trimmed.isEmpty ? "Created: \(iso)" : "\(trimmed)\nCreated: \(iso)"
    } else if !trimmed.isEmpty {
        tiffDict[kCGImagePropertyTIFFImageDescription as String] = seed
    }
    var result: [String: Any] = [
        kCGImagePropertyTIFFDictionary as String: tiffDict,
    ]
    if !trimmed.isEmpty {
        result[kCGImagePropertyIPTCDictionary as String] = [
            kCGImagePropertyIPTCCaptionAbstract as String: seed,
            kCGImagePropertyIPTCKeywords as String: ["fonster", "seed", seed],
        ]
    }
    return result
}

private func pngData(from cgImage: CGImage, metadata: [String: Any]) -> Data? {
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { return nil }
    CGImageDestinationAddImage(dest, cgImage, metadata as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return data as Data
}

/// Renders the image onto a white background (JPEG has no alpha) and encodes as JPEG.
private func jpegData(from cgImage: CGImage, metadata: [String: Any], quality: Float = 0.9) -> Data? {
    let w = cgImage.width
    let h = cgImage.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
    guard let ctx = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { return nil }
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let opaqueImage = ctx.makeImage() else { return nil }
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(
        data,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ) else { return nil }
    let options: [String: Any] = [
        kCGImageDestinationLossyCompressionQuality as String: quality,
    ]
    var addMetadata = metadata
    for (k, v) in options { addMetadata[k] = v }
    CGImageDestinationAddImage(dest, opaqueImage, addMetadata as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return data as Data
}

/// Fetches random text from API; on failure tries local fallback for "words" and "uuid". Returns (text, usedFallback).
private func fetchRandomTextWithFallback(source: String) async -> (String?, Bool) {
    let urlString = "https://nathanfennel.com/api/creature-avatar/random-text?source=\(source.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? source)"
    guard let url = URL(string: urlString) else { return (localFallbackRandomText(source: source), true) }
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let text = json?["text"] as? String { return (text, false) }
    } catch { }
    let fallback = localFallbackRandomText(source: source)
    return (fallback, fallback != nil)
}

/// Local fallback when API is unavailable. Supports "words" and "uuid"; returns nil for quote/lorem.
private func localFallbackRandomText(source: String) -> String? {
    switch source {
    case "uuid":
        return UUID().uuidString
    case "words":
        let words = ["glow", "leaf", "coral", "flame", "forest", "river", "stone", "cloud", "star", "moon", "sun", "wind", "wave", "seed", "root", "vine", "frost", "ember", "shadow", "light"]
        let count = 4 + (words.count % 5)
        return (0..<count).map { _ in words.randomElement()! }.joined(separator: " ")
    default:
        return nil
    }
}

// MARK: - tvOS play/pause remote button

#if os(tvOS)
/// On tvOS, intercepts the remote’s play/pause button and invokes the callback so it can toggle the evolution animation.
private struct PlayPauseHandlerView: UIViewRepresentable {
    var onPlayPause: () -> Void

    func makeUIView(context: Context) -> PlayPauseHandlerHostView {
        let v = PlayPauseHandlerHostView()
        v.onPlayPause = onPlayPause
        return v
    }

    func updateUIView(_ uiView: PlayPauseHandlerHostView, context: Context) {
        uiView.onPlayPause = onPlayPause
    }
}

private final class PlayPauseHandlerHostView: UIView {
    var onPlayPause: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    /// Become first responder when in window so we receive play/pause from the remote.
    /// Other keys (arrows, select) are passed through so focus can move to the creature/play button.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            _ = becomeFirstResponder()
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .playPause {
                onPlayPause?()
                return
            }
        }
        resignFirstResponder()
        super.pressesEnded(presses, with: event)
    }
}
#endif

#Preview {
    ContentView()
        .environmentObject(PendingImportURLHolder())
        .modelContainer(for: Fonster.self, inMemory: true)
}
