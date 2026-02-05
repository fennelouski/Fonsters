//
//  CreatureNameView.swift
//  Fonsters
//
//  Styled creature name for the detail view: user-selected font, palette colors
//  (opaque only), per-character size/quirk (first letter larger, some smaller,
//  last letter crooked 8%, "t" lower 17%), and tap-to-jiggle animation.
//

import SwiftUI

// MARK: - Font option (shared with font picker)

/// AppStorage key for the selected creature name font.
let creatureNameFontIdKey = "creatureNameFontId"

/// Default font id when none is set (fun display font).
let creatureNameFontIdDefault = "Chalkduster"

struct CreatureNameFontOption: Identifiable {
    let id: String
    let displayName: String
    func font(size: CGFloat) -> Font {
        if id == "system" {
            return .title2
        }
        if !CreatureNameFont.knownIds.contains(id) {
            return .title2
        }
        return Font.custom(id, size: size)
    }
}

/// Curated human-readable fonts for creature names. Each monster gets one deterministically from its name.
enum CreatureNameFont {
    static let knownIds: Set<String> = Set(options.map(\.id))
    static let options: [CreatureNameFontOption] = [
        CreatureNameFontOption(id: "Chalkduster", displayName: "Chalkduster"),
        CreatureNameFontOption(id: "Papyrus", displayName: "Papyrus"),
        CreatureNameFontOption(id: "Noteworthy-Bold", displayName: "Noteworthy Bold"),
        CreatureNameFontOption(id: "SnellRoundhand-Bold", displayName: "Snell Roundhand"),
        CreatureNameFontOption(id: "MarkerFelt-Wide", displayName: "Marker Felt"),
        CreatureNameFontOption(id: "AvenirNext-Heavy", displayName: "Avenir Next Heavy"),
        CreatureNameFontOption(id: "Georgia-Bold", displayName: "Georgia Bold"),
        CreatureNameFontOption(id: "AmericanTypewriter-Bold", displayName: "American Typewriter Bold"),
        CreatureNameFontOption(id: "AvenirNext-Medium", displayName: "Avenir Next Medium"),
        CreatureNameFontOption(id: "AvenirNext-Bold", displayName: "Avenir Next Bold"),
        CreatureNameFontOption(id: "Baskerville-Bold", displayName: "Baskerville Bold"),
        CreatureNameFontOption(id: "Cochin-Bold", displayName: "Cochin Bold"),
        CreatureNameFontOption(id: "Futura-Medium", displayName: "Futura Medium"),
        CreatureNameFontOption(id: "Futura-Bold", displayName: "Futura Bold"),
        CreatureNameFontOption(id: "GillSans-Bold", displayName: "Gill Sans Bold"),
        CreatureNameFontOption(id: "Helvetica-Bold", displayName: "Helvetica Bold"),
        CreatureNameFontOption(id: "HelveticaNeue-Bold", displayName: "Helvetica Neue Bold"),
        CreatureNameFontOption(id: "HoeflerText-Black", displayName: "Hoefler Text Black"),
        CreatureNameFontOption(id: "Optima-Bold", displayName: "Optima Bold"),
        CreatureNameFontOption(id: "Palatino-Bold", displayName: "Palatino Bold"),
        CreatureNameFontOption(id: "TimesNewRomanPS-BoldMT", displayName: "Times New Roman Bold"),
        CreatureNameFontOption(id: "TrebuchetMS-Bold", displayName: "Trebuchet MS Bold"),
        CreatureNameFontOption(id: "Verdana-Bold", displayName: "Verdana Bold"),
        CreatureNameFontOption(id: "Georgia", displayName: "Georgia"),
        CreatureNameFontOption(id: "Palatino-Roman", displayName: "Palatino"),
        CreatureNameFontOption(id: "HoeflerText-Regular", displayName: "Hoefler Text"),
        CreatureNameFontOption(id: "Baskerville-SemiBold", displayName: "Baskerville SemiBold"),
        CreatureNameFontOption(id: "Didot-Bold", displayName: "Didot Bold"),
        CreatureNameFontOption(id: "ArialRoundedMTBold", displayName: "Arial Rounded Bold"),
        CreatureNameFontOption(id: "Noteworthy-Light", displayName: "Noteworthy Light"),
        CreatureNameFontOption(id: "SavoyeLetPlain", displayName: "Savoye LET"),
    ]
}

// MARK: - Creature name view

private let nameBaseSize: CGFloat = 34
private let nameFirstLetterScale: CGFloat = 1.2
private let nameSmallLetterScale: CGFloat = 0.9
private let nameLastCrookedDegrees: Double = 12
private let nameTLowerOffset: CGFloat = 3

struct CreatureNameView: View {
    let displayName: String
    let seed: String
    /// When set, tap is handled by the parent (e.g. macOS detail: single = jiggle + creature, double = edit). When nil, tap triggers jiggle internally.
    var externalJiggleTrigger: Binding<Int>? = nil
    @Environment(\.colorScheme) private var colorScheme

    @State private var tapJiggle: Bool = false

    /// Font for this monster: deterministic from its name so each monster has a stable, distinct style.
    private var fontIdForMonster: String {
        let nameSeed = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? effectiveSeed : displayName
        let idx = segmentPick(seed: nameSeed, segmentId: "name_font", n: CreatureNameFont.options.count)
        return CreatureNameFont.options[idx].id
    }

    private var paletteColors: [Color] {
        let colors = opaquePaletteColorsForDisplay(seed: seed, isDarkMode: colorScheme == .dark)
        return colors.isEmpty ? [.primary] : colors
    }

