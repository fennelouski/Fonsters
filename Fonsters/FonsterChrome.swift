import SwiftUI

/// Shared adaptive asset catalog is included in every app and extension target.
/// Artwork keeps its own palette; text and controls follow the system appearance.
enum FonsterChrome {
    static let background = Color("ChromeBackground")
    static let surface = Color("ChromeSurface")
    static let primary = Color("ChromePrimary")
    static let secondary = Color("ChromeSecondary")
    static let onSelection = Color("ChromeOnSelection")
}
