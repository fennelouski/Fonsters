//
//  FonstersApp.swift
//  Fonsters
//
//  App entry point. Configures SwiftData with the Fonster model and presents
//  the main Master–Detail content view.
//
//  Supported platforms: iOS, macOS, visionOS (as built by the current scheme).
//  See DOCUMENTATION.md for what works on each platform.
//

import SwiftUI
import SwiftData
import CloudKit
import Combine
#if canImport(Tips)
import Tips
#endif

/// The task-local preview bundle always uses memory-only data, even when double-clicked.
private var isPlayroomPrototype: Bool {
    #if os(macOS)
    return ProcessInfo.processInfo.arguments.contains("--prototype") ||
        Bundle.main.bundleIdentifier == "com.nathanfennel.Fonsters.Playroom"
    #elseif os(iOS) || os(tvOS)
    return ProcessInfo.processInfo.arguments.contains("--prototype")
    #else
    return false
    #endif
}

/// Holds a URL that was used to open the app (custom scheme or universal link); ContentView consumes it and imports seeds.
final class PendingImportURLHolder: ObservableObject {
    @Published var url: URL?
}

#if os(macOS)
/// Actions provided by ContentView so the macOS menu bar can show and trigger keyboard shortcuts.
struct FonstersMenuActions {
    var addFonster: () -> Void
    var shareCurrentFonster: () -> Void
    var selectFonsterAt: (Int) -> Void
    var selectPreviousFonster: () -> Void
    var selectNextFonster: () -> Void
    var toggleSidebar: () -> Void
}

private struct FonstersMenuActionsKey: FocusedValueKey {
    typealias Value = FonstersMenuActions
}

extension FocusedValues {
    var fonstersMenuActions: FonstersMenuActions? {
        get { self[FonstersMenuActionsKey.self] }
        set { self[FonstersMenuActionsKey.self] = newValue }
    }
}

