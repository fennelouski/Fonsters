import Foundation

enum CompanionEnvironment: String, CaseIterable, Identifiable {
    case meadow, seaside, moonlit
    var id: String { rawValue }
    var title: String { switch self { case .meadow: "Meadow"; case .seaside: "Seaside"; case .moonlit: "Moonlit garden" } }
    var symbol: String { switch self { case .meadow: "leaf.fill"; case .seaside: "water.waves"; case .moonlit: "moon.stars.fill" } }
}
