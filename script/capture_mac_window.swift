import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Capture only this checkout's running preview, using existing authorization.
/// Never requests screen-recording permission or captures the desktop.
@main struct CaptureFonstersWindow {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        guard CommandLine.arguments.count == 3, CGPreflightScreenCaptureAccess() else {
            throw NSError(domain: "FonstersCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Existing screen-capture authorization and an app/output path are required. No permission was requested."])
        }
        let appURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
        guard appURL.lastPathComponent == "Fonsters.app", appURL.path.contains("/.prototype-build/"),
              let app = NSWorkspace.shared.runningApplications.first(where: {
                  $0.bundleURL?.standardizedFileURL == appURL
              }) else {
            throw NSError(domain: "FonstersCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Open this checkout's Fonsters preview first."])
        }
        let available = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = available.windows.filter({
            $0.owningApplication?.processID == app.processIdentifier && $0.frame.width > 600 && $0.frame.height > 400
        }).max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else {
            throw NSError(domain: "FonstersCapture", code: 3, userInfo: [NSLocalizedDescriptionKey: "The preview window is not visible."])
        }
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width)
        configuration.height = Int(window.frame.height)
        configuration.scalesToFit = true
        configuration.preservesAspectRatio = true
        configuration.showsCursor = false
        configuration.captureResolution = .best
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let frame = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let image = NSBitmapImageRep(cgImage: frame)
        guard let png = image.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
        print("Captured this checkout's actual Fonsters window: \(frame.width) × \(frame.height)")
    }
}
