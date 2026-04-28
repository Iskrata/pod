import AppKit

final class SoundManager {
    static let shared = SoundManager()

    private let tick = NSSound(named: "Tink")
    private let click = NSSound(named: "Pop")

    private init() {
        tick?.volume = 0.25
        click?.volume = 0.35
    }

    func playTick() {
        guard GlobalState.shared.soundEnabled, let s = tick else { return }
        s.stop(); s.play()
    }

    func playClick() {
        guard GlobalState.shared.soundEnabled, let s = click else { return }
        s.stop(); s.play()
    }
}
