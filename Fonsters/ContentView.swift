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
//    Play (evolution animation), PNG / GIF / JPEG (macOS) export (share/save), Refresh/Undo/Redo.
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
    @Environment(\.colorScheme) private var colorScheme
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
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    @EnvironmentObject private var featureFlags: FeatureFlagStore
    @State private var showHelpSheet = false
    #if DEBUG
    @State private var showFeatureFlagDebug = false
    #endif

    var body: some View {
        uprightContent
            .environmentObject(uprightCreatureState)
            .environmentObject(onboardingCoordinator)
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
            sidebarColumn
        } detail: {
            detailColumn
        }
        #if os(macOS) || os(iOS)
        .background {
            keyboardShortcutButtons
        }
        #endif
        #if os(macOS)
        .focusedSceneValue(\.fonstersMenuActions, FonstersMenuActions(
            addFonster: addFonster,
            shareCurrentFonster: {
                if let id = selectedId, let fonster = fonsters.first(where: { $0.id == id }) {
                    shareFonster(fonster)
                }
            },
            selectFonsterAt: selectFonsterAt,
            selectPreviousFonster: selectPreviousFonster,
            selectNextFonster: selectNextFonster,
            toggleSidebar: {
                columnVisibility = columnVisibility == .doubleColumn ? .detailOnly : .doubleColumn
            }
        ))
        #endif
    }

    private var sidebarColumn: some View {
        sidebarColumnContent
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            #endif
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: sidebarToolbar)
            .navigationTitle("Fonsters")
            .sheet(isPresented: $showImportSheet) {
                ImportSheet(onImport: { _ = importSeeds($0) }, onDismiss: { showImportSheet = false })
            }
            .alert("Share link too long", isPresented: $shareURLWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Try fewer creatures or shorter text so the link stays under 2,000 characters.")
            }
            #if os(tvOS)
            .alert("Share URL", isPresented: $showShareURLAlert) {
                Button("OK", role: .cancel) { shareURLToShow = nil }
            } message: {
                Text(shareURLToShow ?? "")
            }
            #endif
            .confirmationDialog(deleteConfirmationTitle, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Cancel", role: .cancel) { pendingDeleteOffsets = nil }
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
                if let seeds = parseSeedsFromShareURL(url.absoluteString),
                   let firstId = importSeeds(seeds) {
                    selectedId = firstId
                }
                pendingImportURL.url = nil
            }
            .task {
                await seedInitialCreaturesIfNeeded()
                await ensureSelectionOnLaunch()
                #if canImport(Tips)
                OnboardingCoordinator.shared = onboardingCoordinator
                if !onboardingCoordinator.hasCompletedOnboarding {
                    onboardingCoordinator.startWalkthrough()
                }
                #endif
            }
            .sheet(isPresented: $showHelpSheet) {
                HelpSheetView()
            }
            #if DEBUG
            .sheet(isPresented: $showFeatureFlagDebug) {
                FeatureFlagDebugSheet(store: featureFlags)
            }
            #endif
    }

    private var sidebarColumnContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            #if os(macOS)
            sidebarHeader
            #endif
            sidebarFonstersList
            #if os(macOS)
            sidebarFooter
            #endif
        }
    }

    @ViewBuilder
    private var sidebarFooter: some View {
        #if os(iOS)
        VStack(spacing: 0) {
            #if canImport(Tips)
            Group {
                if onboardingCoordinator.shouldShowTip(for: 1) {
                    Button(action: addFonster) {
                        HStack(alignment: .center) {
                            Label("Add Fonster", systemImage: "plus")
                                .font(.caption)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .popoverTip(AddFonsterTip())
                } else {
                    Button(action: addFonster) {
                        HStack(alignment: .center) {
                            Label("Add Fonster", systemImage: "plus")
                                .font(.caption)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial)
            Button {
                onboardingCoordinator.showTipsAgain()
            } label: {
                HStack(alignment: .center) {
                    Label("Show tips again", systemImage: "lightbulb")
                        .font(.caption)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial)
            #else
            Button(action: addFonster) {
                HStack(alignment: .center) {
                    Label("Add Fonster", systemImage: "plus")
                        .font(.caption)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial)
            Button {
                showHelpSheet = true
            } label: {
                HStack(alignment: .center) {
                    Label("How to use Fonsters", systemImage: "questionmark.circle")
                        .font(.caption)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial)
            #endif
        }
        #else
        #if canImport(Tips)
        Button {
            onboardingCoordinator.showTipsAgain()
        } label: {
            Label("Show tips again", systemImage: "lightbulb")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        #if !os(tvOS)
        .background(.quaternary.opacity(0.4))
        #endif
        #else
        Button {
            showHelpSheet = true
        } label: {
            Label("How to use Fonsters", systemImage: "questionmark.circle")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        #if !os(tvOS)
        .background(.quaternary.opacity(0.4))
        #endif
        #endif
        #endif
    }

    private var sidebarHeader: some View {
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
    }

    @ViewBuilder
    private var sidebarFonstersList: some View {
        List(selection: $selectedId) {
            ForEach(fonsters) { fonster in
                NavigationLink(value: fonster.id) {
                    sidebarRow(for: fonster)
                }
                #if os(iOS)
                .listRowBackground(colorScheme == .dark ? Color(white: 0.2) : Color(uiColor: .secondarySystemGroupedBackground))
                #endif
                #if os(tvOS)
                .listRowInsets(
                    EdgeInsets(
                        top: 18,
                        leading: 16,
                        bottom: 18,
                        trailing: 16
                    )
                )
                #endif
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
            #if os(tvOS)
            Section {
                Button {
                    showHelpSheet = true
                } label: {
                    Label("How to use Fonsters", systemImage: "questionmark.circle")
                        .font(.body)
                }
                .buttonStyle(.plain)
            }
            .listRowInsets(
                EdgeInsets(
                    top: 18,
                    leading: 8,
                    bottom: 18,
                    trailing: 8
                )
            )
            .focusSection()
            #endif
            #if os(iOS)
            Section {
                #if canImport(Tips)
                Group {
                    if onboardingCoordinator.shouldShowTip(for: 1) {
                        Button(action: addFonster) {
                            Label("Add Fonster", systemImage: "plus")
                        }
                        .popoverTip(AddFonsterTip())
                    } else {
                        Button(action: addFonster) {
                            Label("Add Fonster", systemImage: "plus")
                        }
                    }
                }
                Button {
                    onboardingCoordinator.showTipsAgain()
                } label: {
                    Label("Show tips again", systemImage: "lightbulb")
                }
                #else
                Button(action: addFonster) {
                    Label("Add Fonster", systemImage: "plus")
                }
                Button {
                    showHelpSheet = true
                } label: {
                    Label("How to use Fonsters", systemImage: "questionmark.circle")
                }
                #endif
            }
            .listRowBackground(Rectangle().fill(.ultraThinMaterial))
            #endif
        }
        #if canImport(Tips)
        .modifier(ConditionalPopoverTip(step: 3, tip: ListTip(), coordinator: onboardingCoordinator))
        #endif
    }

    private func sidebarRow(for fonster: Fonster) -> some View {
        #if os(tvOS)
        sidebarRowContent(for: fonster)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        #else
        sidebarRowContent(for: fonster)
        #endif
    }

    private func sidebarRowContent(for fonster: Fonster) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CreatureAvatarView(seed: fonster.seed, size: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(displayName(for: fonster))
                #if os(tvOS)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                #else
                .lineLimit(1)
                #endif
            if fonster.isBirthdayAnniversary {
                Text("Birthday!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ToolbarContentBuilder
    private func sidebarToolbar() -> some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: addFonster) {
                Image(systemName: "plus")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
        }
        #endif
        #if canImport(Tips)
        #if !os(iOS) && !os(tvOS)
        ToolbarItem {
            Group {
                if onboardingCoordinator.shouldShowTip(for: 1) {
                    Button(action: addFonster) { Label("Add Fonster", systemImage: "plus") }
                        .popoverTip(AddFonsterTip())
                } else {
                    Button(action: addFonster) { Label("Add Fonster", systemImage: "plus") }
                }
            }
        }
        #endif
        #if !os(iOS) && !os(tvOS)
        ToolbarItem {
            Group {
                if onboardingCoordinator.shouldShowTip(for: 2) {
                    Button(action: shareFonsters) { Label("Share", systemImage: "square.and.arrow.up") }
                        .popoverTip(ShareImportTip())
                } else {
                    Button(action: shareFonsters) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
        }
        ToolbarItem {
            Button(action: { showImportSheet = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
        }
        #endif
        #else
        #if !os(iOS) && !os(tvOS)
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
        #endif
        #endif
        #if os(macOS)
        ToolbarItem {
            Button {
                columnVisibility = columnVisibility == .doubleColumn ? .detailOnly : .doubleColumn
            } label: {
                Label("Show/Hide Sidebar", systemImage: "sidebar.left")
            }
            .keyboardShortcut(KeyEquivalent("`"), modifiers: [.command, .option])
        }
        #endif
        #if DEBUG && !os(tvOS)
        ToolbarItem(placement: .primaryAction) {
            Button {
                showFeatureFlagDebug = true
            } label: {
                Label("Feature Flags", systemImage: "flag")
            }
        }
        #endif
        #if os(tvOS)
        ToolbarItem(placement: .primaryAction) {
            Button(action: addFonster) {
                Image(systemName: "plus")
                    .padding(12)
            }
        }
        #endif
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let id = selectedId, let fonster = fonsters.first(where: { $0.id == id }) {
            #if os(iOS)
            NavigationStack {
                FonsterDetailView(fonster: fonster, onShare: shareFonster)
            }
            #else
            FonsterDetailView(fonster: fonster)
            #endif
        } else {
            ContentUnavailableView("Select a Fonster", systemImage: "sparkles")
        }
    }

    #if os(macOS) || os(iOS)
    private var keyboardShortcutButtons: some View {
        Group {
            ForEach(1...10, id: \.self) { position in
                keyboardShortcutButton(for: position)
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
            Button("") { duplicateCurrentFonster() }
                .keyboardShortcut("d", modifiers: .command)
        }
        .hidden()
    }

    private func keyboardShortcutButton(for position: Int) -> some View {
        let keyChar = Character(Unicode.Scalar(48 + (position == 10 ? 0 : position))!)
        return Button("") { selectFonsterAt(position: position) }
            .keyboardShortcut(KeyEquivalent(keyChar), modifiers: .command)
    }
    #endif

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
            let f = Fonster(name: InitialCreatureNames.oneName(), seed: InstallationSeeds.currentTimeSeed(), createdAtISO8601: Fonster.currentCreatedAtISO8601())
            modelContext.insert(f)
            selectedId = f.id
        }
    }

    #if os(macOS) || os(iOS)
    private func duplicateCurrentFonster() {
        guard let id = selectedId, let f = fonsters.first(where: { $0.id == id }) else { return }
        withAnimation {
            let copy = Fonster(
                name: f.name,
                seed: f.seed,
                randomSource: f.randomSource,
                history: [],
                future: [],
                createdAtISO8601: Fonster.currentCreatedAtISO8601()
            )
            modelContext.insert(copy)
            selectedId = copy.id
        }
    }
    #endif

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
                let f = Fonster(name: InitialCreatureNames.oneName(), seed: seed, createdAtISO8601: Fonster.currentCreatedAtISO8601())
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
                let f = Fonster(name: InitialCreatureNames.oneName(), seed: InstallationSeeds.currentTimeSeed(), createdAtISO8601: Fonster.currentCreatedAtISO8601())
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
                Text("Paste a Fonsters share link to import those creatures.")
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

// MARK: - Help sheet (tvOS / visionOS or when TipKit is unavailable)
struct HelpSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Add a Fonster with the + button in the toolbar.", systemImage: "plus.circle")
                    Label("Share creates a link others can open; Import adds creatures from a pasted link.", systemImage: "square.and.arrow.up")
                    Label("Tap a creature in the list to open it and edit its name and source text.", systemImage: "list.bullet")
                    Label("Type in the source text field to change the creature; use Get random for quick ideas.", systemImage: "text.cursor")
                    Label("Tap Play to watch the creature evolve; tap the creature for a short animation.", systemImage: "play.circle.fill")
                    Label("Export as PNG or GIF to save or share.", systemImage: "square.and.arrow.down")
                }
            }
            .navigationTitle("How to use Fonsters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Detail shortcut buttons (macOS/iOS) — extracted to ease type-checking

#if os(macOS) || os(iOS)
private struct DetailShortcutButtonsView: View {
    var canRefresh: Bool
    var canUndo: Bool
    var canRedo: Bool
    var onRefresh: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onCopy: () -> Void

    var body: some View {
        Group {
            Button("", action: onRefresh)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!canRefresh)
            Button("", action: onUndo)
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!canUndo)
            Button("", action: onRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!canRedo)
            Button("", action: onCopy)
                .keyboardShortcut("c", modifiers: .command)
        }
        .hidden()
    }
}
#endif

// MARK: - Detail View

struct FonsterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var uprightCreatureState: UprightCreatureState
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @EnvironmentObject private var featureFlags: FeatureFlagStore
    @Bindable var fonster: Fonster
    var onShare: ((Fonster) -> Void)? = nil
    @State private var seedText: String = ""
    @State private var isPlaying = false
    @State private var playFrameIndex = 0
    @State private var gifLoading = false
    @State private var randomLoading: String?
    @FocusState private var nameFocused: Bool
    @FocusState private var seedFocused: Bool
    @State private var playTask: Task<Void, Never>?
    /// 0.1 = 10% (current default speed), 1.0 = 100% (10× faster). Controls Play evolution and GIF frame timing.
    @State private var animationSpeedMultiplier: Double = 0.1
    /// When user leaves seed field, push this value as previous for undo (so manual edits are undoable).
    @State private var seedWhenFocused: String?
    @State private var showBirthdayCelebration = false
    @State private var triggerBirthdayDanceID = 0
    #if os(iOS) || os(macOS)
    @State private var showFontPicker = false
    #endif
    #if os(macOS) || os(tvOS)
    @State private var nameLabelLastTapTime: Date?
    @State private var nameLabelSingleTapTask: Task<Void, Never>?
    @State private var nameLabelJiggleTrigger: Int = 0
    @State private var showEditNameSheet = false
    #endif
    #if os(tvOS)
    @State private var showEditSeedSheet = false
    @State private var seedWhenEditSeedSheetOpened: String?
    #endif

    var body: some View {
        #if os(iOS)
        iosDetailBody
        #else
        ZStack {
        #if os(tvOS)
        ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 0) {
                // Left column: form and controls (narrower), birthday pinned to bottom
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 24) {
                            if fonster.isBirthdayAnniversary {
                                HStack(spacing: 8) {
                                    Image(systemName: "birthday.cake")
                                    Text(birthdayBannerText)
                                        .font(.subheadline.weight(.medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                #if !os(tvOS)
                                .background(.quaternary.opacity(0.6))
                                #endif
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .center, spacing: 8) {
                                    Text("Name")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 32)
                                    Spacer(minLength: 0)
                                    Button {
                                        showEditNameSheet = true
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(.plain)
                                    Spacer(minLength: 8)
                                }
                                // Spacer to reserve space for name
                                Color.clear
                                    .frame(height: 100)
                            }
                            .padding(.vertical, 4)

                        randomButtonRow(
                            label: "Get random:",
                            sources: ["quote", "words", "uuid", "lorem"],
                            action: { source in Task { await loadRandom(source: source) } },
                            disabled: randomLoading != nil,
                            trailingEditAction: {
                                seedWhenEditSeedSheetOpened = seedText
                                showEditSeedSheet = true
                            }
                        )
                        randomButtonRow(
                            label: "Add random to start:",
                            sources: ["quote", "words", "uuid", "lorem"],
                            action: { source in Task { await prependRandom(source: source) } },
                            disabled: randomLoading != nil
                        )

                        Spacer(minLength: 24)

                        actionButtons

                        Spacer(minLength: 24)
                    }
                    .padding(
                        EdgeInsets(
                            top: 20,
                            leading: 32,
                            bottom: 20,
                            trailing: 0
                        )
                    )
                    .frame(minWidth: 480, alignment: .leading)
                }
                .frame(maxWidth: .infinity)

                if featureFlags.isEnabled(.showBirthdayOverlay) {
                    Button {
                        showBirthdayCelebration = true
                        triggerBirthdayDanceID += 1
                    } label: {
                        HStack(spacing: 6) {
                            Text("🎂")
                            Text(fonsterBirthdayMonthDayString(for: fonster))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: 480)
            
            // Overlay name so it can extend beyond left column bounds
            VStack(alignment: .leading, spacing: 0) {
                if fonster.isBirthdayAnniversary {
                    Spacer()
                        .frame(height: 20 + 50) // top padding + birthday banner
                } else {
                    Spacer()
                        .frame(height: 20) // top padding
                }
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: 32) // leading padding
                    VStack(alignment: .leading, spacing: 12) {
                        Spacer()
                            .frame(height: 30) // "Name" label height
                        CreatureNameView(
                            displayName: displayName,
                            seed: fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : fonster.seed,
                            externalJiggleTrigger: $nameLabelJiggleTrigger
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            nameLabelSingleTapTask?.cancel()
                            nameLabelSingleTapTask = nil
                            showEditNameSheet = true
                        }
                        .onTapGesture(count: 1) {
                            let now = Date()
                            nameLabelJiggleTrigger += 1
                            nameLabelSingleTapTask?.cancel()
                            nameLabelSingleTapTask = nil
                            if let last = nameLabelLastTapTime, now.timeIntervalSince(last) < 0.35 {
                                nameLabelLastTapTime = nil
                                showEditNameSheet = true
                                return
                            }
                            nameLabelLastTapTime = now
                        }
                    }
                    Spacer()
                }
                Spacer()
            }
            .allowsHitTesting(true)

            // Right column: creature in maximal square with padding around it, controls below
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    creatureSection
                        .frame(width: side, height: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Play/stop buttons and speed controls below the creature image
                // Centered horizontally under the creature image and vertically aligned with the birthday label
                HStack(alignment: .center, spacing: 32) {
                    tvOSPlayStopRow
                    animationSpeedSlider
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16) // Spacing from creature image
                .padding(.bottom, 12) // Match birthday label vertical padding
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #else
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Birthday banner when today is this Fonster's birthday (anniversary only)
                    if fonster.isBirthdayAnniversary {
                        HStack(spacing: 8) {
                            Image(systemName: "birthday.cake")
                            Text(birthdayBannerText)
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(.quaternary.opacity(0.6))
                    }

                    // Form: name, seed, random buttons
                    VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    #if os(macOS) || os(tvOS)
                    nameFieldOrLabel
                    #else
                    TextField("Fonster name", text: $fonster.name)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                        .onKeyPress(keys: [.escape]) { _ in nameFocused = false; return .handled }
                    #endif
                    }

                    // Seed / source
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Source text")
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
                            .onChange(of: seedFocused) { _, focused in
                                if focused {
                                    seedWhenFocused = seedText
                                } else {
                                    if let prev = seedWhenFocused, prev != seedText {
                                        fonster.pushPreviousAndSetSeed(previous: prev, newSeed: seedText)
                                    }
                                    seedWhenFocused = nil
                                }
                            }
                        #if !os(tvOS)
                        randomButtonRow(
                            label: "Get random:",
                            sources: ["quote", "words", "uuid", "lorem"],
                            action: { source in Task { await loadRandom(source: source) } },
                            disabled: randomLoading != nil
                        )
                        randomButtonRow(
                            label: "Add random to start:",
                            sources: ["quote", "words", "uuid", "lorem"],
                            action: { source in Task { await prependRandom(source: source) } },
                            disabled: randomLoading != nil
                        )
                        #endif
                    }
                }
                #if canImport(Tips)
                .modifier(ConditionalPopoverTip(step: 4, tip: DetailSeedTip(), coordinator: onboardingCoordinator))
                #endif
                .padding()

                // Creature area: environment + preview + play
                creatureSection
                    .padding(.horizontal)
                    .padding(.top, 8)
                #if canImport(Tips)
                    .modifier(ConditionalPopoverTip(step: 5, tip: PlayTip(), coordinator: onboardingCoordinator))
                #endif
                #if !os(tvOS)
                // What shapes your creature: show beneath the image only while playing
                if isPlaying, let usedLen = usedPrefixLength, usedLen < trimmedSeed.count {
                    let prefix = String(trimmedSeed.prefix(usedLen))
                    HStack(alignment: .top, spacing: 8) {
                        Text("What shapes your creature:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(prefix)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Button("Use this") {
                            let newSeed = String(trimmedSeed.prefix(usedLen))
                            fonster.seed = newSeed
                            seedText = newSeed
                            playFrameIndex = newSeed.count
                            isPlaying = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                #endif
                Spacer(minLength: 16)
                actionButtons
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                #if canImport(Tips)
                    .modifier(ConditionalPopoverTip(step: 6, tip: ExportTip(), coordinator: onboardingCoordinator))
                #endif
                if isPlaying {
                    animationSpeedSlider
                        .padding(.horizontal)
                }
                #if os(iOS) || os(visionOS) || os(tvOS)
                if featureFlags.isEnabled(.showBirthdayOverlay) {
                Button {
                    showBirthdayCelebration = true
                    triggerBirthdayDanceID += 1
                } label: {
                    HStack(spacing: 6) {
                        Text("Birthday")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(fonsterBirthdayMonthDayString(for: fonster))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
                }
                #endif
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            #if os(macOS)
            if featureFlags.isEnabled(.showBirthdayOverlay) {
            // Footer: Birthday (pinned to bottom, outside scroll)
            Button {
                showBirthdayCelebration = true
                triggerBirthdayDanceID += 1
            } label: {
                HStack(spacing: 6) {
                    Text("Birthday")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(fonsterBirthdayMonthDayString(for: fonster))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.4))
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        
        ZStack {
            if featureFlags.isEnabled(.showBirthdayOverlay), showBirthdayCelebration {
                GeometryReader { geo in
                    BirthdayCelebrationOverlay(
                        size: geo.size,
                        effect: celebrationEffect,
                        onDismiss: { showBirthdayCelebration = false }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #if os(tvOS)
        .navigationTitle("")
        #else
        .navigationTitle(displayName)
        #endif
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            }
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFontPicker = true
                } label: {
                    Image(systemName: "textformat")
                }
            }
            #endif
        }
        #if os(macOS) || os(tvOS)
        .sheet(isPresented: $showEditNameSheet) {
            EditFonsterNameSheet(name: $fonster.name)
        }
        #endif
        #if os(tvOS)
        .sheet(isPresented: $showEditSeedSheet) {
            EditFonsterSeedSheet(seedText: $seedText)
        }
        .onChange(of: showEditSeedSheet) { _, showing in
            if !showing {
                if let prev = seedWhenEditSeedSheetOpened, prev != seedText {
                    fonster.pushPreviousAndSetSeed(previous: prev, newSeed: seedText)
                }
                seedWhenEditSeedSheetOpened = nil
            }
        }
        #endif
        #if os(macOS)
        .sheet(isPresented: $showFontPicker) {
            CreatureNameFontPickerView(sampleName: displayName)
        }
        #endif
        #if !os(visionOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .onKeyPress(keys: [.space]) { _ in
            #if os(macOS) || os(tvOS)
            if showEditNameSheet { return .ignored }
            #endif
            #if os(tvOS)
            if showEditSeedSheet { return .ignored }
            #endif
            if nameFocused || seedFocused {
                return .ignored
            }
            if fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty {
                return .ignored
            }
            isPlaying.toggle()
            return .handled
        }
        .onKeyPress(keys: [.return]) { _ in
            #if os(macOS) || os(tvOS)
            if showEditNameSheet { return .ignored }
            #endif
            #if os(tvOS)
            if showEditSeedSheet { return .ignored }
            #endif
            if nameFocused || seedFocused {
                return .ignored
            }
            if fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty {
                return .ignored
            }
            isPlaying.toggle()
            return .handled
        }
        #if os(macOS) || os(iOS)
        .background(DetailShortcutButtonsView(
            canRefresh: fonster.randomSource != nil && randomLoading == nil,
            canUndo: !fonster.history.isEmpty,
            canRedo: !fonster.future.isEmpty,
            onRefresh: { Task { await refreshRandom() } },
            onUndo: { _ = fonster.undo() },
            onRedo: { _ = fonster.redo() },
            onCopy: copySourceToPasteboard
        ))
        #endif
        #if os(tvOS)
        .background(PlayPauseHandlerView(onPlayPause: {
            if !showEditNameSheet && !showEditSeedSheet && !nameFocused && !seedFocused && !fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty {
                isPlaying.toggle()
            }
        }))
        #endif
        // Reset animation to stopped state on appear/selection/seed change — applies to all platforms (iOS, macOS, tvOS, visionOS).
        .onAppear {
            seedText = fonster.seed
            // Start in stopped state: full creature visible, animation off.
            isPlaying = false
            playTask?.cancel()
            playTask = nil
            let s = fonster.seed.trimmingCharacters(in: .whitespaces)
            playFrameIndex = s.isEmpty ? 0 : s.count
        }
        #if os(tvOS)
        .onDisappear {
            // When leaving (e.g. back on remote), return to full/original state so next time we show the complete creature.
            if isPlaying || playFrameIndex < fonster.seed.trimmingCharacters(in: .whitespaces).count {
                isPlaying = false
                playTask?.cancel()
                playTask = nil
                let s = fonster.seed.trimmingCharacters(in: .whitespaces)
                playFrameIndex = s.isEmpty ? 0 : s.count
            }
            // Always re-enable screensaver when leaving the view
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
        .onChange(of: fonster.id) { _, _ in
            // When a different Fonster is selected (same as Stop button).
            isPlaying = false
            playTask?.cancel()
            playTask = nil
            let s = fonster.seed.trimmingCharacters(in: .whitespaces)
            if !s.isEmpty {
                playFrameIndex = s.count
            } else {
                playFrameIndex = 0
            }
        }
        .onChange(of: fonster.seed) { _, newValue in
            if seedText != newValue { seedText = newValue }
            // After every change to source text (keystroke, paste, etc.), same as Stop.
            isPlaying = false
            playTask?.cancel()
            playTask = nil
            let s = newValue.trimmingCharacters(in: .whitespaces)
            playFrameIndex = s.isEmpty ? 0 : s.count
        }
        .onChange(of: isPlaying) { _, playing in
            #if os(tvOS)
            // Prevent screensaver while animation is playing
            UIApplication.shared.isIdleTimerDisabled = playing
            #endif
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
                        let intervalNs = UInt64(playFrameIntervalSeconds * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: intervalNs)
                        guard !Task.isCancelled else { break }
                        advancePlayFrame()
                    }
                }
            }
        }
        #endif
    }

    #if os(iOS)
    private var iosDetailBody: some View {
        let displaySeed = fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : fonster.seed
        return ZStack {
            VStack(spacing: 0) {
                CreatureNameView(displayName: displayName, seed: displaySeed)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                Spacer(minLength: 0)
                TappableCreatureView(seed: displaySeed, size: 240, triggerBirthdayDanceID: triggerBirthdayDanceID)
                    .rotationEffect(
                        uprightCreatureState.isEnabled ? Angle(radians: uprightCreatureState.gravityAngle) : .zero,
                        anchor: .center
                    )
                    .frame(width: 240, height: 240)
                Spacer(minLength: 0)
                if featureFlags.isEnabled(.showBirthdayOverlay) {
                Button {
                    showBirthdayCelebration = true
                    triggerBirthdayDanceID += 1
                } label: {
                    HStack(spacing: 6) {
                        Text("Birthday")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(fonsterBirthdayMonthDayString(for: fonster))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                }
            Menu {
                Button {
                    onShare?(fonster)
                } label: {
                    Label("Share link", systemImage: "link")
                }
                Button {
                    exportPNG()
                } label: {
                    Label("Share image", systemImage: "photo")
                }
                Button {
                    Task { await exportGIF() }
                } label: {
                    Label("Share GIF", systemImage: "photo")
                }
                .disabled(gifLoading || fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Share")
            .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if featureFlags.isEnabled(.showBirthdayOverlay), showBirthdayCelebration {
                GeometryReader { geo in
                    BirthdayCelebrationOverlay(
                        size: geo.size,
                        effect: celebrationEffect,
                        onDismiss: { showBirthdayCelebration = false }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(tvOS)
        .navigationTitle("")
        #else
        .navigationTitle(displayName)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        showFontPicker = true
                    } label: {
                        Image(systemName: "textformat")
                    }
                    NavigationLink {
                        FonsterEditView(
                            fonster: fonster,
                            onShare: onShare ?? { _ in },
                            onShareImage: { exportPNG() },
                            onShareGIF: { Task { await exportGIF() } }
                        )
                    } label: {
                        Text("Edit")
                    }
                }
            }
        }
        .sheet(isPresented: $showFontPicker) {
            CreatureNameFontPickerView(sampleName: displayName)
        }
    }
    #endif

    private var displayName: String {
        if !fonster.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return fonster.name
        }
        let seed = fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : fonster.seed
        let idx = segmentPick(
            seed: seed,
            segmentId: "default_display_name",
            n: InitialCreatureNames.premade.count
        )
        return InitialCreatureNames.premade[idx]
    }

    #if os(macOS) || os(tvOS)
    /// macOS/tvOS: Styled name label (single tap = jiggle, double tap = edit popup), plus edit button that opens the same popup.
    @ViewBuilder
    private var nameFieldOrLabel: some View {
        HStack(alignment: .center, spacing: 8) {
            CreatureNameView(
                displayName: displayName,
                seed: fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : fonster.seed,
                externalJiggleTrigger: $nameLabelJiggleTrigger
            )
            #if os(tvOS)
            .fixedSize(horizontal: false, vertical: true)
            #else
            .frame(maxWidth: .infinity, alignment: .leading)
            #endif
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                nameLabelSingleTapTask?.cancel()
                nameLabelSingleTapTask = nil
                showEditNameSheet = true
            }
            .onTapGesture(count: 1) {
                let now = Date()
                nameLabelJiggleTrigger += 1
                nameLabelSingleTapTask?.cancel()
                nameLabelSingleTapTask = nil
                if let last = nameLabelLastTapTime, now.timeIntervalSince(last) < 0.35 {
                    nameLabelLastTapTime = nil
                    showEditNameSheet = true
                    return
                }
                nameLabelLastTapTime = now
            }
            Button {
                showEditNameSheet = true
            } label: {
                Image(systemName: "pencil")
            }
            #if os(macOS)
            .buttonStyle(.bordered)
            .help("Edit name")
            #else
            .buttonStyle(.plain)
            #endif
        }
    }
    #endif

    /// Celebration effect chosen deterministically from Fonster seed.
    private var celebrationEffect: CelebrationEffect {
        let seed = fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : fonster.seed
        let idx = segmentPick(seed: seed, segmentId: "birthday_celebration", n: CelebrationEffect.allCases.count)
        return CelebrationEffect(rawValue: idx) ?? .confetti
    }

    /// Birthday banner text: named "It's {name}'s birthday!" or "It's your Fonster's Birthday!" when unnamed.
    private var birthdayBannerText: String {
        let name = fonster.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            return "It's \(name)'s birthday!"
        }
        return "It's your Fonster's Birthday!"
    }

    /// Birthday as spelled month and day (e.g. "February 4") for display.
    private func fonsterBirthdayMonthDayString(for fonster: Fonster) -> String {
        birthdayMonthDayString(from: fonster.createdAt)
    }

    private var trimmedSeed: String {
        fonster.seed.trimmingCharacters(in: .whitespaces)
    }

    /// When stopped (playFrameIndex >= count) or not playing and at full length, show full seed; otherwise show prefix for current frame.
    /// Uses seedText when showing the full seed so the creature updates in real time as the user types.
    /// When seedText is not yet synced (e.g. before onAppear), use fonster.seed so the creature is visible by default.
    private var effectiveSeedForDisplay: String {
        let s = trimmedSeed
        if s.isEmpty && seedText.trimmingCharacters(in: .whitespaces).isEmpty { return " " }
        if !isPlaying && playFrameIndex >= s.count {
            let live = seedText.trimmingCharacters(in: .whitespaces)
            if live.isEmpty { return s.isEmpty ? " " : fonster.seed }
            return seedText
        }
        if s.isEmpty { return " " }
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

    /// User-friendly display name for random source buttons (uuid, lorem are technical); used as accessibility label.
    private func randomSourceDisplayName(for source: String) -> String {
        switch source {
        case "uuid": return "Random code"
        case "lorem": return "Sample text"
        default: return source.capitalized
        }
    }

    /// SF Symbol name for each random source (used for button icon).
    private func randomSourceSymbol(for source: String) -> String {
        switch source {
        case "quote": return "quote.bubble"
        case "words": return "text.word.spacing"
        case "uuid": return "number"
        case "lorem": return "doc.text"
        default: return "questionmark.circle"
        }
    }

    /// Random button row: label on top; buttons wrap to next line when horizontal space is limited.
    private func randomButtonRow(
        label: String,
        sources: [String],
        action: @escaping (String) -> Void,
        disabled: Bool,
        trailingEditAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            #if os(tvOS)
            if let trailingEditAction {
                HStack(alignment: .center, spacing: 8) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 32)
                    Spacer(minLength: 0)
                    Button(action: trailingEditAction) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit source text")
                    Spacer(minLength: 8)
                }
            } else {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            #else
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            #endif
            #if os(tvOS)
            WrapLayout(spacing: 16, lineSpacing: 16) {
                ForEach(sources, id: \.self) { source in
                    Button { action(source) } label: {
                        Image(systemName: randomSourceSymbol(for: source))
                    }
                    .padding(16)
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .disabled(disabled)
                    .accessibilityLabel(randomSourceDisplayName(for: source))
                }
            }
            #else
            WrapLayout(spacing: 8, lineSpacing: 8) {
                ForEach(sources, id: \.self) { source in
                    Button { action(source) } label: {
                        Image(systemName: randomSourceSymbol(for: source))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(disabled)
                    .accessibilityLabel(randomSourceDisplayName(for: source))
                }
            }
            #endif
        }
    }

    /// Creature area: expands to fill space; creature scales to fill its container (no gap).
    private var creatureSection: some View {
        GeometryReader { geo in
            let padding: CGFloat = 24
            let availableW = max(0, geo.size.width - padding * 2)
            #if os(tvOS)
            // On tvOS, controls are below the creature image, so use full height
            let availableH = max(0, geo.size.height - padding * 2)
            #else
            let availableH = max(0, geo.size.height - padding * 2 - 44) // leave room for play/stop
            #endif
            let creatureSize = max(160, min(availableW, availableH))
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                creaturePreviewWithUpright(size: creatureSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(padding)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                #if !os(tvOS)
                playStopButtons
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(minHeight: 200, maxHeight: .infinity)
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
        let useGlow = featureFlags.isEnabled(.creatureGlowEffect)
        let glowBlur: CGFloat = 14
        #if os(visionOS)
        if useGlow {
            ZStack {
                CreatureAvatarView(seed: effectiveSeedForDisplay, size: size)
                    .colorInvert()
                    .blur(radius: glowBlur)
                CreatureVoxelView(seed: effectiveSeedForDisplay, size: size, triggerBirthdayDanceID: triggerBirthdayDanceID)
            }
        } else {
            CreatureVoxelView(seed: effectiveSeedForDisplay, size: size, triggerBirthdayDanceID: triggerBirthdayDanceID)
        }
        #else
        if useGlow {
            ZStack {
                CreatureAvatarView(seed: effectiveSeedForDisplay, size: size)
                    .colorInvert()
                    .blur(radius: glowBlur)
                TappableCreatureView(seed: effectiveSeedForDisplay, size: size, triggerBirthdayDanceID: triggerBirthdayDanceID)
            }
        } else {
            TappableCreatureView(seed: effectiveSeedForDisplay, size: size, triggerBirthdayDanceID: triggerBirthdayDanceID)
        }
        #endif
    }

    /// Frame interval in seconds: 0.3 at 10% (current default), 0.03 at 100% (10× faster).
    private var playFrameIntervalSeconds: Double {
        let baseSeconds: Double = 0.3
        let speedFactor = animationSpeedMultiplier * 10 // 1 at 10%, 10 at 100%
        return baseSeconds / speedFactor
    }

    private var animationSpeedSlider: some View {
        HStack(spacing: 8) {
            Label("Speed", systemImage: "speedometer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                #if os(tvOS)
                .fixedSize(horizontal: true, vertical: false)
                #else
                .frame(width: 80, alignment: .leading)
                #endif
            #if os(tvOS)
            Button {
                animationSpeedMultiplier = max(0.1, animationSpeedMultiplier - 0.05)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            Text("\(Int(animationSpeedMultiplier * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 40)
            Button {
                animationSpeedMultiplier = min(1.0, animationSpeedMultiplier + 0.05)
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            #else
            Slider(value: $animationSpeedMultiplier, in: 0.1...1.0, step: 0.05)
            Text("\(Int(animationSpeedMultiplier * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 28, alignment: .trailing)
            #endif
        }
        .padding(.vertical, 2)
    }

    #if os(tvOS)
    /// Play and stop buttons for tvOS, placed below the creature image view.
    /// Each button fills half the row so focus from the row above or below always lands on play or stop (no dead spacer).
    private var tvOSPlayStopRow: some View {
        let playTint = Color(hue: 1/3, saturation: 0.2, brightness: 0.9)
        let stopTint = Color(hue: 0, saturation: 0.2, brightness: 0.9)
        return HStack(spacing: 16) {
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .tint(playTint)
            .disabled(trimmedSeed.isEmpty)
            Button {
                isPlaying = false
                if !trimmedSeed.isEmpty {
                    playFrameIndex = trimmedSeed.count
                }
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .tint(stopTint)
            .disabled(trimmedSeed.isEmpty)
        }
    }
    #endif

    private var playStopButtons: some View {
        let progress: Double = {
            let s = trimmedSeed
            if s.isEmpty { return 0 }
            let count = s.count
            return min(1, max(0, Double(playFrameIndex) / Double(count)))
        }()
        let progressRingColor: Color = {
            let seed = trimmedSeed.isEmpty ? " " : trimmedSeed
            let colors = opaquePaletteColors(seed: seed)
            return colors.first ?? Color.secondary
        }()
        return HStack(spacing: 4) {
            #if !os(tvOS)
            ZStack {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progressRingColor, lineWidth: 1.5)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 26, height: 26)
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .tint(Color(hue: 1/3, saturation: 0.2, brightness: 0.9))
                .disabled(trimmedSeed.isEmpty)
            }
            .frame(width: 28, height: 28)
            #endif
            #if os(tvOS)
            if isPlaying {
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
                .tint(Color(hue: 0, saturation: 0.2, brightness: 0.9))
                .disabled(trimmedSeed.isEmpty)
            }
            #else
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
            .tint(Color(hue: 0, saturation: 0.2, brightness: 0.9))
            .disabled(trimmedSeed.isEmpty || (!isPlaying && playFrameIndex >= trimmedSeed.count))
            #endif
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
        HStack(spacing: 0) {
            #if !os(tvOS)
            Button {
                exportPNG()
            } label: {
                Label("PNG", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .tint(Color.blue.opacity(0.85))

            Spacer(minLength: 8)

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
            .tint(Color.cyan.opacity(0.85))
            .disabled(gifLoading || fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer(minLength: 8)

            #if os(macOS)
            Button {
                exportJPEG()
            } label: {
                Label("JPEG", systemImage: "photo")
            }
            .buttonStyle(.bordered)
            .tint(Color.orange.opacity(0.85))

            Spacer(minLength: 8)
            #endif
            #endif

            if fonster.randomSource != nil {
                #if !os(tvOS)
                Spacer(minLength: 8)
                #endif

                Button {
                    Task { await refreshRandom() }
                } label: {
                    #if os(tvOS)
                    if randomLoading != nil {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.indigo.opacity(0.85))
                    }
                    #else
                    if randomLoading != nil {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                #else
                .buttonStyle(.bordered)
                .tint(Color.indigo.opacity(0.85))
                #endif
                .disabled(randomLoading != nil)

                #if !os(tvOS)
                Spacer(minLength: 8)
                #endif

                Button {
                    _ = fonster.undo()
                } label: {
                    #if os(tvOS)
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundStyle(Color.orange.opacity(0.8))
                    #else
                    Label("Undo", systemImage: "arrow.uturn.backward")
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                #else
                .buttonStyle(.bordered)
                .tint(Color.orange.opacity(0.8))
                #endif
                .disabled(fonster.history.isEmpty)

                #if !os(tvOS)
                Spacer(minLength: 8)
                #endif

                Button {
                    _ = fonster.redo()
                } label: {
                    #if os(tvOS)
                    Image(systemName: "arrow.uturn.forward")
                        .foregroundStyle(Color.purple.opacity(0.85))
                    #else
                    Label("Redo", systemImage: "arrow.uturn.forward")
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                #else
                .buttonStyle(.bordered)
                .tint(Color.purple.opacity(0.85))
                #endif
                .disabled(fonster.future.isEmpty)
            }
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
              let gifData = creatureGIFData(seeds: frames, frameDelaySeconds: playFrameIntervalSeconds, metadata: metadata) else { return }
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
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            try? jpegData.write(to: url)
        }
    }
    #endif

    private func loadRandom(source: String) async {
        randomLoading = source
        defer { randomLoading = nil }
        let (text, _) = await fetchRandomTextWithFallback(source: source)
        if let text = text {
            fonster.randomSource = source
            fonster.pushHistoryAndSetSeed(text)
        }
    }

    private func refreshRandom() async {
        guard let source = fonster.randomSource else { return }
        randomLoading = source
        defer { randomLoading = nil }
        let (text, _) = await fetchRandomTextWithFallback(source: source)
        if let text = text {
            fonster.pushHistoryAndSetSeed(text)
        }
    }

    private func prependRandom(source: String) async {
        randomLoading = source
        defer { randomLoading = nil }
        let (text, _) = await fetchRandomTextWithFallback(source: source)
        if let text = text {
            fonster.randomSource = source
            let newSeed = text.trimmingCharacters(in: .whitespaces) + " " + fonster.seed
            fonster.pushHistoryAndSetSeed(newSeed)
            seedText = fonster.seed
        }
    }

    #if os(macOS) || os(iOS)
    private func copySourceToPasteboard() {
        let text = fonster.seed
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
    #endif
}

// MARK: - Edit View (iOS only)

#if os(iOS)
struct FonsterEditView: View {
    @Bindable var fonster: Fonster
    var onShare: (Fonster) -> Void
    var onShareImage: (() -> Void)? = nil
    var onShareGIF: (() async -> Void)? = nil
    @State private var seedText: String = ""
    @State private var randomLoading: String?
    @FocusState private var seedFocused: Bool
    @State private var seedWhenFocused: String?

    private let editCreatureSize: CGFloat = 80
    private let randomSources = ["quote", "words", "uuid", "lorem"]

    private var editViewTitle: String {
        let name = fonster.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Edit" : "Edit \(name)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    let displaySeed = fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : fonster.seed
                    TappableCreatureView(seed: displaySeed, size: editCreatureSize)
                        .frame(width: editCreatureSize, height: editCreatureSize)
                    TextField("Fonster name", text: $fonster.name)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                TextField("Type anything...", text: $seedText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
                    .focused($seedFocused)
                    .accessibilityLabel("Source text")
                    .onChange(of: seedText) { _, newValue in
                        fonster.seed = newValue
                    }
                    .onChange(of: seedFocused) { _, focused in
                        if focused {
                            seedWhenFocused = seedText
                        } else {
                            if let prev = seedWhenFocused, prev != seedText {
                                fonster.pushPreviousAndSetSeed(previous: prev, newSeed: seedText)
                            }
                            seedWhenFocused = nil
                        }
                    }
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Text("Get random:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(randomSources, id: \.self) { source in
                        Button {
                            Task { await loadRandom(source: source) }
                        } label: {
                            Image(systemName: randomSourceSymbol(for: source))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(randomLoading != nil)
                        .accessibilityLabel(randomSourceAccessibilityLabel(for: source))
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 6) {
                    Text("Birthday")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(creationDateOnlyString(from: fonster.createdAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(editViewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if onShareImage != nil, onShareGIF != nil {
                    Menu {
                        Button {
                            onShare(fonster)
                        } label: {
                            Label("Share link", systemImage: "link")
                        }
                        Button {
                            onShareImage?()
                        } label: {
                            Label("Share image", systemImage: "photo")
                        }
                        Button {
                            Task { await onShareGIF?() }
                        } label: {
                            Label("Share GIF", systemImage: "photo")
                        }
                        .disabled(fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                } else {
                    Button {
                        onShare(fonster)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            seedText = fonster.seed
        }
        .onChange(of: fonster.seed) { _, newValue in
            if seedText != newValue { seedText = newValue }
        }
    }

    private func loadRandom(source: String) async {
        randomLoading = source
        defer { randomLoading = nil }
        let (text, _) = await fetchRandomTextWithFallback(source: source)
        if let text = text {
            fonster.randomSource = source
            fonster.pushHistoryAndSetSeed(text)
            seedText = fonster.seed
        }
    }

    private func randomSourceSymbol(for source: String) -> String {
        switch source {
        case "quote": return "quote.bubble"
        case "words": return "text.word.spacing"
        case "uuid": return "number"
        case "lorem": return "doc.text"
        default: return "questionmark.circle"
        }
    }

    private func randomSourceAccessibilityLabel(for source: String) -> String {
        switch source {
        case "quote": return "Quote"
        case "words": return "Words"
        case "uuid": return "Random code"
        case "lorem": return "Sample text"
        default: return source
        }
    }
}
#endif

#if os(macOS) || os(tvOS)
/// Sheet for editing a Fonster's name (macOS and tvOS).
struct EditFonsterNameSheet: View {
    @Binding var name: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Fonster name", text: $name)
                #if os(tvOS)
                .textFieldStyle(.plain)
                #else
                .textFieldStyle(.roundedBorder)
                #endif
                .focused($nameFocused)
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                #if os(macOS)
                .keyboardShortcut(.defaultAction)
                #endif
            }
        }
        .padding(24)
        #if os(macOS)
        .frame(minWidth: 280)
        #endif
        .onAppear { nameFocused = true }
    }
}
#endif

#if os(tvOS)
/// Sheet for editing a Fonster's source/seed text on tvOS. Uses TextField (TextEditor is unavailable on tvOS).
struct EditFonsterSeedSheet: View {
    @Binding var seedText: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var seedFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Source text")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Type anything...", text: $seedText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...12)
                .focused($seedFocused)
                .frame(minHeight: 120)
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .onAppear { seedFocused = true }
    }
}
#endif

// MARK: - Helpers (file-private; used by ContentView and FonsterDetailView)

/// Formatted creation date (date only, no time) for display e.g. "Feb 4, 2025".
private func creationDateOnlyString(from date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    f.timeZone = TimeZone.current
    return f.string(from: date)
}

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

/// Birthday as spelled month and day (e.g. "February 4") from a date.
private func birthdayMonthDayString(from date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMM d", options: 0, locale: Locale.current)
    f.timeZone = TimeZone.current
    return f.string(from: date)
}

private func seedMetadata(seed: String, createdAtISO8601: String?, createdAt: Date) -> [String: Any] {
    let trimmed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
    var tiffDict: [String: Any] = [
        kCGImagePropertyTIFFDateTime as String: tiffDateTime(from: createdAt),
    ]
    let birthdayStr = birthdayMonthDayString(from: createdAt)
    if !birthdayStr.isEmpty {
        tiffDict[kCGImagePropertyTIFFImageDescription as String] = trimmed.isEmpty ? "Birthday: \(birthdayStr)" : "\(trimmed)\nBirthday: \(birthdayStr)"
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

/// Horizontal flow layout that lets subviews keep their intrinsic width and wrap when space runs out.
private struct WrapLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude

        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        let measureProposal = ProposedViewSize(width: nil, height: nil)
        for subview in subviews {
            let size = subview.sizeThatFits(measureProposal)
            if rowWidth > 0 && rowWidth + spacing + size.width > maxWidth {
                totalWidth = max(totalWidth, rowWidth)
                totalHeight += rowHeight + lineSpacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = rowWidth == 0 ? size.width : rowWidth + spacing + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalWidth = max(totalWidth, rowWidth)
        totalHeight += rowHeight

        if let proposedWidth = proposal.width {
            totalWidth = proposedWidth
        }

        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        let measureProposal = ProposedViewSize(width: nil, height: nil)
        for subview in subviews {
            let size = subview.sizeThatFits(measureProposal)
            if x != bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PendingImportURLHolder())
        .modelContainer(for: Fonster.self, inMemory: true)
}
