import Foundation

// Regole di Alba: logica pura (solo Foundation, nessun AlarmKit), provata da Tests/main.swift su GitHub Actions.

/// Tutti i numeri delle regole in un unico punto.
enum Costanti {
    static let gradiniProgressiva = 15                   // progressiva = 15 × passoProgressivaSec (15 min)
    static let dbInizialeProgressiva = -60.0             // partenza della progressiva continua (test P1: -30 dB era troppo forte)
    static let ritardoCatena = 300                       // la catena AlarmKit di sicurezza parte a T + 5 min
    static let ritardoCatenaTest = 60                    // mattine di test: T + 1 min
    static let tolleranzaStopTag: TimeInterval = 60      // Stop seguito dal tag entro 60 s: nessuna penalità
    static let finestraPrima: TimeInterval = 2 * 3600    // blocco modifiche e spegnimento anticipato
    static let sogliaVolume: TimeInterval = 120          // sveglie "in corso" più vecchie di così = tasti volume
    static let margineFine: TimeInterval = 60            // dopo l'ultima sveglia della catena
    static let creditiMax = 2
    static let creditiIniziali = 1
    static let ricaricaOgni: TimeInterval = 7 * 86400
    static let tolleranzaOrologio: TimeInterval = 300    // differenze minori non contano come "orologio indietro"
    static let mattineProgrammate = 2
    static let giorniOrizzonte = 8
    static let catenaRidottaMin = 10

    // Punteggio giornaliero
    static let punteggioPieno = 100
    static let penalitaStop = 10
    static let ttsGratis: TimeInterval = 60
    static let ttsPasso: TimeInterval = 15
    static let ttsPenalitaMax = 40
    static let punteggioEmergenza = 20
    static let punteggioFallita = 0
    static let punteggioAnticipo = 100

    static let fraseEmergenza = "Sono sveglio e mi alzo"
    static let secondiEmergenza: Double = 10

    // "Vado a dormire ora"
    static let addormentarsi: TimeInterval = 15 * 60
    static let cicloSonno: TimeInterval = 90 * 60
    static let cicliProposti = [3, 4, 5, 6]
    static let cicliConsigliati = 5
}

extension Mattina {
    /// Quando l'app inizia a suonare: inizio della progressiva, oppure l'orario.
    var inizio: Date {
        parametri.progressiva
            ? orario.addingTimeInterval(-Double(Costanti.gradiniProgressiva * parametri.passoProgressivaSec))
            : orario
    }
    /// Prima sveglia AlarmKit (sirena di sicurezza).
    var inizioCatena: Date { orario.addingTimeInterval(Double(parametri.ritardoCatenaSec ?? 0)) }
    /// Dopo questo istante, senza tag né Emergency, la mattina è fallita.
    var fine: Date { inizioCatena.addingTimeInterval(Double(parametri.durataCatenaMin * 60) + Costanti.margineFine) }
    var conclusa: Bool { esito != nil }
    func inCorso(_ ora: Date) -> Bool { !conclusa && ora >= inizio && ora <= fine }
    func nellaFinestraPrima(_ ora: Date) -> Bool {
        !conclusa && ora < inizio && ora >= inizio.addingTimeInterval(-Costanti.finestraPrima)
    }
    /// Nelle 2 ore prima e durante la mattina la sveglia non si può modificare senza tag.
    func bloccata(_ ora: Date) -> Bool {
        !conclusa && ora >= inizio.addingTimeInterval(-Costanti.finestraPrima) && ora <= fine
    }
}

enum Regole {

    // MARK: - Piano di una mattina

    struct VocePiano: Equatable {
        var fase: Fase
        var indice: Int
        var orario: Date
        var suono: String
    }

    /// Le sveglie AlarmKit di una mattina: solo la catena di sicurezza, tutte con la sirena, una ogni
    /// intervallo da T + ritardo. La suoneria scelta e la progressiva le suona l'app (Guardiano):
    /// se l'app è stata chiusa resta questa catena.
    static func piano(orario t: Date, parametri p: ParametriMattina) -> [VocePiano] {
        let inizio = t.addingTimeInterval(Double(p.ritardoCatenaSec ?? 0))
        let intervallo = max(p.intervalloCatenaSec, 5)
        let totale = max(p.durataCatenaMin, 0) * 60 / intervallo + 1
        return (1...totale).map { i in
            VocePiano(fase: .catena, indice: i, orario: inizio.addingTimeInterval(Double((i - 1) * intervallo)),
                      suono: Suoni.punizione)
        }
    }

