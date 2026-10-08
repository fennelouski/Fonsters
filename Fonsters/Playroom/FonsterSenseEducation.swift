#if os(macOS) || os(iOS)
import SwiftUI

/// A simulated preview never opens capture hardware or requests permission.
@available(macOS 15.0, iOS 18.0, *)
struct FonsterSenseEducation: View {
    enum Sense: String, Identifiable { case camera, microphone; var id: String { rawValue } }
    let sense: Sense
    let continueAction: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = PlayroomController()
    private let companion = PlayroomCompanion.fixtures[0]
    var body: some View {
        VStack(spacing: 20) {
            HStack { Spacer(); FonsterIconButton(title: "Cancel", symbol: "xmark") { dismiss() } }
            CreatureStageView(companion: companion, controller: controller)
                .frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 24))
                .accessibilityLabel("Simulated Fonster preview; camera and microphone are off")
            Label(sense == .camera ? "Move together" : "Talk to your Fonster", systemImage: sense == .camera ? "video" : "mic")
                .font(.title2.bold())
            Text(sense == .camera ? "Wave, tilt your head or close your eyes. Your Fonster follows you using this device’s camera." : "Say wave, jump, dance or sleep. Your Fonster listens for short commands using on-device English speech recognition.")
                .multilineTextAlignment(.center)
            Text("Nothing is recorded or uploaded. You can stop at any time. A grown-up review comes next, followed by device permission.")
                .font(.callout).multilineTextAlignment(.center)
            HStack(spacing: 28) {
                FonsterIconButton(title: "Preview again", symbol: "play.fill", tone: .play) { controller.perform(sense == .camera ? .greet : .hop, name: companion.name) }
                FonsterIconButton(title: "Continue to grown-up review", symbol: "arrow.right", tone: .company) { dismiss(); continueAction() }
                    .accessibilityIdentifier("senseEducationContinue")
            }
        }.padding(24).frame(maxWidth: 440).foregroundStyle(FonsterChrome.primary).background(FonsterChrome.background)
        .onAppear { controller.soundEnabled = false }
        .task(id: controller.rendererReady) { if controller.rendererReady { controller.perform(.greet, name: companion.name) } }
        .task(id: controller.shouldAnimate) { if controller.shouldAnimate { await controller.animate() } }
        .onChange(of: reduceMotion, initial: true) { controller.systemReduceMotion = reduceMotion }
        .onChange(of: scenePhase, initial: true) { controller.backgrounded = scenePhase != .active }
        .onDisappear { controller.backgrounded = true; controller.silence() }
    }
}
#endif
