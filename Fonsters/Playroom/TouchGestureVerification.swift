#if os(macOS)
import SwiftUI
import AppKit
import RealityKit
import simd

/// Opt-in replay through this app's own NSWindow/SwiftUI gesture recognizer.
/// Never moves the system pointer or sends events to another process.
@available(macOS 15.0, *)
struct TouchGestureVerification: NSViewRepresentable {
    let controller: PlayroomController
    let entities: [Entity]
    final class ReplayView: NSView {
        var controller: PlayroomController?
        var entities: [Entity] = []
        private var scheduled = false
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard !scheduled, window != nil, ProcessInfo.processInfo.arguments.contains("--touch-demo") else { return }
            scheduled = true
            Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(2)); try await self?.replay() }
                catch { self?.save(["error": error.localizedDescription]) }
            }
        }
        private func project(_ point: SIMD3<Float>, camera: PerspectiveCamera) -> CGPoint {
            let p = camera.convert(position: point, from: nil)
            let tangent = tan(Float(camera.camera.fieldOfViewInDegrees) * .pi / 360)
            return .init(x: CGFloat(0.5 + p.x / (-p.z * tangent * Float(bounds.width / bounds.height)) * 0.5) * bounds.width,
                         y: CGFloat(0.5 - p.y / (-p.z * tangent) * 0.5) * bounds.height)
        }
        private func event(_ type: NSEvent.EventType, _ point: CGPoint) {
            guard let window, let event = NSEvent.mouseEvent(with: type, location: convert(point, to: nil),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) else { return }
            window.sendEvent(event)
        }
        private func save(_ values: [String: Any]) {
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "--touch-evidence-dir"), i + 1 < args.count else { return }
            let directory = URL(fileURLWithPath: args[i + 1], isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys, .prettyPrinted]) {
                try? data.write(to: directory.appendingPathComponent("gesture-results.json"), options: .atomic)
            }
        }
        private func replay() async throws {
            guard let controller, let rig = controller.rig, let camera = controller.touchCamera, let window,
                  bounds.width > 20, bounds.height > 20 else { throw CocoaError(.featureUnsupported) }
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "--touch-evidence-dir"), i + 1 < args.count else { return }
            let directory = URL(fileURLWithPath: args[i + 1], isDirectory: true)
            // Restored windows can be key instead of this stage. Replay only
            // into this app-owned window, with no system pointer events.
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
            controller.autonomyEnabled = false
            controller.roaming = false
            try await Task.sleep(for: .milliseconds(350))
            func headPoint(_ x: Float, _ y: Float) -> CGPoint {
                let h = rig.descriptor.head
                let local: SIMD3<Float> = [x * Float(h.radius * h.ellipseX) * rig.pixel,
                                          y * Float(h.radius * h.ellipseY) * rig.pixel,
                                          rig.depth * sqrt(max(0.12, 1 - x * x - y * y)) + 0.02]
                return project(rig.head.convert(position: local, to: nil), camera: camera)
            }
            var results: [[String: Any]] = []
            let began = ProcessInfo.processInfo.systemUptime
            var frames: [[String: Any]] = []
            func capture(_ filename: String, segment: String) async throws {
                // Do not run a second renderer while delivering time-sensitive
                // strokes. Record actual held/settled poses between sequences.
                let time = (ProcessInfo.processInfo.systemUptime - began) * 1000
                try await NativeSceneExport.capture(entities, width: 960, height: 675, to: directory.appendingPathComponent(filename))
                frames.append(["file": filename, "time": time, "segment": segment])
            }
            try await capture("touch-00-idle.png", segment: "idle")
            for (index, duration, startX, endX, y, expected) in [
                (1, 1.0, Float(-0.22), Float(0.22), Float(0.62), "softStroke"),
                (2, 0.75, Float(0.15), Float(0.15), Float(0.35), "cuddle"),
                (3, 0.22, Float(-0.40), Float(0.40), Float(0.48), "lively")
            ] {
                let start = headPoint(startX, y)
                event(.leftMouseDown, start)
                let steps = max(6, Int(duration * 60))
                for step in 1...steps {
                    try await Task.sleep(for: .seconds(duration / Double(steps)))
                    event(.leftMouseDragged, headPoint(startX + (endX - startX) * Float(step) / Float(steps), y))
                }
                let actual = controller.touch.response.manner.rawValue
                results.append(["expected": expected, "actual": actual, "captured": controller.touching,
                                "pass": controller.touching && actual == expected])
                try await Task.sleep(for: .milliseconds(40))
                try await capture("touch-0\(index)-\(expected).png", segment: expected)
                event(.leftMouseUp, headPoint(endX, y))
                try await Task.sleep(for: .milliseconds(650))
                try await capture("touch-0\(index)-settled.png", segment: "release")
            }
            if let data = try? JSONSerialization.data(withJSONObject: frames, options: [.sortedKeys]) {
                try? data.write(to: directory.appendingPathComponent("frames.json"), options: .atomic)
            }
            // Actual repeated mouse taps, rather than direct controller calls.
            for _ in 0..<30 {
                let point = headPoint(0.1, 0.5)
                event(.leftMouseDown, point)
                try await Task.sleep(for: .milliseconds(12))
                event(.leftMouseUp, point)
                try await Task.sleep(for: .milliseconds(20))
            }
            try await Task.sleep(for: .milliseconds(650))
            try await NativeSceneExport.capture(entities, to: directory.appendingPathComponent("touch-04-settled.png"))
            let matrix = rig.root.transform.matrix
            save(["source": "Native NSWindow events through SwiftUI; actual RealityKit scene captures",
                  "sequences": results, "repeatedTaps": 30, "released": !controller.touching,
                  "finite": matrix.columns.3.x.isFinite && matrix.columns.3.y.isFinite,
                  "windowNumber": window.windowNumber])
        }
    }
    func makeNSView(context: Context) -> ReplayView { let view = ReplayView(); view.controller = controller; view.entities = entities; return view }
    func updateNSView(_ view: ReplayView, context: Context) { view.controller = controller; view.entities = entities }
}
#endif
