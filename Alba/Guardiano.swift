import AVFoundation
import MediaPlayer
import SwiftUI
import UserNotifications

/// La sveglia suonata dall'app: porting del Laboratorio (prototipo/PORTING_ALBA.md, codice testato in `Lab`).
///
/// Da «Vado a letto» fino alla sveglia, il guardiano suona la suoneria in loop a volume zero
/// (UIBackgroundModes = audio): così iOS non sospende l'app. Solo la notte, per risparmiare batteria;
/// 9 ore prima di ogni sveglia una notifica ricorda di premerlo. All'inizio della mattina lo stesso player alza il
/// volume (progressiva continua da -60 dB), il volume di sistema va al massimo e i tasti volume vengono annullati,
/// Apple Music va in pausa. Quando la mattina si chiude (tag, Emergency, fine) il suono si ferma.
/// Se l'app è stata chiusa resta solo la catena AlarmKit di sicurezza da T+5 min.
///
/// È guidato dai dati: StatoApp gli passa le mattine a ogni salvataggio e un timer da 1 s fa il resto.
@MainActor
final class Guardiano {
    static let shared = Guardiano()

    /// L'audio è in riproduzione (guardiano o sveglia): l'app resta viva in background.
    /// Salvato anche in UserDefaults: se al prossimo avvio è ancora vero, l'app era stata chiusa.
    private(set) var attivo = false {
        didSet {
            StatoApp.shared.guardiano = attivo
            UserDefaults.standard.set(attivo, forKey: Self.chiaveAttivo)
        }
    }

    /// Quando è stato premuto «Vado a letto». Salvato: alla riapertura dell'app il guardiano riparte da solo.
    private var vadoALettoIl = UserDefaults.standard.object(forKey: PromemoriaLetto.chiave) as? Date {
        didSet { UserDefaults.standard.set(vadoALettoIl, forKey: PromemoriaLetto.chiave) }
    }
    private var mattine: [Mattina] = []
    private var fileProgressiva = Suoneria.dolce.file
    private var suona: UUID?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var osservaVolume: NSKeyValueObservation?
    private var ultimoBattito: Date?
    private var ultimoLogVivo = Date.distantPast
    private var ultimoErrore = Date.distantPast
    private var ultimoMinutoLoggato = -1
    private var avvisatoAudioFermo = false
    private var appleMusicDaRiprendere = false

    private static let chiaveAttivo = "guardianoAttivo"
    private static let chiaveBattito = "guardianoUltimoBattito"
    private static let idNotifica = "alba-guardiano"

