//
//  PopSound.swift
//  Docked
//
//  A tiny synthesized "pop" — a fast pitch-dropping blip with an exponential
//  decay, generated once at first use and played from a small pool so rapid
//  taps overlap. Uses an ambient, mix-with-others audio session so the user's
//  floating PiP video keeps playing underneath.
//

import AVFoundation

final class PopSound {
    static let shared = PopSound()

    private var players: [AVAudioPlayer] = []
    private var idx = 0

    private init() {
        guard let data = Self.makeWAV() else { return }
        for _ in 0..<6 {
            if let p = try? AVAudioPlayer(data: data) {
                p.prepareToPlay()
                p.volume = 0.5
                players.append(p)
            }
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func play() {
        guard !players.isEmpty else { return }
        let p = players[idx % players.count]
        idx += 1
        p.currentTime = 0
        p.play()
    }

    // MARK: synthesis

    private static func makeWAV() -> Data? {
        let sampleRate = 44_100.0
        let duration = 0.11
        let n = Int(sampleRate * duration)
        var samples: [Int16] = []
        samples.reserveCapacity(n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let env = exp(-t * 34.0)                    // fast decay
            let freq = max(90.0, 620.0 * (1.0 - t * 3.2))  // pitch drops
            let tone = sin(2.0 * .pi * freq * t) * env
            let tick = i < 40 ? (Double(40 - i) / 40.0) * 0.45 : 0.0   // attack click
            let v = max(-1.0, min(1.0, (tone + tick) * 0.9))
            samples.append(Int16(v * 32_000))
        }
        return wav(samples: samples, sampleRate: Int(sampleRate))
    }

    private static func wav(samples: [Int16], sampleRate: Int) -> Data {
        let dataSize = samples.count * 2
        func u32(_ v: Int) -> Data { withUnsafeBytes(of: UInt32(v).littleEndian) { Data($0) } }
        func u16(_ v: Int) -> Data { withUnsafeBytes(of: UInt16(v).littleEndian) { Data($0) } }
        var d = Data()
        d.append(Data("RIFF".utf8))
        d.append(u32(36 + dataSize))
        d.append(Data("WAVE".utf8))
        d.append(Data("fmt ".utf8))
        d.append(u32(16))
        d.append(u16(1))            // PCM
        d.append(u16(1))            // mono
        d.append(u32(sampleRate))
        d.append(u32(sampleRate * 2))  // byte rate
        d.append(u16(2))            // block align
        d.append(u16(16))           // bits per sample
        d.append(Data("data".utf8))
        d.append(u32(dataSize))
        for s in samples {
            d.append(withUnsafeBytes(of: s.littleEndian) { Data($0) })
        }
        return d
    }
}
