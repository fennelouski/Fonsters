#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI
import Observation
import CryptoKit
#if os(macOS)
import AppKit
import QuartzCore
#endif
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Shared visual vocabulary. Color groups actions; symbols, focus, checkmarks,
/// tooltips and native accessibility keep every choice usable without color.
enum FonsterTone {
    case company, play, world, quiet
    var ink: Color { Color(prefix + "Ink") }
    var wash: Color { Color(prefix + "Wash") }
    private var prefix: String {
        switch self { case .company: "Company"; case .play: "Play"; case .world: "World"; case .quiet: "Quiet" }
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
            .foregroundStyle(selected ? FonsterChrome.onSelection : tone.ink)
            .background(selected ? tone.ink : tone.wash, in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(tone.ink, FonsterChrome.onSelection)
                        .offset(x: 3, y: 3)
                }
            }
            .accessibilityHidden(true)
    }
}

/// One discovery badge per launch. Every encountered icon registers itself,
/// including icons in panels, without saving names, profiles or analytics.
@MainActor @Observable final class FonsterButtonDiscovery {
    private(set) var suggestion: String?
    private var chosen = false
    private let defaults = UserDefaults.standard
    private var seen: Set<String>
    init() { seen = Set(UserDefaults.standard.stringArray(forKey: "Fonsters.triedButtons.v1") ?? []) }
    func encounter(_ key: String) {
        guard !chosen, !seen.contains(key), !["xmark", "stop.fill", "questionmark.circle", "checkmark", "arrow.right"].contains(key.components(separatedBy: "|").first ?? "") else { return }
        suggestion = key; chosen = true
    }
    func tried(_ key: String) { seen.insert(key); defaults.set(Array(seen).sorted(), forKey: "Fonsters.triedButtons.v1"); if suggestion == key { suggestion = nil } }
}
private struct FonsterDiscoveryKey: EnvironmentKey { static let defaultValue: FonsterButtonDiscovery? = nil }
extension EnvironmentValues {
    var fonsterButtonDiscovery: FonsterButtonDiscovery? { get { self[FonsterDiscoveryKey.self] } set { self[FonsterDiscoveryKey.self] = newValue } }
}
struct FonsterIconButton: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.fonsterButtonDiscovery) private var discovery
    private var discoveryKey: String { symbol + "|" + SHA256.hash(data: Data(title.utf8)).map { String(format: "%02x", $0) }.joined() }
    let title: String
    let symbol: String
    var tone: FonsterTone = .quiet
    var selected = false
    var detail: String? = nil
    let action: () -> Void
    var body: some View {
        Button { discovery?.tried(discoveryKey); action() } label: {
            FonsterIcon(symbol: symbol, tone: tone, selected: selected)
                .overlay(alignment: .topTrailing) { if discovery?.suggestion == discoveryKey { Circle().fill(FonsterTone.play.ink).frame(width: 8, height: 8).accessibilityHidden(true) } }
        }
        .onAppear { if isEnabled { discovery?.encounter(discoveryKey) } }
        .onChange(of: isEnabled) { if isEnabled { discovery?.encounter(discoveryKey) } }
            #if os(tvOS)
            .buttonStyle(.bordered)
            #else
            .buttonStyle(.plain)
            #endif
            .fonsterHelp(title, symbol: symbol, detail: detail).accessibilityLabel(title)
            .accessibilityAddTraits(selected ? .isSelected : []).opacity(isEnabled ? 1 : 0.45)
    }
}

struct FonsterIconToggle: View {
    @Environment(\.fonsterButtonDiscovery) private var discovery
    private var discoveryKey: String { symbol + "|" + SHA256.hash(data: Data(title.utf8)).map { String(format: "%02x", $0) }.joined() }
    let title: String
    let symbol: String
    var tone: FonsterTone = .quiet
    @Binding var isOn: Bool
    var body: some View {
        Button { discovery?.tried(discoveryKey); isOn.toggle() } label: { FonsterIcon(symbol: symbol, tone: tone, selected: isOn) }
            #if os(tvOS)
            .buttonStyle(.bordered)
            #else
            .buttonStyle(.plain)
            #endif
            .onAppear { discovery?.encounter(discoveryKey) }
            .overlay(alignment: .topTrailing) { if discovery?.suggestion == discoveryKey { Circle().fill(FonsterTone.play.ink).frame(width: 8, height: 8).accessibilityHidden(true) } }
            .fonsterHelp("\(title): \(isOn ? "on" : "off")", symbol: symbol)
            .accessibilityRepresentation { Toggle(title, isOn: $isOn) }
    }
}