    /// Livelli da provare quando AlarmKit segnala il limite: catena intera, catena ridotta, una sola sirena.
    static func riduzioni(_ p: ParametriMattina) -> [(parametri: ParametriMattina, nota: String?)] {
        var livelli: [(parametri: ParametriMattina, nota: String?)] = [(p, nil)]
        var q = p
        if p.durataCatenaMin > Costanti.catenaRidottaMin {
            q.durataCatenaMin = Costanti.catenaRidottaMin
            livelli.append((q, "sirena di sicurezza per \(Costanti.catenaRidottaMin) min"))
        }
        q.durataCatenaMin = 0
        livelli.append((q, "una sola sirena di sicurezza"))
        return livelli
    }

    /// Volume della progressiva continua in dB: da dbIniziale all'inizio a 0 dB all'orario, lineare in dB
    /// (come lo percepisce l'orecchio). Senza progressiva (inizio = orario) subito 0 dB.
    static func dbProgressiva(ora: Date, inizio: Date, orario: Date) -> Double {
        let durata = orario.timeIntervalSince(inizio)
        let p = durata <= 0 ? 1 : min(1, max(0, ora.timeIntervalSince(inizio) / durata))
        return Costanti.dbInizialeProgressiva * (1 - p)
    }

    // MARK: - Quali mattine programmare

    /// Prossime occorrenze di una sveglia attiva in (dopo, fino].
    static func occorrenze(_ s: Sveglia, dopo: Date, fino: Date, calendario cal: Calendar = .current) -> [Date] {
        guard s.attiva else { return [] }
        if let d = s.dataUnaTantum { return d > dopo && d <= fino ? [d] : [] }
        guard !s.giorni.isEmpty else { return [] }
        var risultato: [Date] = []
        var cursore = dopo
        let orario = DateComponents(hour: s.ora, minute: s.minuti, second: 0)
        while let d = cal.nextDate(after: cursore, matching: orario, matchingPolicy: .nextTime), d <= fino {
            if s.giorni.contains(cal.component(.weekday, from: d)) { risultato.append(d) }
            cursore = d
        }
        return risultato
    }

    /// Prossimo orario utile per ora:minuti (oggi se ancora nel futuro, altrimenti domani).
    static func prossimoOrario(ora: Int, minuti: Int, dopo: Date, calendario cal: Calendar = .current) -> Date {
        cal.nextDate(after: dopo, matching: DateComponents(hour: ora, minute: minuti, second: 0),
                     matchingPolicy: .nextTime) ?? dopo
    }

    struct Desiderata: Equatable {
        var svegliaID: UUID
        var orario: Date
    }

    /// Le mattine che devono essere programmate adesso: le prossime 2 di tutte le sveglie normali
    /// più tutte quelle delle sveglie di test. Esclude le mattine già chiuse (per esempio annullate in anticipo).
    static func mattineDesiderate(sveglie: [Sveglia], mattine: [Mattina], ora: Date,
                                  calendario cal: Calendar = .current) -> [Desiderata] {
        let fino = ora.addingTimeInterval(Double(Costanti.giorniOrizzonte) * 86400)
        func giaChiusa(_ id: UUID, _ t: Date) -> Bool {
            mattine.contains { $0.svegliaID == id && $0.conclusa && stessoIstante($0.orario, t) }
        }
        var normali: [Desiderata] = []
        var test: [Desiderata] = []
        for s in sveglie {
            let fineS = s.test != nil ? Date.distantFuture : fino
            for t in occorrenze(s, dopo: ora, fino: fineS, calendario: cal) where !giaChiusa(s.id, t) {
                if s.test != nil { test.append(Desiderata(svegliaID: s.id, orario: t)) }
                else { normali.append(Desiderata(svegliaID: s.id, orario: t)) }
            }
        }
        normali.sort { $0.orario < $1.orario }
        return (Array(normali.prefix(Costanti.mattineProgrammate)) + test).sorted { $0.orario < $1.orario }
    }

    static func stessoIstante(_ a: Date, _ b: Date) -> Bool { abs(a.timeIntervalSince(b)) < 1 }

    /// Sveglie una tantum da togliere: la loro mattina è chiusa (anche annullata in anticipo, quindi prima
    /// dell'orario), oppure l'orario è passato senza mattine aperte.
    static func unaTantumFinite(_ sveglie: [Sveglia], mattine: [Mattina], ora: Date) -> Set<UUID> {
        Set(sveglie.filter { s in
            guard let t = s.dataUnaTantum,
                  !mattine.contains(where: { !$0.conclusa && $0.svegliaID == s.id }) else { return false }
            return t < ora || mattine.contains { $0.conclusa && $0.svegliaID == s.id && stessoIstante($0.orario, t) }
        }.map(\.id))
    }

    static func svegliaBloccata(_ id: UUID, mattine: [Mattina], ora: Date) -> Bool {
        mattine.contains { $0.svegliaID == id && $0.bloccata(ora) }
    }

    // MARK: - Valutazione della mattina

