#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI
import Observation

private struct ParentActionPresenter: ViewModifier {
    @Bindable var gate: ParentActionGate
    @Environment(\.scenePhase) private var phase
    func body(content: Content) -> some View {
        content.sheet(item: $gate.challenge, onDismiss: gate.finish) { challenge in
            ParentChallengeView(challenge: challenge, purpose: gate.purpose, approve: { gate.approve($0) }, cancel: gate.cancel)
        }
        .onChange(of: phase) { _, phase in if phase == .background { gate.cancel() } }
        .onDisappear { gate.cancel() }
    }
}
extension View {
    func parentActions(_ gate: ParentActionGate) -> some View { modifier(ParentActionPresenter(gate: gate)) }
}

private struct ParentChallengeView: View {
    let challenge: ParentChallenge
    let purpose: String
    let approve: (String) -> Bool
    let cancel: () -> Void
    @State private var answer = ""
    @State private var incorrect = false
    var body: some View {
        VStack(spacing: 20) {
            HStack { Spacer(); FonsterIconButton(title: "Cancel parent action", symbol: "xmark", action: cancel).accessibilityIdentifier("cancelParentAction") }
            Image(systemName: "person.badge.shield.checkmark").font(.system(size: 48)).foregroundStyle(FonsterTone.company.ink).accessibilityHidden(true)
            Text("Ask a grown-up").font(.title2.bold())
            Text(purpose).multilineTextAlignment(.center)
            Text(challenge.question).font(.title3).accessibilityIdentifier("parentQuestion")
            TextField("Answer", text: $answer).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Parent answer").accessibilityIdentifier("parentAnswer")
                .onSubmit(submit)
            if incorrect { Text("Try again, or close to keep playing.").foregroundStyle(.secondary).accessibilityIdentifier("parentIncorrect") }
            FonsterIconButton(title: "Continue parent action", symbol: "checkmark", tone: .company, action: submit)
                .disabled(answer.isEmpty).accessibilityIdentifier("approveParentAction")
        }.padding(24).frame(maxWidth: 420)
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 360)
        #elseif os(iOS)
        .phoneOrientation(.details)
        #endif
    }
    private func submit() { incorrect = !approve(answer) }
}

/// Legacy galleries/windows retain all functionality inside an adult area.
/// Unlock lives only in this presentation; backgrounding locks it again.
struct ParentOnlyArea<Content: View>: View {
    let purpose: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var challenge = ParentChallenge()
    @State private var allowed = false
    var body: some View {
        Group {
            if allowed { content() }
            else { ParentChallengeView(challenge: challenge, purpose: purpose, approve: { answer in
                guard challenge.accepts(answer) else { return false }; allowed = true; return true
            }, cancel: { dismiss() }) }
        }
        .onChange(of: phase) { _, phase in if phase == .background { allowed = false; challenge = ParentChallenge() } }
        #if os(iOS)
        .phoneOrientation(.details)
        #endif
    }
}

struct FamilyPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Protected play", systemImage: "hand.raised.fill").font(.headline)
                    Text("A little world for playing, dancing and caring. No Fonsters signup, advertising, public feed or strangers in the lobby.")
                }
                Section("Privacy policy · 8 October 2026") {
                    Text("This notice covers the current protected Fonsters experience for children and families. Everyone gets this experience for now. We do not ask for your age, birthday, location or contact details.")
                    Label("Your library", systemImage: "books.vertical")
                    Text("Fonster appearances, names and optional stories are saved on your device. When the existing iCloud setup is available, Apple can sync your library in your private iCloud database. There is no Fonsters account or public profile. Use a made-up name and story; do not enter personal contact details.")
                    Label("Little memories", systemImage: "heart")
                    Text("Care memories, chosen feelings and learned movement settings stay in local app files. Practice keeps only three bounded movement values when you choose Keep. They do not contain recordings or transcripts.")
                    Label("Camera and microphone", systemImage: "video")
                    Text("These start off. A grown-up task and your device permission are needed to enable them. The camera processes eyes, mouth shape, head and hands on this device. It can approximate whether you face the screen; it cannot know how you feel. Your chosen feeling stays yours. Spoken commands require on-device English speech support; there is no cloud speech fallback. Frames, measurements, audio and recognized words are not saved or uploaded by Fonsters. Stop, switch Fonsters or leave care to turn inputs off. Backgrounding pauses capture.")
                    Label("Typed requests", systemImage: "text.bubble")
                    Text("Known actions work locally. Compatible devices may interpret other short requests with Apple's on-device model. Fonsters does not save or send your typed request to an external AI service. This is an action interpreter, not a chat service.")
                    Label("Sharing with a grown-up", systemImage: "square.and.arrow.up")
                    Text("Sharing and original portrait exports are behind a grown-up task. A visit file contains a random public identifier and a creature snapshot; feelings and backstory are optional. Email addresses are removed from the visit snapshot. A recipient can keep or reshare a copy. Original portrait links contain recoverable seed text: base64 is not encryption. A grown-up should check the content before sharing.")
                    Label("No tracking", systemImage: "eye.slash")
                    Text("No ads, analytics SDKs, third-party random-text requests or remote feature-flag requests run in protected play. There is no external agent control, public social posting, chat, location access or contact access. Apple may process iCloud and diagnostic information under your device settings and Apple's policies.")
                    Label("Your choices", systemImage: "slider.horizontal.3")
                    Text("Camera and microphone can be turned off at any time. Cancel practice to discard a draft; Undo or Reset changes learned movement. A grown-up can edit or remove library entries in the original gallery. Removing the app does not necessarily remove iCloud backups or copies shared with someone else. Existing library records and links are preserved by this update.")
                    Text("A grown-up task helps prevent accidental access. It does not verify age or establish legal parental consent. A future account experience will have a separate age, country and consent review and its own notice; it will never silently upgrade protected play.").font(.footnote)
                }
                Section("Privacy questions") {
                    Text("Nathan Fennel · nathanfennel.com. This preview notice is being prepared for publication. Full operator contact details must be confirmed before a public child release.")
                }
            }
            .navigationTitle("Privacy & family")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { FonsterIconButton(title: "Close privacy", symbol: "xmark") { dismiss() }.accessibilityIdentifier("closeFamilyPrivacy") } }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 560)
        #elseif os(iOS)
        .phoneOrientation(.details)
        #endif
        .accessibilityIdentifier("familyPrivacy")
    }
}
#endif