/// Children publish the same explanations used by their hover and accessibility
/// hints. The panel guide therefore lists the controls actually present.
struct FonsterControlGroup<Content: View>: View {
    let title: String
    var tone: FonsterTone = .quiet
    @ViewBuilder let content: Content
    @State private var items: [FonsterHelpItem] = []
    @State private var showingHelp = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                content
                Button { showingHelp.toggle() } label: {
                    Image(systemName: "questionmark.circle").font(.system(size: 19)).frame(width: 44, height: 44)
                }
                #if os(tvOS)
                .buttonStyle(.bordered)
                #else
                .buttonStyle(.plain)
                #endif
                .foregroundStyle(tone.ink)
                    .fonsterHoverHelp("Explain the \(title.lowercased()) controls").accessibilityLabel("Help: " + title)
                    .accessibilityIdentifier("help_" + title)
            }.onPreferenceChange(FonsterHelpPreference.self) { items = $0 }
        }.padding(6).background(tone.wash.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain).accessibilityLabel(title)
            .modifier(FonsterGuidePresentation(showing: $showingHelp, title: title, items: items))
            .preference(key: FonsterPanelHelpPreference.self, value: items)
    }
}

private struct FonsterGuidePresentation: ViewModifier {
    @Binding var showing: Bool
    let title: String
    let items: [FonsterHelpItem]
    func body(content: Content) -> some View {
        #if os(macOS)
        content.popover(isPresented: $showing) { guide }
        #else
        content.sheet(isPresented: $showing) { guide }
        #endif
    }
    private var guide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    FonsterIconButton(title: "Close help", symbol: "xmark") { showing = false }
                }
                FonsterPanelGuide(title: title, items: items)
            }.padding(20)
        }
        #if os(macOS)
        .frame(width: 420, height: 420)
        #elseif os(tvOS)
        .frame(width: 900, height: 700)
        #elseif os(visionOS)
        .frame(width: 600, height: 600)
        #else
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        #endif
    }
}

/// A single entry point keeps secondary controls off the stage. Touch platforms
/// use a dismissible sheet; Mac uses an anchored popover; TV uses native focus.
struct FonsterControlPanel<Content: View>: View {
    let title: String
    let symbol: String
    var tone: FonsterTone = .quiet
    var compact = false
    @ViewBuilder let content: Content
    @State private var showing = false
    @State private var showingHelp = false
    @State private var items: [FonsterHelpItem] = []
    @State private var groupedItems: [FonsterHelpItem] = []
    @State private var contentHeight: CGFloat = 180
    private var guideItems: [FonsterHelpItem] {
        (items + groupedItems).reduce(into: []) { result, item in
            if !result.contains(item) { result.append(item) }
        }
    }
    var body: some View {
        FonsterIconButton(title: title, symbol: symbol, tone: tone, selected: showing, detail: "Open this panel. Its question mark explains every control; close with X to return.") { showing.toggle() }
            .accessibilityIdentifier("panel_" + title)
            #if os(macOS)
            .popover(isPresented: $showing) { panel }
            .task {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("--verify-manual"), let index = args.firstIndex(of: "--panel-preview"),
                   index + 1 < args.count, args[index + 1] == title { showing = true }
            }
            #else
            .sheet(isPresented: $showing) { panel }
            #endif
    }
    private var panel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 10 : 16) {
                HStack {
                    Label(title, systemImage: symbol).font(.headline)
                    Spacer()
                    Button { showingHelp = true } label: {
                        Image(systemName: "questionmark.circle").font(.system(size: 19)).frame(width: 44, height: 44)
                    }
                    #if os(tvOS)
                    .buttonStyle(.bordered)
                    #else
                    .buttonStyle(.plain)
                    #endif
                    .fonsterHoverHelp("Explain every control in " + title.lowercased())
                    .accessibilityLabel("Panel help: " + title).accessibilityIdentifier("helpPanel_" + title)
                    FonsterIconButton(title: "Close panel", symbol: "xmark") { showing = false }
                }
                VStack(alignment: .leading, spacing: compact ? 8 : 16) { content }
                    .onPreferenceChange(FonsterHelpPreference.self) { items = $0 }
                    .onPreferenceChange(FonsterPanelHelpPreference.self) { groupedItems = $0 }
            }.padding(compact ? 14 : 20)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    if compact && abs(contentHeight - height) > 1 { contentHeight = ceil(height) }
                }
        }
        #if os(macOS)
        .frame(minWidth: compact ? 320 : 360, maxWidth: compact ? 320 : 520,
               minHeight: compact ? nil : 140, maxHeight: compact ? nil : 600)
        .frame(height: compact ? max(140, min(contentHeight, 600)) : nil)
        #elseif os(tvOS)
        .frame(width: compact ? 640 : 1000, height: compact ? max(240, min(contentHeight, 680)) : 680)
        #elseif os(visionOS)
        .frame(width: 600, height: 600)
        #else
        .presentationDetents(compact ? [.height(max(180, min(contentHeight + 20, 480))), .large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
        .accessibilityElement(children: .contain).accessibilityIdentifier("controlPanel_" + title)
        .modifier(FonsterGuidePresentation(showing: $showingHelp, title: title, items: guideItems))
    }
}

