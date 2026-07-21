//
//  Theme.swift
//  Fonsters
//
//  Central design system: palette, gradients, radii, button/field styles, and
//  reusable surfaces. The palette is drawn from the app icon — a deep plum "F"
//  with hot-pink creature pixels, muted blue eyes, on warm cream. The colorful
//  creatures are the stars, so the chrome stays warm, soft, and calm.
//
//  This file is compiled into every target that includes the `Fonsters/` folder
//  (main app + Watch + Clock + iMessage), so it must stay cross-platform: no
//  UIKit/AppKit-only APIs, only SwiftUI primitives available on all platforms.
//

import SwiftUI

// MARK: - Tokens

enum Theme {
    /// Hot pink from the icon's creature pixels — the primary interactive accent (#F0416E).
    static let accent = Color(red: 0.941, green: 0.255, blue: 0.431)
    /// Brighter pink for gradients / dark-mode emphasis (#FF5C88).
    static let accentBright = Color(red: 1.0, green: 0.361, blue: 0.533)
    /// Deeper pink for gradient shadow side (#DB216B).
    static let accentDeep = Color(red: 0.859, green: 0.129, blue: 0.420)
    /// Deep plum/aubergine from the icon letterform (#281038).
    static let plum = Color(red: 0.157, green: 0.063, blue: 0.220)
    /// Muted blue from the icon's eyes — a supporting accent (#28436F).
    static let blue = Color(red: 0.204, green: 0.322, blue: 0.518)
    /// Warm cream from the icon background (#F7F2E7).
    static let cream = Color(red: 0.969, green: 0.949, blue: 0.906)

    // Supporting hues, harmonized with the brand. Used to tell related actions
    // apart (export vs. undo/redo) without returning to a primary-color rainbow.
    static let violet = Color(red: 0.451, green: 0.353, blue: 0.722)
    static let teal = Color(red: 0.157, green: 0.529, blue: 0.529)
    static let amber = Color(red: 0.780, green: 0.502, blue: 0.180)

    // Corner radii
    static let cornerCard: CGFloat = 22
    static let cornerControl: CGFloat = 14

    // Spacing scale
    static let spaceXS: CGFloat = 6
    static let spaceS: CGFloat = 10
    static let spaceM: CGFloat = 16
    static let spaceL: CGFloat = 24

