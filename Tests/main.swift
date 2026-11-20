import Foundation

// Test delle regole di Alba. Su GitHub Actions:
//   swiftc Alba/Modello.swift Alba/Regole.swift Tests/main.swift && ./test_regole
// Esce con codice 1 se un controllo fallisce (e la build si ferma).

var falliti = 0
var totali = 0
func verifica(_ ok: Bool, _ nome: String, riga: Int = #line) {
    totali += 1
    if !ok { falliti += 1; print("FALLITO (riga \(riga)): \(nome)") }
}

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "Europe/Rome")!
cal.locale = Locale(identifier: "it_IT")
func data(_ g: Int, _ h: Int, _ m: Int, _ s: Int = 0) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 11, day: g, hour: h, minute: m, second: s))!
}
let T = data(19, 7, 0) // giovedì 19 novembre 2026, 7:00

func mattina(progressiva: Bool = false, eventi: [EventoMattina] = []) -> Mattina {
    let p = ParametriMattina(progressiva: progressiva, ritardoCatenaSec: Costanti.ritardoCatena)
    return Mattina(svegliaID: UUID(), nome: "Test", orario: T, richiesti: p, parametri: p,
                   suoneria: Suoneria.normale.file, eventi: eventi)
}
func stop(_ secondiDaT: Double, fase: Fase = .catena) -> EventoMattina {
    EventoMattina(data: T.addingTimeInterval(secondiDaT), tipo: .stop, fase: fase, indice: 1)
}

// MARK: Piano della mattina
do {
    let p = ParametriMattina(progressiva: true, ritardoCatenaSec: Costanti.ritardoCatena)
    let piano = Regole.piano(orario: T, parametri: p)
    verifica(piano.count == 61, "catena di sicurezza: 61 sveglie (30 min, una ogni 30 s); la progressiva non usa AlarmKit")
    verifica(piano[0].orario == T.addingTimeInterval(300) && piano[0].fase == .catena, "la prima sirena è a T+5 min")
    verifica(piano.allSatisfy { $0.suono == Suoni.punizione }, "tutte con la sirena di punizione")
    verifica(piano.last!.orario == T.addingTimeInterval(300 + 1800), "l'ultima è a T+35 min")
    verifica(zip(piano, piano.dropFirst()).allSatisfy { $1.orario.timeIntervalSince($0.orario) == 30 }, "una ogni 30 s")
    verifica(Regole.piano(orario: T, parametri: ParametriMattina(progressiva: false))[0].orario == T,
             "mattina programmata senza guardiano (ritardo nil): catena dall'orario")

    let rid = Regole.riduzioni(p)
    verifica(rid.count == 3 && rid[1].parametri.durataCatenaMin == 10 && rid[2].parametri.durataCatenaMin == 0,
             "riduzioni: catena intera, 10 min, una sola sirena")
    verifica(rid.allSatisfy { $0.parametri.progressiva }, "le riduzioni non tolgono la progressiva (non usa AlarmKit)")
    verifica(Regole.piano(orario: T, parametri: rid[2].parametri).count == 1, "una sola sirena = 1 sveglia")
}

// MARK: Progressiva continua dell'app
do {
    let inizio = T.addingTimeInterval(-900)
    verifica(Regole.dbProgressiva(ora: inizio, inizio: inizio, orario: T) == -60, "parte da -60 dB")
    verifica(Regole.dbProgressiva(ora: T.addingTimeInterval(-450), inizio: inizio, orario: T) == -30, "a metà -30 dB")
    verifica(Regole.dbProgressiva(ora: T, inizio: inizio, orario: T) == 0, "all'orario 0 dB")
    verifica(Regole.dbProgressiva(ora: T.addingTimeInterval(600), inizio: inizio, orario: T) == 0, "dopo l'orario resta a 0 dB")
    verifica(Regole.dbProgressiva(ora: inizio.addingTimeInterval(-5), inizio: inizio, orario: T) == -60, "prima dell'inizio -60 dB")
    verifica(Regole.dbProgressiva(ora: T, inizio: T, orario: T) == 0, "senza progressiva subito al massimo")
}

