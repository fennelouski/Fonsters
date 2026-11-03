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
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
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
    #if os(macOS)
    @NSApplicationDelegateAdaptor(FonstersMacDelegate.self) private var macDelegate
    #endif
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
            Group {
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
            #if os(macOS)
            .background(FonstersWindowChrome())
            .overlay(alignment: .top) { if #available(macOS 15.0, *) { FonstersWindowHandle() } }
            #endif
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1080, height: 740)
        .windowStyle(.hiddenTitleBar)
        #endif
        #if os(macOS)
        .commands {
            FonstersSearchCommands()
            FonstersCommands()
            PlayroomCommands()
            FonstersWindowCommands()
        }
        #endif
        #if os(macOS)
        Window("Fonsters Playroom", id: "playroom") {
            Group {
                if #available(macOS 15.0, *) {
                    ParentOnlyArea(purpose: "Open the original playroom and its export controls.") { PlayroomView() }
                } else { Text("The Playroom requires macOS 15 or later.") }
            }.background(FonstersWindowChrome())
                .overlay(alignment: .top) { if #available(macOS 15.0, *) { FonstersWindowHandle() } }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1080, height: 740)
        Window("Fonsters Lobby", id: "lobby") {
            Group {
                if #available(macOS 15.0, *) { ParentOnlyArea(purpose: "Open the original local world and its experimental tools.") { LocalLobbyView() } }
                else { Text("The local lobby requires macOS 15 or later.") }
            }.background(FonstersWindowChrome())
                .overlay(alignment: .top) { if #available(macOS 15.0, *) { FonstersWindowHandle() } }
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

#if os(macOS)
private final class FonstersMacDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

private struct FonstersWindowCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button("Toggle Full Screen") { (NSApp.keyWindow ?? NSApp.mainWindow)?.toggleFullScreen(nil) }
                .keyboardShortcut("f", modifiers: [.command, .shift])
        }
    }
}

/// Retain the standard resizable/full-screen NSWindow, while removing its
/// title chrome. SwiftUI's hiddenTitleBar alone still exposes traffic lights.
private struct FonstersWindowChrome: NSViewRepresentable {
    final class Anchor: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            if window.title.isEmpty { window.title = "Fonsters" }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar = nil
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
        }
    }
    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ nsView: Anchor, context: Context) {}
}

@available(macOS 15.0, *)
private struct FonstersWindowHandle: View {
    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(.secondary.opacity(0.45)).frame(width: 52, height: 5)
                .frame(width: 100, height: 28).contentShape(Rectangle())
                .gesture(WindowDragGesture()).allowsWindowActivationEvents(true)
                .help("Drag to move the window")
                .accessibilityLabel("Move Fonsters window")
            Button { NSApp.keyWindow?.performClose(nil) } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).frame(width: 28, height: 28)
            }.buttonStyle(.plain).help("Close window (Command-W)").accessibilityLabel("Close window")
        }.foregroundStyle(.secondary).padding(.horizontal, 8)
            .background(.regularMaterial, in: Capsule()).padding(.top, 7)
    }
}
#endif

#if os(macOS) || os(iOS)
extension Notification.Name {
    static let fonstersSearchDismissRequested = Notification.Name("Fonsters.searchDismissRequested")
    static let fonstersSearchRequested = Notification.Name("Fonsters.searchRequested")
}
#endif
#if os(macOS)
private struct FonstersSearchCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Search Fonsters, Interests and Memories") {
                NotificationCenter.default.post(name: .fonstersSearchRequested, object: NSApp.keyWindow ?? NSApp.mainWindow)
            }.keyboardShortcut("f", modifiers: .command)
        }
    }
}
/// Weak ownership routes Mac menu commands to exactly one native scene.
@MainActor final class FonstersSearchWindowOwner { weak var window: NSWindow? }
struct FonstersSearchWindowAnchor: NSViewRepresentable {
    let owner: FonstersSearchWindowOwner
    final class Anchor: NSView {
        var owner: FonstersSearchWindowOwner?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); owner?.window = window }
    }
    func makeNSView(context: Context) -> Anchor { let view = Anchor(); view.owner = owner; return view }
    func updateNSView(_ view: Anchor, context: Context) { view.owner = owner; owner.window = view.window }
}
#endif

