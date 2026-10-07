#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct FonsterVisitDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(card: FonsterVisitCard) throws { data = try card.encoded() }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw VisitCardError.invalid }
        _ = try FonsterVisitCard.decode(data); self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
    static func readSelectedFile(_ url: URL) throws -> FonsterVisitCard {
        guard url.isFileURL else { throw VisitCardError.invalid }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw VisitCardError.invalid }
        guard let size = values.fileSize, size <= FonsterVisitCard.byteLimit else { throw VisitCardError.tooLarge }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        return try .decode(handle.read(upToCount: FonsterVisitCard.byteLimit + 1) ?? Data())
    }
}

/// Visitors have no seed. This draws their exact resolved 32 × 32 portrait.
struct ResolvedPortrait: View {
    let appearance: CreatureAppearanceDescriptor
    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 32
            for (offset, index) in appearance.raster.enumerated() where index >= 0 && Int(index) < appearance.rgbaPalette.count {
                let rgba = appearance.rgbaPalette[Int(index)]
                guard rgba.count == 4 else { continue }
                let color = Color(.sRGB, red: Double(rgba[0]) / 255, green: Double(rgba[1]) / 255,
                                  blue: Double(rgba[2]) / 255, opacity: Double(rgba[3]) / 255)
                context.fill(Path(CGRect(x: Double(offset % 32) * unit, y: Double(offset / 32) * unit,
                                         width: unit, height: unit)), with: .color(color))
            }
        }.accessibilityHidden(true)
    }
}

@available(macOS 15.0, *)
struct VisitShareSheet: View {
    let lobby: LocalLobbyController
    let member: LocalLobbyController.Member
    @Environment(\.dismiss) private var dismiss
    @State private var includeFeeling = false
    @State private var exporting = false
    @State private var document: FonsterVisitDocument?
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 24) {
                ResolvedPortrait(appearance: member.descriptor).frame(width: 90, height: 90)
                Image(systemName: "arrow.right").font(.system(size: 22)).foregroundStyle(FonsterTone.world.ink)
                Image(systemName: "person.2").font(.system(size: 38)).foregroundStyle(FonsterTone.company.ink)
                Spacer()
            }.accessibilityElement(children: .ignore).accessibilityLabel("Save a portable visit from \(member.name) to send to a person you choose")
            HStack {
                Text(member.name).font(.system(size: 26, weight: .bold, design: .rounded))
                Spacer()
                FonsterInfo(title: "Visit file contents", detail: "Save this file and send it to someone you choose. It contains a random public ID, this appearance, and two personality tendencies. No email, original seed, camera or microphone input, private memories, or friendship list. Feelings and activities don't update across Macs.")
            }
            Toggle("Share chosen feeling: \(member.controller.feeling.title)", isOn: $includeFeeling).toggleStyle(.checkbox)
            Text("Recipients can keep this copy. Ending your visit cannot revoke their file.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.system(size: 12)) }
            HStack {
                FonsterIconButton(title: "Cancel", symbol: "xmark") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                FonsterIconButton(title: "Save visit file to share", symbol: "square.and.arrow.down", tone: .world) {
                    do { document = try .init(card: lobby.card(for: member, includeFeeling: includeFeeling)); exporting = true }
                    catch { self.error = error.localizedDescription }
                }
            }
        }.padding(28).frame(width: 450)

        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                      defaultFilename: "\(member.name).fonster") { result in
            switch result { case .success: dismiss(); case .failure: error = "The visit file couldn't be saved. You can try again." }
        }
    }
}

@available(macOS 15.0, *)
struct VisitReviewSheet: View {
    let card: FonsterVisitCard
    let invite: () throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 24) {
                ResolvedPortrait(appearance: card.appearance).frame(width: 90, height: 90)
                Image(systemName: "arrow.right").font(.system(size: 22)).foregroundStyle(FonsterTone.world.ink)
                Image(systemName: "person.3").font(.system(size: 38)).foregroundStyle(FonsterTone.company.ink)
            }.accessibilityElement(children: .ignore).accessibilityLabel("Invite \(card.name)'s snapshot into this local world")
            HStack {
                Text(card.name).font(.system(size: 26, weight: .bold, design: .rounded))
                if let feeling = card.feeling { FonsterStatus(symbol: feeling.symbol, detail: "Shared chosen feeling: \(feeling.title)", tone: .company) }
                Spacer()
            }
            Text("A local snapshot with an unverified owner. No live messages or private inputs are sent.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.system(size: 12)) }
            HStack {
                FonsterIconButton(title: "Cancel", symbol: "xmark") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                FonsterIconButton(title: "Invite into this local lobby", symbol: "person.crop.circle.badge.plus", tone: .company) {
                    do { try invite(); dismiss() } catch { self.error = error.localizedDescription }
                }
            }
        }.padding(28).frame(width: 450)

    }
}
#endif
