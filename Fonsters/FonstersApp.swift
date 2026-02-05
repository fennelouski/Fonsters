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
        }
        CommandGroup(after: .sidebar) {
            Button("Show/Hide Sidebar") {
                actions?.toggleSidebar()
            }
            .keyboardShortcut(KeyEquivalent("`"), modifiers: [.command, .option])
        }
        CommandMenu("Fonsters") {
            Button("Share Current Fonster") {
                actions?.shareCurrentFonster()
            }
            .keyboardShortcut("p", modifiers: .command)
            Divider()
            Button("Previous Fonster") {
                actions?.selectPreviousFonster()
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            Button("Next Fonster") {
                actions?.selectNextFonster()
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            Divider()
            Group {
                Button("Go to 1st Fonster") { actions?.selectFonsterAt(1) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Go to 2nd Fonster") { actions?.selectFonsterAt(2) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Go to 3rd Fonster") { actions?.selectFonsterAt(3) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Go to 4th Fonster") { actions?.selectFonsterAt(4) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("Go to 5th Fonster") { actions?.selectFonsterAt(5) }
                    .keyboardShortcut("5", modifiers: .command)
                Button("Go to 6th Fonster") { actions?.selectFonsterAt(6) }
                    .keyboardShortcut("6", modifiers: .command)
                Button("Go to 7th Fonster") { actions?.selectFonsterAt(7) }
                    .keyboardShortcut("7", modifiers: .command)
                Button("Go to 8th Fonster") { actions?.selectFonsterAt(8) }
                    .keyboardShortcut("8", modifiers: .command)
                Button("Go to 9th Fonster") { actions?.selectFonsterAt(9) }
                    .keyboardShortcut("9", modifiers: .command)
                Button("Go to 10th Fonster") { actions?.selectFonsterAt(10) }
                    .keyboardShortcut("0", modifiers: .command)
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

    var body: some Scene {
        WindowGroup {
            if loadingComplete {
                ContentView()
                    .environmentObject(pendingImportURL)
                    .environmentObject(featureFlags)
                    .task { featureFlags.refreshFromRemote() }
                    #if !os(tvOS) && !os(visionOS)
                    .onOpenURL { url in
                        pendingImportURL.url = url
                    }
                    #endif
            } else {
                LoadingView(onComplete: { loadingComplete = true })
            }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            FonstersCommands()
        }
        #endif
    }
}