    /// Stop (anche dal pulsante Emergenza) fuori dalla progressiva che NON sono seguiti dal tag entro la tolleranza.
    static func stopPenalizzati(_ eventi: [EventoMattina], tag: Date?) -> Int {
        eventi.filter { e in
            guard e.tipo == .stop || e.tipo == .pulsanteEmergenza, e.fase != .progressiva else { return false }
            if let tag {
                let dopo = tag.timeIntervalSince(e.data)
                if dopo >= 0 && dopo <= Costanti.tolleranzaStopTag { return false }
            }
            return true
        }.count
    }

    static func timeToScan(orario: Date, tag: Date) -> TimeInterval { max(0, tag.timeIntervalSince(orario)) }

    static func punteggio(esito: Esito, stopPenalizzati: Int, timeToScan: TimeInterval?) -> Int? {
        switch esito {
        case .tag:
            let oltre = max(0, (timeToScan ?? 0) - Costanti.ttsGratis)
            let lentezza = min(Costanti.ttsPenalitaMax, Int(oltre / Costanti.ttsPasso))
            return max(0, Costanti.punteggioPieno - stopPenalizzati * Costanti.penalitaStop - lentezza)
        case .anticipo: return Costanti.punteggioAnticipo
        case .emergenza: return Costanti.punteggioEmergenza
        case .fallita, .fallitaVolume: return Costanti.punteggioFallita
        case .fuoriCasa: return nil
        }
    }

    /// Chiude la mattina con l'esito e calcola time-to-scan, stop penalizzati e punteggio.
    static func chiudi(_ m: inout Mattina, esito: Esito, ora: Date) {
        m.esito = esito
        m.chiusa = ora
        let tag: Date? = esito == .tag || esito == .fallitaVolume ? ora : nil
        m.timeToScan = esito == .tag ? timeToScan(orario: m.orario, tag: ora) : nil
        m.stopPenalizzati = stopPenalizzati(m.eventi, tag: tag)
        m.punteggio = punteggio(esito: esito, stopPenalizzati: m.stopPenalizzati ?? 0, timeToScan: m.timeToScan)
    }

    /// Trucco dei tasti volume: una sveglia ancora "in corso" più vecchia della soglia.
    /// Uno Stop vero le ferma tutte, quindi una sveglia vecchia ancora in corso è stata solo zittita.
    static func volumeSospetto(orariInCorso: [Date], ora: Date) -> Bool {
        orariInCorso.contains { ora.timeIntervalSince($0) > Costanti.sogliaVolume }
    }

    // MARK: - Statistiche

    /// Mattine riuscite consecutive (le ultime). Emergency e fallite azzerano, fuori casa mette in pausa.
    static func streak(_ mattine: [Mattina]) -> Int {
        var n = 0
        for m in mattine.filter({ !$0.test && $0.esito != nil }).sorted(by: { $0.orario < $1.orario }) {
            guard let e = m.esito, !e.inPausa else { continue }
            n = e.riuscita ? n + 1 : 0
        }
        return n
    }

    static func riuscite(_ mattine: [Mattina]) -> Int {
        mattine.filter { !$0.test && ($0.esito?.riuscita ?? false) }.count
    }

    /// Mattine che contano nelle statistiche: chiuse, non di test, non fuori casa.
    static func conteggiate(_ mattine: [Mattina]) -> Int {
        mattine.filter { !$0.test && $0.esito != nil && $0.esito != .fuoriCasa }.count
    }

    /// Media del tempo al tag delle ultime 30 mattine chiuse col tag.
    static func mediaTimeToScan(_ mattine: [Mattina]) -> TimeInterval? {
        let tempi = mattine.filter { !$0.test && $0.esito == .tag }
            .sorted { $0.orario > $1.orario }.prefix(30).compactMap(\.timeToScan)
        return tempi.isEmpty ? nil : tempi.reduce(0, +) / Double(tempi.count)
    }

    struct GiornoPunteggio: Equatable {
        var giorno: Date
        var punteggio: Int?
    }

    /// Punteggio degli ultimi `giorni` giorni (oggi compreso, dal più vecchio): l'ultima mattina conteggiata di ogni giorno.
    static func punteggiGiorni(_ mattine: [Mattina], giorni: Int = 7, ora: Date, calendario cal: Calendar = .current) -> [GiornoPunteggio] {
        let oggi = cal.startOfDay(for: ora)
        return (0..<giorni).reversed().compactMap { k in
            guard let giorno = cal.date(byAdding: .day, value: -k, to: oggi) else { return nil }
            let delGiorno = mattine.filter { !$0.test && $0.punteggio != nil && cal.isDate($0.orario, inSameDayAs: giorno) }
            return GiornoPunteggio(giorno: giorno, punteggio: delGiorno.max { $0.orario < $1.orario }?.punteggio)
        }
    }

