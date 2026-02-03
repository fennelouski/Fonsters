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
import Combine

/// Holds a URL that was used to open the app (custom scheme or universal link); ContentView consumes it and imports seeds.
final class PendingImportURLHolder: ObservableObject {
    @Published var url: URL?
}

@main
struct FonstersApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(ShakeListenerAppDelegate.self) private var appDelegate
    #endif
    @StateObject private var pendingImportURL = PendingImportURLHolder()
    @State private var loadingComplete = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Fonster.self,
        ])
        let modelConfiguration = ModelConfiguration(
            "Synced",
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if loadingComplete {
                ContentView()
                    .environmentObject(pendingImportURL)
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
    }
}
