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
    let p = ParametriMattina(progressiva: progressiva)
    return Mattina(svegliaID: UUID(), nome: "Test", orario: T, richiesti: p, parametri: p,
                   suoneria: Suoneria.normale.file, eventi: eventi)
}
func stop(_ secondiDaT: Double, fase: Fase = .catena) -> EventoMattina {
    EventoMattina(data: T.addingTimeInterval(secondiDaT), tipo: .stop, fase: fase, indice: 1)
}

// MARK: Piano della mattina
do {
    let senza = Regole.piano(orario: T, parametri: ParametriMattina(progressiva: false), suoneria: "normale.wav")
    verifica(senza.count == 61, "senza progressiva: principale + 60 di catena = 61 sveglie")
    verifica(senza[0].fase == .principale && senza[0].orario == T, "la prima è la principale alle T")
    verifica(senza[3].suono == "normale.wav", "la 4ª suona normale")
    verifica(senza[4].suono == Suoni.punizione && senza[4].orario == T.addingTimeInterval(120), "la 5ª è la sirena, a T+2 min")
    verifica(senza.last!.orario == T.addingTimeInterval(1800), "l'ultima è a T+30 min")

    let con = Regole.piano(orario: T, parametri: ParametriMattina(progressiva: true), suoneria: "normale.wav")
    verifica(con.count == 76, "con progressiva: 15 + 61 = 76 sveglie")
    verifica(con[0].orario == T.addingTimeInterval(-900) && con[0].suono == "dolce_01.wav", "progressiva da T-15 min, livello 1")
    verifica(con[14].orario == T.addingTimeInterval(-60) && con[14].suono == "dolce_15.wav", "ultimo gradino a T-1 min, livello 15")
    verifica(zip(con, con.dropFirst()).allSatisfy { $0.orario < $1.orario }, "orari crescenti")

    let rid1 = Regole.riduzioni(ParametriMattina(progressiva: true), prima: true)
    verifica(rid1.count == 4 && rid1[1].nota == "senza progressiva" && rid1[3].parametri.durataCatenaMin == 0,
             "riduzioni prima mattina: piena, senza progressiva, catena 10 min, solo principale")
    let rid2 = Regole.riduzioni(ParametriMattina(progressiva: true), prima: false)
    verifica(rid2.count == 3 && rid2[1].parametri.durataCatenaMin == 10 && !rid2[1].parametri.progressiva,
             "riduzioni seconda mattina: piena, principale + catena ridotta, solo principale")
    let soloPrincipale = Regole.piano(orario: T, parametri: rid2[2].parametri, suoneria: "normale.wav")
    verifica(soloPrincipale.count == 1, "solo principale = 1 sveglia")
}

// MARK: Finestre: in corso, 2 ore prima, blocco
do {
    let m = mattina()
    verifica(!m.bloccata(data(19, 4, 59)), "4:59 non bloccata")
    verifica(m.bloccata(data(19, 5, 0)) && m.nellaFinestraPrima(data(19, 5, 0)), "5:00 bloccata e nella finestra di anticipo")
    verifica(m.inCorso(data(19, 7, 20)) && !m.nellaFinestraPrima(data(19, 7, 20)), "7:20 in corso")
    verifica(m.inCorso(data(19, 7, 31, 0)) && !m.inCorso(data(19, 7, 31, 1)), "fine = T + 30 min + 60 s")
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
