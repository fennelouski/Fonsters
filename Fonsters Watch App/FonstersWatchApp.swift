//
//  FonstersWatchApp.swift
//  Fonsters Watch App
//
//  watchOS app: list of Fonsters, detail with creature image and Digital Crown
//  for evolution playback, and optional modify.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct FonstersWatchApp: App {
    @StateObject private var featureFlags = FeatureFlagStore(remoteProvider: NoOpFeatureFlagRemoteProvider())
    @State private var loadingComplete = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Fonster.self])
        var useCloudKit = false
        let semaphore = DispatchSemaphore(value: 0)
        CKContainer.default().accountStatus { status, _ in
            useCloudKit = (status == .available)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.0)

        if useCloudKit {
            let config = ModelConfiguration(
                "Synced",
                schema: schema,
                cloudKitDatabase: .automatic
            )
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
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
                WatchListView()
                    .environmentObject(featureFlags)
            } else {
                LoadingView(onComplete: { loadingComplete = true })
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
