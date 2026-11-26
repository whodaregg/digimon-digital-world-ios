import AVFoundation
import UIKit

@MainActor
final class FeedbackEngine {
    private var player: AVAudioPlayer?
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    init() {
        // .ambient respects the silent switch and allows other audio to keep playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    }
    func play(sound: Bool, haptics: Bool,volume: Double = 0.55) {
        if haptics { haptic.impactOccurred(intensity: 0.65) }
        guard sound else { return }
        if player == nil { player = try? AVAudioPlayer(data: Self.tone()) }
        player?.volume = Float(min(1,max(0,volume))); player?.currentTime = 0; player?.play()
    }
    private static func tone() -> Data {
        let rate = 22050, samples = 1102
        var data = Data()
        func text(_ string: String) { data.append(contentsOf: string.utf8) }
        func u16(_ n: UInt16) { var v = n.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ n: UInt32) { var v = n.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36+samples*2)); text("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate*2)); u16(2); u16(16)
        text("data"); u32(UInt32(samples*2))
        for i in 0..<samples {
            let wave = sin(Double(i) / Double(rate) * 880 * 2 * .pi) >= 0 ? 1.0 : -1.0
            let envelope = 1 - Double(i) / Double(samples)
            let sample = Int16(wave * envelope * 1800)
            u16(UInt16(bitPattern: sample))
        }
        return data
    }
}