struct FonsterHelpItem: Equatable {
    let title: String
    let symbol: String
    let detail: String
}
private struct FonsterHelpPreference: PreferenceKey {
    static let defaultValue: [FonsterHelpItem] = []
    static func reduce(value: inout [FonsterHelpItem], nextValue: () -> [FonsterHelpItem]) {
        for item in nextValue() where !value.contains(item) { value.append(item) }
    }
}

/// Group readers resolve their own controls. Republish that resolved inventory
/// on a distinct key so a panel receives every group through presentation boundaries.
private struct FonsterPanelHelpPreference: PreferenceKey {
    static let defaultValue: [FonsterHelpItem] = []
    static func reduce(value: inout [FonsterHelpItem], nextValue: () -> [FonsterHelpItem]) {
        FonsterHelpPreference.reduce(value: &value, nextValue: nextValue)
    }
}

private struct FonsterHoverHelp: ViewModifier {
    let text: String
    #if os(iOS)
    @State private var hovering = false
    #elseif os(tvOS)
    @FocusState private var hovering: Bool
    #endif
    #if os(iOS) || os(tvOS)
    @State private var showing = false
    @State private var tooltipHovered = false
    @State private var tooltipHeight: CGFloat = 160
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #endif
    func body(content: Content) -> some View {
        #if os(macOS)
        content.background(FonsterMacTooltip(text: text)).accessibilityHint(text)
        #elseif os(iOS) || os(tvOS)
        content.help(text)
            #if os(tvOS)
            .focused($hovering)
            #else
            .onHover { hovering = $0 }
            #endif
            .task(id: hovering || tooltipHovered) {
                guard hovering || tooltipHovered else {
                    do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
                    withAnimation(.easeInOut(duration: 0.22)) { showing = false }
                    return
                }
                guard !showing else { return }
                do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
                withAnimation(.easeInOut(duration: 0.16)) { showing = hovering || tooltipHovered }
            }
            .overlay {
                if showing {
                    GeometryReader { geometry in
                        let frame = geometry.frame(in: .global)
                        let screen = UIScreen.main.bounds
                        #if os(tvOS)
                        let desiredWidth: CGFloat = 360
                        #else
                        let desiredWidth: CGFloat = 260
                        #endif
                        let width = min(desiredWidth, screen.width - 32)
                        let left = max(16, min(frame.midX - width / 2, screen.width - width - 16)) - frame.minX
                        Text(text).font(.callout).foregroundStyle(.primary)
                            .padding(12).frame(width: width, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .fixedSize(horizontal: false, vertical: true)
                            .onHover { tooltipHovered = $0 }
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tooltipHeight = $0 }
                            .offset(x: left, y: frame.maxY + tooltipHeight + 12 < screen.height ? geometry.size.height + 8 : -tooltipHeight - 8)
                    }.transition(reduceMotion ? .opacity : .scale(scale: 0.015).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }.zIndex(showing ? 1000 : 0)
        #else
        content.help(text)
        #endif
    }
}

#if os(macOS)
/// A nonactivating native tooltip remains above clipped panels and never steals
/// focus. Tracking and modifier monitors are removed when its anchor detaches.
private struct FonsterMacTooltip: NSViewRepresentable {
    let text: String
    @Environment(\.colorScheme) private var scheme
    func makeNSView(context: Context) -> Anchor { let anchor = Anchor(); anchor.identifier = .init("FonsterTooltipAnchor"); return anchor }
    func updateNSView(_ view: Anchor, context: Context) {
        view.text = text; view.tipAppearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    }
    static func dismantleNSView(_ view: Anchor, coordinator: ()) { view.detach() }
    @MainActor final class Anchor: NSView {
        var text = ""
        var tipAppearance: NSAppearance?
        private var hovering = false
        private var suppressed = false
        private var pending: DispatchWorkItem?
        private var monitor: Any?
        private var observer: NSObjectProtocol?
        private var panel: TipPanel?
        private var pointerTimer: Timer?
        private var dismissal: DispatchWorkItem?
        private var animationID = UUID()
        private var hiding = false
        var pointerLocation: () -> NSPoint = { NSEvent.mouseLocation }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow(); detach()
            guard let window else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .leftMouseDown, .rightMouseDown]) { [weak self] event in
                let option = event.modifierFlags.contains(.option), flags = event.type == .flagsChanged
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if flags { if self.hovering && option { self.show() } }
                    else { self.suppressed = true; self.hide(animated: false) }
                }
                return event
            }
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.hovering = false; self?.hide(animated: false) }
            }
        }
        override func mouseEntered(with event: NSEvent) {
            hovering = true; suppressed = false
            dismissal?.cancel(); dismissal = nil
            if panel?.isVisible == true { restoreTip(); return }
            if event.modifierFlags.contains(.option) { show(); return }
            let task = DispatchWorkItem { [weak self] in self?.show() }
            pending = task; DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: task)
        }
        override func mouseExited(with event: NSEvent) {
            hovering = false; suppressed = false
            pending?.cancel(); pending = nil
            checkPointer()
        }
        private func checkPointer() {
            guard let panel, panel.isVisible else { return }
            if hovering || panel.frame.contains(pointerLocation()) {
                dismissal?.cancel(); dismissal = nil
                if hiding { restoreTip() }
            } else if dismissal == nil && !hiding {
                let task = DispatchWorkItem { [weak self] in self?.hide() }
                dismissal = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: task)
            }
        }
        private func restoreTip() {
            animationID = UUID(); hiding = false
            panel?.contentView?.layer?.removeAllAnimations()
            panel?.hasShadow = true
        }
        private func show() {
            pending?.cancel(); pending = nil
            guard hovering, !suppressed, let window, window.isKeyWindow, !text.isEmpty else { return }
            let width: CGFloat = 292
            let font = NSFont.systemFont(ofSize: 13)
            let height = min(240, max(44, NSAttributedString(string: text, attributes: [.font: font]).boundingRect(with: NSSize(width: width - 24, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading]).height + 24))
            let tip = panel ?? TipPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            tip.title = "Fonster tooltip"
            panel = tip; tip.isOpaque = false; tip.backgroundColor = .clear; tip.hasShadow = true
            tip.level = .popUpMenu; tip.ignoresMouseEvents = true; tip.appearance = tipAppearance
            let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
            background.material = .popover; background.state = .active; background.wantsLayer = true
            background.layer?.cornerRadius = 10; background.layer?.masksToBounds = true
            let label = NSTextField(wrappingLabelWithString: text)
            label.font = font; label.textColor = .labelColor; label.frame = background.bounds.insetBy(dx: 12, dy: 10)
            background.addSubview(label); tip.contentView = background
            let rect = window.convertToScreen(convert(bounds, to: nil))
            let screen = window.screen?.visibleFrame ?? window.frame
            let x = min(screen.maxX - width - 8, max(screen.minX + 8, rect.midX - width / 2))
            let y = rect.minY - height - 8 >= screen.minY ? rect.minY - height - 8 : rect.maxY + 8
            tip.setFrame(NSRect(x: x, y: min(screen.maxY - height - 8, y), width: width, height: height), display: true)
            tip.orderFront(nil)
            restoreTip()
            pointerTimer?.invalidate()
            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.checkPointer() }
            }
            pointerTimer = timer; RunLoop.main.add(timer, forMode: .common)
        }
        private func hide(animated: Bool = true) {
            pending?.cancel(); pending = nil
            dismissal?.cancel(); dismissal = nil
            guard let panel else { return }
            animationID = UUID(); let id = animationID
            guard animated, panel.isVisible, let layer = panel.contentView?.layer else {
                pointerTimer?.invalidate(); pointerTimer = nil
                layerReset(); panel.orderOut(nil); return
            }
            hiding = true; panel.hasShadow = false
            let animation = CAAnimationGroup()
            var animations: [CAAnimation] = []
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                let size = panel.contentView!.bounds.size
                var transform = CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0)
                transform = CATransform3DScale(transform, 0.015, 0.015, 1)
                transform = CATransform3DTranslate(transform, -size.width / 2, -size.height / 2, 0)
                let shrink = CABasicAnimation(keyPath: "transform")
                shrink.fromValue = CATransform3DIdentity; shrink.toValue = transform
                animations.append(shrink)
            }
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1; fade.toValue = 0; animations.append(fade)
            animation.animations = animations; animation.duration = 0.22
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .forwards; animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: "fonsterTooltipDismiss")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                guard let self, self.animationID == id else { return }
                self.pointerTimer?.invalidate(); self.pointerTimer = nil
                self.layerReset(); panel.orderOut(nil)
            }
        }
        private func layerReset() { panel?.contentView?.layer?.removeAllAnimations(); hiding = false }
        func detach() {
            hovering = false; hide(animated: false)
            if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
            if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil
        }
    }
    @MainActor final class TipPanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
}
#endif

