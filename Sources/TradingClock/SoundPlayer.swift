import AVFoundation
import Foundation
import TradingClockCore

/// Plays the bundled chimes and pre-rendered speech. Falls back to the system voice
/// when a speech file is missing so a phrase is never silently dropped.
@MainActor
final class SoundPlayer {
    private var players: [String: AVAudioPlayer] = [:]
    private let synthesizer = AVSpeechSynthesizer()
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        for kind in EventKind.allCases {
            preload("Sounds/\(kind.key)")
            preload("Speech/\(kind.key)")
        }
        preload("Sounds/candle_tick")
    }

    func announce(_ kind: EventKind) {
        guard !settings.muted else { return }
        let chime = settings.chimes(kind)
        if chime { play("Sounds/\(kind.key)") }
        if settings.speaks(kind) {
            // Let the chime ring before the voice comes in.
            let delay: TimeInterval = chime ? 0.55 : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.speak(kind) }
        }
    }

    func candleTick() {
        guard !settings.muted else { return }
        play("Sounds/candle_tick")
    }

    /// For the Test Sounds menu: chime and phrase regardless of per-event settings.
    func preview(_ kind: EventKind) {
        play("Sounds/\(kind.key)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in self?.speak(kind) }
    }

    private func speak(_ kind: EventKind) {
        if let p = players["Speech/\(kind.key)"] {
            p.volume = Float(settings.volume)
            p.currentTime = 0
            p.play()
        } else {
            let u = AVSpeechUtterance(string: kind.phrase)
            u.rate = 0.45
            u.volume = Float(settings.volume)
            synthesizer.speak(u)
        }
    }

    private func play(_ name: String) {
        guard let p = players[name] else { return }
        p.volume = Float(settings.volume)
        p.currentTime = 0
        p.play()
    }

    private func preload(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.prepareToPlay()
        players[name] = p
    }
}
