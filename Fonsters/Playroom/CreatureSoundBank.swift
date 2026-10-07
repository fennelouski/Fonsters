#if os(macOS) || os(iOS) || os(tvOS)
import AVFoundation
import Foundation

@MainActor
final class CreatureSoundBank {
    private var player: AVAudioPlayer?
    private var sequence = 0
    private(set) var playCount = 0
    var isPlaying: Bool { player?.isPlaying == true }
    func play(_ event: String, preferredVariant: Int? = nil) {
        let variant = preferredVariant.map { min(2, max(0, $0)) } ?? sequence % 3; sequence += 1
        guard let url = Bundle.main.url(forResource: "fonster_\(event)_\(variant)", withExtension: "wav") else { return }
        player?.stop()
        guard let next = try? AVAudioPlayer(contentsOf: url) else { return }
        next.volume = 0.55
        next.prepareToPlay()
        if next.play() { playCount += 1; player = next }
    }
    func stop() { player?.stop(); player = nil }
}
#endif