extension View {
    /// Native tooltips on Mac/visionOS, explicit pointer tooltips on iPad/iPhone,
    /// focus hints on TV, and native accessibility hints on every platform.
    func fonsterHoverHelp(_ text: String) -> some View { modifier(FonsterHoverHelp(text: text)) }
}

extension View {
    func fonsterHelp(_ title: String, symbol: String = "circle", detail: String? = nil) -> some View {
        let explanation = detail ?? FonsterControlHelp.explanation(title: title, symbol: symbol)
        return fonsterHoverHelp(title + ". " + explanation).accessibilityHint(explanation)
            .preference(key: FonsterHelpPreference.self, value: [.init(title: title, symbol: symbol, detail: explanation)])
    }
}

struct FonsterPanelGuide: View {
    let title: String
    let items: [FonsterHelpItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.symbol).frame(width: 24).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        Text(item.detail).font(.callout).foregroundStyle(.secondary)
                    }
                }.accessibilityElement(children: .combine)
            }
        }.padding(12).frame(maxWidth: 440, alignment: .leading)
            .accessibilityIdentifier("guide_" + title)
    }
}

enum FonsterControlHelp {
    static func explanation(title: String, symbol: String) -> String {
        let lower = title.lowercased()
        if lower.contains("take over") { return "Stop the agent's current plan and take control. Prepare and start a reviewed plan again when you want agent company." }
        if lower.contains("revoke") { return "Stop agent control and clear its influence and reflection choices. Enable choices again in Agent Studio to start a new reviewed plan." }
        if lower.contains("allow agent") { return "Allow this influence in the local reviewed plan. Tap again to revoke that influence; direct interaction always gives control back to you." }
        if lower.contains("prefer") && lower.contains("voice") { return "Remember a preference for this voice. Choose another heart to favor a different voice; earlier shared preferences remain in memory." }
        if lower.contains("hear") && lower.contains("voice") { return "Preview this local voice with sound enabled. Muting stops playback; you can preview it again." }
        if lower.contains("approve") { return "Add this fictional moment to this Mac's local feed. No external platform is connected. Approved moments currently have no Undo." }
        if lower.contains("pass this draft") { return "Keep this draft out of the local feed. Passing a draft currently has no Undo." }
        if lower.contains("create") && lower.contains("profile") { return "Create a fictional profile on this device. No external account is created. Undo does not delete this local profile." }
        if lower.contains("type a request") { return "Open a request field. Try sends it to the local action interpreter; Cancel stops a pending request. Stop activity ends a reaction already applied." }
        if lower.contains("undo") { return "Restore the last selection, environment, camera or motion setting. Shared moments and sounds already experienced stay in memory." }
        if lower.contains("stop activity") { return "End the current reaction, walk or game immediately. It does not erase shared memories. Choose another action to start again." }
        if lower.contains("panel") || lower.contains("controls") || lower.contains("more reactions") { return "Open a small panel. Its question mark explains each control. Close with X or swipe down to return." }
        switch symbol {
        case "hand.wave", "heart", "hand.raised", "sparkles", "tennisball", "hare", "moon", "eye", "eyes", "figure.flexibility", "arrow.trianglehead.2.clockwise.rotate.90", "person.3.sequence", "chair.lounge":
            return "Start this activity now. A different reaction replaces it immediately; Stop activity ends it. Deliberate shared moments may gently shape personality."
        case "pause.fill", "play.fill": return "Pause or resume movement. Tap again to reverse; Undo also restores the previous setting."
        case "snowflake": return "Keep the scene still while expressions remain available. Tap again or Undo to restore the setting. Reduce Motion also keeps it still."
        case "speaker.wave.2": return "Turn local sound effects on or off. Tap again or Undo to restore the setting."
        case "figure.walk": return "Let Fonsters wander on their own. Tap again or Undo to restore this setting."
        case "mic": return "React to voice activity locally. Permission is requested first. Tap again to stop listening; audio is not recorded."
        case "video": return "Follow a face locally. Permission is requested first. Tap again to turn the camera off; frames are not saved."
        case "scope": return "Keep the camera beside the selected Fonster as it explores. Overview or Undo restores the previous view."
        case "map", "viewfinder": return "Show the whole world and reset the camera. Undo restores the preceding view."
        case "rotate.3d", "arrow.counterclockwise", "arrow.clockwise": return "Turn around the view target. Drag to orbit freely; Undo restores the preceding angle."
        case "plus.magnifyingglass": return "Move the view closer. Pinch or + also zooms in; Undo restores the previous distance."
        case "minus.magnifyingglass": return "Move the view further away. Pinch or − also zooms out; Undo restores the previous distance."
        case "arrow.up", "arrow.down": return "Tilt the camera vertically. Up/down arrow keys do the same; Undo restores the previous angle."
        case "arrow.up.to.line", "arrow.down.to.line": return "Raise or lower the view target. Q/E keys or Option-Shift-drag on Mac move vertically; Undo restores the previous height."
        case "arrow.left", "arrow.right", "arrow.up.forward", "arrow.down.backward": return "Move across the world relative to the camera heading. W/A/S/D or Shift-drag on Mac pans; Undo restores the previous position."
        case "leaf", "leaf.fill", "sun.horizon", "water.waves", "moon.stars", "moon.stars.fill": return "Open this environment around your companion. Undo returns to the previous environment."
        case "person.3": return "Explore the local world with other Fonsters. Close its window or tap Back to return to your companion."
        case "xmark": return "Close this panel and return to the scene."
        default: return "\(title). Selected options show a checkmark. Settings can be changed again; close panels with X to return."
        }
    }
}

