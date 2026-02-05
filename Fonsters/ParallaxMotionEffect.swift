//
//  ParallaxMotionEffect.swift
//  Fonsters
//
//  Applies a subtle parallax motion effect to the wrapped view (e.g. creature avatar)
//  so it shifts with device tilt (iOS) or Siri Remote (tvOS). Only the view content
//  moves; backgrounds and siblings are unaffected.
//

import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit

/// Wraps SwiftUI content in a UIKit container that has UIMotionEffect applied,
/// so the content shifts subtly with motion (tilt on iOS, remote on tvOS).
private struct ParallaxMotionHostingView<Content: View>: UIViewRepresentable {
    let content: Content
    /// Motion magnitude in points (max translation per axis).
    var magnitude: CGFloat = 12

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = false

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        context.coordinator.hostingController = hosting

        let horizontal = UIInterpolatingMotionEffect(
            keyPath: "layer.transform.translation.x",
            type: .tiltAlongHorizontalAxis
        )
        horizontal.minimumRelativeValue = -magnitude
        horizontal.maximumRelativeValue = magnitude

        let vertical = UIInterpolatingMotionEffect(
            keyPath: "layer.transform.translation.y",
            type: .tiltAlongVerticalAxis
        )
        vertical.minimumRelativeValue = -magnitude
        vertical.maximumRelativeValue = magnitude

        let group = UIMotionEffectGroup()
        group.motionEffects = [horizontal, vertical]
        container.addMotionEffect(group)

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var hostingController: UIHostingController<Content>?
    }
}

/// View modifier that applies parallax motion to the content (iOS and tvOS only).
/// Only the view it's applied to moves; siblings and background do not.
struct ParallaxMotionModifier: ViewModifier {
    var magnitude: CGFloat = 12

    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(0)
                .accessibilityHidden(true)
            ParallaxMotionHostingView(content: content, magnitude: magnitude)
                .allowsHitTesting(false)
        }
        .drawingGroup(opaque: false)
    }
}

extension View {
    /// Applies a subtle parallax motion effect to this view on iOS and tvOS.
    /// Only this view shifts; the background and surrounding layout do not.
    func parallaxMotion(magnitude: CGFloat = 12) -> some View {
        modifier(ParallaxMotionModifier(magnitude: magnitude))
    }
}
#endif
