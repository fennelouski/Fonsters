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

/// Curated "fun" fonts available on iOS (and typically macOS). System is fallback.
enum CreatureNameFont {
    static let knownIds: Set<String> = Set(options.map(\.id))
    static let options: [CreatureNameFontOption] = [
        CreatureNameFontOption(id: "system", displayName: "System"),
        CreatureNameFontOption(id: "Chalkduster", displayName: "Chalkduster"),
        CreatureNameFontOption(id: "Papyrus", displayName: "Papyrus"),
        CreatureNameFontOption(id: "Noteworthy-Bold", displayName: "Noteworthy Bold"),
        CreatureNameFontOption(id: "SnellRoundhand-Bold", displayName: "Snell Roundhand"),
        CreatureNameFontOption(id: "MarkerFelt-Wide", displayName: "Marker Felt"),
        CreatureNameFontOption(id: "AvenirNext-Heavy", displayName: "Avenir Next Heavy"),
        CreatureNameFontOption(id: "Georgia-Bold", displayName: "Georgia Bold"),
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
    @AppStorage(creatureNameFontIdKey) private var fontId: String = creatureNameFontIdDefault
    @Environment(\.colorScheme) private var colorScheme

    @State private var tapJiggle: Bool = false

    private var paletteColors: [Color] {
        let colors = opaquePaletteColorsForDisplay(seed: seed, isDarkMode: colorScheme == .dark)
        return colors.isEmpty ? [.primary] : colors
    }

    /// Sign tilt in degrees: ±20° so the name looks like a sign above a door.
    private var signTiltDegrees: Double {
        let u = segmentHash(seed: effectiveSeed, segmentId: "name_sign_tilt")
        return -20 + u * 40
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
                    tapJiggle ? .easeInOut(duration: 0.06).repeatCount(4, autoreverses: true).delay(Double(index) * 0.02) : .default,
                    value: tapJiggle
                )
            }
        }
        .rotationEffect(.degrees(signTiltDegrees))
        .onTapGesture {
            triggerJiggle()
        }
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
        let fontSize = nameBaseSize * sizeScale
        let fontOption = CreatureNameFontOption(id: fontId, displayName: "")
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
            try? await Task.sleep(nanoseconds: 250_000_000)
            tapJiggle = false
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
            List(CreatureNameFont.options) { option in
                Button {
                    fontId = option.id
                    dismiss()
                } label: {
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
            .navigationTitle("Name Font")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
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
