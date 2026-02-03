//
//  MessagesViewController.swift
//  Fonsters iMessage Extension
//
//  Presents the user's Fonsters from SwiftData (CloudKit) as iMessage stickers.
//  Stickers are generated at runtime: creatureImage(seed) → scale to 408×408 → PNG → MSSticker.
//

import UIKit
import Messages
import SwiftData

private let stickerSize: MSStickerSize = .regular

final class FonsterStickerBrowserViewController: MSStickerBrowserViewController {
    var stickers: [MSSticker] = [] {
        didSet { stickerBrowserView.reloadData() }
    }

    override func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int {
        stickers.count
    }

    override func stickerBrowserView(_ stickerBrowserView: MSStickerBrowserView, stickerAt index: Int) -> MSSticker {
        stickers[index]
    }
}

final class MessagesViewController: MSMessagesAppViewController {
    private var browserViewController: FonsterStickerBrowserViewController!
    private var modelContainer: ModelContainer?
    private var cacheDirectory: URL?
    private var generatedURLs: [URL] = [] // keep references so files persist for MSSticker

    override func viewDidLoad() {
        super.viewDidLoad()
        cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FonsterStickers", isDirectory: true)
        browserViewController = FonsterStickerBrowserViewController(stickerSize: stickerSize)
        browserViewController.view.frame = view.bounds
        browserViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addChild(browserViewController)
        view.addSubview(browserViewController.view)
        browserViewController.didMove(toParent: self)
        loadStickers()
    }

    private func loadStickers() {
        guard let cacheDir = cacheDirectory else { return }
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let container: ModelContainer
        do {
            let schema = Schema([Fonster.self])
            let config = ModelConfiguration(
                "Synced",
                schema: schema,
                cloudKitDatabase: .automatic
            )
            container = try ModelContainer(for: schema, configurations: [config])
            modelContainer = container
        } catch {
            browserViewController.stickers = []
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Fonster>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let fonsters: [Fonster]
        do {
            fonsters = try context.fetch(descriptor)
        } catch {
            browserViewController.stickers = []
            return
        }

        if fonsters.isEmpty {
            browserViewController.stickers = []
            return
        }

        // Generate sticker PNGs and MSStickers. Do file I/O on background; MSSticker creation on main.
        generatedURLs = []
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var newStickers: [MSSticker] = []
            var urlsToKeep: [URL] = []
            for (_, fonster) in fonsters.enumerated() {
                let name = fonster.name.trimmingCharacters(in: .whitespaces)
                let label = name.isEmpty ? (fonster.seed.isEmpty ? "Fonster" : String(fonster.seed.prefix(20))) : name
                let fileURL = cacheDir.appendingPathComponent("sticker_\(fonster.id.uuidString).png")
                guard writeCreatureStickerPNG(seed: fonster.seed, to: fileURL) else { continue }
                urlsToKeep.append(fileURL)
                if let sticker = try? MSSticker(contentsOfFileURL: fileURL, localizedDescription: label) {
                    newStickers.append(sticker)
                }
            }
            DispatchQueue.main.async {
                self.generatedURLs = urlsToKeep
                self.browserViewController.stickers = newStickers
            }
        }
    }
}
