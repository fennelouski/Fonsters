//
//  OnboardingCoordinator.swift
//  Fonsters
//
//  Drives the sequential onboarding walkthrough. Only one tip is shown at a time
//  by attaching .popoverTip only for the current step. TipKit on iOS/macOS.
//

import SwiftUI
import Combine
#if canImport(Tips)
import Tips
#endif

private let hasCompletedOnboardingKey = "Fonsters.hasCompletedOnboarding"
private let onboardingStepCount = 6

/// Coordinator for the onboarding walkthrough. Only one tip is active per step.
/// On iOS/macOS, TipKit tips are attached for the current step; on tvOS/visionOS, only the help sheet is used.
final class OnboardingCoordinator: ObservableObject {
    /// 0 = none, 1...onboardingStepCount = current step.
    @Published var currentStep: Int = 0
    @Published var isWalkthroughActive: Bool = false

    /// Shared reference so Tip actions (which are static) can advance or skip. Set on iOS/macOS only.
    static weak var shared: OnboardingCoordinator?

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey) }
    }

    var isFirstStep: Bool { currentStep == 1 }
    var isLastStep: Bool { currentStep == onboardingStepCount }
    var totalSteps: Int { onboardingStepCount }

    /// Call when the current tip is dismissed (e.g. user tapped Next or close).
    func advanceStep() {
        if currentStep >= onboardingStepCount {
            endWalkthrough()
            return
        }
        currentStep += 1
    }

    /// End the walkthrough and mark onboarding complete for first-time flow.
    func endWalkthrough() {
        currentStep = 0
        isWalkthroughActive = false
        hasCompletedOnboarding = true
    }

    /// Start the walkthrough (e.g. first launch or "Show tips again").
    func startWalkthrough() {
        isWalkthroughActive = true
        currentStep = 1
    }

    /// "Show tips again" from footer: on iOS/macOS reset TipKit datastore, then start walkthrough.
    func showTipsAgain() {
        #if canImport(Tips)
        try? Tips.resetDatastore()
        #endif
        startWalkthrough()
    }

    /// Whether to show the tip for the given step (only one step shows a tip at a time).
    func shouldShowTip(for step: Int) -> Bool {
        isWalkthroughActive && currentStep == step
    }
}

// MARK: - Tips (one per step)
#if canImport(Tips)

struct AddFonsterTip: Tip {
    var title: Text { Text("Add a Fonster") }
    var message: Text? { Text("Tap the + button to create a new creature. You can also use Share to send a link or Import to add creatures from a link.") }
    var image: Image? { Image(systemName: "plus.circle.fill") }

    var actions: [Action] {
        [
            Action(id: "next", title: "Next") {
                OnboardingCoordinator.shared?.advanceStep()
                invalidate(reason: .actionPerformed)
            },
            Action(id: "skip", title: "Skip") {
                OnboardingCoordinator.shared?.endWalkthrough()
                invalidate(reason: .actionPerformed)
            }
        ]
    }
}

struct ShareImportTip: Tip {
    var title: Text { Text("Share & Import") }
    var message: Text? { Text("Share creates a link others can open to get your creatures. Import lets you paste a share link to add those creatures to your list.") }
    var image: Image? { Image(systemName: "square.and.arrow.up") }

    var actions: [Action] {
        [
            Action(id: "next", title: "Next") {
                OnboardingCoordinator.shared?.advanceStep()
                invalidate(reason: .actionPerformed)
            },
            Action(id: "skip", title: "Skip") {
                OnboardingCoordinator.shared?.endWalkthrough()
                invalidate(reason: .actionPerformed)
            }
        ]
    }
}

struct ListTip: Tip {
    var title: Text { Text("Your Fonsters") }
    var message: Text? { Text("This list shows all your creatures. Tap one to open it and edit its name and source text. Swipe to delete, or use the toolbar.") }
    var image: Image? { Image(systemName: "list.bullet") }

    var actions: [Action] {
        [
            Action(id: "next", title: "Next") {
                OnboardingCoordinator.shared?.advanceStep()
                invalidate(reason: .actionPerformed)
            },
            Action(id: "skip", title: "Skip") {
                OnboardingCoordinator.shared?.endWalkthrough()
                invalidate(reason: .actionPerformed)
            }
        ]
    }
}

struct DetailSeedTip: Tip {
    var title: Text { Text("Name & source text") }
    var message: Text? { Text("Give your creature a name and type anything in the source text field. The creature updates as you type. Use Get random or Add random to start for quick ideas.") }
    var image: Image? { Image(systemName: "text.cursor") }

    var actions: [Action] {
        [
            Action(id: "next", title: "Next") {
                OnboardingCoordinator.shared?.advanceStep()
                invalidate(reason: .actionPerformed)
            },
            Action(id: "skip", title: "Skip") {
                OnboardingCoordinator.shared?.endWalkthrough()
                invalidate(reason: .actionPerformed)
            }
        ]
    }
}

struct PlayTip: Tip {
    var title: Text { Text("Watch it evolve") }
    var message: Text? { Text("Tap Play to watch your creature evolve character by character. Tap the creature for a fun animation. Use PNG or GIF to export and share.") }
    var image: Image? { Image(systemName: "play.circle.fill") }

    var actions: [Action] {
        [
            Action(id: "next", title: "Next") {
                OnboardingCoordinator.shared?.advanceStep()
                invalidate(reason: .actionPerformed)
            },
            Action(id: "skip", title: "Skip") {
                OnboardingCoordinator.shared?.endWalkthrough()
                invalidate(reason: .actionPerformed)
            }
        ]
    }
}

struct ExportTip: Tip {
    var title: Text { Text("Export & done") }
    var message: Text? { Text("Export as PNG or GIF to save or share. You can run this walkthrough again anytime from \"Show tips again\" in the sidebar footer. Have fun!") }
    var image: Image? { Image(systemName: "square.and.arrow.down") }

    var actions: [Action] {
        [
            Action(id: "done", title: "Done") {
                OnboardingCoordinator.shared?.endWalkthrough()
                invalidate(reason: .actionPerformed)
            },
            Action(id: "skip", title: "Skip") {
                OnboardingCoordinator.shared?.endWalkthrough()
                invalidate(reason: .actionPerformed)
            }
        ]
    }
}

/// Applies `.popoverTip(tip)` only when the coordinator is on the given step, so only one tip shows at a time.
struct ConditionalPopoverTip<T: Tip>: ViewModifier {
    let step: Int
    let tip: T
    @ObservedObject var coordinator: OnboardingCoordinator

    func body(content: Content) -> some View {
        if coordinator.shouldShowTip(for: step) {
            content.popoverTip(tip)
        } else {
            content
        }
    }
}
#endif
