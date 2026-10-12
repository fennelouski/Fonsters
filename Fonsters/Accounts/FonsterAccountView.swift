#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI
import UniformTypeIdentifiers

/// This screen is usable with an injected reviewed client. The shipped protected
/// screen supplies none and cannot start identity, storage or network work.
struct FonsterAccountView: View {
    var client: FonsterAccountClient? = nil
    var identity: FonsterAccountClient.Identity? = nil
    @State private var account: FonsterAccountClient.Account?
    @State private var busy = false
    @State private var message = ""
    @State private var confirmDelete = false
    @State private var export: FonsterAccountExport?
    @State private var exporting = false
    @Environment(\.scenePhase) private var phase
    @State private var operation: Task<Void, Never>?
    var body: some View {
        List {
            Section {
                Label("Private account", systemImage: "person.crop.circle.badge.checkmark")
                Text("Protected play and your private iCloud creature library work without a Fonsters account. Public profiles and social sharing remain unavailable.")
            }
            if client == nil {
                Section {
                    Text("Hosted accounts are not available in this release. No sign-in or personal information is requested.")
                }
            } else if account != nil {
                Section("Your account") {
                    if let client { NavigationLink("Private interests") { FonsterPrivateInterestsView(client: client) } }
                    Button("Export private account data") { perform { client in export = FonsterAccountExport(data: try await client.exportAccount()); exporting = true } }
                    Button("Sign out") { perform { client in account = nil; try await client.signOut() } }
                    if identity != nil { Button("Sign in again") { signIn() } }
                    Button("Delete hosted account", role: .destructive) { confirmDelete = true }
                    Text("Deletion removes the hosted account and private interest selections. Your local creature library, iCloud library and copies previously shared with others are separate.").font(.footnote)
                }.disabled(busy)
            } else {
                Section {
                    Button("Sign in with Apple") { signIn() }.disabled(busy || identity == nil)
                    Text("Hosted accounts are for verified adults only. Children and teens keep private local play. A reviewed adult eligibility check is required separately from Apple identity. A grown-up task does not unlock accounts.").font(.footnote)
                }
            }
            if busy { ProgressView("Working…"); Button("Cancel") { operation?.cancel() } }
            if !message.isEmpty { Text(message).accessibilityIdentifier("accountResult") }
        }
        .navigationTitle("Private account")
        .task(id: phase) { guard phase == .active, let client else { return }; // A foreground transition may arrive before a cancelled operation
            // unwinds. Wait cancellably, then reload instead of skipping it.
            do { while busy { try await Task.sleep(for: .milliseconds(30)) }; try Task.checkCancellation() }
            catch { return }
            busy = true
            defer { busy = false }
            do { let current = try await client.currentAccount(); try Task.checkCancellation(); if phase == .active { account = current } }
            catch is CancellationError {} catch { if phase == .active { message = Self.message(error) } } }
        .onDisappear { operation?.cancel(); export = nil }
        .onChange(of: phase) { _, phase in if phase != .active { operation?.cancel(); export = nil; exporting = false } }
        .confirmationDialog("Delete hosted account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete hosted account", role: .destructive) { perform { client in
                let pending = try await client.deleteAccount(); account = nil
                message = pending ? "Account access is blocked. Provider cleanup is pending; the service will retry." : "Hosted account deleted."
            } }
            Button("Cancel", role: .cancel) {}
        }
        .fileExporter(isPresented: $exporting, document: export, contentType: .json, defaultFilename: "Fonsters-private-account") { result in
            export = nil
            if case .failure = result { message = "The export was not saved. You can try again." }
        }
    }
    private func signIn() {
        perform { client in
            guard let identity else { return }
            account = nil
            try await client.signIn(identity: { nonce in try await identity(nonce) })
            account = try await client.currentAccount()
        }
    }
    private func perform(_ action: @escaping @MainActor (FonsterAccountClient) async throws -> Void) {
        guard !busy, let client else { return }
        busy = true; message = ""
        operation = Task { @MainActor in
            defer { busy = false; operation = nil }
            do { try await action(client) }
            catch { message = Self.message(error); if error as? FonsterAccountClient.Failure == .signedOut { account = nil } }
        }
    }
    private static func message(_ error: Error) -> String {
        if error is CancellationError { return "Cancelled. You can try again." }
        switch error as? FonsterAccountClient.Failure {
        case .reauthenticate: return "Sign in again before deleting your account."
        case .signedOut: return "Your session ended. Sign in again to continue."
        case .protectedExperience: return "Hosted accounts are unavailable. You can keep playing locally."
        case .conflict: return "Your private selections changed. Reload before saving again."
        default: return "The account service is unavailable. Try again later."
        }
    }
}
struct FonsterAccountExport: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
#endif