    /// Prominent-button gradient (bright → deep pink).
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accentBright, accentDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Adaptive surfaces

/// Full-screen warm background: cream gradient in light, plum-tinted near-black in dark.
struct FonsterScreenBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if scheme == .dark {
                LinearGradient(
                    colors: [Color(red: 0.086, green: 0.047, blue: 0.122),
                             Color(red: 0.043, green: 0.024, blue: 0.063)],
                    startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(
                    colors: [Theme.cream, Color(red: 0.988, green: 0.973, blue: 0.945)],
                    startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Palette-derived stage tint

private struct StageRGB {
    var r: Double
    var g: Double
    var b: Double

    /// HSV saturation — how vivid the color is.
    var saturation: Double {
        let hi = max(r, max(g, b)), lo = min(r, min(g, b))
        return hi <= 0 ? 0 : (hi - lo) / hi
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}

private func parseStageHex(_ hex: String) -> StageRGB? {
    guard hex.hasPrefix("#") else { return nil }
    let s = String(hex.dropFirst())
    guard let n = Int(s, radix: 16) else { return nil }
    if s.count == 6 {
        return StageRGB(r: Double((n >> 16) & 0xFF) / 255,
                        g: Double((n >> 8) & 0xFF) / 255,
                        b: Double(n & 0xFF) / 255)
    }
    if s.count == 3 {
        return StageRGB(r: Double((n >> 8) & 0xF) * 17 / 255,
                        g: Double((n >> 4) & 0xF) * 17 / 255,
                        b: Double(n & 0xF) * 17 / 255)
    }
    return nil
}

private extension StageRGB {
    var hsv: (h: Double, s: Double, v: Double) {
        let hi = max(r, max(g, b)), lo = min(r, min(g, b))
        let d = hi - lo
        var h = 0.0
        if d > 0 {
            if hi == r { h = (g - b) / d + (g < b ? 6 : 0) }
            else if hi == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h /= 6
        }
        return (h, hi <= 0 ? 0 : d / hi, hi)
    }

    static func fromHSV(h: Double, s: Double, v: Double) -> StageRGB {
        guard s > 0 else { return StageRGB(r: v, g: v, b: v) }
        let sector = Int(h * 6) % 6
        let f = h * 6 - Double(Int(h * 6))
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch sector {
        case 0: return StageRGB(r: v, g: t, b: p)
        case 1: return StageRGB(r: q, g: v, b: p)
        case 2: return StageRGB(r: p, g: v, b: t)
        case 3: return StageRGB(r: p, g: q, b: v)
        case 4: return StageRGB(r: t, g: p, b: v)
        default: return StageRGB(r: v, g: p, b: q)
        }
    }
}

/// The creature's signature hue, as a glow color. Creature palettes are frequently
/// near-black or desaturated, and using them raw washes the stage out to gray — so
/// we take the most vivid entry and lift its saturation/brightness into a real hue.
private func stageSpotlight(seed: String) -> Color {
    let effective = seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
    let (palette, _) = getPaletteForSeed(seed: effective)
    let parsed = palette.filter { $0 != TRANSPARENT }.compactMap(parseStageHex)
    let fallback = StageRGB(r: 0.941, g: 0.255, b: 0.431) // brand pink
    let best = parsed.max(by: { $0.saturation < $1.saturation }) ?? fallback
    let (h, s, v) = best.hsv
    guard s > 0.05 else { return Theme.accent }  // truly gray palette → brand pink
    return StageRGB.fromHSV(h: h, s: max(0.55, s), v: max(0.80, v)).color
}

/// Whether the creature actually *renders* dark, so the stage can guarantee contrast.
///
/// This weights each palette color by how many cells use it, rather than averaging the
/// palette array. A palette is often [near-black, white, pale mint]: averaging the array
/// calls that "light" even though the creature draws almost entirely in the near-black.
private func creatureIsDark(seed: String) -> Bool {
    let effective = seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
    let (palette, _) = getPaletteForSeed(seed: effective)
    let luminances: [Double?] = palette.map { hex in
        guard hex != TRANSPARENT, let c = parseStageHex(hex) else { return nil }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    let grid = generateCreatureGrid(seed: effective)
    var total = 0.0
    var count = 0.0
    for row in grid {
        for cell in row {
            let index = Int(cell)
            guard index >= 0, index < luminances.count, let lum = luminances[index] else { continue }
            total += lum
            count += 1
        }
    }
    guard count > 0 else { return true }
    return total / count < 0.5
}

/// A soft, warm "stage" the creature sits on, lit by a spotlight in the creature's
/// own signature color. The base brightness flips with the creature's luminance so a
/// near-black creature never sits on near-black, and vice versa.
struct CreatureStage: View {
    let seed: String
    var cornerRadius: CGFloat = Theme.cornerCard
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = scheme == .dark
        let spot = stageSpotlight(seed: seed)
        let creatureDark = creatureIsDark(seed: seed)

        let baseColors: [Color] = {
            if isDark {
                // Near-black creatures need a genuinely mid-toned card to read
                // against — a lightly lifted plum is not enough separation.
                return creatureDark
                    ? [Color(red: 0.408, green: 0.353, blue: 0.482),
                       Color(red: 0.310, green: 0.263, blue: 0.384)]
                    : [Color(red: 0.129, green: 0.078, blue: 0.180),
                       Color(red: 0.067, green: 0.039, blue: 0.098)]
            }
            // Light mode: pale card for dark creatures, warm deeper card for pale ones.
            return creatureDark
                ? [Color.white, Theme.cream]
                : [Color(red: 0.831, green: 0.796, blue: 0.749),
                   Color(red: 0.741, green: 0.702, blue: 0.659)]
        }()

        // Keep the spotlight subtle enough that the base tone still carries contrast.
        let spotStrong = isDark ? 0.24 : 0.24
        let spotSoft = isDark ? 0.09 : 0.08

        shape
            .fill(
                LinearGradient(colors: baseColors, startPoint: .top, endPoint: .bottom)
            )
            .overlay {
                // Spotlight in the creature's own hue, centered behind it.
                shape.fill(
                    RadialGradient(
                        colors: [spot.opacity(spotStrong), spot.opacity(spotSoft), .clear],
                        center: .center, startRadius: 0, endRadius: 280)
                )
            }
            .overlay {
                shape.strokeBorder(
                    isDark ? Color.white.opacity(0.10) : Theme.plum.opacity(0.07),
                    lineWidth: 1)
            }
            .compositingGroup()
    }
}

// MARK: - Card / section modifiers

private struct FonsterCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(scheme == .dark ? Color.white.opacity(0.08) : Theme.plum.opacity(0.06))
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.28 : 0.06), radius: 12, x: 0, y: 6)
    }
}

private struct FonsterSectionLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

extension View {
    /// Soft rounded card surface with subtle border and shadow.
    func fonsterCard(cornerRadius: CGFloat = Theme.cornerCard, padding: CGFloat = Theme.spaceM) -> some View {
        modifier(FonsterCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Small uppercase tracked "kicker" label style for field/section headers.
    func fonsterSectionLabel() -> some View {
        modifier(FonsterSectionLabelModifier())
    }
}

// MARK: - Pill

/// Small rounded pill for metadata (e.g. birthday). Tinted, translucent.
struct FonsterPill<Content: View>: View {
    var tint: Color = Theme.accent
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 5) {
            content()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.vertical, 5)
        .padding(.horizontal, 11)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.18)))
    }
}

// MARK: - Button styles

/// Filled capsule with the accent gradient — for the primary action on a screen.
struct FonsterProminentButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 22)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Capsule(style: .continuous).fill(Theme.accentGradient))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.18)))
            .shadow(color: Theme.accent.opacity(0.35), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Soft, translucent tinted capsule — for secondary actions (export, refresh, …).
struct FonsterSoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Capsule(style: .continuous).fill(tint.opacity(0.15)))
            .overlay(Capsule(style: .continuous).strokeBorder(tint.opacity(0.20)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Circular soft icon button — for compact icon actions (random-source picker, etc.).
struct FonsterIconButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var diameter: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: diameter * 0.4, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(tint.opacity(0.15)))
            .overlay(Circle().strokeBorder(tint.opacity(0.20)))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .contentShape(Circle())
    }
}

// MARK: - Text field style

private struct FonsterFieldBackground: View {
    @Environment(\.colorScheme) private var scheme
    var focused: Bool
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cornerControl, style: .continuous)
        shape
            .fill(scheme == .dark ? Color.white.opacity(0.07) : Color.white)
            .overlay(
                shape.strokeBorder(
                    focused ? Theme.accent.opacity(0.7)
                            : (scheme == .dark ? Color.white.opacity(0.10) : Theme.plum.opacity(0.10)),
                    lineWidth: focused ? 1.5 : 1)
            )
    }
}

/// Soft filled text field (replaces the default rounded-border "engineer" look).
struct FonsterFieldStyle: TextFieldStyle {
    var focused: Bool = false
    // swiftlint:disable:next identifier_name
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .background(FonsterFieldBackground(focused: focused))
    }
}
