import AVFoundation
import MediaPlayer
import SwiftUI

/// Sveglia suonata dall'app stessa (senza AlarmKit) + "guardiano": audio a volume zero in loop
/// che tiene l'app viva in background (UIBackgroundModes = audio). Serve a misurare quando iOS
/// la sospende o la chiude, a bloccare i tasti volume e a provare il risveglio progressivo continuo.
@Observable
final class Lab {
    static let shared = Lab()

    var guardiano = false
    var orario: Date?
    var suona = false
    var volumeApp: Float = 0
    var bloccaVolume = true
    var durataProgressiva = 15 // minuti, 0 = subito al massimo
    var dbIniziale = -60.0 // partenza della progressiva: scelta col test P1 (-30 era troppo forte)
    var suono = "dolce.wav"

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var inizioSuono: Date?
    private var osservaVolume: NSKeyValueObservation?
    private var ultimoBattito = Date.distantPast
    private var ultimoMinutoLoggato = -1
    private var avvisatoAudioFermo = false
    private var appleMusicDaRiprendere = false

    private init() {
        let d = UserDefaults.standard
        if d.bool(forKey: "labGuardiano") {
            let ultimo = (d.object(forKey: "labUltimoBattito") as? Date)?.formatted(date: .omitted, time: .standard) ?? "?"
            Log.add("LAB app riaperta dopo una CHIUSURA: il guardiano era attivo, ultimo segno di vita alle \(ultimo)")
            d.set(false, forKey: "labGuardiano")
        }
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let tipo = (n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            if tipo == .began {
                Log.add("LAB interruzione audio INIZIATA (telefonata, Siri o altra app)")
            } else {
                Log.add("LAB interruzione audio FINITA: riprendo")
                try? AVAudioSession.sharedInstance().setActive(true)
                self?.player?.play()
            }
        }
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in
            Log.add("LAB uscita audio cambiata: \(Lab.uscita())")
        }
    }

    // MARK: guardiano

    func avviaGuardiano() {
        guard preparaAudio() else { return }
        guardiano = true
        UserDefaults.standard.set(true, forKey: "labGuardiano")
        Log.add("LAB guardiano ATTIVO (uscita: \(Lab.uscita()))")
    }

    func fermaGuardiano() {
        guardiano = false
        UserDefaults.standard.set(false, forKey: "labGuardiano")
        if !suona {
            player?.stop(); player = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        Log.add("LAB guardiano disattivato")
    }

    /// Sessione audio + player in loop. mixWithOthers: niente comandi "pausa" sulla schermata di blocco
    /// e le altre app audio non ci interrompono.
    @discardableResult
    private func preparaAudio() -> Bool {
        if let p = player, p.url?.lastPathComponent == suono, p.isPlaying { return true }
        guard let url = Bundle.main.url(forResource: suono, withExtension: nil) else {
            Log.add("LAB ERRORE: suono \(suono) mancante nell'app"); return false
        }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, options: [.mixWithOthers])
            try s.setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = suona ? volumeApp : 0
            p.play()
            player?.stop()
            player = p
        } catch {
            Log.add("LAB ERRORE audio: \(error)"); return false
        }
        avviaTimer()
        if osservaVolume == nil {
            osservaVolume = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.old, .new]) { [weak self] _, c in
                DispatchQueue.main.async { self?.volumeCambiato(da: c.oldValue ?? 0, a: c.newValue ?? 0) }
            }
        }
        return true
    }

    private func avviaTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    // MARK: sveglia

    func imposta(_ data: Date) {
        orario = data
        avviaTimer()
        Log.add("LAB sveglia dell'app impostata alle \(data.formatted(date: .omitted, time: .standard)) (guardiano: \(guardiano ? "ON" : "OFF"), progressiva: \(durataProgressiva) min da \(Int(dbIniziale)) dB, suono: \(suono))")
    }

    private func tick() {
        let ora = Date()
        UserDefaults.standard.set(ora, forKey: "labUltimoBattito")
        if guardiano, ora.timeIntervalSince(ultimoBattito) >= 600 {
            ultimoBattito = ora
            Log.add("LAB guardiano vivo (batteria \(Lab.batteria()))")
        }
        if guardiano || suona, let p = player, !p.isPlaying {
            if !avvisatoAudioFermo { Log.add("LAB audio FERMO: provo a ripartire"); avvisatoAudioFermo = true }
            try? AVAudioSession.sharedInstance().setActive(true)
            if p.play() { avvisatoAudioFermo = false; Log.add("LAB audio ripartito") }
        }
        if let o = orario, !suona, ora >= o { inizia(ritardo: ora.timeIntervalSince(o)) }
        if suona { aggiornaVolume() }
    }

    private func inizia(ritardo: TimeInterval) {
        orario = nil
        suona = true
        inizioSuono = Date()
        ultimoMinutoLoggato = -1
        volumeApp = 0
        preparaAudio()
        zittisciAltreApp()
        if bloccaVolume { Lab.impostaVolumeSistema(1) }
        Log.add("LAB SVEGLIA SUONA (ritardo \(Int(ritardo)) s, uscita: \(Lab.uscita()), volume di sistema \(Lab.pct(AVAudioSession.sharedInstance().outputVolume)))")
        aggiornaVolume()
    }

    /// Da background iOS vieta di interrompere le altre app (errore 560557684 "cannotInterruptOthers",
    /// e disattivare la sessione ci lascia muti finché l'app non torna in primo piano).
    /// Strade permesse: abbassare le altre app (duckOthers, come i navigatori) e mettere in pausa Apple Music.
    private func zittisciAltreApp() {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            try s.setActive(true)
        } catch { Log.add("LAB ERRORE abbassamento altre app: \(error)") }
        let musica = MPMusicPlayerController.systemMusicPlayer
        if musica.playbackState == .playing {
            musica.pause()
            appleMusicDaRiprendere = true
            Log.add("LAB Apple Music stava suonando: chiesta la pausa (permesso libreria: \(MPMediaLibrary.authorizationStatus() == .authorized ? "si" : "no"))")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Log.add("LAB musica di altre app: \(s.isOtherAudioPlaying ? "ancora attiva (dovrebbe essere abbassata)" : "ferma"), Apple Music: \(musica.playbackState == .playing ? "ANCORA in riproduzione" : "ferma")")
        }
    }

    /// Progressiva continua: da dbIniziale a 0 dB, lineare in dB (come la percepisce l'orecchio).
    private func aggiornaVolume() {
        guard let i = inizioSuono else { return }
        let secondi = Date().timeIntervalSince(i)
        let p = durataProgressiva == 0 ? 1 : min(1, secondi / Double(durataProgressiva * 60))
        volumeApp = Float(pow(10, dbIniziale * (1 - p) / 20))
        player?.volume = volumeApp
        let minuto = Int(secondi / 60)
        if minuto != ultimoMinutoLoggato {
            ultimoMinutoLoggato = minuto
            Log.add("LAB minuto \(minuto): volume app \(Int(dbIniziale * (1 - p))) dB, sistema \(Lab.pct(AVAudioSession.sharedInstance().outputVolume))")
        }
    }

    func ferma(motivo: String) {
        guard suona || orario != nil else { return }
        orario = nil
        guard suona else { Log.add("LAB sveglia dell'app annullata (\(motivo))"); return }
        suona = false
        inizioSuono = nil
        volumeApp = 0
        player?.stop()
        player = nil
        // notifyOthers: la musica delle altre app può ripartire
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Log.add("LAB sveglia dell'app FERMATA (\(motivo))")
        if appleMusicDaRiprendere {
            appleMusicDaRiprendere = false
            MPMusicPlayerController.systemMusicPlayer.play()
            Log.add("LAB Apple Music: chiesta la ripartenza")
        }
        if guardiano {
            Log.add(preparaAudio() ? "LAB guardiano ripartito in sottofondo" : "LAB guardiano NON ripartito dopo lo stop")
        }
    }

    // MARK: volume

    private func volumeCambiato(da: Float, a: Float) {
        guard suona else { return }
        Log.add("LAB tasto volume durante la sveglia: \(Lab.pct(da)) -> \(Lab.pct(a))")
        if bloccaVolume && a < 0.99 { Lab.impostaVolumeSistema(1) }
    }

    // Trucco non ufficiale: l'unico modo di cambiare il volume di sistema è il cursore di MPVolumeView.
    static let volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))

    static func impostaVolumeSistema(_ v: Float) {
        guard let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first else {
            Log.add("LAB impossibile alzare il volume: cursore di sistema non trovato"); return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            slider.value = v
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Log.add("LAB volume di sistema impostato a \(pct(v)): ora è \(pct(AVAudioSession.sharedInstance().outputVolume))")
            }
        }
    }

    static func pct(_ v: Float) -> String { "\(Int((v * 100).rounded()))%" }

    static func uscita() -> String {
        AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName).joined(separator: ", ")
    }

    static func batteria() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let l = UIDevice.current.batteryLevel
        return l < 0 ? "?" : pct(l)
    }
}

