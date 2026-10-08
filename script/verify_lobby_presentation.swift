import Foundation
import simd

@main struct VerifyLobbyPresentation {
    static func main() {
        let names = ["Coral", "Moss", "Coraline", "Éclair", "Orbit", "Coral"]
        precondition(LobbyPresentation.ranked("coral", names: names) == [0, 5, 2])
        precondition(LobbyPresentation.ranked("  ECLAIR  ", names: names) == [3])
        precondition(LobbyPresentation.ranked("absent", names: names).isEmpty)
        let natural = names.indices.map { LobbyPresentation.Pose(position: [Float($0)-2, 0.594, 0], heading: Float($0)*0.1) }
        var p = LobbyPresentation()
        p.change(query: "coral", care: nil, names: names, natural: natural, immediate: false)
        p.advance(dt: 0.3, natural: natural)
        let interrupted = p.poses
        p.change(query: "moss", care: nil, names: names, natural: natural, immediate: false)
        precondition(p.poses == interrupted, "replacement must start at the actual visible positions")
        p.advance(dt: 1, natural: natural)
        precondition(p.poses[1].position.x == 0 && p.poses[0].position.x != 0)
        p.change(query: "moss", care: 1, names: names, natural: natural, immediate: true)
        precondition(p.poses[1].scale == 0.93)
        precondition(p.poses.enumerated().filter { $0.offset != 1 }.allSatisfy { abs($0.element.position.x) == 18 })
        for _ in 0..<100 {
            p.change(query: "", care: 2, names: names, natural: natural, immediate: false)
            p.advance(dt: 0.08, natural: natural)
            p.change(query: "", care: nil, names: names, natural: natural, immediate: false)
            p.advance(dt: 1, natural: natural)
            precondition(p.poses == natural && !p.borrowingStage)
        }
        p.change(query: "orbit", care: nil, names: names, natural: natural, immediate: true)
        let still = p.poses; p.advance(dt: .nan, natural: natural)
        precondition(p.poses == still && p.matches == [4])
        print("PASS: exact/prefix/diacritic/stable duplicate-name search; front match and side positions; 100 interrupted care/back transitions restore natural poses; immediate static layout and nonfinite input.")
    }
}