/// One-step history for reversible visual controls. Async onChange callbacks
/// acknowledge a restoration without making Undo toggle back to the new value.
struct FonsterControlHistory<Value: Equatable> {
    private(set) var previous: Value?
    private var restoring: Value?
    var canUndo: Bool { previous != nil }
    mutating func record(old: Value, new: Value) {
        guard old != new else { return }
        if restoring == new { restoring = nil; return }
        previous = old; restoring = nil
    }
    mutating func undo() -> Value? {
        guard let previous else { return nil }
        self.previous = nil; restoring = previous; return previous
    }
}

struct FonsterInfo: View {
    let title: String
    let detail: String
    @State private var showing = false
    var body: some View {
        Button { showing.toggle() } label: { Image(systemName: "questionmark.circle").font(.system(size: 16)).frame(width: 32, height: 32) }
            .buttonStyle(.plain).foregroundStyle(FonsterTone.quiet.ink).fonsterHoverHelp(title).accessibilityLabel(title)
            #if os(tvOS)
            .sheet(isPresented: $showing) {
                Text(detail)
                    .font(.body).padding(40)
            }
            #else
            .popover(isPresented: $showing) {
                Text(detail).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .padding(20).frame(width: 330)
            }
            #endif
    }
}

struct FonsterStatus: View {
    let symbol: String
    let detail: String
    var tone: FonsterTone = .quiet
    var body: some View {
        Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(tone.ink)
            .frame(minWidth: 28, minHeight: 28).fonsterHoverHelp(detail)
            .accessibilityLabel(detail)
    }
}

struct FonsterPortraitChoice<Portrait: View>: View {
    let name: String
    let selected: Bool
    var detail: String? = nil
    @ViewBuilder let portrait: Portrait
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            portrait.frame(width: 48, height: 48).padding(10)
                .background(selected ? FonsterTone.world.wash : FonsterChrome.surface, in: RoundedRectangle(cornerRadius: 21))
                .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(selected ? FonsterTone.world.ink : .clear, lineWidth: 2))
                .overlay(alignment: .bottomTrailing) {
                    if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(FonsterTone.world.ink, FonsterChrome.onSelection).offset(x: 3, y: 3) }
                }
        }.buttonStyle(.plain).fonsterHelp(name, detail: detail ?? "Choose this companion. The selected portrait has a checkmark; choose another portrait or Undo to return.").accessibilityLabel(name)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#elseif os(watchOS)
import SwiftUI
extension View {
    func fonsterHoverHelp(_ text: String) -> some View { help(text) }
}
#endif
