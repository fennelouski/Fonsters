//
//  WatchModifyView.swift
//  Fonsters Watch App
//
//  Screen 3: Modify seed – load random (Words/UUID) or simple actions.
//

import SwiftUI
import SwiftData

struct WatchModifyView: View {
    @Bindable var fonster: Fonster
    @Environment(\.dismiss) private var dismiss
    @State private var loadingSource: String?

    var body: some View {
        List {
            Section("Load random") {
                ForEach(["words", "uuid"], id: \.self) { source in
                    Button(source.capitalized) {
                        Task { await loadRandom(source: source) }
                    }
                    .disabled(loadingSource != nil)
                    if loadingSource == source {
                        HStack {
                            ProgressView()
                            Text("Loading…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Modify")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadRandom(source: String) async {
        loadingSource = source
        defer { loadingSource = nil }
        guard let text = await fetchRandomText(source: source) else { return }
        fonster.randomSource = source
        fonster.pushHistoryAndSetSeed(text)
    }
}

private func fetchRandomText(source: String) async -> String? {
    let urlString = "https://nathanfennel.com/api/creature-avatar/random-text?source=\(source.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? source)"
    guard let url = URL(string: urlString) else { return nil }
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["text"] as? String
    } catch {
        return nil
    }
}
