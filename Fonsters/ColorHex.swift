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
