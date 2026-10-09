#if os(macOS) || os(iOS)
import SwiftUI

/// A screen projection of the selected creature's live crown, not a HUD tag.
@available(macOS 15.0, iOS 18.0, *)
struct OverheadFonsterName: View {
    let lobby: LocalLobbyController
    let record: Fonster?
    let edit: (Fonster) -> Void
    @State private var labelSize = CGSize(width: 100, height: 30)
    var body: some View {
        GeometryReader { geometry in
            if let anchor = lobby.overheadNameAnchor, lobby.inCare {
                Group {
                    if let record {
                        Button { edit(record) } label: { name.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
                            .buttonStyle(.plain)
                            .fonsterHoverHelp("Edit name, backstory and interests")
                            .accessibilityLabel("Name and backstory")
                            .accessibilityValue(lobby.selectedMember.name)
                            .accessibilityHint("Edit this Fonster’s name and private interests")
                            .accessibilityIdentifier("editFonsterProfile")
                    } else { name }
                }
                .frame(maxWidth: min(240, max(80, geometry.size.width - 24)))
                .fixedSize(horizontal: true, vertical: true)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { labelSize = $0 }
                .position(x: min(geometry.size.width - labelSize.width / 2 - 8,
                                 max(labelSize.width / 2 + 8, CGFloat(anchor.x) * geometry.size.width)),
                          y: CGFloat(anchor.y) * geometry.size.height - labelSize.height / 2 - 8)
            }
        }
    }
    private var name: some View {
        Text(lobby.selectedMember.name).font(.headline)
            .foregroundStyle(FonsterChrome.primary)
            .lineLimit(1).truncationMode(.middle)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(FonsterChrome.surface.opacity(0.95), in: Capsule())
            .accessibilityIdentifier("careName")
    }
}
#endif
