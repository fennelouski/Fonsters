//
//  UprightCreatureFeature.swift
//  Fonsters
//
//  iOS-only: shake-to-toggle upright creature (bottom points toward ground via
//  accelerometer). UprightCreatureState exists on all platforms for environment
//  injection; motion and shake detection are iOS-only.
//

import SwiftUI
import Combine
#if os(iOS)
import CoreMotion
#endif

/// State for the upright-creature feature. On iOS, shake toggles; when enabled,
/// creature rotates so its bottom points toward gravity. On other platforms,
/// isEnabled stays false and no motion is used.
final class UprightCreatureState: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var gravityAngle: Double = 0

    #if os(iOS)
    private let motionManager = CMMotionManager()
    private let filterFactor: Double = 0.12
    private var smoothedAngle: Double = 0
    #endif

    func toggle() {
        isEnabled.toggle()
        #if os(iOS)
        if isEnabled {
            startMotion()
        } else {
            stopMotion()
        }
        #endif
    }

    #if os(iOS)
    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            let g = motion.gravity
            // Screen plane (portrait): X right, Y down. Angle so view "down" (0,1) aligns with (g.x, g.y).
            let raw = atan2(g.x, g.y)
            self.smoothedAngle = self.smoothedAngle + self.filterFactor * (raw - self.smoothedAngle)
            self.gravityAngle = self.smoothedAngle
        }
    }

    private func stopMotion() {
        motionManager.stopDeviceMotionUpdates()
        gravityAngle = 0
        smoothedAngle = 0
    }
    #endif
}

#if os(iOS)
import UIKit
import ObjectiveC

/// Posted when the device is shaken (global listener). Observers receive it regardless of which view is presented.
extension Notification.Name {
    static let deviceDidShake = Notification.Name("FonstersDeviceDidShake")
}

// MARK: - Global shake detection (sendEvent swizzle)

private func installGlobalShakeListener() {
    guard let appClass = UIApplication.self as? AnyClass else { return }
    let originalSel = #selector(UIApplication.sendEvent(_:))
    let swizzledSel = #selector(UIApplication.fonsters_sendEvent(_:))
    guard let originalMethod = class_getInstanceMethod(appClass, originalSel),
          let swizzledMethod = class_getInstanceMethod(appClass, swizzledSel) else { return }
    method_exchangeImplementations(originalMethod, swizzledMethod)
}

extension UIApplication {
    @objc fileprivate func fonsters_sendEvent(_ event: UIEvent) {
        if event.type == .motion, event.subtype == .motionShake {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .deviceDidShake, object: nil)
            }
        }
        fonsters_sendEvent(event)
    }
}

/// Call from AppDelegate application(_:didFinishLaunchingWithOptions:) on iOS to enable global shake detection.
func installUprightCreatureShakeListenerIfNeeded() {
    installGlobalShakeListener()
}

/// iOS-only app delegate that installs global shake detection so shake is received even when sheets/modals are presented.
final class ShakeListenerAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        installUprightCreatureShakeListenerIfNeeded()
        return true
    }
}
#endif
