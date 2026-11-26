import AVFoundation
import UIKit

@MainActor
final class FeedbackEngine {
    enum Cue: String { case key, feed, clean, medicine, evolution, victory, defeat, attention }
    private var players: [Cue:AVAudioPlayer] = [:]
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    init() { try? AVAudioSession.sharedInstance().setCategory(.ambient,mode: .default) }
    func play(sound: Bool,haptics: Bool,volume: Double = 0.55,cue: Cue = .key) {
        if haptics { haptic.impactOccurred(intensity: cue == .attention ? 0.9 : 0.65) }
        guard sound else { return }
        if players[cue] == nil { players[cue] = try? AVAudioPlayer(data: Self.tone(cue)) }
        let player = players[cue]; player?.volume = Float(min(1,max(0,volume))); player?.currentTime = 0; player?.play()
    }
    private static func tone(_ cue: Cue) -> Data {
        let notes: [(Double,Double)]
        switch cue {
        case .key: notes = [(880,0.05)]
        case .feed: notes = [(660,0.07),(990,0.07)]
        case .clean: notes = [(1100,0.07),(780,0.07),(440,0.1)]
        case .medicine: notes = [(520,0.07),(780,0.07),(1040,0.1)]
        case .evolution: notes = [(440,0.1),(550,0.1),(660,0.1),(880,0.2)]
        case .victory: notes = [(660,0.08),(880,0.08),(1320,0.16)]
        case .defeat: notes = [(550,0.1),(440,0.1),(220,0.16)]
        case .attention: notes = [(1200,0.1),(0,0.08),(1200,0.1)]
        }
        let rate = 22050
        let samples = notes.reduce(0) { $0+Int($1.1*Double(rate)) }
        var data = Data()
        func text(_ string: String) { data.append(contentsOf: string.utf8) }
        func u16(_ n: UInt16) { var v = n.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ n: UInt32) { var v = n.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36+samples*2)); text("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate*2)); u16(2); u16(16)
        text("data"); u32(UInt32(samples*2))
        for (frequency,duration) in notes {
            let count = Int(duration*Double(rate))
            for i in 0..<count {
                let wave = frequency == 0 ? 0 : sin(Double(i)/Double(rate)*frequency*2 * .pi) >= 0 ? 1.0 : -1.0
                let envelope = 1-Double(i)/Double(count)
                u16(UInt16(bitPattern: Int16(wave*envelope*1800)))
            }
        }
        return data
    }
}