#if os(iOS)
@MainActor final class FonstersMobileSearchWindowOwner { weak var window: UIWindow? }
/// Register commands on the actual root responder, without replacing the
/// SwiftUI hosting controller or taking focus from fields/camera navigation.
struct FonstersMobileKeyboardAnchor: UIViewRepresentable {
    let owner: FonstersMobileSearchWindowOwner
    let searching: Bool
    let mayOwnFocus: Bool
    let navigation: (UIKey, Bool) -> Bool
    final class Anchor: UIView {
        var owner: FonstersMobileSearchWindowOwner?
        var searching = false
        var mayOwnFocus = false
        var navigation: ((UIKey, Bool) -> Bool)?
        override var canBecomeFirstResponder: Bool { true }
        override var keyCommands: [UIKeyCommand]? { searching ? [find, cancel] : [find] }
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            if action == find.action || action == cancel.action { return true }
            return super.canPerformAction(action, withSender: sender)
        }
        private func forward(_ presses: Set<UIPress>, event: UIPressesEvent?, held: Bool, ending: Bool = false) {
            let unhandled = Set(presses.filter { press in
                guard let key = press.key else { return true }
                return navigation?(key, held) != true
            })
            if !unhandled.isEmpty {
                if ending { super.pressesEnded(unhandled, with: event) }
                else { super.pressesBegan(unhandled, with: event) }
            }
        }
        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) { forward(presses, event: event, held: true) }
        override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) { forward(presses, event: event, held: true) }
        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) { forward(presses, event: event, held: false, ending: true) }
        override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) { forward(presses, event: event, held: false, ending: true) }
        weak var installedRoot: UIViewController?
        var hasCancel = false
        let find = UIKeyCommand(input: "f", modifierFlags: .command, action: #selector(UIResponder.fonstersFindFromKeyboard(_:)))
        let cancel = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(UIResponder.fonstersCloseSearchFromKeyboard(_:)))
        override func didMoveToWindow() { super.didMoveToWindow(); install() }
        override func layoutSubviews() { super.layoutSubviews(); install() }
        func install() {
            owner?.window = window
            let root = window?.rootViewController
            if installedRoot !== root {
                removeCommands(); installedRoot = root
                find.discoverabilityTitle = "Search Fonsters, interests and memories"
                find.wantsPriorityOverSystemBehavior = true
                cancel.discoverabilityTitle = "Close search"
                cancel.wantsPriorityOverSystemBehavior = true
                root?.addKeyCommand(find)
            }
            if searching != hasCancel, let root {
                if searching { root.addKeyCommand(cancel) } else { root.removeKeyCommand(cancel) }
                hasCancel = searching
            }
            guard mayOwnFocus, !searching, root?.presentedViewController == nil,
                  window?.windowScene?.activationState == .foregroundActive else {
                if isFirstResponder { resignFirstResponder() }; return
            }
            func editing(_ view: UIView) -> Bool {
                if view.isFirstResponder && (view is UITextField || view is UITextView || view is UIControl) { return true }
                return view.subviews.contains(where: editing)
            }
            if let window, !isFirstResponder, !editing(window) { becomeFirstResponder() }
        }
        func removeCommands() {
            installedRoot?.removeKeyCommand(find); installedRoot?.removeKeyCommand(cancel)
            installedRoot = nil; hasCancel = false
        }
    }
    func makeUIView(context: Context) -> Anchor {
        let view = Anchor(); view.owner = owner; view.searching = searching; view.mayOwnFocus = mayOwnFocus; view.navigation = navigation; return view
    }
    func updateUIView(_ view: Anchor, context: Context) {
        view.owner = owner; view.searching = searching; view.mayOwnFocus = mayOwnFocus; view.navigation = navigation; view.install()
    }
    static func dismantleUIView(_ view: Anchor, coordinator: ()) {
        view.removeCommands()
    }
}

extension UIResponder {
    private var fonstersCommandScene: UIWindowScene? {
        if let window = self as? UIWindow, let scene = window.windowScene { return scene }
        if let view = self as? UIView, let scene = view.window?.windowScene { return scene }
        if let controller = self as? UIViewController, let scene = controller.viewIfLoaded?.window?.windowScene { return scene }
        return UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
    }
    @objc fileprivate func fonstersFindFromKeyboard(_ command: UIKeyCommand) {
        NotificationCenter.default.post(name: .fonstersSearchRequested, object: fonstersCommandScene)
    }
    @objc fileprivate func fonstersCloseSearchFromKeyboard(_ command: UIKeyCommand) {
        NotificationCenter.default.post(name: .fonstersSearchDismissRequested, object: fonstersCommandScene)
    }
}
#endif
