#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI
import UniformTypeIdentifiers

/// This screen is usable with an injected reviewed client. The shipped protected
/// screen supplies none and cannot start identity, storage or network work.
struct FonsterAccountView: View {
    var client: FonsterAccountClient? = nil
    var identity: FonsterAccountClient.Identity? = nil
    @State private var account: FonsterAccountClient.Account?
    @State private var work = FonsterAccountTaskState()
    private var busy: Bool { work.busy }
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
                    Button("Export private account data") { perform({ try await $0.exportAccount() }) { data in export = FonsterAccountExport(data: data); exporting = true } }
                    Button("Sign out") { perform({ try await $0.signOut() }, prepare: { account = nil }) { _ in } }
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
        .task(id: phase) {
            guard phase == .active, let client else { return }
            await work.reload(load: { try await client.currentAccount() },
                              apply: { account = $0; message = "" },
                              failed: { error in
                                  message = Self.message(error)
                                  if error as? FonsterAccountClient.Failure == .signedOut { account = nil }
                              })
        }
        .onDisappear { work.invalidate(); operation?.cancel(); export = nil; exporting = false }
        .onChange(of: phase) { _, phase in
            if phase != .active { work.invalidate(); operation?.cancel(); export = nil; exporting = false }
        }
        .confirmationDialog("Delete hosted account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete hosted account", role: .destructive) { perform({ try await $0.deleteAccount() }) { pending in
                account = nil
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
        guard let identity else { return }
        perform({ client in
            try await client.signIn(identity: { nonce in try await identity(nonce) })
            return try await client.currentAccount()
        }, prepare: { account = nil }) { account = $0 }
    }
    private func perform<Value>(_ action: @escaping @MainActor (FonsterAccountClient) async throws -> Value,
                                prepare: @MainActor () -> Void = {},
                                apply: @escaping @MainActor (Value) -> Void) {
        guard phase == .active, let client, let ticket = work.begin() else { return }
        prepare(); message = ""
        operation = Task { @MainActor in
            defer { work.finish(ticket); operation = nil }
            do {
                let value = try await action(client)
                if work.accepts(ticket) { apply(value) }
            } catch {
                if work.accepts(ticket) {
                    message = Self.message(error)
                    if error as? FonsterAccountClient.Failure == .signedOut { account = nil }
                }
            }
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
