//
//  CreatureRaster.swift
//  Fonsters
//
//  Converts creature grid + palette to RGBA buffer, CGImage, and animated GIF.
//  Used for display (CreatureAvatarView), PNG export, and GIF export. Works on
//  iOS and macOS (UIKit/AppKit for image types).
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private let defaultHex = "#888888"

private func hexToRgba(_ hex: String) -> (UInt8, UInt8, UInt8, UInt8) {
    if hex == TRANSPARENT { return (0, 0, 0, 0) }
    guard hex.hasPrefix("#"), let n = Int(hex.dropFirst(), radix: 16) else {
        return (0x88, 0x88, 0x88, 255)
    }
    let r = UInt8((n >> 16) & 0xFF)
    let g = UInt8((n >> 8) & 0xFF)
    let b = UInt8(n & 0xFF)
    return (r, g, b, 255)
}

/// Fill RGBA buffer (32*32*4 bytes) from grid and palette.
public func gridToRgbaBuffer(grid: Grid, palette: [String], _ hasOpaqueBackground: Bool) -> [UInt8] {
    let colors: [(UInt8, UInt8, UInt8, UInt8)] = [
        hexToRgba(palette.indices.contains(0) ? palette[0] : "#000000"),
        hexToRgba(palette.indices.contains(1) ? palette[1] : defaultHex),
        hexToRgba(palette.indices.contains(2) ? palette[2] : "#cccccc"),
        hexToRgba(palette.indices.contains(3) ? palette[3] : "#ffffff"),
        hexToRgba(palette.indices.contains(4) ? palette[4] : defaultHex),
        hexToRgba(palette.indices.contains(5) ? palette[5] : "#dddddd"),
    ]
    var buf = [UInt8](repeating: 0, count: GRID_SIZE * GRID_SIZE * 4)
    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            let idx = grid[y][x]
            let i = (y * GRID_SIZE + x) * 4
            if idx == -1 {
                buf[i] = 0
                buf[i + 1] = 0
                buf[i + 2] = 0
                buf[i + 3] = 0
            } else {
                let c = colors[min(Int(idx), colors.count - 1)]
                buf[i] = c.0
                buf[i + 1] = c.1
                buf[i + 2] = c.2
                buf[i + 3] = c.3
            }
        }
    }
    return buf
}

/// Create a CGImage from a creature grid (for the given seed).
/// Uses premultiplied alpha format (kCGImageAlphaPremultipliedLast) which is supported
/// by CGBitmapContextCreate on all platforms including app extensions; non-premultiplied
/// formats can cause context creation to return nil.
public func creatureImage(for seed: String) -> CGImage? {
    let effectiveSeed = seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
    let grid = generateCreatureGrid(seed: effectiveSeed)
    let (palette, _) = getPaletteForSeed(seed: effectiveSeed)
    let rgba = gridToRgbaBuffer(grid: grid, palette: palette, false)

    // Convert to premultiplied alpha (required for CGBitmapContextCreate compatibility)
    var premul = [UInt8](repeating: 0, count: rgba.count)
    for i in stride(from: 0, to: rgba.count, by: 4) {
        let a = Double(rgba[i + 3]) / 255.0
        premul[i] = UInt8(Double(rgba[i]) * a + 0.5)
        premul[i + 1] = UInt8(Double(rgba[i + 1]) * a + 0.5)
        premul[i + 2] = UInt8(Double(rgba[i + 2]) * a + 0.5)
        premul[i + 3] = rgba[i + 3]
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | (CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)

    return premul.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> CGImage? in
        guard let base = ptr.baseAddress else { return nil }
        guard let context = CGContext(
            data: base,
            width: GRID_SIZE,
            height: GRID_SIZE,
            bitsPerComponent: 8,
            bytesPerRow: GRID_SIZE * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        return context.makeImage()
    }
}

/// Scale a CGImage to the given size (e.g. 408 for iMessage regular sticker). Uses nearest-neighbor for crisp pixel-art.
public func scaleImage(_ image: CGImage, toSideLength sideLength: Int) -> CGImage? {
    let w = image.width
    let h = image.height
    guard w > 0, h > 0, sideLength > 0 else { return nil }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | (CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)
    guard let context = CGContext(
        data: nil,
        width: sideLength,
        height: sideLength,
        bitsPerComponent: 8,
        bytesPerRow: sideLength * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { return nil }
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 0, y: 0, width: sideLength, height: sideLength))
    return context.makeImage()
}

/// iMessage sticker recommended size (regular grid): 136 pt × 3 = 408 px.
public let stickerImageSideLength = 408

/// Write a creature as a sticker-sized PNG to the given file URL. Returns true on success. File must stay on disk for MSSticker to use it.
public func writeCreatureStickerPNG(seed: String, to fileURL: URL, sideLength: Int = stickerImageSideLength) -> Bool {
    guard let small = creatureImage(for: seed),
          let scaled = scaleImage(small, toSideLength: sideLength) else { return false }
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dest, scaled, nil)
    guard CGImageDestinationFinalize(dest) else { return false }
    do {
        try (data as Data).write(to: fileURL)
        return true
    } catch {
        return false
    }
}

/// Create animated GIF data from an array of seeds (one frame per seed prefix).
/// frameDelaySeconds: delay between frames (e.g. 0.3 for 300ms).
public func creatureGIFData(
    seeds: [String],
    frameDelaySeconds: Double = 0.3,
    metadata: [String: Any] = [:]
) -> Data? {
    guard !seeds.isEmpty else { return nil }
    var images: [CGImage] = []
    for s in seeds {
        guard let img = creatureImage(for: s) else { continue }
        images.append(img)
    }
    guard !images.isEmpty else { return nil }

    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, images.count, nil) else { return nil }

    var fileProps = metadata
    fileProps[kCGImagePropertyGIFDictionary as String] = [
        kCGImagePropertyGIFLoopCount as String: 0
    ]
    CGImageDestinationSetProperties(dest, fileProps as CFDictionary)

    let frameProps: [String: Any] = [
        kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFDelayTime as String: frameDelaySeconds
        ]
    ]
    for img in images {
        CGImageDestinationAddImage(dest, img, frameProps as CFDictionary)
    }
    guard CGImageDestinationFinalize(dest) else { return nil }
    return data as Data
}