    // MARK: - Vado a letto

    /// «Vado a letto» premuto in `letto` è finito: una sveglia successiva alla pressione è chiusa o la sua catena
    /// è passata (con l'app viva una mattina fallita si chiude solo al riallineamento successivo).
    /// Le mattine vecchie chiuse dopo la pressione non contano.
    static func vadoALettoFinito(_ letto: Date, mattine: [Mattina], ora: Date) -> Bool {
        mattine.contains { $0.orario > letto && ($0.conclusa || $0.fine < ora) }
    }

    // MARK: - Vado a dormire ora

    struct Ciclo: Equatable {
        var cicli: Int
        var orario: Date
        var durata: TimeInterval
    }

    /// Orari a cicli completi: dal minuto intero successivo + 15 min per addormentarsi + k × 90 min.
    static func cicliSonno(da ora: Date) -> [Ciclo] {
        let base = (ora.timeIntervalSinceReferenceDate / 60).rounded(.up) * 60
        return Costanti.cicliProposti.map { k in
            let durata = Double(k) * Costanti.cicloSonno
            return Ciclo(cicli: k, orario: Date(timeIntervalSinceReferenceDate: base + Costanti.addormentarsi + durata), durata: durata)
        }
    }

    // MARK: - Crediti Emergency

    /// Ricarica di 1 credito ogni 7 giorni, fino al massimo. Se l'orologio è tornato indietro rispetto
    /// all'ultima data vista non ricarica e restituisce una nota da registrare.
    static func ricarica(_ imp: Impostazioni, ora: Date) -> (impostazioni: Impostazioni, nota: String?) {
        var i = imp
        if ora < i.ultimaDataVista.addingTimeInterval(-Costanti.tolleranzaOrologio) {
            return (i, "OROLOGIO INDIETRO: ora \(ora), ultima data vista \(i.ultimaDataVista). Ricarica Emergency sospesa")
        }
        i.ultimaDataVista = max(i.ultimaDataVista, ora)
        if i.creditiEmergenza >= Costanti.creditiMax {
            i.creditiEmergenza = Costanti.creditiMax
            i.ultimaRicarica = ora // il conteggio dei 7 giorni parte quando si usa un credito
            return (i, nil)
        }
        let settimane = Int(ora.timeIntervalSince(i.ultimaRicarica) / Costanti.ricaricaOgni)
        if settimane > 0 {
            i.creditiEmergenza = min(Costanti.creditiMax, i.creditiEmergenza + settimane)
            i.ultimaRicarica = i.ultimaRicarica.addingTimeInterval(Double(settimane) * Costanti.ricaricaOgni)
            return (i, "Ricarica Emergency: crediti \(i.creditiEmergenza)/\(Costanti.creditiMax)")
        }
        return (i, nil)
    }

    static func prossimaRicarica(_ imp: Impostazioni) -> Date? {
        imp.creditiEmergenza >= Costanti.creditiMax ? nil : imp.ultimaRicarica.addingTimeInterval(Costanti.ricaricaOgni)
    }

    // MARK: - Codice segreto, nomi, frase

    static func nuovoCodice() -> String {
        let alfabeto = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // niente 0/O e 1/I
        let c = (0..<8).map { _ in String(alfabeto.randomElement()!) }
        return c[0..<4].joined() + "-" + c[4..<8].joined()
    }

    private static func normalizza(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func codiceValido(_ dato: String?, atteso: String) -> Bool {
        guard let dato else { return false }
        let a = normalizza(dato).replacingOccurrences(of: " ", with: "")
        return !a.isEmpty && a == normalizza(atteso).replacingOccurrences(of: " ", with: "")
    }

    static func stessoNome(_ a: String, _ b: String?) -> Bool {
        guard let b else { return false }
        return normalizza(a) == normalizza(b)
    }

    static func fraseValida(_ s: String) -> Bool { normalizza(s) == normalizza(Costanti.fraseEmergenza) }

    // MARK: - Scadenza del profilo (embedded.mobileprovision)

    /// Il profilo è un plist XML dentro una firma CMS: si estrae il blocco <?xml ... </plist> e si legge ExpirationDate.
    static func scadenza(profilo dati: Data) -> Date? {
        guard let inizio = dati.range(of: Data("<?xml".utf8)),
              let fine = dati.range(of: Data("</plist>".utf8), in: inizio.lowerBound..<dati.endIndex) else { return nil }
        let plist = dati.subdata(in: inizio.lowerBound..<fine.upperBound)
        let radice = try? PropertyListSerialization.propertyList(from: plist, options: [], format: nil)
        return (radice as? [String: Any])?["ExpirationDate"] as? Date
    }
}