    /// Sign tilt in degrees: -20° to -5° for short names; less angle for longer names so they don't overlap the UI below.
    private var signTiltDegrees: Double {
        let u = segmentHash(seed: effectiveSeed, segmentId: "name_sign_tilt")
        let baseTilt = -20 + u * 15
        let count = displayName.count
        let shortThreshold = 12
        let longThreshold = 28
        let t = min(1, max(0, Double(count - shortThreshold) / Double(max(1, longThreshold - shortThreshold))))
        let scale = 1 - t
        return baseTilt * scale
    }

    private var lastLetterCrooked: Bool {
        segmentRoll(seed: effectiveSeed, segmentId: "name_last_crooked", p: 0.08)
    }

    private var lastLetterAngle: Double {
        guard lastLetterCrooked else { return 0 }
        let u = segmentHash(seed: effectiveSeed, segmentId: "name_last_crooked_angle")
        return -nameLastCrookedDegrees + (u * 2 * nameLastCrookedDegrees)
    }

    private var tLower: Bool {
        segmentRoll(seed: effectiveSeed, segmentId: "name_t_lower", p: 0.17)
    }

    private var effectiveSeed: String {
        seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
    }

    /// Base font size for the name; ~2× on tvOS for better readability at a distance.
    private var effectiveBaseSize: CGFloat {
        #if os(tvOS)
        return nameBaseSize * 2
        #else
        return nameBaseSize
        #endif
    }

    var body: some View {
        let chars = Array(displayName)
        let lastIndex = chars.count - 1
        HStack(spacing: 0) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                characterView(
                    character: String(char),
                    index: index,
                    isLast: index == lastIndex,
                    color: paletteColors[index % paletteColors.count]
                )
                .rotationEffect(.degrees(jiggleRotation(for: index)))
                .animation(
                    tapJiggle ? .easeInOut(duration: 0.12).repeatCount(4, autoreverses: true).delay(Double(index) * 0.04) : .default,
                    value: tapJiggle
                )
            }
        }
        .rotationEffect(.degrees(signTiltDegrees))
        .onChange(of: externalJiggleTrigger?.wrappedValue ?? 0) { _, _ in
            if externalJiggleTrigger != nil { triggerJiggle() }
        }
        .modifier(NameLabelTapModifier(useInternalTap: externalJiggleTrigger == nil, onTap: triggerJiggle))
    }

    /// Per-letter jiggle rotation (each letter animates separately; direction and amount from seed).
    private func jiggleRotation(for index: Int) -> Double {
        guard tapJiggle else { return 0 }
        let u = segmentHash(seed: effectiveSeed, segmentId: "name_jiggle_\(index)")
        return (u * 2 - 1) * 8
    }

    @ViewBuilder
    private func characterView(character: String, index: Int, isLast: Bool, color: Color) -> some View {
        let sizeScale = characterSizeScale(index: index)
        let fontSize = effectiveBaseSize * sizeScale
        let fontOption = CreatureNameFontOption(id: fontIdForMonster, displayName: "")
        let font = fontOption.font(size: fontSize)
        let isT = character == "t" || character == "T"
        let offsetY: CGFloat = (isT && tLower) ? nameTLowerOffset : 0
        let rotation: Double = isLast ? lastLetterAngle : 0

        Text(character)
            .font(font)
            .foregroundStyle(color)
            .offset(y: offsetY)
            .rotationEffect(.degrees(rotation))
    }

    private func characterSizeScale(index: Int) -> CGFloat {
        if index == 0 { return nameFirstLetterScale }
        if segmentRoll(seed: effectiveSeed, segmentId: "name_size_\(index)", p: 0.3) {
            return nameSmallLetterScale
        }
        return 1.0
    }

    private func triggerJiggle() {
        tapJiggle = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 960_000_000)
            tapJiggle = false
        }
    }
}

/// When useInternalTap is true, adds onTapGesture so the name label handles taps (e.g. on iOS). When false, no gesture so the parent can handle single/double tap (e.g. macOS detail).
private struct NameLabelTapModifier: ViewModifier {
    var useInternalTap: Bool
    var onTap: () -> Void
    func body(content: Content) -> some View {
        if useInternalTap {
            content.onTapGesture(perform: onTap)
        } else {
            content
        }
    }
}

// MARK: - Font picker modal

struct CreatureNameFontPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(creatureNameFontIdKey) private var fontId: String = creatureNameFontIdDefault
    var sampleName: String = "Creature Name"

    var body: some View {
        NavigationStack {
            fontPickerList
                #if os(macOS)
                .frame(minWidth: 320, minHeight: 360)
                #endif
            .navigationTitle("Name Font")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var fontPickerList: some View {
        #if os(macOS)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(CreatureNameFont.options) { option in
                    Button {
                        fontId = option.id
                        dismiss()
                    } label: {
                        fontOptionRow(option: option)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        #else
        List(CreatureNameFont.options) { option in
            Button {
                fontId = option.id
                dismiss()
            } label: {
                fontOptionRow(option: option)
            }
        }
        #endif
    }

    private func fontOptionRow(option: CreatureNameFontOption) -> some View {
        HStack {
            Text(sampleName)
                .font(option.font(size: nameBaseSize))
            Spacer()
            if option.id == fontId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("CreatureNameView") {
    VStack {
        CreatureNameView(displayName: "Fonster", seed: "hello")
        CreatureNameView(displayName: "Twilight", seed: "other")
    }
    .padding()
}
