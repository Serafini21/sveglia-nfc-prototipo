import AlarmKit
import Foundation
import SwiftUI

// MARK: - Log persistente (file di testo in Documents, sopravvive alla chiusura dell'app)

enum Log {
    static let url = URL.documentsDirectory.appending(path: "log.txt")
    private static let lock = NSLock()

    static func add(_ testo: String) {
        let riga = "[\(Date().formatted(.dateTime.day().month().hour().minute().second()))] \(testo)\n"
        lock.lock(); defer { lock.unlock() }
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(Data(riga.utf8))
            try? h.close()
        } else {
            try? Data(riga.utf8).write(to: url)
        }
    }

    static func leggi() -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
}

// MARK: - Catena di sveglie

struct DatiSveglia: AlarmMetadata {
    var indice: Int
    var totale: Int
}

enum Catena {
    static let manager = AlarmManager.shared
    static let suonoNormale = "suoneria_normale.wav"
    static let suonoPunizione = "suoneria_punizione.wav"
    static let suonoLungo = "test_lungo_3min.wav"
    static let primaPunizione = 5 // dalla 5ª sveglia in poi

    /// Programma subito la sveglia principale e tutte quelle di riserva.
    /// Se AlarmKit segnala il limite massimo, allarga l'intervallo e riprova.
    static func programma(inizio: Date, intervallo: Int, durataMinuti: Int) async {
        cancellaTutto(motivo: "nuova programmazione")
        var intervallo = max(intervallo, 5)
        for _ in 0..<4 {
            let totale = durataMinuti * 60 / intervallo + 1
            var programmate = 0
            do {
                for i in 0..<totale {
                    let suono = i + 1 >= primaPunizione ? suonoPunizione : suonoNormale
                    try await programmaUna(data: inizio.addingTimeInterval(Double(i * intervallo)),
                                           indice: i + 1, totale: totale, suono: suono)
                    programmate += 1
                }
                Log.add("Catena programmata: \(totale) sveglie ogni \(intervallo) s per \(durataMinuti) min, prima alle \(inizio.formatted(date: .omitted, time: .standard))")
                return
            } catch {
                if case .maximumLimitReached = error as? AlarmManager.AlarmError {
                    Log.add("LIMITE AlarmKit raggiunto dopo \(programmate) sveglie (richieste \(totale))")
                    cancellaTutto(motivo: "limite raggiunto, riprovo")
                    guard programmate > 1 else { return }
                    // stessa durata coperta con meno sveglie
                    intervallo = Int((Double(durataMinuti * 60) / Double(programmate - 1)).rounded(.up))
                    Log.add("Nuovo intervallo: \(intervallo) s")
                } else {
                    Log.add("ERRORE programmazione sveglia \(programmate + 1): \(error)")
                    return
                }
            }
        }
    }

    /// Una sola sveglia (per il test del suono lungo).
    static func programmaSingola(data: Date, suono: String) async {
        do {
            try await programmaUna(data: data, indice: 1, totale: 1, suono: suono)
            Log.add("Sveglia singola alle \(data.formatted(date: .omitted, time: .standard)) con \(suono)")
        } catch {
            Log.add("ERRORE sveglia singola: \(error)")
        }
    }

    private static func programmaUna(data: Date, indice: Int, totale: Int, suono: String) async throws {
        let punizione = suono == suonoPunizione
        let titolo: LocalizedStringResource = punizione
            ? "PUNIZIONE \(indice)/\(totale) - usa il tag!"
            : "Sveglia \(indice)/\(totale)"
        // Init deprecato in iOS 26.1 ma l'unico disponibile con target 26.0; da 26.1 il sistema ignora stopButton.
        let alert = AlarmPresentation.Alert(title: titolo,
                                            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
                                            secondaryButton: nil,
                                            secondaryButtonBehavior: nil)
        let attributi = AlarmAttributes(presentation: AlarmPresentation(alert: alert),
                                        metadata: DatiSveglia(indice: indice, totale: totale),
                                        tintColor: punizione ? .red : .orange)
        let id = UUID()
        let config = AlarmManager.AlarmConfiguration.alarm(schedule: .fixed(data),
                                                          attributes: attributi,
                                                          stopIntent: StopSenzaTagIntent(alarmID: id.uuidString, indice: indice),
                                                          secondaryIntent: nil,
                                                          sound: .named(suono))
        _ = try await manager.schedule(id: id, configuration: config)
    }

    /// Ferma quella che suona e cancella tutte le altre. Ritorna quante ne ha tolte.
    @discardableResult
    static func cancellaTutto(motivo: String) -> Int {
        let tutte = (try? manager.alarms) ?? []
        for a in tutte {
            // stop() su una sveglia singola che suona la rimuove già: un cancel() dopo darebbe errore Code=0
            do {
                if a.state == .alerting { try manager.stop(id: a.id) } else { try manager.cancel(id: a.id) }
            } catch { Log.add("Errore cancellazione \(a.id): \(error)") }
        }
        if !tutte.isEmpty { Log.add("Cancellate \(tutte.count) sveglie (\(motivo))") }
        return tutte.count
    }

    /// Logica unica usata sia dall'App Intent sia dal pulsante "Simula tag".
    static func spegniConTag(nomeTag: String?) -> Int {
        let inCorso = ((try? manager.alarms) ?? []).filter { $0.state == .alerting }.count
        Log.add("SPEGNIMENTO COL TAG \"\(nomeTag ?? "-")\" (sveglie in corso: \(inCorso))")
        return cancellaTutto(motivo: "tag")
    }

    static func data(di alarm: Alarm) -> Date? {
        if case .fixed(let d) = alarm.schedule { return d }
        return nil
    }
}
