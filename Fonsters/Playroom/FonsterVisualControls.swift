#if os(macOS) || os(iOS)
import SwiftUI

/// Shared visual vocabulary. Color groups actions; symbols, focus, checkmarks,
/// tooltips and native accessibility keep every choice usable without color.
enum FonsterTone {
    case company, play, world, quiet
    var ink: Color {
        switch self {
        case .company: Color(red: 0.19, green: 0.40, blue: 0.31)
        case .play: Color(red: 0.58, green: 0.28, blue: 0.16)
        case .world: Color(red: 0.39, green: 0.28, blue: 0.55)
        case .quiet: Color(red: 0.33, green: 0.34, blue: 0.40)
        }
    }
    var wash: Color {
        switch self {
        case .company: Color(red: 0.86, green: 0.94, blue: 0.89)
        case .play: Color(red: 0.99, green: 0.89, blue: 0.80)
        case .world: Color(red: 0.92, green: 0.88, blue: 0.97)
        case .quiet: Color(red: 0.94, green: 0.94, blue: 0.95)
        }
    }
}

struct FonsterIcon: View {
    let symbol: String
    var tone: FonsterTone = .quiet
    var selected = false
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .medium))
            .frame(width: 44, height: 44)
            .foregroundStyle(selected ? .white : tone.ink)
            .background(selected ? tone.ink : tone.wash, in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(tone.ink, .white)
                        .offset(x: 3, y: 3)
                }
            }
            .accessibilityHidden(true)
    }
}

struct FonsterIconButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let symbol: String
    var tone: FonsterTone = .quiet
    var selected = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { FonsterIcon(symbol: symbol, tone: tone, selected: selected) }
            .buttonStyle(.plain).help(title).accessibilityLabel(title)
            .accessibilityAddTraits(selected ? .isSelected : []).opacity(isEnabled ? 1 : 0.45)
    }
}

struct FonsterIconToggle: View {
    let title: String
    let symbol: String
    var tone: FonsterTone = .quiet
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: { FonsterIcon(symbol: symbol, tone: tone, selected: isOn) }
            .buttonStyle(.plain).help("\(title): \(isOn ? "on" : "off")")
            .accessibilityRepresentation { Toggle(title, isOn: $isOn) }
    }
}

struct FonsterControlGroup<Content: View>: View {
    let title: String
    var tone: FonsterTone = .quiet
    @ViewBuilder let content: Content
    var body: some View {
        HStack(spacing: 6) { content }
            .padding(6).background(tone.wash.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain).accessibilityLabel(title)
    }
}

struct FonsterInfo: View {
    let title: String
    let detail: String
    @State private var showing = false
    var body: some View {
        Button { showing.toggle() } label: { Image(systemName: "info.circle").font(.system(size: 16)).frame(width: 32, height: 32) }
            .buttonStyle(.plain).foregroundStyle(FonsterTone.quiet.ink).help(title).accessibilityLabel(title)
            .popover(isPresented: $showing) {
                Text(detail).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .padding(20).frame(width: 330)
            }
    }
}

struct FonsterStatus: View {
    let symbol: String
    let detail: String
    var tone: FonsterTone = .quiet
    var body: some View {
        Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(tone.ink)
            .frame(minWidth: 28, minHeight: 28).help(detail)
            .accessibilityLabel(detail)
    }
}

struct FonsterPortraitChoice<Portrait: View>: View {
    let name: String
    let selected: Bool
    @ViewBuilder let portrait: Portrait
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            portrait.frame(width: 48, height: 48).padding(10)
                .background(selected ? FonsterTone.world.wash : .white.opacity(0.75), in: RoundedRectangle(cornerRadius: 21))
                .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(selected ? FonsterTone.world.ink : .clear, lineWidth: 2))
                .overlay(alignment: .bottomTrailing) {
                    if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(FonsterTone.world.ink, .white).offset(x: 3, y: 3) }
                }
        }.buttonStyle(.plain).help(name).accessibilityLabel(name)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
