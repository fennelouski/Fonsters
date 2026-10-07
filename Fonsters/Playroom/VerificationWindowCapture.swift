#if os(macOS)
import SwiftUI
import AppKit

/// Opt-in verification of this app's own window. No desktop control or screen permissions.
/// Metal-backed content may be omitted by AppKit; keep the separate RealityKit scene exports.
struct VerificationWindowCapture: NSViewRepresentable {
    final class CaptureView: NSView {
        private var captured = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let args = ProcessInfo.processInfo.arguments
            guard !captured, let window, let index = args.firstIndex(of: "--window-export-file"), index + 1 < args.count else { return }
            captured = true
            let url = URL(fileURLWithPath: args[index + 1])
            let delay: Double
            if let i = args.firstIndex(of: "--window-export-delay"), i + 1 < args.count, let seconds = Double(args[i + 1]), seconds.isFinite {
                delay = min(20, max(2, seconds))
            } else { delay = 2 }
            Task { @MainActor [weak window] in
                try? await Task.sleep(for: .seconds(delay))
                guard let view = window?.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    func makeNSView(context: Context) -> CaptureView { CaptureView() }
    func updateNSView(_ nsView: CaptureView, context: Context) {}
}
#endif
