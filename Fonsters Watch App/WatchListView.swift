//
//  WatchListView.swift
//  Fonsters Watch App
//
//  Screen 1: List of Fonsters. Tap to open detail (creature + Digital Crown).
//  First row is virtual "Clock" (time-driven creature); rest are stored Fonsters.
//

import SwiftUI
import SwiftData

enum WatchListDestination: Hashable {
    case clock
    case fonster(UUID)
}

struct WatchListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Fonster.createdAt, order: .reverse) private var fonsters: [Fonster]
    @State private var hasPerformedLaunchSelectionCheck = false
    @State private var pendingDeleteOffsets: IndexSet?
    @State private var showDeleteConfirmation = false
    @State private var showsHelp = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: WatchListDestination.clock) {
                    HStack(spacing: 8) {
                        WatchCreatureView(seed: InstallationSeeds.currentTimeSeed(), size: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("Clock")
                            .lineLimit(1)
                    }
                }
                ForEach(fonsters) { fonster in
                    NavigationLink(value: WatchListDestination.fonster(fonster.id)) {
                        HStack(spacing: 8) {
                            WatchCreatureView(seed: fonster.seed, size: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(displayName(for: fonster))
                                .lineLimit(1)
                            if fonster.isBirthdayAnniversary {
                                Text("Birthday!")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteFonsters)
            }
            .navigationTitle("Fonsters")
            .navigationDestination(for: WatchListDestination.self) { destination in
                switch destination {
                case .clock:
                    ClockDetailView()
                case .fonster(let id):
                    if let fonster = fonsters.first(where: { $0.id == id }) {
                        WatchDetailView(fonster: fonster)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: addFonster) {
                        Image(systemName: "plus")
                    }.help("Add a Fonster").accessibilityLabel("Add a Fonster")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showsHelp = true } label: { Image(systemName: "questionmark.circle") }
                        .help("Explain the gallery controls").accessibilityLabel("Gallery help")
                }
            }
            .sheet(isPresented: $showsHelp) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Plus adds a portrait. Tap a portrait to visit it; Back returns to the list.", systemImage: "plus")
                        Label("Turn the Digital Crown to preview evolution. The pencil opens appearance controls with Undo and Redo.", systemImage: "pencil")
                        Label("Swipe to delete. Cancel keeps the portrait; confirmed deletion cannot be undone.", systemImage: "trash")
                        Button { showsHelp = false } label: { Image(systemName: "xmark") }.accessibilityLabel("Close help").help("Close help")
                    }.padding()
                }
            }
            .confirmationDialog(deleteConfirmationTitle, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Cancel", role: .cancel) {
                    pendingDeleteOffsets = nil
                }
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDeleteOffsets {
                        performDeleteFonsters(offsets: offsets)
                        pendingDeleteOffsets = nil
                    }
                }
            } message: {
                Text("This cannot be undone.")
            }
            .task {
                await seedInitialCreaturesIfNeeded()
                await ensureSelectionOnLaunch()
            }
        }
    }

    private func displayName(for fonster: Fonster) -> String {
        if !fonster.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return fonster.name
        }
        if !fonster.seed.trimmingCharacters(in: .whitespaces).isEmpty {
            let s = fonster.seed.trimmingCharacters(in: .whitespaces)
            return s.count > 20 ? String(s.prefix(17)) + "..." : s
        }
        return "Untitled"
    }

    private func addFonster() {
        withAnimation {
            let f = Fonster(name: InitialCreatureNames.oneName(), seed: InstallationSeeds.currentTimeSeed(), createdAtISO8601: Fonster.currentCreatedAtISO8601())
            modelContext.insert(f)
        }
    }

    private var deleteConfirmationTitle: String {
        guard let offsets = pendingDeleteOffsets else { return "Delete Fonster?" }
        return offsets.count == 1 ? "Delete Fonster?" : "Delete \(offsets.count) Fonsters?"
    }

    private func deleteFonsters(offsets: IndexSet) {
        pendingDeleteOffsets = offsets
        showDeleteConfirmation = true
    }

    private func performDeleteFonsters(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(fonsters[index])
            }
        }
    }

    private func seedInitialCreaturesIfNeeded() async {
        try? await PersonalFonsterLibrary.ensureStarters(in: modelContext)
    }

    /// Runs once per app launch: if store is empty, creates one Fonster with current time.
    private func ensureSelectionOnLaunch() async {
        guard !hasPerformedLaunchSelectionCheck else { return }
        hasPerformedLaunchSelectionCheck = true
        await Task.yield()

    }
}
