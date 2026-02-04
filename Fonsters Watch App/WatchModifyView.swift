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

    var body: some View {
        List {
            Section("Get random") {
                Button("Random") {
                    let seed = watchLocalRandomSeed()
                    fonster.randomSource = nil
                    fonster.pushHistoryAndSetSeed(seed)
                }
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

