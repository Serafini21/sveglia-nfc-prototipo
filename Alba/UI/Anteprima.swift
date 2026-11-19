import AVFoundation

/// Anteprima delle suonerie nell'app (anche col telefono in silenzioso). Non serve nessuna capability.
@MainActor
final class Anteprima {
    static let shared = Anteprima()
    private var player: AVAudioPlayer?

    func suona(_ file: String) {
        guard let url = Bundle.main.url(forResource: file, withExtension: nil) else {
            EventLog.scrivi("Anteprima: suono \(file) assente nel bundle")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player?.stop()
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            EventLog.scrivi("ERRORE anteprima \(file): \(error)")
        }
    }

    func ferma() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
