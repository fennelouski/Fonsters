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
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ResolvedPortrait(appearance: member.descriptor).frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Send a little company.").font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("A portable visit from \(member.name)").foregroundStyle(.secondary)
                }
            }
            Text("Save this visit file, then send it to someone you choose. They can invite this snapshot into their Fonsters preview lobby.")
            Toggle("Include my chosen feeling: \(member.controller.feeling.title)", isOn: $includeFeeling)
                .toggleStyle(.checkbox)
            Text("The file contains a random public ID, this appearance and two personality tendencies. It includes no email, original seed, camera or microphone input, private memories, or friendship list.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text("A recipient can keep this copy. Ending a local visit doesn't revoke their file. Feelings and activities don't update across Macs in this preview.")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.system(size: 12)) }
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Save visit file…") {
                do { document = try .init(card: lobby.card(for: member, includeFeeling: includeFeeling)); exporting = true }
                catch { self.error = error.localizedDescription }
            }.buttonStyle(.borderedProminent) }
        }.padding(28).frame(width: 510)
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ResolvedPortrait(appearance: card.appearance).frame(width: 80, height: 80)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Meet \(card.name).").font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(card.feeling.map { "Chosen feeling: \($0.title)" } ?? "Their owner didn't share a feeling.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            Text("Invite this snapshot to stay with Coral, Moss and Iris. Orbit will make room until you end the visit.")
            Text("This is a local copy, without live messages or a verified owner. Your camera, microphone, feelings and friendship memories aren't sent anywhere by inviting it.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.system(size: 12)) }
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Invite into this lobby") {
                do { try invite(); dismiss() } catch { self.error = error.localizedDescription }
            }.buttonStyle(.borderedProminent) }
        }.padding(28).frame(width: 480)
    }
}
#endif
