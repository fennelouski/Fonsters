#if os(macOS)
import AppKit
import RealityKit

/// An original soft studio environment shared by the native view and scene exports.
@available(macOS 15.0, *)
@MainActor
enum CreatureSceneLighting {
    static let name = "fonsters-soft-studio"
    private static var cached: EnvironmentResource?

    static func environment() async throws -> EnvironmentResource {
        if let cached { return cached }
        let width = 256, height = 128
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            let vertical = Float(y) / Float(height - 1)
            for x in 0..<width {
                let horizontal = Float(x) / Float(width - 1)
                let softbox = exp(-pow((horizontal - 0.35) / 0.20, 2) - pow((vertical - 0.30) / 0.28, 2))
                let light = 0.53 + (1 - vertical) * 0.25 + softbox * 0.20
                let i = (y * width + x) * 4
                bytes[i] = UInt8(min(255, light * 255))
                bytes[i + 1] = UInt8(min(255, light * 0.97 * 255))
                bytes[i + 2] = UInt8(min(255, light * 0.94 * 255))
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { throw CocoaError(.featureUnsupported) }
        let resource = try await EnvironmentResource(equirectangular: image, withName: name)
        cached = resource
        return resource
    }

    static func studio(for entities: [Entity]) async throws -> Entity {
        let light = Entity(); light.name = name
        light.components.set(ImageBasedLightComponent(source: .single(try await environment()), intensityExponent: 1.0))
        bind(entities, to: light)
        return light
    }

    /// Cloning a scene requires reconnecting the receiver to that scene's own light.
    static func bind(_ entities: [Entity], to light: Entity) {
        func visit(_ entity: Entity) {
            if entity.components[ModelComponent.self] != nil {
                entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
            }
            for child in entity.children { visit(child) }
        }
        for entity in entities { visit(entity) }
    }
}
#endif