/// Il cursore del volume deve stare nella gerarchia delle viste perché il trucco funzioni.
struct CursoreVolume: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView { Lab.volumeView }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

struct LabView: View {
    @State private var ora = Date()
    private let lab = Lab.shared

    var body: some View {
        @Bindable var lab = lab
        NavigationStack {
            Form {
                Section {
                    Toggle("Guardiano notturno", isOn: Binding(get: { lab.guardiano },
                                                                set: { $0 ? lab.avviaGuardiano() : lab.fermaGuardiano() }))
                } footer: {
                    Text("Audio a volume zero in loop: tiene l'app viva a schermo bloccato. Spento, iOS sospende l'app pochi secondi dopo che la lasci.")
                }

                Section("Sveglia dell'app (senza AlarmKit)") {
                    DatePicker("Orario", selection: $ora, displayedComponents: .hourAndMinute)
                    Button("Imposta") { lab.imposta(Catena.prossima(ora)) }
                    Button("Test: tra 1 minuto") { lab.imposta(.now.addingTimeInterval(60)) }
                    Picker("Progressiva", selection: $lab.durataProgressiva) {
                        Text("Subito al massimo").tag(0)
                        Text("1 minuto").tag(1)
                        Text("5 minuti").tag(5)
                        Text("15 minuti").tag(15)
                    }
                    Picker("Partenza progressiva", selection: $lab.dbIniziale) {
                        Text("-30 dB (forte)").tag(-30.0)
                        Text("-40 dB").tag(-40.0)
                        Text("-50 dB").tag(-50.0)
                        Text("-60 dB (sussurro)").tag(-60.0)
                    }
                    Picker("Suono", selection: $lab.suono) {
                        Text("Dolce").tag("dolce.wav")
                        Text("Normale").tag("normale.wav")
                        Text("Punizione").tag("punizione.wav")
                    }
                    Toggle("Blocca il volume al massimo", isOn: $lab.bloccaVolume)
                }

                Section("Stato") {
                    Text("Guardiano: \(lab.guardiano ? "ATTIVO" : "spento")")
                    if let o = lab.orario { Text("Suonerà alle \(o.formatted(date: .omitted, time: .standard))") }
                    if lab.suona { Text("STA SUONANDO - volume app \(Lab.pct(lab.volumeApp))").foregroundStyle(.red).bold() }
                }

                Section {
                    Button("Ferma (simula tag)") { _ = Catena.spegniConTag(nomeTag: "laboratorio") }
                    Button("Prova: alza volume di sistema al massimo") { Lab.impostaVolumeSistema(1) }
                    Button("Permesso Apple Music (per metterla in pausa)") {
                        MPMediaLibrary.requestAuthorization { stato in Log.add("LAB permesso Apple Music: \(stato == .authorized ? "concesso" : "negato")") }
                    }
                }
            }
            .navigationTitle("Laboratorio")
        }
    }
}