    /// Trucco non ufficiale (verificato su iOS 26, test L6 e L8): il volume di sistema si cambia solo dal
    /// cursore di un MPVolumeView, che deve stare in una finestra (vedi CursoreVolume).
    static let volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))

    private init() {
        let d = UserDefaults.standard
        if d.bool(forKey: Self.chiaveAttivo) {
            // il processo precedente è morto col guardiano acceso: chiusura dal multitasking, riavvio o iOS
            d.set(false, forKey: Self.chiaveAttivo)
            let ultimo = d.object(forKey: Self.chiaveBattito) as? Date
            EventLog.scrivi("GUARDIANO: app riaperta dopo una CHIUSURA, ultimo segno di vita \(ultimo.map(EventLog.data) ?? "sconosciuto")")
            if let ultimo {
                segnala("Alba si è chiusa alle \(Formati.ora(ultimo)): se non resta aperta in background suona solo la sirena.")
            }
        }
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { n in
            let tipo = (n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            MainActor.assumeIsolated { Guardiano.shared.interruzione(finita: tipo == .ended) }
        }
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Guardiano.shared.uscitaCambiata() }
        }
    }

    /// Chiamato da StatoApp a ogni salvataggio dei dati (solo con l'interfaccia caricata).
    func aggiorna(_ dati: DatiAlba) {
        mattine = dati.mattine
        fileProgressiva = dati.impostazioni.suoneriaProgressiva.file
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                MainActor.assumeIsolated { Guardiano.shared.controlla() }
            }
        }
        controlla()
    }

    /// «Vado a letto»: guardiano acceso fino alla prossima sveglia.
    func vadoALetto() {
        vadoALettoIl = Date()
        EventLog.scrivi("VADO A LETTO: guardiano acceso fino alla prossima sveglia")
        controlla()
        Task { await AlarmEngine.shared.riallinea("vado a letto") } // toglie il promemoria di stasera
    }

    func annullaVadoALetto() {
        vadoALettoIl = nil
        EventLog.scrivi("VADO A LETTO annullato")
        controlla()
        Task { await AlarmEngine.shared.riallinea("vado a letto annullato") } // rimette il promemoria
    }

    private func controlla() {
        let ora = Date()
        if attivo { battito(ora) }

        // 1. Il suono si ferma quando la mattina non è più in corso (tag, Emergency, fine della catena);
        //    all'orario passa dal suono della progressiva alla suoneria della sveglia
        if let id = suona {
            let m = mattine.first { $0.id == id }
            if let m, m.inCorso(ora) {
                if player?.url?.lastPathComponent != suono(m, ora), preparaAudio(suono(m, ora)) {
                    EventLog.scrivi("GUARDIANO: ora suona \(suono(m, ora))")
                }
            } else {
                fermaSuono(m)
            }
        }
        let aperte = mattine.filter { !$0.conclusa && $0.fine > ora }.sorted { $0.inizio < $1.inizio }

        // 2. Inizio della mattina: progressiva o subito al massimo (se l'app è viva, anche senza «Vado a letto»)
        if suona == nil, let m = aperte.first(where: { $0.inCorso(ora) }) { inizia(m, ora) }

        // 3. «Vado a letto» finisce quando è finita una sveglia successiva alla pressione (tag, anticipo,
        //    Emergency, catena passata) o se non resta nessuna sveglia; le mattine vecchie chiuse adesso non contano
        if let letto = vadoALettoIl,
           Regole.vadoALettoFinito(letto, mattine: mattine, ora: ora) || (aperte.isEmpty && ora.timeIntervalSince(letto) > 60) {
            vadoALettoIl = nil
            EventLog.scrivi("VADO A LETTO concluso: la sveglia è finita")
        }

        // 4. Guardiano acceso da «Vado a letto», con la suoneria della prossima già in loop
        if suona == nil {
            if vadoALettoIl != nil, let prossima = aperte.first {
                if !attivo || player?.url?.lastPathComponent != suono(prossima, ora) { avvia(prossima, ora) }
            } else if attivo {
                spegni()
            }
        }

        if let p = player, !p.isPlaying { riparti(p) }
        if suona != nil { aggiornaVolume(ora) }
    }

    // MARK: - Guardiano

    private func avvia(_ prossima: Mattina, _ ora: Date) {
        let riparte = player == nil // altrimenti è solo un cambio di suoneria
        guard preparaAudio(suono(prossima, ora)), riparte else { return }
        attivo = true
        ultimoBattito = ora
        ultimoLogVivo = .distantPast
        uscitaCambiata()
        EventLog.scrivi("GUARDIANO ATTIVO fino a «\(prossima.nome)» \(EventLog.data(prossima.orario)) (uscita: \(Self.uscita()))")
        // Spotify e YouTube non si possono fermare da background (test M6): meglio avvisare la sera
        if AVAudioSession.sharedInstance().isOtherAudioPlaying {
            EventLog.scrivi("GUARDIANO: c'è musica di altre app in riproduzione")
            StatoApp.shared.avvisa("C'è musica in riproduzione: mettila in pausa prima di dormire.")
        }
    }

    private func spegni() {
        player?.stop()
        player = nil
        attivo = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.idNotifica])
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        EventLog.scrivi("GUARDIANO spento")
    }

    private func battito(_ ora: Date) {
        if let b = ultimoBattito, ora.timeIntervalSince(b) > 90 {
            // il timer non è girato: iOS aveva sospeso l'app (audio fermato e non ripartito)
            EventLog.scrivi("GUARDIANO: nessun segno di vita dalle \(EventLog.data(b)): l'app era SOSPESA")
            segnala("Alba è rimasta ferma dalle \(Formati.ora(b)) alle \(Formati.ora(ora)): in quel periodo poteva suonare solo la sirena.")
        }
        ultimoBattito = ora
        UserDefaults.standard.set(ora, forKey: Self.chiaveBattito)
        if ora.timeIntervalSince(ultimoLogVivo) >= 600 {
            ultimoLogVivo = ora
            EventLog.scrivi("GUARDIANO vivo (batteria \(Self.batteria()), uscita \(Self.uscita()))")
            programmaNotificaChiusura()
        }
    }

    /// Notifica "a uomo morto": a ogni battito (10 min) viene spostata 20 minuti avanti. Se l'app muore
    /// o viene sospesa nessuno la sposta più e arriva. Senza suono: può arrivare di notte.
    private func programmaNotificaChiusura() {
        let c = UNMutableNotificationContent()
        c.title = "Alba non è più aperta"
        c.body = "Riaprila e lasciala in background: così la sveglia suona con la tua suoneria, non solo con la sirena."
        let richiesta = UNNotificationRequest(identifier: Self.idNotifica, content: c,
                                              trigger: UNTimeIntervalNotificationTrigger(timeInterval: 20 * 60, repeats: false))
        Task {
            do { try await UNUserNotificationCenter.current().add(richiesta) } catch {
                EventLog.scrivi("ERRORE notifica del guardiano: \(error)")
            }
        }
    }

    // MARK: - Audio

    /// Sessione audio + player in loop. mixWithOthers: niente comandi "pausa" sulla schermata di blocco
    /// e le altre app audio non ci interrompono. Se suona già lo stesso file non tocca niente.
    @discardableResult
    private func preparaAudio(_ suono: String) -> Bool {
        if let p = player, p.url?.lastPathComponent == suono, p.isPlaying { return true }
        guard Date().timeIntervalSince(ultimoErrore) > 10 else { return false } // niente log a raffica
        guard let url = Bundle.main.url(forResource: suono, withExtension: nil) else {
            EventLog.scrivi("GUARDIANO ERRORE: suono \(suono) mancante nell'app")
            ultimoErrore = Date()
            return false
        }
        do {
            let s = AVAudioSession.sharedInstance()
            // mentre suona resta duckOthers (vedi zittisciAltreApp), anche al cambio di suono all'orario
            try s.setCategory(.playback, options: suona == nil ? [.mixWithOthers] : [.mixWithOthers, .duckOthers])
            try s.setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0
            p.play()
            player?.stop() // il nuovo parte prima di fermare il vecchio: l'audio non si interrompe mai
            player = p
        } catch {
            EventLog.scrivi("GUARDIANO ERRORE audio: \(error)")
            ultimoErrore = Date()
            return false
        }
        if osservaVolume == nil {
            // @Sendable: KVO chiama da un thread qualsiasi, il lavoro torna sul main actor
            osservaVolume = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.old, .new]) { @Sendable _, c in
                let da = c.oldValue ?? 0, a = c.newValue ?? 0
                Task { @MainActor in Guardiano.shared.volumeCambiato(da: da, a: a) }
            }
        }
        return true
    }

    private func riparti(_ p: AVAudioPlayer) {
        if !avvisatoAudioFermo { EventLog.scrivi("GUARDIANO: audio FERMO, provo a ripartire"); avvisatoAudioFermo = true }
        try? AVAudioSession.sharedInstance().setActive(true)
        if p.play() { avvisatoAudioFermo = false; EventLog.scrivi("GUARDIANO: audio ripartito") }
    }

    private func interruzione(finita: Bool) {
        guard attivo else { return }
        if finita {
            EventLog.scrivi("GUARDIANO: interruzione audio FINITA, riprendo")
            try? AVAudioSession.sharedInstance().setActive(true)
            player?.play()
        } else {
            EventLog.scrivi("GUARDIANO: interruzione audio INIZIATA (telefonata, Siri o altra app)")
        }
    }

    private func uscitaCambiata() {
        let esterne = AVAudioSession.sharedInstance().currentRoute.outputs
            .filter { $0.portType != .builtInSpeaker && $0.portType != .builtInReceiver }
        let nome = esterne.isEmpty ? nil : esterne.map(\.portName).joined(separator: ", ")
        if nome != StatoApp.shared.uscitaEsterna, attivo { EventLog.scrivi("GUARDIANO: uscita audio cambiata: \(Self.uscita())") }
        StatoApp.shared.uscitaEsterna = nome
    }

    // MARK: - Sveglia

    private func inizia(_ m: Mattina, _ ora: Date) {
        guard preparaAudio(suono(m, ora)) else { return } // riprova al prossimo secondo
        if !attivo { ultimoBattito = ora } // app aperta a mattina iniziata: nessun buco da segnalare
        attivo = true
        suona = m.id
        ultimoMinutoLoggato = -1
        zittisciAltreApp()
        Self.impostaVolumeSistema(1)
        EventLog.scrivi("GUARDIANO: SVEGLIA «\(m.nome)» SUONA dall'app (ritardo \(Int(ora.timeIntervalSince(m.inizio))) s, progressiva \(m.parametri.progressiva ? "sì" : "no"), uscita \(Self.uscita()), volume di sistema \(Self.pct(AVAudioSession.sharedInstance().outputVolume)))")
        aggiornaVolume(ora)
    }

    /// Da background iOS vieta di interrompere le altre app (trappole 1 e 2): si possono solo abbassare
    /// (duckOthers, senza effetto su Spotify e YouTube) e mettere in pausa Apple Music.
    private func zittisciAltreApp() {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            try s.setActive(true)
        } catch { EventLog.scrivi("GUARDIANO ERRORE abbassamento altre app: \(error)") }
        let musica = MPMusicPlayerController.systemMusicPlayer
        if musica.playbackState == .playing {
            musica.pause()
            appleMusicDaRiprendere = true
            EventLog.scrivi("GUARDIANO: Apple Music in pausa (permesso: \(MPMediaLibrary.authorizationStatus() == .authorized ? "sì" : "no"))")
        }
    }

    /// Prima dell'orario, con la progressiva, suona il suono della progressiva; poi la suoneria della sveglia.
    private func suono(_ m: Mattina, _ ora: Date) -> String {
        m.parametri.progressiva && ora < m.orario ? fileProgressiva : m.suoneria
    }

    private func aggiornaVolume(_ ora: Date) {
        guard let id = suona, let m = mattine.first(where: { $0.id == id }) else { return }
        let db = Regole.dbProgressiva(ora: ora, inizio: m.inizio, orario: m.orario)
        player?.volume = Float(pow(10, db / 20))
        // in dB e non in percentuale: i valori bassi risulterebbero tutti "0%"
        let minuto = Int(ora.timeIntervalSince(m.inizio) / 60)
        if minuto != ultimoMinutoLoggato {
            ultimoMinutoLoggato = minuto
            EventLog.scrivi("GUARDIANO minuto \(minuto): volume app \(Int(db.rounded())) dB, sistema \(Self.pct(AVAudioSession.sharedInstance().outputVolume))")
        }
    }

    private func fermaSuono(_ m: Mattina?) {
        suona = nil
        player?.stop()
        player = nil
        // solo adesso: disattivare la sessione prima della sveglia la lascerebbe muta (trappola 1)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        EventLog.scrivi("GUARDIANO: suono dell'app FERMATO (\(m?.esito?.titolo ?? "mattina tolta"))")
        if appleMusicDaRiprendere {
            appleMusicDaRiprendere = false
            if m?.esito != .fallita {
                MPMusicPlayerController.systemMusicPlayer.play()
                EventLog.scrivi("GUARDIANO: Apple Music riparte")
            }
        }
        // i punti 3 e 4 di controlla() chiudono «Vado a letto» e spengono il guardiano
    }

    private func volumeCambiato(da: Float, a: Float) {
        guard suona != nil, a < 0.99 else { return }
        EventLog.scrivi("GUARDIANO: tasto volume durante la sveglia \(Self.pct(da)) → \(Self.pct(a)), lo rialzo")
        Self.impostaVolumeSistema(1)
    }

    static func impostaVolumeSistema(_ v: Float) {
        guard let cursore = volumeView.subviews.compactMap({ $0 as? UISlider }).first else {
            EventLog.scrivi("GUARDIANO: impossibile alzare il volume, cursore di sistema non trovato")
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            cursore.value = v
            try? await Task.sleep(for: .milliseconds(500))
            EventLog.scrivi("GUARDIANO: volume di sistema impostato a \(pct(v)), ora è \(pct(AVAudioSession.sharedInstance().outputVolume))")
        }
    }

    // MARK: - Permessi e avvisi

    /// Permesso per mettere in pausa Apple Music: chiesto una volta, al primo avvio.
    nonisolated static func chiediPermessoMusica() async {
        guard MPMediaLibrary.authorizationStatus() == .notDetermined else { return }
        let stato = await withCheckedContinuation { c in MPMediaLibrary.requestAuthorization { c.resume(returning: $0) } }
        EventLog.scrivi("Permesso Apple Music: \(stato == .authorized ? "concesso" : "negato")")
    }

    /// Avviso persistente nella Home, passando dalla coda di AlarmEngine come tutte le scritture.
    private func segnala(_ testo: String) {
        Task { await AlarmEngine.shared.mostraAvviso(testo) }
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

/// Promemoria «Vado a letto»: una notifica 9 ore prima di ogni sveglia in programma, tranne quella già
/// coperta dal guardiano. Ricalcolati a ogni riallineamento (coda di AlarmEngine), anche ad app chiusa.
enum PromemoriaLetto {
    static let chiave = "guardianoVadoALetto"
    static let anticipo: TimeInterval = 9 * 3600
    private static let prefisso = "alba-letto-"

    /// Restituisce una nota per il log del riallineamento.
    static func sincronizza(_ mattine: [Mattina], ora: Date) async -> String {
        let centro = UNUserNotificationCenter.current()
        let vecchi = await centro.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefisso) }
        centro.removePendingNotificationRequests(withIdentifiers: vecchi)
        let prossime = mattine.filter { !$0.conclusa && !$0.test && $0.fine > ora }.sorted { $0.orario < $1.orario }
        let letto = UserDefaults.standard.object(forKey: chiave) as? Date
        let coperta = letto.flatMap { l in Regole.vadoALettoFinito(l, mattine: mattine, ora: ora) ? nil : prossime.first?.id }
        var orari: [String] = []
        for m in prossime where m.id != coperta {
            let quando = m.orario.addingTimeInterval(-anticipo)
            guard quando > ora else { continue }
            let c = UNMutableNotificationContent()
            c.title = "Sveglia alle \(Formati.ora(m.orario))"
            c.body = "Prima di dormire apri Alba e tocca «Vado a letto»: così suona con la tua suoneria e la progressiva."
            c.sound = .default
            let quale = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: quando)
            do {
                try await centro.add(UNNotificationRequest(identifier: prefisso + m.id.uuidString, content: c,
                                                         trigger: UNCalendarNotificationTrigger(dateMatching: quale, repeats: false)))
                orari.append("\(Formati.giornoBreve(quando)) \(Formati.ora(quando))")
            } catch {
                return "ERRORE promemoria «Vado a letto»: \(error)"
            }
        }
        return orari.isEmpty ? "nessun promemoria «Vado a letto»" : "promemoria «Vado a letto»: \(orari.joined(separator: ", "))"
    }
}

/// Aggancia il cursore del volume direttamente alla finestra: così resta nella gerarchia anche sotto le
/// schermate a tutto schermo (Sveglia in corso), che nascondono la TabView.
struct CursoreVolume: UIViewRepresentable {
    func makeUIView(context: Context) -> Aggancio { Aggancio() }
    func updateUIView(_ uiView: Aggancio, context: Context) {}

    final class Aggancio: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            let cursore = Guardiano.volumeView
            guard let window, cursore.superview !== window else { return }
            cursore.alpha = 0.01
            cursore.isUserInteractionEnabled = false
            window.addSubview(cursore)
        }
    }
}