private struct FonstersCommands: Commands {
    @FocusedValue(\.fonstersMenuActions) private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Fonster") {
                actions?.addFonster()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(actions == nil)
        }
        CommandGroup(after: .sidebar) {
            Button("Show/Hide Sidebar") {
                actions?.toggleSidebar()
            }
            .keyboardShortcut(KeyEquivalent("`"), modifiers: [.command, .option])
            .disabled(actions == nil)
        }
        CommandMenu("Fonsters") {
            Button("Share Current Fonster") {
                actions?.shareCurrentFonster()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(actions == nil)
            Divider()
            Button("Previous Fonster") {
                actions?.selectPreviousFonster()
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(actions == nil)
            Button("Next Fonster") {
                actions?.selectNextFonster()
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(actions == nil)
            Divider()
            Group {
                Button("Go to 1st Fonster") { actions?.selectFonsterAt(1) }
                    .keyboardShortcut("1", modifiers: .command)
                    .disabled(actions == nil)
                Button("Go to 2nd Fonster") { actions?.selectFonsterAt(2) }
                    .keyboardShortcut("2", modifiers: .command)
                    .disabled(actions == nil)
                Button("Go to 3rd Fonster") { actions?.selectFonsterAt(3) }
                    .keyboardShortcut("3", modifiers: .command)
                    .disabled(actions == nil)
                Button("Go to 4th Fonster") { actions?.selectFonsterAt(4) }
                    .keyboardShortcut("4", modifiers: .command)
                    .disabled(actions == nil)
                Button("Go to 5th Fonster") { actions?.selectFonsterAt(5) }
                    .keyboardShortcut("5", modifiers: .command)
                    .disabled(actions == nil)
                Button("Go to 6th Fonster") { actions?.selectFonsterAt(6) }
                    .keyboardShortcut("6", modifiers: .command)
                    .disabled(actions == nil)
                Button("Go to 7th Fonster") { actions?.selectFonsterAt(7) }
                    .keyboardShortcut("7", modifiers: .command)
                    .disabled(actions == nil)
                Button("Go to 8th Fonster") { actions?.selectFonsterAt(8) }
                    .keyboardShortcut("8", modifiers: .command)
                    .disabled(actions == nil)
                Button("Go to 9th Fonster") { actions?.selectFonsterAt(9) }
                    .keyboardShortcut("9", modifiers: .command)
                    .disabled(actions == nil)
                Button("Go to 10th Fonster") { actions?.selectFonsterAt(10) }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(actions == nil)
            }
        }
    }
}
#endif

@main
struct FonstersApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(ShakeListenerAppDelegate.self) private var appDelegate
    #endif
    @StateObject private var pendingImportURL = PendingImportURLHolder()
    @StateObject private var featureFlags = FeatureFlagStore(
        remoteProvider: FeatureFlagBackendConfiguration.backendURL().map { HTTPFeatureFlagRemoteProvider(url: $0) } ?? NoOpFeatureFlagRemoteProvider()
    )
    @State private var loadingComplete = false

    init() {
        RandomTextFallbacks.registerDefaults()
        #if canImport(Tips)
        do {
            try Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        } catch {
            #if DEBUG
            NSLog("Fonsters: TipKit configuration failed: \(error)")
            #endif
        }
        #endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Fonster.self,
        ])
        #if os(macOS) || os(iOS) || os(tvOS)
        if isPlayroomPrototype {
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "--library-store"), index + 1 < args.count {
                let url = URL(fileURLWithPath: args[index + 1])
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                return try! ModelContainer(for: schema, configurations: [ModelConfiguration("PersonalPreview", schema: schema, url: url, cloudKitDatabase: .none)])
            }
            return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        }
        #endif
        // Only use CloudKit when an iCloud account is available; otherwise we get
        // "Unable to initialize without an iCloud account" and mirroring errors in the console.
        var useCloudKit = false
        let semaphore = DispatchSemaphore(value: 0)
        CKContainer.default().accountStatus { status, _ in
            useCloudKit = (status == .available)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.0)

        if useCloudKit {
            let cloudKitConfig = ModelConfiguration(
                "Synced",
                schema: schema,
                cloudKitDatabase: .automatic
            )
            do {
                return try ModelContainer(for: schema, configurations: [cloudKitConfig])
            } catch {
                #if DEBUG
                NSLog("Fonsters: CloudKit ModelContainer failed (\(error)); using local-only container.")
                #endif
                // Fall through to local-only.
            }
        }

        let localConfig = ModelConfiguration(
            "Local",
            schema: schema,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private var nativeAnimatedLaunch: Bool {
        #if os(macOS) || os(iOS)
        return !ProcessInfo.processInfo.arguments.contains("--original-gallery")
        #else
        return false
        #endif
    }
    var body: some Scene {
        WindowGroup {
            if isPlayroomPrototype {
                #if os(macOS)
                if #available(macOS 15.0, *) {
                    if ProcessInfo.processInfo.arguments.contains("--legacy-playroom") { ParentOnlyArea(purpose: "Open the original playroom and its export controls.") { PlayroomView() } }
                    else if ProcessInfo.processInfo.arguments.contains("--legacy-world") { ParentOnlyArea(purpose: "Open the original local world and its experimental tools.") { LocalLobbyView() } }
                    else { ContinuousLobbyView().environmentObject(pendingImportURL).environmentObject(featureFlags).onOpenURL { pendingImportURL.url = $0 } }
                }
                else { Text("The Playroom requires macOS 15 or later.") }
                #elseif os(iOS)
                Group {
                    if ProcessInfo.processInfo.arguments.contains("--legacy-world") { ParentOnlyArea(purpose: "Open the original mobile lobby and exports.") { MobileLobbyView() } }
                    else if ProcessInfo.processInfo.arguments.contains("--legacy-playroom") { ParentOnlyArea(purpose: "Open the original gallery and portrait exports.") { MobileFonstersHome() } }
                    else { ContinuousLobbyView() }
                }.environmentObject(pendingImportURL).environmentObject(featureFlags)
                    .onOpenURL { url in pendingImportURL.url = url }
                #elseif os(tvOS)
                if #available(tvOS 26.0, *) { TelevisionFonstersHome().environmentObject(pendingImportURL).environmentObject(featureFlags) }
                else { ParentOnlyArea(purpose: "Review original seed links, imports and portrait exports before sharing outside Fonsters.") { ContentView() }.environmentObject(pendingImportURL).environmentObject(featureFlags) }
                #else
                ParentOnlyArea(purpose: "Review original seed links, imports and portrait exports before sharing outside Fonsters.") { ContentView() }.environmentObject(pendingImportURL).environmentObject(featureFlags)
                #endif
            } else if loadingComplete || nativeAnimatedLaunch {
                #if os(iOS)
                Group {
                    if ProcessInfo.processInfo.arguments.contains("--original-gallery") { ParentOnlyArea(purpose: "Review original seed links, imports and portrait exports before sharing outside Fonsters.") { ContentView() } }
                    else { ContinuousLobbyView() }
                }
                    .task { featureFlags.refreshFromRemote() }
                    .environmentObject(pendingImportURL)
                    .environmentObject(featureFlags)
                    .onOpenURL { url in pendingImportURL.url = url }
                #elseif os(tvOS)
                Group {
                    if #available(tvOS 26.0, *) { TelevisionFonstersHome() }
                    else { ParentOnlyArea(purpose: "Review original seed links, imports and portrait exports before sharing outside Fonsters.") { ContentView() } }
                }.environmentObject(pendingImportURL).environmentObject(featureFlags)
                    .task { featureFlags.refreshFromRemote() }
                #elseif os(macOS)
                Group {
                    if #available(macOS 15.0, *), !ProcessInfo.processInfo.arguments.contains("--original-gallery") { ContinuousLobbyView() }
                    else { ParentOnlyArea(purpose: "Review original seed links, imports and portrait exports before sharing outside Fonsters.") { ContentView() } }
                }
                    .environmentObject(pendingImportURL)
                    .environmentObject(featureFlags)
                    .task { featureFlags.refreshFromRemote() }
                    .onOpenURL { pendingImportURL.url = $0 }
                #else
                ParentOnlyArea(purpose: "Review original seed links, imports and portrait exports before sharing outside Fonsters.") { ContentView() }
                    .environmentObject(pendingImportURL)
                    .environmentObject(featureFlags)
                    .task { featureFlags.refreshFromRemote() }
                    #if !os(tvOS) && !os(visionOS)
                    .onOpenURL { url in
                        pendingImportURL.url = url
                    }
                    #endif
                #endif
            } else {
                LoadingView(onComplete: { loadingComplete = true })
            }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1080, height: 740)
        #endif
        #if os(macOS)
        .commands {
            FonstersCommands()
            PlayroomCommands()
        }
        #endif
        #if os(macOS)
        Window("Fonsters Playroom", id: "playroom") {
            if #available(macOS 15.0, *) {
                ParentOnlyArea(purpose: "Open the original playroom and its export controls.") { PlayroomView() }
            } else { Text("The Playroom requires macOS 15 or later.") }
        }
        .defaultSize(width: 1080, height: 740)
        Window("Fonsters Lobby", id: "lobby") {
            if #available(macOS 15.0, *) { ParentOnlyArea(purpose: "Open the original local world and its experimental tools.") { LocalLobbyView() } }
            else { Text("The local lobby requires macOS 15 or later.") }
        }
        .defaultSize(width: 1080, height: 740)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}

#if os(macOS)
private struct PlayroomCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandMenu("Playroom") {
            Button("Meet the 3D Fonsters") { openWindow(id: "playroom") }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Button("Open the local lobby") { openWindow(id: "lobby") }
                .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}
#endif
