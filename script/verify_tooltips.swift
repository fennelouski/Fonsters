@main
struct VerifyTooltips {
    @MainActor final class HostWindow: NSWindow {
        override var isKeyWindow: Bool { true }
    }
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = HostWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        let anchor = FonsterMacTooltip.Anchor(frame: NSRect(x: 100, y: 160, width: 80, height: 40))
        anchor.text = "Explore the world and return to a saved place."
        var pointer = NSPoint(x: -10_000, y: -10_000)
        anchor.pointerLocation = { pointer }
        window.contentView!.addSubview(anchor)
        window.makeKeyAndOrderFront(nil)
        let originalKeyWindow = app.keyWindow
        func event(_ option: Bool = false) -> NSEvent {
            NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: option ? [.option] : [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
        }
        func tip() -> NSWindow? { app.windows.first { $0.title == "Fonster tooltip" && $0.isVisible } }
        do {
            func wait(_ ms: Int) { RunLoop.main.run(until: Date().addingTimeInterval(Double(ms) / 1000)) }
            anchor.mouseEntered(with: event())
            wait(100); precondition(tip() == nil)
            wait(600); precondition(tip() != nil && app.keyWindow == originalKeyWindow && !tip()!.canBecomeKey)
            print("PASS: delayed tooltip appears without stealing focus")
            pointer = NSPoint(x: tip()!.frame.midX, y: tip()!.frame.midY)
            anchor.mouseExited(with: event()); wait(500)
            precondition(tip() != nil)
            print("PASS: moving from button onto tooltip keeps it visible")
            pointer = NSPoint(x: -10_000, y: -10_000)
            wait(200)
            precondition(tip()?.contentView?.layer?.animation(forKey: "fonsterTooltipDismiss") != nil)
            if let group = tip()?.contentView?.layer?.animation(forKey: "fonsterTooltipDismiss") as? CAAnimationGroup,
               let shrink = group.animations?.compactMap({ $0 as? CABasicAnimation }).first(where: { $0.keyPath == "transform" }) {
                precondition(shrink.toValue is NSValue, "Core Animation needs a boxed transform to interpolate the shrink")
            }
            wait(300); precondition(tip() == nil)
            print("PASS: leaving both starts shrink/fade and then removes tooltip")
            anchor.mouseEntered(with: event(true)); precondition(tip() != nil)
            anchor.mouseExited(with: event()); wait(160)
            anchor.mouseEntered(with: event(true)); wait(300)
            precondition(tip() != nil && tip()!.contentView!.layer!.animationKeys() == nil)
            print("PASS: Option shows immediately; reentering interrupts dismissal")
            anchor.detach(); precondition(tip() == nil)
            anchor.mouseEntered(with: event()); anchor.mouseExited(with: event())
            wait(700); precondition(tip() == nil)
            anchor.detach()
            print("PASS: exit cancels pending show; detaching removes tooltip and tracking")
        }
    }
}
