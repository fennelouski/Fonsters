//
//  WatchModifyView.swift
//  Fonsters Watch App
//
//  Screen 3: Modify seed – load random (local only) or simple actions.
//  On watchOS we don’t call the API; users can’t see the source. We generate
//  a random seed from 4 UUIDs with a random number between each for variety.
//

import SwiftUI
import SwiftData

/// Generates a random seed locally: 4 UUIDs with a random number between each. No API call.
private func watchLocalRandomSeed() -> String {
    let uuids = (0..<4).map { _ in UUID().uuidString }
    let numbers = (0..<3).map { _ in UInt64.random(in: 0...UInt64.max) }
    return [
        uuids[0], String(numbers[0]), uuids[1], String(numbers[1]), uuids[2], String(numbers[2]), uuids[3]
    ].joined(separator: " ")
}

struct WatchModifyView: View {
    @Bindable var fonster: Fonster
    @Environment(\.dismiss) private var dismiss
    @State private var showsHelp = false

    var body: some View {
        List {
            Section("Get random") {
                Button {
                    let seed = watchLocalRandomSeed()
                    fonster.randomSource = nil
                    fonster.pushHistoryAndSetSeed(seed)
                } label: { Image(systemName: "shuffle") }
                    .help("New random appearance; Undo restores the previous one").accessibilityLabel("Random appearance")
                Button { _ = fonster.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .help("Restore the previous appearance").accessibilityLabel("Undo appearance").disabled(fonster.history.isEmpty)
                Button { _ = fonster.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .help("Restore the appearance you undid").accessibilityLabel("Redo appearance").disabled(fonster.future.isEmpty)
                Button { showsHelp = true } label: { Image(systemName: "questionmark.circle") }
                    .help("Explain these controls").accessibilityLabel("Appearance help")
            }
        }
        .sheet(isPresented: $showsHelp) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Shuffle creates a new appearance locally. Undo restores the previous source and portrait; Redo brings the change back.", systemImage: "shuffle")
                    Button { showsHelp = false } label: { Image(systemName: "xmark") }.help("Close help").accessibilityLabel("Close help")
                }.padding()
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

