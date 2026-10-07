#if os(macOS)
import SwiftUI
import AppKit
import RealityKit

/// Opt-in verification of this app's own window. No desktop control or screen permissions.
/// AppKit omits Metal surfaces. With --ui-scene-photo, composite an actual
/// RealityKit render from that window's live entities into its measured stage.
/// This is an app-owned UI/scene composite, not a desktop screenshot.
struct VerificationWindowCapture: NSViewRepresentable {
    var label = "window"
    final class CaptureView: NSView {
        var label = "window"
        private var captured = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let args = ProcessInfo.processInfo.arguments
            guard !captured, let window, let index = args.firstIndex(of: "--window-export-file"), index + 1 < args.count else { return }
            if let target = args.firstIndex(of: "--window-export-target"), target + 1 < args.count, args[target + 1] != label { return }
            captured = true
            let url = URL(fileURLWithPath: args[index + 1])
            let delay: Double
            if let i = args.firstIndex(of: "--window-export-delay"), i + 1 < args.count, let seconds = Double(args[i + 1]), seconds.isFinite {
                delay = min(20, max(2, seconds))
            } else { delay = 2 }
            Task { @MainActor [weak window] in
                try? await Task.sleep(for: .seconds(delay))
                guard let window, let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let output: NSBitmapImageRep
                if #available(macOS 15.0, *) { output = VerificationSceneMarker.composite(bitmap, contentView: view, window: window) ?? bitmap }
                else { output = bitmap }
                guard let data = output.representation(using: .png, properties: [:]) else { return }
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    func makeNSView(context: Context) -> CaptureView { let view = CaptureView(); view.label = label; return view }
    func updateNSView(_ nsView: CaptureView, context: Context) {}
}

@available(macOS 15.0, *)
struct VerificationSceneMarker: NSViewRepresentable {
    let entities: [Entity]
    final class MarkerView: NSView {
        var entities: [Entity] = []
        var photo: NSImage?
        private var pending = false
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); captureIfNeeded() }
        func captureIfNeeded() {
            guard ProcessInfo.processInfo.arguments.contains("--ui-scene-photo"), !pending, !entities.isEmpty, window != nil else { return }
            pending = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(600))
                guard let self, self.bounds.width > 0, self.bounds.height > 0 else { return }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("fonster-ui-scene-\(UUID().uuidString).png")
                defer { try? FileManager.default.removeItem(at: url) }
                do {
                    let scale = min(2, 2048 / max(self.bounds.width, self.bounds.height))
                    try await NativeSceneExport.capture(self.entities, width: max(1, Int(self.bounds.width * scale)), height: max(1, Int(self.bounds.height * scale)), to: url)
                    self.photo = NSImage(contentsOf: url)
                } catch { /* standalone scene export remains available */ }
            }
        }
    }
    func makeNSView(context: Context) -> MarkerView { MarkerView() }
    func updateNSView(_ view: MarkerView, context: Context) { view.entities = entities; view.captureIfNeeded() }
    static func composite(_ bitmap: NSBitmapImageRep, contentView: NSView, window: NSWindow) -> NSBitmapImageRep? {
        guard ProcessInfo.processInfo.arguments.contains("--ui-scene-photo"), let base = bitmap.cgImage,
              let context = CGContext(data: nil, width: base.width, height: base.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))
        let sx = CGFloat(base.width) / contentView.bounds.width, sy = CGFloat(base.height) / contentView.bounds.height
        func visit(_ view: NSView) {
            if let marker = view as? MarkerView, let photo = marker.photo,
               let cg = photo.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let bounds = marker.convert(marker.bounds, to: contentView)
                let y = contentView.isFlipped ? contentView.bounds.height - bounds.maxY : bounds.minY
                let rect = CGRect(x: bounds.minX * sx, y: y * sy, width: bounds.width * sx, height: bounds.height * sy)
                context.saveGState()
                context.addPath(CGPath(roundedRect: rect, cornerWidth: 26 * sx, cornerHeight: 26 * sy, transform: nil)); context.clip()
                context.draw(cg, in: rect); context.restoreGState()
            }
            view.subviews.forEach(visit)
        }
        visit(contentView)
        return context.makeImage().map { NSBitmapImageRep(cgImage: $0) }
    }
}
#endif