// MARK: Vado a letto
do {
    let letto = data(18, 23, 0)
    var ieri = mattina()
    ieri.orario = data(18, 7, 0)
    ieri.esito = .fallita // chiusa adesso dal riallineamento: è precedente, non conta
    verifica(!Regole.vadoALettoFinito(letto, mattine: [ieri, mattina()], ora: data(19, 6, 0)), "di notte: ancora attivo")
    var conTag = mattina()
    conTag.esito = .tag
    verifica(Regole.vadoALettoFinito(letto, mattine: [conTag], ora: data(19, 7, 1)), "tag: finito")
    verifica(Regole.vadoALettoFinito(letto, mattine: [mattina()], ora: data(19, 7, 37)), "catena passata senza chiusura: finito")
    verifica(!Regole.vadoALettoFinito(letto, mattine: [mattina()], ora: data(19, 7, 20)), "sveglia in corso: ancora attivo")
}

// MARK: Dati delle build precedenti
do {
    let vecchi = Data(#"{"progressiva":true,"passoProgressivaSec":60,"intervalloCatenaSec":30,"durataCatenaMin":30}"#.utf8)
    let p = try? JSONDecoder().decode(ParametriMattina.self, from: vecchi)
    verifica(p != nil && p?.ritardoCatenaSec == nil, "i parametri salvati senza ritardo si leggono ancora (ritardo nil)")
    verifica(p != ParametriMattina(progressiva: true, ritardoCatenaSec: Costanti.ritardoCatena),
             "diversi dai nuovi: le mattine vecchie non bloccate vengono riprogrammate")
}

// MARK: Finestre: in corso, 2 ore prima, blocco
do {
    let m = mattina()
    verifica(!m.bloccata(data(19, 4, 59)), "4:59 non bloccata")
    verifica(m.bloccata(data(19, 5, 0)) && m.nellaFinestraPrima(data(19, 5, 0)), "5:00 bloccata e nella finestra di anticipo")
    verifica(m.inCorso(data(19, 7, 20)) && !m.nellaFinestraPrima(data(19, 7, 20)), "7:20 in corso")
    verifica(m.inCorso(data(19, 7, 36, 0)) && !m.inCorso(data(19, 7, 36, 1)), "fine = T + 5 min + 30 min + 60 s")
    var vecchia = m
    vecchia.parametri.ritardoCatenaSec = nil
    verifica(vecchia.inCorso(data(19, 7, 31, 0)) && !vecchia.inCorso(data(19, 7, 31, 1)), "mattina vecchia: fine = T + 30 min + 60 s")
    let p = mattina(progressiva: true)
    verifica(p.inCorso(data(19, 6, 45)) && p.nellaFinestraPrima(data(19, 6, 44)), "con progressiva la mattina inizia a T-15")
    var chiusa = m
    chiusa.esito = .tag
    verifica(!chiusa.bloccata(data(19, 6, 0)) && !chiusa.inCorso(data(19, 7, 5)), "mattina chiusa: né bloccata né in corso")
}

// MARK: Tolleranza, punteggio, esiti
do {
    verifica(Regole.stopPenalizzati([stop(5)], tag: T.addingTimeInterval(50)) == 0, "Stop e tag dopo 45 s: nessuna penalità")
    verifica(Regole.stopPenalizzati([stop(5)], tag: T.addingTimeInterval(70)) == 1, "Stop e tag dopo 65 s: penalità")
    verifica(Regole.stopPenalizzati([stop(5), stop(40), stop(-300, fase: .progressiva)], tag: T.addingTimeInterval(200)) == 2,
             "gli stop della progressiva non contano")
    verifica(Regole.stopPenalizzati([stop(5), stop(35)], tag: T.addingTimeInterval(60)) == 0, "due stop entrambi entro 60 s dal tag")

    verifica(Regole.punteggio(esito: .tag, stopPenalizzati: 0, timeToScan: 30) == 100, "tag in 30 s = 100")
    verifica(Regole.punteggio(esito: .tag, stopPenalizzati: 0, timeToScan: 120) == 96, "tag in 2 min = 96")
    verifica(Regole.punteggio(esito: .tag, stopPenalizzati: 0, timeToScan: 3600) == 60, "lentezza al massimo -40")
    verifica(Regole.punteggio(esito: .tag, stopPenalizzati: 2, timeToScan: 75) == 79, "2 stop e 75 s = 79")
    verifica(Regole.punteggio(esito: .tag, stopPenalizzati: 12, timeToScan: 3600) == 0, "mai sotto zero")
    verifica(Regole.punteggio(esito: .emergenza, stopPenalizzati: 0, timeToScan: nil) == 20, "Emergency = 20")
    verifica(Regole.punteggio(esito: .fallita, stopPenalizzati: 0, timeToScan: nil) == 0, "fallita = 0")
    verifica(Regole.punteggio(esito: .fallitaVolume, stopPenalizzati: 0, timeToScan: nil) == 0, "fallita – volume = 0")
    verifica(Regole.punteggio(esito: .fuoriCasa, stopPenalizzati: 0, timeToScan: nil) == nil, "fuori casa non conteggiata")

    var m = mattina(eventi: [stop(10)])
    Regole.chiudi(&m, esito: .tag, ora: T.addingTimeInterval(40))
    verifica(m.esito == .tag && m.timeToScan == 40 && m.stopPenalizzati == 0 && m.punteggio == 100,
             "Stop, sblocco e tag entro 60 s: esito tag, nessuna penalità")
    var p = mattina(progressiva: true)
    Regole.chiudi(&p, esito: .tag, ora: T.addingTimeInterval(-120))
    verifica(p.timeToScan == 0, "tag durante la progressiva: time-to-scan 0")
}

// MARK: Trucco del volume
do {
    verifica(!Regole.volumeSospetto(orariInCorso: [T], ora: T.addingTimeInterval(119)), "in corso da 119 s: ok")
    verifica(Regole.volumeSospetto(orariInCorso: [T.addingTimeInterval(90), T], ora: T.addingTimeInterval(121)), "in corso da 121 s: volume")
    verifica(!Regole.volumeSospetto(orariInCorso: [], ora: T.addingTimeInterval(9999)), "nessuna in corso: ok")
}

// MARK: Streak e riuscite
do {
    func chiusa(_ e: Esito, giorno: Int, test: Bool = false) -> Mattina {
        var m = mattina()
        m.orario = data(giorno, 7, 0)
        m.esito = e
        m.test = test
        return m
    }
    let storia = [chiusa(.tag, giorno: 10), chiusa(.emergenza, giorno: 11), chiusa(.tag, giorno: 12),
                  chiusa(.fuoriCasa, giorno: 13), chiusa(.anticipo, giorno: 14), chiusa(.fallita, giorno: 9, test: true)]
    verifica(Regole.streak(storia) == 2, "Emergency azzera, fuori casa in pausa, test ignorate")
    verifica(Regole.streak(storia + [chiusa(.fallitaVolume, giorno: 15)]) == 0, "fallita – volume azzera")
    verifica(Regole.riuscite(storia) == 3, "riuscite: tag + anticipo, escluse le test")
}

// MARK: Crediti Emergency
do {
    var imp = Impostazioni()
    imp.creditiEmergenza = 1
    imp.ultimaRicarica = data(1, 12, 0)
    imp.ultimaDataVista = data(1, 12, 0)
    verifica(Regole.ricarica(imp, ora: data(7, 12, 0)).impostazioni.creditiEmergenza == 1, "6 giorni: nessuna ricarica")
    let r = Regole.ricarica(imp, ora: data(8, 12, 0))
    verifica(r.impostazioni.creditiEmergenza == 2 && r.nota != nil, "7 giorni: +1")
    verifica(Regole.ricarica(imp, ora: data(29, 12, 0)).impostazioni.creditiEmergenza == 2, "mai oltre 2")
    var indietro = imp
    indietro.ultimaDataVista = data(20, 12, 0)
    let ri = Regole.ricarica(indietro, ora: data(10, 12, 0))
    verifica(ri.impostazioni.creditiEmergenza == 1 && ri.nota?.contains("OROLOGIO") == true, "orologio indietro: niente ricarica, evento registrato")
    var pieno = imp
    pieno.creditiEmergenza = 2
    verifica(Regole.ricarica(pieno, ora: data(20, 12, 0)).impostazioni.ultimaRicarica == data(20, 12, 0),
             "al massimo il conteggio riparte da adesso")
    verifica(Impostazioni().creditiEmergenza == 1, "alla prima installazione 1 credito")
}

// MARK: Occorrenze e mattine da programmare
do {
    let feriali = Sveglia(nome: "Lavoro", ora: 7, minuti: 0, giorni: [2, 3, 4, 5, 6])
    let sabato = data(21, 9, 0)
    let occ = Regole.occorrenze(feriali, dopo: sabato, fino: sabato.addingTimeInterval(8 * 86400), calendario: cal)
    verifica(occ.first == data(23, 7, 0), "da sabato la prossima feriale è lunedì 23 alle 7:00")
    verifica(occ.count == 5, "5 feriali in 8 giorni")

    let unaVolta = Sveglia(nome: "Una", ora: 6, minuti: 30, dataUnaTantum: data(19, 6, 30))
    let des = Regole.mattineDesiderate(sveglie: [feriali, unaVolta], mattine: [], ora: data(18, 22, 0), calendario: cal)
    verifica(des.count == 2 && des[0].orario == data(19, 6, 30) && des[1].orario == data(19, 7, 0), "solo le prossime 2 mattine")

    var annullata = mattina()
    annullata.svegliaID = feriali.id
    annullata.orario = data(19, 7, 0)
    annullata.esito = .anticipo
    let des2 = Regole.mattineDesiderate(sveglie: [feriali], mattine: [annullata], ora: data(19, 6, 0), calendario: cal)
    verifica(des2.first?.orario == data(20, 7, 0), "una mattina annullata in anticipo non viene riprogrammata")

    var lontana = Sveglia(nome: "Test scadenza", dataUnaTantum: data(28, 7, 0))
    lontana.test = ParametriMattina(progressiva: false)
    let des3 = Regole.mattineDesiderate(sveglie: [feriali, lontana], mattine: [], ora: data(19, 8, 0), calendario: cal)
    verifica(des3.count == 3 && des3.last?.orario == data(28, 7, 0), "le sveglie di test sono sempre programmate")

    var spenta = feriali
    spenta.attiva = false
    verifica(Regole.occorrenze(spenta, dopo: sabato, fino: data(30, 0, 0), calendario: cal).isEmpty, "sveglia disattivata: nessuna mattina")
    verifica(Regole.prossimoOrario(ora: 7, minuti: 0, dopo: data(19, 8, 0), calendario: cal) == data(20, 7, 0), "orario passato: domani")
}

// MARK: Sveglie una tantum finite
do {
    let ora = data(19, 11, 30)
    let unaVolta = Sveglia(nome: "Una", ora: 12, minuti: 0, dataUnaTantum: data(19, 12, 0))
    func mattinaDi(_ s: Sveglia, esito: Esito?) -> Mattina {
        var m = mattina()
        m.svegliaID = s.id
        m.orario = s.dataUnaTantum!
        m.esito = esito
        return m
    }
    verifica(Regole.unaTantumFinite([unaVolta], mattine: [mattinaDi(unaVolta, esito: .anticipo)], ora: ora) == [unaVolta.id],
             "annullata in anticipo: la sveglia una tantum sparisce subito")
    verifica(Regole.unaTantumFinite([unaVolta], mattine: [mattinaDi(unaVolta, esito: nil)], ora: data(19, 12, 10)).isEmpty,
             "mattina ancora aperta: resta")
    verifica(Regole.unaTantumFinite([unaVolta], mattine: [], ora: ora).isEmpty, "ancora da suonare: resta")
    verifica(Regole.unaTantumFinite([unaVolta], mattine: [], ora: data(19, 12, 1)) == [unaVolta.id],
             "orario passato senza mattine aperte: sparisce")
    var chiusaAltroOrario = mattinaDi(unaVolta, esito: .tag)
    chiusaAltroOrario.orario = data(18, 12, 0)
    verifica(Regole.unaTantumFinite([unaVolta], mattine: [chiusaAltroOrario], ora: ora).isEmpty,
             "una mattina chiusa a un altro orario non conta")
    let ripetuta = Sveglia(nome: "Lavoro", giorni: [2, 3, 4, 5, 6])
    verifica(Regole.unaTantumFinite([ripetuta], mattine: [], ora: data(30, 0, 0)).isEmpty, "le sveglie ripetute non spariscono")
}

// MARK: Fase 2: vado a dormire, statistiche
do {
    let cicli = Regole.cicliSonno(da: data(18, 23, 30))
    verifica(cicli.map(\.cicli) == [3, 4, 5, 6], "proposte da 3 a 6 cicli")
    verifica(cicli[0].orario == data(19, 4, 15) && cicli[2].orario == data(19, 7, 15), "23:30 → 4:15 (3 cicli), 7:15 (5 cicli)")
    verifica(cicli[2].durata == 7.5 * 3600, "5 cicli = 7 h 30")
    verifica(Regole.cicliSonno(da: data(18, 23, 30, 20))[0].orario == data(19, 4, 16), "dal minuto intero successivo")

    func chiusa(_ e: Esito, giorno: Int, ora: Int = 7, punti: Int?, tts: TimeInterval? = nil, test: Bool = false) -> Mattina {
        var m = mattina()
        m.orario = data(giorno, ora, 0)
        m.esito = e
        m.punteggio = punti
        m.timeToScan = tts
        m.test = test
        return m
    }
    let storia = [chiusa(.tag, giorno: 13, punti: 90, tts: 60), chiusa(.tag, giorno: 17, punti: 80, tts: 120),
                  chiusa(.tag, giorno: 17, ora: 9, punti: 70, tts: 180), chiusa(.fuoriCasa, giorno: 18, punti: nil),
                  chiusa(.fallita, giorno: 19, punti: 0), chiusa(.tag, giorno: 19, ora: 6, punti: 100, tts: 5, test: true)]
    verifica(Regole.conteggiate(storia) == 4, "conteggiate: senza test e fuori casa")
    verifica(Regole.mediaTimeToScan(storia) == 120, "media al tag: (60 + 120 + 180) / 3")
    let settimana = Regole.punteggiGiorni(storia, ora: data(19, 12, 0), calendario: cal)
    verifica(settimana.count == 7 && settimana.first?.giorno == data(13, 0, 0) && settimana.last?.giorno == data(19, 0, 0),
             "7 giorni, da 6 giorni fa a oggi")
    verifica(settimana.map(\.punteggio) == [90, nil, nil, nil, 70, nil, 0], "ultima mattina del giorno, test esclusi, fuori casa vuoto")
}

// MARK: Codice, nomi, frase, profilo
do {
    let codice = Regole.nuovoCodice()
    verifica(codice.count == 9 && codice.contains("-"), "codice nel formato XXXX-XXXX")
    verifica(Regole.codiceValido(codice.lowercased().replacingOccurrences(of: "-", with: " "), atteso: codice), "codice: maiuscole e trattino non contano")
    verifica(!Regole.codiceValido(nil, atteso: codice) && !Regole.codiceValido("", atteso: codice), "codice assente rifiutato")
    verifica(!Regole.codiceValido("ABCD-EFGH", atteso: "ABCD-EFGJ"), "codice sbagliato rifiutato")
    verifica(Regole.stessoNome("Bagno", " bagno ") && !Regole.stessoNome("Bagno", "Cucina"), "nomi tag")
    verifica(Regole.fraseValida("sono sveglio e mi alzo.") && Regole.fraseValida("Sono  sveglio e mi alzo!"), "frase con maiuscole e punteggiatura")
    verifica(!Regole.fraseValida("Sono sveglio"), "frase incompleta rifiutata")

    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict><key>ExpirationDate</key><date>2026-11-25T10:00:00Z</date></dict></plist>
    """
    var profilo = Data([0x30, 0x82, 0x01, 0xFF, 0x00])
    profilo.append(Data(plist.utf8))
    profilo.append(Data([0x00, 0xA0, 0x82]))
    let attesa = ISO8601DateFormatter().date(from: "2026-11-25T10:00:00Z")
    verifica(Regole.scadenza(profilo: profilo) == attesa, "ExpirationDate letta dal profilo")
    verifica(Regole.scadenza(profilo: Data("niente".utf8)) == nil, "profilo illeggibile: nil")
}

print("Test delle regole: \(totali - falliti)/\(totali) superati")
exit(falliti == 0 ? 0 : 1)
