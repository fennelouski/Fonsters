#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI

/// Separate from native biography/public chips. Only canonical private IDs reach
/// the account service; draft queries and provider display data stay in memory.
struct FonsterPrivateInterestsView: View {
    let client: FonsterAccountClient
    @Environment(\.scenePhase) private var phase
    @State private var query = ""
    @State private var category = FonsterInterestCategory.movies
    @State private var results: [FonsterInterestEntity] = []
    @State private var selections: [FonsterAccountClient.Selection] = []
    @State private var revision: Int?
    @State private var message = ""
    @State private var loading = false
    @State private var work = FonsterAccountTaskState()
    private var busy: Bool { work.busy }
    @State private var saving = false
    @State private var saveTask: Task<Void, Never>?
    private var searchKey: String { category.rawValue + ":" + query + ":" + String(phase == .active) }
    var body: some View {
        List {
            Section {
                Text("These interests belong only to your private hosted account. Provider identification does not approve an item for children or public sharing.")
                Picker("Category", selection: $category) {
                    ForEach(FonsterInterestCategory.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0) }
                }
                TextField("Find a private interest", text: $query)
                    .onChange(of: query) { _, value in if value.utf16.count > 128 { query = String(value.prefix(128)) } }
                if loading { ProgressView("Finding source records…") }
                ForEach(results) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.title).font(.headline)
                        Text(record.summary)
                        Text("Source: " + record.source).font(.caption)
                        Text(record.url.absoluteString).font(.caption).textSelection(.enabled)
                        Button(selected(record) ? "Remove private selection" : "Select privately") { toggle(record) }
                            .disabled(revision == nil || busy || (!selected(record) && selections.count >= 32))
                    }
                }
            }
            Section("Saved private selections") {
                ForEach(selections, id: \.self) { selection in
                    HStack {
                        Text(selection.category.capitalized + " · private source record")
                        Spacer()
                        Button("Remove") { selections.removeAll { $0 == selection } }.disabled(busy || revision == nil)
                    }
                }
                Text("Saved source details may need revalidation after the provider cache expires. Unresolved records cannot be used in public sharing.").font(.footnote)
                Button("Save private selections") { save() }.disabled(busy || revision == nil)
                if saving { ProgressView("Saving…") }
                if !message.isEmpty { Text(message) }
            }
        }
        .navigationTitle("Private interests")
        .task(id: phase) {
            guard phase == .active else { return }
            revision = nil
            await work.reload(load: {
                let data = try await client.exportAccount()
                return try JSONDecoder().decode(FonsterAccountClient.Archive.self, from: data)
            }, apply: { archive in
                selections = archive.selections; revision = archive.account.revision; message = ""
            }, failed: { _ in
                message = "Private interests are unavailable. Sign in again or try later."
            })
        }
        .task(id: searchKey) {
            results = []; loading = false
            guard phase == .active, query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return }
            do {
                try await Task.sleep(for: .milliseconds(300)); loading = true
                let resolver = try await client.privateInterestResolver()
                let records = try await resolver.resolve(query, category: category)
                try Task.checkCancellation(); results = records; loading = false
            } catch is CancellationError {} catch {
                guard !Task.isCancelled, phase == .active else { return }
                loading = false; message = "Search is unavailable. Your saved selections are unchanged."
            }
        }
        .onChange(of: phase) { _, phase in if phase != .active { work.invalidate(); revision = nil; query = ""; results = []; loading = false; saveTask?.cancel() } }
        .onDisappear { work.invalidate(); revision = nil; query = ""; results = []; loading = false; saveTask?.cancel() }
    }
    private func selected(_ record: FonsterInterestEntity) -> Bool {
        guard let id = UUID(uuidString: record.id) else { return false }
        return selections.contains(.init(id: id, category: category.rawValue))
    }
    private func toggle(_ record: FonsterInterestEntity) {
        guard revision != nil, !busy, let id = UUID(uuidString: record.id) else { return }
        let selection = FonsterAccountClient.Selection(id: id, category: category.rawValue)
        if selections.contains(selection) { selections.removeAll { $0 == selection } }
        else if selections.count < 32 { selections.append(selection) }
    }
    private func save() {
        guard phase == .active, let revision, let ticket = work.begin() else { return }
        saving = true; message = ""
        let draft = selections
        saveTask = Task { @MainActor in
            defer { work.finish(ticket); saving = false; saveTask = nil }
            do {
                let savedRevision = try await client.saveSelections(draft, revision: revision)
                if work.accepts(ticket) { self.revision = savedRevision; message = "Private selections saved." }
            } catch {
                guard work.accepts(ticket) else { return }
                if error as? FonsterAccountClient.Failure == .conflict {
                    self.revision = nil; message = "Selections changed on another device. Reopen this page before saving."
                } else if error is CancellationError {
                    message = "Save cancelled. Reopen this page to check the latest selections."
                } else { message = "Selections could not be saved. No public sharing was enabled." }
            }
        }
    }
}
#endif
