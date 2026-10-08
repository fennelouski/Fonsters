#if os(iOS)
import SwiftUI
import UIKit

enum PhoneExperienceOrientation: Equatable { case lobby, details }

/// Geometry belongs to the window scene that actually contains this view.
/// No UIDevice orientation mutation, global screen lookup or iPad locking.
@MainActor enum PhoneOrientation {
    private static let requests = NSMapTable<UIWindowScene, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    static func mask(for window: UIWindow?) -> UIInterfaceOrientationMask {
        guard window?.traitCollection.userInterfaceIdiom == .phone,
              let scene = window?.windowScene else { return .all }
        return requests.object(forKey: scene)?.boolValue == true ? .landscape : .portrait
    }
    static func apply(_ orientation: PhoneExperienceOrientation, to window: UIWindow) {
        guard window.traitCollection.userInterfaceIdiom == .phone, let scene = window.windowScene else { return }
        let landscape = orientation == .lobby
        let changed = requests.object(forKey: scene)?.boolValue != landscape
        requests.setObject(NSNumber(value: landscape), forKey: scene)
        var controller = window.rootViewController
        controller?.setNeedsUpdateOfSupportedInterfaceOrientations()
        while let presented = controller?.presentedViewController {
            presented.setNeedsUpdateOfSupportedInterfaceOrientations(); controller = presented
        }
        let mask: UIInterfaceOrientationMask = landscape ? .landscape : .portrait
        if changed || !mask.contains(UIInterfaceOrientationMask(rawValue: 1 << scene.interfaceOrientation.rawValue)) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                // Geometry may be deferred while a presentation is in flight.
                // The sentinel reapplies when the view appears/layouts again.
                #if DEBUG
                NSLog("Fonsters orientation request deferred: %@", error.localizedDescription)
                #endif
            }
        }
    }
}

private struct PhoneOrientationSentinel: UIViewControllerRepresentable {
    let orientation: PhoneExperienceOrientation
    func makeUIViewController(context: Context) -> Controller { Controller(orientation: orientation) }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.orientation = orientation; controller.updateOrientation()
    }
    final class Controller: UIViewController {
        var orientation: PhoneExperienceOrientation
        init(orientation: PhoneExperienceOrientation) { self.orientation = orientation; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
        override func loadView() { view = UIView(); view.isUserInteractionEnabled = false }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); updateOrientation() }
        override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); updateOrientation() }
        func updateOrientation() { if let window = viewIfLoaded?.window { PhoneOrientation.apply(orientation, to: window) } }
    }
}

extension View {
    func phoneOrientation(_ orientation: PhoneExperienceOrientation) -> some View {
        background { PhoneOrientationSentinel(orientation: orientation).frame(width: 0, height: 0).accessibilityHidden(true) }
    }
}
#endif
