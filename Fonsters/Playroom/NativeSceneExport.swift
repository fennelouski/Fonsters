#if os(macOS)
import AppKit
import RealityKit
import Metal

/// Exports this app's own live entities with RealityKit. Does not capture the desktop.
/// These files are scene renders, not window screenshots, and need no recording permission.
@available(macOS 15.0, *)
@MainActor
enum NativeSceneExport {
    static func capture(_ entities: [Entity], width: Int = 1280, height: Int = 900, to url: URL) async throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw CocoaError(.featureUnsupported) }
        let renderer = try RealityRenderer()
        let clones = entities.map { $0.clone(recursive: true) }
        if let light = clones.first(where: { $0.name == CreatureSceneLighting.name }) {
            CreatureSceneLighting.bind(clones, to: light)
        }
        renderer.entities.append(contentsOf: clones)
        renderer.activeCamera = clones.first { $0.name == "preview-camera" }
        guard renderer.activeCamera != nil else { throw CocoaError(.featureUnsupported) }
        renderer.cameraSettings.colorBackground = .color(NSColor(srgbRed: 0.94, green: 0.92, blue: 0.94, alpha: 1).cgColor)
        let description = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        description.usage = [.renderTarget, .shaderRead]; description.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: description) else { throw CocoaError(.featureUnsupported) }
        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        for _ in 0..<5 {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    try renderer.updateAndRender(deltaTime: 1.0 / 30, cameraOutput: output, onComplete: { _ in continuation.resume() })
                } catch { continuation.resume(throwing: error) }
            }
        }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url, options: .atomic)
    }
    static func verificationTask(entities: [Entity], label: String) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--scene-export-dir"), index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        Task { @MainActor in
            do {
                for frame in 0..<12 {
                    try await Task.sleep(for: .milliseconds(750))
                    try await capture(entities, to: directory.appendingPathComponent(String(format: "%@-%02d.png", label, frame)))
                }
            } catch {
                try? Data("Native scene export failed: \(error.localizedDescription)".utf8).write(to: directory.appendingPathComponent(label + "-export-error.txt"))
            }
        }
    }
}
#endif
