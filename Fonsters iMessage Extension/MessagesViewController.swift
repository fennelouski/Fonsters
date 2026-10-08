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
import CloudKit

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
        let helpButton = UIButton(type: .system)
        helpButton.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        helpButton.toolTip = "How to use Fonster stickers"
        helpButton.accessibilityLabel = "Sticker help"
        helpButton.accessibilityHint = "Explain adding a sticker and removing an unsent sticker"
        helpButton.backgroundColor = .secondarySystemBackground
        helpButton.layer.cornerRadius = 22
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        helpButton.addAction(UIAction { [weak self] _ in
            let alert = UIAlertController(title: "Fonster stickers", message: "Tap a portrait to add it to your message, or press and drag it onto a message. Remove an unsent sticker in Messages before sending. Sending and any available undo are controlled by Messages.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel))
            self?.present(alert, animated: true)
        }, for: .primaryActionTriggered)
        view.addSubview(helpButton)
        NSLayoutConstraint.activate([
            helpButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            helpButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            helpButton.widthAnchor.constraint(equalToConstant: 44), helpButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        loadStickers()
    }

    private func loadStickers() {
        guard let cacheDir = cacheDirectory else { return }
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let schema = Schema([Fonster.self])
        var useCloudKit = false
        let semaphore = DispatchSemaphore(value: 0)
        CKContainer.default().accountStatus { status, _ in
            useCloudKit = (status == .available)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.0)

        let container: ModelContainer
        do {
            if useCloudKit {
                let config = ModelConfiguration(
                    "Synced",
                    schema: schema,
                    cloudKitDatabase: .automatic
                )
                container = try ModelContainer(for: schema, configurations: [config])
            } else {
                let config = ModelConfiguration(
                    "Local",
                    schema: schema,
                    cloudKitDatabase: .none
                )
                container = try ModelContainer(for: schema, configurations: [config])
            }
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
