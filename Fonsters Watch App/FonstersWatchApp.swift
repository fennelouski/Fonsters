//
//  FonstersWatchApp.swift
//  Fonsters Watch App
//
//  watchOS app: list of Fonsters, detail with creature image and Digital Crown
//  for evolution playback, and optional modify.
//

import SwiftUI
import SwiftData

@main
struct FonstersWatchApp: App {
    @StateObject private var featureFlags = FeatureFlagStore(remoteProvider: NoOpFeatureFlagRemoteProvider())
    @State private var loadingComplete = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Fonster.self])
        let config = ModelConfiguration(
            "Synced",
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
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
