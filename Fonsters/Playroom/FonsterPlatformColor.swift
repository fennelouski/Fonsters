#if os(macOS)
import AppKit
typealias FonsterPlatformColor = NSColor
#elseif os(iOS) || os(tvOS)
import UIKit
typealias FonsterPlatformColor = UIColor
extension UIColor {
    convenience init(srgbRed: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(red: srgbRed, green: green, blue: blue, alpha: alpha)
    }
}
#endif
