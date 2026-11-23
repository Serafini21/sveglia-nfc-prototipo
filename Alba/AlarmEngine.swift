import AlarmKit
import AppIntents
import Foundation
import SwiftUI

struct MetaAlba: AlarmMetadata {
    var fase: String
    var indice: Int
}

struct Risposta: Sendable {
    var ok: Bool
    var messaggio: String
}

/// L'unico punto che parla con AlarmManager.
/// Ogni operazione pubblica passa da una coda seriale: intent e interfaccia non si sovrappongono
/// nemmeno durante le attese di AlarmKit, quindi le mattine non vengono mai scritte da due parti insieme.
actor AlarmEngine {
    static let shared = AlarmEngine()
    private let manager = AlarmManager.shared
    private var ultima: Task<Void, Never>?

    private func inCoda<T: Sendable>(_ operazione: @escaping @Sendable () async -> T) async -> T {
        let precedente = ultima
        let task = Task { () -> T in
            await precedente?.value
            return await operazione()
        }
        ultima = Task { _ = await task.value }
        return await task.value
    }

    // MARK: - Operazioni pubbliche (tutte in coda)

    func riallinea(_ motivo: String) async { await inCoda { await self._riallinea(motivo) } }

    func stop(alarmID: String, pulsanteEmergenza: Bool) async {
        await inCoda { await self._stop(alarmID, emergenza: pulsanteEmergenza) }
    }

    func spegniConTag(nome: String?, codice: String?, simulato: Bool = false) async -> Risposta {
        await inCoda { await self._tag(nome, codice, simulato: simulato) }
    }

    /// fuoriCasa: la posizione (letta dall'app al momento) è certamente oltre 150 m da casa.
    func emergenza(fuoriCasa: Bool = false) async -> Risposta { await inCoda { await self._emergenza(fuoriCasa) } }

    func salva(_ s: Sveglia) async -> Risposta { await inCoda { await self._salva(s) } }

    func elimina(_ id: UUID) async -> Risposta { await inCoda { await self._elimina(id) } }

    func impostaProgressiva(_ attiva: Bool) async {
        await inCoda {
            await Store.shared.modifica { $0.impostazioni.progressiva = attiva }
            EventLog.scrivi("Progressiva \(attiva ? "attivata" : "disattivata")")
            await self._riallinea("progressiva")
        }
    }

    func segnaRisveglioVisto(_ id: UUID) async {
        await inCoda {
            await Store.shared.modifica { d in
                if let i = d.mattine.firstIndex(where: { $0.id == id }) { d.mattine[i].risveglioVisto = true }
            }
        }
    }

    func segnaRoutine(_ mattinaID: UUID, voce: UUID, fatta: Bool) async {
        await inCoda {
            await Store.shared.modifica { d in
                guard let i = d.mattine.firstIndex(where: { $0.id == mattinaID }) else { return }
                var fatte = Set(d.mattine[i].routineFatte ?? [])
                if fatta { fatte.insert(voce) } else { fatte.remove(voce) }
                d.mattine[i].routineFatte = Array(fatte)
            }
        }
    }

    /// Modalità sviluppatore: cancella lo storico delle mattine chiuse (per ripartire dopo i test).
    func azzeraStatistiche() async -> Risposta {
        await inCoda {
            let n = await Store.shared.modifica { d -> Int in
                let prima = d.mattine.count
                let ora = Date()
                // le mattine future annullate in anticipo restano, altrimenti verrebbero riprogrammate
                d.mattine.removeAll { $0.conclusa && $0.orario < ora }
                return prima - d.mattine.count
            }
            EventLog.scrivi("SVILUPPATORE: statistiche azzerate, tolte \(n) mattine chiuse")
            return Risposta(ok: true, messaggio: "Statistiche azzerate (\(n) mattine)")
        }
    }

    func chiudiAvviso() async { await inCoda { await Store.shared.modifica { $0.avviso = nil } } }

    func mostraAvviso(_ testo: String) async { await inCoda { await Store.shared.modifica { $0.avviso = testo } } }

    func fermaEDisattivaTutto() async -> Risposta { await inCoda { await self._fermaTutto() } }

    // Lettura dello stato per l'interfaccia
    nonisolated var autorizzazione: AlarmManager.AuthorizationState { AlarmManager.shared.authorizationState }

    nonisolated func chiediAutorizzazione() async -> AlarmManager.AuthorizationState {
        do {
            let stato = try await AlarmManager.shared.requestAuthorization()
            EventLog.scrivi("Autorizzazione sveglie: \(stato)")
            return stato
        } catch {
            EventLog.scrivi("ERRORE autorizzazione sveglie: \(error)")
            return AlarmManager.shared.authorizationState
        }
    }

    nonisolated func osserva(sveglie: @escaping @MainActor ([Alarm]) -> Void,
                             autorizzazione: @escaping @MainActor (AlarmManager.AuthorizationState) -> Void) async {
        await withTaskGroup(of: Void.self) { gruppo in
            gruppo.addTask { for await l in AlarmManager.shared.alarmUpdates { await sveglie(l) } }
            gruppo.addTask { for await a in AlarmManager.shared.authorizationUpdates { await autorizzazione(a) } }
        }
    }

    // MARK: - Riallineamento

    /// Confronta le sveglie attese con quelle di AlarmKit e corregge: chiude le mattine finite (rilevando il
    /// trucco del volume), toglie le sveglie che non servono più, programma le prossime 2 mattine.
    private func _riallinea(_ motivo: String) async {
        let ora = Date()
        var d = await Store.shared.leggi()
        var kit = sveglieKit()
        let autorizzata = manager.authorizationState == .authorized
        var note: [String] = []

        let ricarica = Regole.ricarica(d.impostazioni, ora: ora)
        if let n = ricarica.nota { note.append(n) }
        let imp = ricarica.impostazioni

        // 1. Mattine finite, o con sveglie zittite dai tasti volume
        for i in d.mattine.indices where !d.mattine[i].conclusa {
            let m = d.mattine[i]
            let zittite = orariInCorso(m, kit)
            let volume = Regole.volumeSospetto(orariInCorso: zittite, ora: ora)
            guard ora > m.fine || (m.inCorso(ora) && volume) else { continue }
            if volume {
                d.mattine[i].eventi.append(EventoMattina(data: ora, tipo: .volume, nota: "\(zittite.count) sveglie in corso"))
            }
            Regole.chiudi(&d.mattine[i], esito: volume ? .fallitaVolume : .fallita, ora: ora)
            note.append("MATTINA \(descr(m)) chiusa: \(d.mattine[i].esito?.titolo ?? "?")")
        }

        // 2. Via da AlarmKit le sveglie di mattine chiuse e quelle sconosciute (il mini-test resta un'ora)
        d.sveglieTest.removeAll { $0.orario < ora.addingTimeInterval(-3600) }
        var attese = Set(d.mattine.filter { !$0.conclusa }.flatMap { $0.sveglie.map(\.id) })
        attese.formUnion(d.sveglieTest.map(\.id))
        let superflue = Set(kit.map(\.id)).subtracting(attese)
        if !superflue.isEmpty { note.append("Tolte \(togli(superflue, kit)) sveglie non più necessarie") }

        // 3. Mattine aperte non più desiderate (sveglia modificata, disattivata o eliminata), se non bloccate
        let desiderate = Regole.mattineDesiderate(sveglie: d.sveglie, mattine: d.mattine, ora: ora)
        func desiderata(_ m: Mattina) -> Bool {
            desiderate.contains { $0.svegliaID == m.svegliaID && Regole.stessoIstante($0.orario, m.orario) }
        }
        let daTogliere = d.mattine.filter { !$0.conclusa && ora < $0.inizio && !$0.bloccata(ora) && !desiderata($0) }
        for m in daTogliere {
            togli(Set(m.sveglie.map(\.id)), kit)
            note.append("Mattina \(descr(m)) tolta (sveglia modificata, disattivata o oltre le prossime 2)")
        }
        let idTolte = Set(daTogliere.map(\.id))
        d.mattine.removeAll { idTolte.contains($0.id) }

        // 4. Programma le desiderate, in ordine di orario: la prima ha la precedenza se AlarmKit è al limite
        kit = sveglieKit()
        let presenti = Set(kit.map(\.id))
        var normaliViste = 0
        for des in desiderate {
            guard let s = d.sveglie.first(where: { $0.id == des.svegliaID }) else { continue }
            let richiesti = s.test ?? ParametriMattina(progressiva: imp.progressiva, ritardoCatenaSec: Costanti.ritardoCatena)
            let suono = (Suoneria(rawValue: s.suoneria) ?? .normale).file
            let prima = s.test != nil || normaliViste == 0
            if s.test == nil { normaliViste += 1 }

            if let i = d.mattine.firstIndex(where: { !$0.conclusa && $0.svegliaID == s.id && Regole.stessoIstante($0.orario, des.orario) }) {
                let m = d.mattine[i]
                let future = m.sveglie.filter { $0.orario > ora.addingTimeInterval(5) }
                let mancanti = future.filter { !presenti.contains($0.id) }
                let attesiFuturi = Regole.piano(orario: m.orario, parametri: m.parametri)
                    .filter { $0.orario > ora.addingTimeInterval(5) }.count
                let cambiata = (m.richiesti != richiesti || m.suoneria != suono) && !m.bloccata(ora)
                // shortcut: se AlarmKit è sempre al limite questo ritenta a ogni riallineamento; va bene finché il limite reale non è noto
                let daCompletare = m.ridotta != nil && prima && ora < m.inizio
                if !mancanti.isEmpty {
                    note.append("SVEGLIE MANCANTI: \(mancanti.count) della mattina \(descr(m)), le riprogrammo")
                    d.avviso = "Alba ha riprogrammato \(mancanti.count) sveglie mancanti di \(Formati.quando(m.orario))."
                }
                guard autorizzata, !mancanti.isEmpty || future.count < attesiFuturi || cambiata || daCompletare else { continue }
                if cambiata {
                    d.mattine[i].suoneria = suono
                    d.mattine[i].nome = s.nome
                }
                await ripianifica(&d.mattine[i], richiesti: cambiata ? richiesti : m.richiesti, ora: ora, note: &note)
            } else {
                var m = Mattina(svegliaID: s.id, nome: s.nome, orario: des.orario, richiesti: richiesti,
                                parametri: richiesti, suoneria: suono, test: s.test != nil)
                if autorizzata {
                    await ripianifica(&m, richiesti: richiesti, ora: ora, note: &note)
                } else {
                    note.append("PERMESSO SVEGLIE MANCANTE: mattina \(descr(m)) non programmata")
                }
                d.mattine.append(m)
            }
        }

        // 5. Le sveglie una tantum finite spariscono (anche quelle annullate in anticipo)
        let finite = Regole.unaTantumFinite(d.sveglie, mattine: d.mattine, ora: ora)
        d.sveglie.removeAll { finite.contains($0.id) }

        let finali = d
        await Store.shared.modifica { dati in
            dati.mattine = finali.mattine
            dati.sveglie = finali.sveglie
            dati.sveglieTest = finali.sveglieTest
            dati.avviso = finali.avviso
            dati.impostazioni.creditiEmergenza = imp.creditiEmergenza
            dati.impostazioni.ultimaRicarica = imp.ultimaRicarica
            dati.impostazioni.ultimaDataVista = imp.ultimaDataVista
        }
        let aperte = finali.mattine.filter { !$0.conclusa }.count
        let promemoria = await PromemoriaLetto.sincronizza(finali.mattine, ora: ora)
        let riga = "Riallinea (\(motivo)): \(sveglieKit().count) sveglie in AlarmKit, \(aperte) mattine aperte, \(promemoria)"
        EventLog.scrivi(([riga] + note).joined(separator: "\n    "))
    }

    /// Toglie le sveglie future della mattina e la riprogramma, riducendola se AlarmKit segnala il limite.
    private func ripianifica(_ m: inout Mattina, richiesti: ParametriMattina, ora: Date, note: inout [String]) async {
        let soglia = ora.addingTimeInterval(2)
        togli(Set(m.sveglie.filter { $0.orario > soglia }.map(\.id)), sveglieKit())
        m.sveglie.removeAll { $0.orario > soglia }
        m.richiesti = richiesti
        for livello in Regole.riduzioni(richiesti) {
            let voci = Regole.piano(orario: m.orario, parametri: livello.parametri).filter { $0.orario > soglia }
            var fatte: [SvegliaProgrammata] = []
            do {
                for v in voci {
                    let id = try await programma(v)
                    fatte.append(SvegliaProgrammata(id: id, fase: v.fase, indice: v.indice, orario: v.orario, suono: v.suono))
                }
                m.parametri = livello.parametri
                m.ridotta = livello.nota
                m.sveglie += fatte
                note.append("Mattina \(descr(m)) programmata: \(fatte.count) sveglie" + (livello.nota.map { " – RIDOTTA: \($0)" } ?? ""))
                return
            } catch {
                togli(Set(fatte.map(\.id)), sveglieKit())
                guard case .maximumLimitReached = error as? AlarmManager.AlarmError else {
                    note.append("ERRORE programmazione mattina \(descr(m)): \(error)")
                    return
                }
                note.append("LIMITE AlarmKit dopo \(fatte.count) sveglie della mattina \(descr(m)) (ne servivano \(voci.count))")
            }
        }
        note.append("Mattina \(descr(m)): impossibile programmare anche una sola sirena di sicurezza")
    }

    // MARK: - Stop, tag, Emergency

    private func _stop(_ alarmID: String, emergenza: Bool) async {
        let ora = Date()
        let fermate = fermaTutteInCorso()
        let d = await Store.shared.leggi()
        var testo = "sveglia sconosciuta \(alarmID)"
        if let id = UUID(uuidString: alarmID),
           let m = d.mattine.first(where: { $0.sveglie.contains { $0.id == id } }),
           let v = m.sveglie.first(where: { $0.id == id }) {
            testo = "\(v.fase.rawValue) n. \(v.indice) della mattina \(descr(m))"
            let evento = EventoMattina(data: ora, tipo: emergenza ? .pulsanteEmergenza : .stop, fase: v.fase, indice: v.indice)
            await Store.shared.modifica { dati in
                if let j = dati.mattine.firstIndex(where: { $0.id == m.id }) { dati.mattine[j].eventi.append(evento) }
            }
        } else if let id = UUID(uuidString: alarmID), d.sveglieTest.contains(where: { $0.id == id }) {
            testo = "sveglia del mini-test"
        }
        EventLog.scrivi("\(emergenza ? "PULSANTE EMERGENZA" : "STOP SENZA TAG") su \(testo), fermate anche \(fermate) sveglie in corso")
        await _riallinea(emergenza ? "pulsante Emergenza" : "stop")
    }

    private func _tag(_ nome: String?, _ codice: String?, simulato: Bool) async -> Risposta {
        let ora = Date()
        var d = await Store.shared.leggi()
        let nomeLog = nome?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "-"
        if simulato {
            EventLog.scrivi("SIMULA TAG (modalità sviluppatore)")
        } else {
            guard Regole.codiceValido(codice, atteso: d.impostazioni.codiceSegreto) else {
                EventLog.scrivi("TAG RIFIUTATO \"\(nomeLog)\": codice \(codice == nil ? "assente" : "sbagliato") – TENTATIVO SOSPETTO")
                return Risposta(ok: false, messaggio: "Codice segreto mancante o sbagliato: spegnimento rifiutato.")
            }
            guard let tag = d.tag.first(where: { Regole.stessoNome($0.nome, nome) }) else {
                EventLog.scrivi("TAG RIFIUTATO \"\(nomeLog)\": nome non registrato")
                return Risposta(ok: false, messaggio: "Il tag «\(nomeLog)» non è registrato in Alba: controlla il nome nell'automazione.")
            }
            await Store.shared.modifica { dati in
                if let j = dati.tag.firstIndex(where: { $0.id == tag.id }) { dati.tag[j].ultimaScansione = ora }
            }
        }

        let kit = sveglieKit()
        let risposta: Risposta
        if let i = d.mattine.firstIndex(where: { $0.inCorso(ora) }) {
            if simulato && !d.mattine[i].test {
                return Risposta(ok: false, messaggio: "«Simula tag» funziona solo sulle mattine di test.")
            }
            let zittite = orariInCorso(d.mattine[i], kit)
            let volume = Regole.volumeSospetto(orariInCorso: zittite, ora: ora)
            let fermate = fermaTutteInCorso()
            togli(Set(d.mattine[i].sveglie.map(\.id)), sveglieKit())
            d.mattine[i].eventi.append(EventoMattina(data: ora, tipo: .tag, nota: nomeLog))
            if volume {
                d.mattine[i].eventi.append(EventoMattina(data: ora, tipo: .volume, nota: "\(zittite.count) sveglie in corso"))
            }
            Regole.chiudi(&d.mattine[i], esito: volume ? .fallitaVolume : .tag, ora: ora)
            let m = d.mattine[i]
            EventLog.scrivi("SPEGNIMENTO COL TAG \"\(nomeLog)\" – mattina \(descr(m)): esito \(m.esito?.titolo ?? "?"), time-to-scan \(Int(m.timeToScan ?? 0)) s, stop penalizzati \(m.stopPenalizzati ?? 0), punteggio \(m.punteggio ?? 0), sveglie in corso \(zittite.count), fermate \(fermate)")
            risposta = volume
                ? Risposta(ok: true, messaggio: "Sveglia spenta. Mattina «fallita – volume»: la sveglia era stata zittita con i tasti volume.")
                : Risposta(ok: true, messaggio: "Sveglia spenta ✓ Buona giornata!")
        } else if let i = d.mattine.indices.filter({ d.mattine[$0].nellaFinestraPrima(ora) })
                    .min(by: { d.mattine[$0].inizio < d.mattine[$1].inizio }) {
            if simulato && !d.mattine[i].test {
                return Risposta(ok: false, messaggio: "«Simula tag» funziona solo sulle mattine di test.")
            }
            togli(Set(d.mattine[i].sveglie.map(\.id)), kit)
            d.mattine[i].eventi.append(EventoMattina(data: ora, tipo: .anticipo, nota: nomeLog))
            Regole.chiudi(&d.mattine[i], esito: .anticipo, ora: ora)
            EventLog.scrivi("SPEGNIMENTO ANTICIPATO COL TAG \"\(nomeLog)\" – mattina \(descr(d.mattine[i])) annullata")
            risposta = Risposta(ok: true, messaggio: "Sveglia \(Formati.quando(d.mattine[i].orario)) annullata in anticipo ✓")
        } else if kit.contains(where: { $0.state == .alerting }) {
            let n = fermaTutteInCorso()
            EventLog.scrivi("TAG \"\(nomeLog)\": nessuna mattina in corso, fermate \(n) sveglie che suonavano")
            risposta = Risposta(ok: true, messaggio: "Sveglie fermate.")
        } else {
            EventLog.scrivi("TAG \"\(nomeLog)\" riconosciuto: nessuna sveglia da spegnere (rifiutato)")
            return Risposta(ok: false, messaggio: "Tag «\(nomeLog)» riconosciuto ✓ Nessuna sveglia da spegnere adesso.")
        }
        let mattine = d.mattine
        await Store.shared.modifica { $0.mattine = mattine }
        await _riallinea("tag")
        return risposta
    }

    private func _emergenza(_ fuoriCasa: Bool) async -> Risposta {
        let ora = Date()
        var d = await Store.shared.leggi()
        var imp = Regole.ricarica(d.impostazioni, ora: ora).impostazioni
        guard fuoriCasa || imp.creditiEmergenza > 0 else {
            EventLog.scrivi("EMERGENCY rifiutato: nessun credito")
            return Risposta(ok: false, messaggio: "Nessun credito Emergency: usa il tag.")
        }
        let inCorso = d.mattine.firstIndex { $0.inCorso(ora) }
        let prossima = d.mattine.indices.filter { d.mattine[$0].nellaFinestraPrima(ora) }
            .min { d.mattine[$0].inizio < d.mattine[$1].inizio }
        guard let i = inCorso ?? prossima else {
            return Risposta(ok: false, messaggio: "Nessuna sveglia in corso o nelle prossime 2 ore.")
        }
        let fermate = fermaTutteInCorso()
        togli(Set(d.mattine[i].sveglie.map(\.id)), sveglieKit())
        d.mattine[i].eventi.append(EventoMattina(data: ora, tipo: .emergenza, nota: fuoriCasa ? "fuori casa" : nil))
        // fuori casa: nessun credito, streak in pausa (PROGETTO §6.7)
        Regole.chiudi(&d.mattine[i], esito: fuoriCasa ? .fuoriCasa : .emergenza, ora: ora)
        if !fuoriCasa { imp.creditiEmergenza -= 1 }
        let mattine = d.mattine
        let crediti = imp.creditiEmergenza
        let ricarica = imp.ultimaRicarica
        let vista = imp.ultimaDataVista
        await Store.shared.modifica { dati in
            dati.mattine = mattine
            dati.impostazioni.creditiEmergenza = crediti
            dati.impostazioni.ultimaRicarica = ricarica
            dati.impostazioni.ultimaDataVista = vista
        }
        EventLog.scrivi("\(fuoriCasa ? "EMERGENCY FUORI CASA (nessun credito)" : "EMERGENCY STOP") – mattina \(descr(d.mattine[i])) chiusa, fermate \(fermate) sveglie, crediti rimasti \(crediti)/\(Costanti.creditiMax)")
        await _riallinea("emergenza")
        if fuoriCasa { return Risposta(ok: true, messaggio: "Sveglia spenta: sei fuori casa, nessun credito usato. Lo streak resta in pausa.") }
        return Risposta(ok: true, messaggio: "Sveglia spenta con l'Emergency Stop. Crediti rimasti: \(crediti)/\(Costanti.creditiMax). Lo streak riparte da zero.")
    }

    // MARK: - Sveglie

    private func _salva(_ s: Sveglia) async -> Risposta {
        let d = await Store.shared.leggi()
        if d.sveglie.contains(where: { $0.id == s.id }), Regole.svegliaBloccata(s.id, mattine: d.mattine, ora: Date()) {
            return Risposta(ok: false, messaggio: "Sveglia bloccata: suona entro 2 ore. Usa il tag o l'Emergency Stop.")
        }
        await Store.shared.modifica { dati in
            if let i = dati.sveglie.firstIndex(where: { $0.id == s.id }) { dati.sveglie[i] = s } else { dati.sveglie.append(s) }
        }
        EventLog.scrivi("Sveglia salvata: \(s.nome) \(String(format: "%02d:%02d", s.ora, s.minuti)) giorni \(s.giorni) attiva \(s.attiva)" + (s.dataUnaTantum.map { " una tantum \(EventLog.data($0))" } ?? "") + (s.test != nil ? " [TEST]" : ""))
        await _riallinea("sveglia salvata")
        let dopo = await Store.shared.leggi()
        if let m = dopo.mattine.filter({ $0.svegliaID == s.id && !$0.conclusa }).min(by: { $0.orario < $1.orario }) {
            return Risposta(ok: true, messaggio: "Salvata ✓ Suona \(Formati.quando(m.orario))")
        }
        return Risposta(ok: true, messaggio: s.attiva ? "Salvata ✓" : "Salvata ✓ (disattivata)")
    }

    private func _elimina(_ id: UUID) async -> Risposta {
        let d = await Store.shared.leggi()
        if Regole.svegliaBloccata(id, mattine: d.mattine, ora: Date()) {
            return Risposta(ok: false, messaggio: "Sveglia bloccata: suona entro 2 ore. Usa il tag o l'Emergency Stop.")
        }
        await Store.shared.modifica { $0.sveglie.removeAll { $0.id == id } }
        EventLog.scrivi("Sveglia eliminata \(id)")
        await _riallinea("sveglia eliminata")
        return Risposta(ok: true, messaggio: "Sveglia eliminata")
    }

    // MARK: - Modalità sviluppatore

    private func _fermaTutto() async -> Risposta {
        let kit = sveglieKit()
        let n = togli(Set(kit.map(\.id)), kit)
        await Store.shared.modifica { d in
            d.sveglie.removeAll { $0.test != nil }
            for i in d.sveglie.indices { d.sveglie[i].attiva = false }
            d.mattine.removeAll { !$0.conclusa }
            d.sveglieTest = []
        }
        EventLog.scrivi("SVILUPPATORE: fermate e cancellate \(n) sveglie, tutte le sveglie disattivate")
        return Risposta(ok: true, messaggio: "Tolte \(n) sveglie, tutte disattivate")
    }

    // MARK: - AlarmKit

    private func sveglieKit() -> [Alarm] {
        do { return try manager.alarms } catch {
            EventLog.scrivi("ERRORE lettura sveglie AlarmKit: \(error)")
            return []
        }
    }

    /// Ferma tutte le sveglie che suonano. stop() su una sveglia che suona la rimuove già (niente cancel dopo).
    @discardableResult
    private func fermaTutteInCorso() -> Int {
        var n = 0
        for a in sveglieKit() where a.state == .alerting {
            do { try manager.stop(id: a.id); n += 1 } catch { EventLog.scrivi("Errore stop \(a.id): \(error)") }
        }
        return n
    }

    /// Toglie le sveglie indicate: stop se suonano, cancel altrimenti.
    @discardableResult
    private func togli(_ ids: Set<UUID>, _ kit: [Alarm]) -> Int {
        var n = 0
        for a in kit where ids.contains(a.id) {
            do {
                if a.state == .alerting { try manager.stop(id: a.id) } else { try manager.cancel(id: a.id) }
                n += 1
            } catch { EventLog.scrivi("Errore rimozione \(a.id): \(error)") }
        }
        return n
    }

    private func orariInCorso(_ m: Mattina, _ kit: [Alarm]) -> [Date] {
        let suonano = Set(kit.filter { $0.state == .alerting }.map(\.id))
        return m.sveglie.filter { suonano.contains($0.id) }.map(\.orario)
    }

    private func programma(_ v: Regole.VocePiano) async throws -> UUID {
        let id = UUID()
        let titolo: LocalizedStringResource
        var tinta = Tema.ambra
        var emergenza: AlarmButton?
        switch v.fase {
        case .progressiva:
            titolo = "Buongiorno ☀︎"
        case .principale, .catena:
            let sirena = v.suono == Suoni.punizione
            titolo = sirena ? "PUNIZIONE – usa il tag!" : "Sblocca e avvicina al tag"
            if sirena { tinta = Tema.pericolo }
            emergenza = AlarmButton(text: "Emergenza", textColor: .white, systemImageName: "exclamationmark.triangle.fill")
        case .test:
            titolo = "Mini-test progressiva \(v.indice)/4"
        }
        let alert = AlarmPresentation.Alert(title: titolo, secondaryButton: emergenza,
                                            secondaryButtonBehavior: emergenza == nil ? nil : .custom)
        let attributi = AlarmAttributes(presentation: AlarmPresentation(alert: alert),
                                        metadata: MetaAlba(fase: v.fase.rawValue, indice: v.indice),
                                        tintColor: tinta)
        let secondario: (any LiveActivityIntent)? = emergenza == nil ? nil : EmergenzaIntent(alarmID: id.uuidString)
        let config = AlarmManager.AlarmConfiguration.alarm(schedule: .fixed(v.orario),
                                                          attributes: attributi,
                                                          stopIntent: StopSenzaTagIntent(alarmID: id.uuidString),
                                                          secondaryIntent: secondario,
                                                          sound: .named(v.suono))
        _ = try await manager.schedule(id: id, configuration: config)
        return id
    }

    private func descr(_ m: Mattina) -> String {
        "«\(m.nome)» \(EventLog.data(m.orario).prefix(16))" + (m.test ? " [TEST]" : "")
    }
}
