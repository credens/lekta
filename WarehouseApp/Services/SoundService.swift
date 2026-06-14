import AVFoundation
import UIKit

enum SoundService {
    private static var player: AVAudioPlayer?

    static func playPip() {
        play(frequency: 1760, duration: 0.07, volume: 0.65)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func playError() {
        play(frequency: 440, duration: 0.12, volume: 0.5)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func playSuccess() {
        play(frequency: 1047, duration: 0.10, volume: 0.6)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Internal

    private static func play(frequency: Double, duration: Double, volume: Float) {
        guard let data = makeWAV(frequency: frequency, duration: duration) else { return }
        player = try? AVAudioPlayer(data: data)
        player?.volume = volume
        player?.play()
    }

    private static func makeWAV(frequency: Double, duration: Double) -> Data? {
        let sampleRate = 44100
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        let fadeStart = duration * 0.65
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            var amp = sin(2.0 * .pi * frequency * t)
            if t > fadeStart { amp *= 1.0 - (t - fadeStart) / (duration - fadeStart) }
            samples[i] = Int16(amp * 12_000)
        }

        let dataSize = count * 2
        var wav = Data()
        func le<T: FixedWidthInteger>(_ v: T) { var x = v.littleEndian; withUnsafeBytes(of: &x) { wav.append(contentsOf: $0) } }
        wav.append(contentsOf: "RIFF".utf8); le(UInt32(36 + dataSize))
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8); le(UInt32(16)); le(UInt16(1)); le(UInt16(1))
        le(UInt32(sampleRate)); le(UInt32(sampleRate * 2)); le(UInt16(2)); le(UInt16(16))
        wav.append(contentsOf: "data".utf8); le(UInt32(dataSize))
        for s in samples { le(s) }
        return wav
    }
}
