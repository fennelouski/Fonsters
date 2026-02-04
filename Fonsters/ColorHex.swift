//
//  ColorHex.swift
//  Fonsters
//
//  Converts hex color strings to SwiftUI Color with full opacity (no transparency).
//  Used for creature name styling so characters never look missing.
//

import SwiftUI

/// Parses a hex string (#RRGGBB or #RGB) and returns a SwiftUI Color with alpha = 1.0.
/// Returns a fallback color if the string is transparent or invalid.
func colorFromHex(_ hex: String) -> Color {
    if hex == TRANSPARENT { return .primary }
    guard hex.hasPrefix("#") else { return .primary }
    let s = String(hex.dropFirst())
    guard let n = Int(s, radix: 16) else { return .primary }
    let r, g, b: Double
    if s.count == 6 {
        r = Double((n >> 16) & 0xFF) / 255
        g = Double((n >> 8) & 0xFF) / 255
        b = Double(n & 0xFF) / 255
    } else if s.count == 3 {
        r = Double((n >> 8) & 0xF) * 17 / 255
        g = Double((n >> 4) & 0xF) * 17 / 255
        b = Double(n & 0xF) * 17 / 255
    } else {
        return .primary
    }
    return Color(red: r, green: g, blue: b)
}

/// Returns opaque colors from a creature palette (filters out transparent).
func opaquePaletteColors(seed: String) -> [Color] {
    let (palette, _) = getPaletteForSeed(seed: seed.isEmpty ? " " : seed)
    return palette
        .filter { $0 != TRANSPARENT && $0.hasPrefix("#") }
        .map { colorFromHex($0) }
}

/// Relative luminance (0...1) for sRGB.
private func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
    func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.299 * linearize(red) + 0.587 * linearize(green) + 0.114 * linearize(blue)
}

/// Returns opaque palette colors, lightening dark colors in dark mode for readability.
func opaquePaletteColorsForDisplay(seed: String, isDarkMode: Bool) -> [Color] {
    let (palette, _) = getPaletteForSeed(seed: seed.isEmpty ? " " : seed)
    let hexStrings = palette.filter { $0 != TRANSPARENT && $0.hasPrefix("#") }
    guard !hexStrings.isEmpty else { return [.primary] }
    let minLuminance: Double = 0.45
    let blendWithWhite: Double = 0.55
    return hexStrings.map { hex in
        if hex == TRANSPARENT { return .primary }
        let s = String(hex.dropFirst())
        guard let n = Int(s, radix: 16) else { return .primary }
        let r, g, b: Double
        if s.count == 6 {
            r = Double((n >> 16) & 0xFF) / 255
            g = Double((n >> 8) & 0xFF) / 255
            b = Double(n & 0xFF) / 255
        } else if s.count == 3 {
            r = Double((n >> 8) & 0xF) * 17 / 255
            g = Double((n >> 4) & 0xF) * 17 / 255
            b = Double(n & 0xF) * 17 / 255
        } else {
            return .primary
        }
        if !isDarkMode { return Color(red: r, green: g, blue: b) }
        let lum = relativeLuminance(red: r, green: g, blue: b)
        if lum >= minLuminance { return Color(red: r, green: g, blue: b) }
        let t = (minLuminance - lum) / (1 - lum)
        let mix = min(1, t / blendWithWhite)
        let r2 = r + (1 - r) * mix
        let g2 = g + (1 - g) * mix
        let b2 = b + (1 - b) * mix
        return Color(red: r2, green: g2, blue: b2)
    }
}
