import Foundation

/// Unico punto di accesso ai dati: un file JSON versionato in Application Support, scritto in modo atomico.
/// Le modifiche alle mattine passano dalla coda di AlarmEngine; qui ogni lettura e scrittura è serializzata dall'attore.
actor Store {
    static let shared = Store()

    let url: URL
    private var dati: DatiAlba

    init() {
        let cartella = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        let file = cartella.appending(path: "alba.json")
        url = file
        dati = Store.carica(file)
    }

    func leggi() -> DatiAlba { dati }

    @discardableResult
    func modifica<T>(_ cambia: (inout DatiAlba) -> T) -> T {
        let risultato = cambia(&dati)
        salva()
        return risultato
    }

    private func salva() {
        do {
            try Store.codificatore.encode(dati).write(to: url, options: [.atomic])
        } catch {
            EventLog.scrivi("ERRORE salvataggio dati: \(error)")
        }
        let copia = dati
        Task { @MainActor in StatoApp.shared.dati = copia }
    }

    private static var codificatore: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    /// Legge il file. Se manca parte da zero; se è illeggibile o di una versione futura lo mette da parte
    /// (alba-illeggibile-<data>.json) invece di sovrascriverlo, così i dati non vanno persi.
    private static func carica(_ url: URL) -> DatiAlba {
        guard let byte = try? Data(contentsOf: url) else {
            // salvato subito: il codice segreto generato ora non deve cambiare al prossimo avvio
            let nuovi = DatiAlba()
            try? codificatore.encode(nuovi).write(to: url, options: [.atomic])
            EventLog.scrivi("Dati: nessun file, primo avvio")
            return nuovi
        }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        do {
            let dati = try d.decode(DatiAlba.self, from: byte)
            guard dati.schemaVersion <= DatiAlba.versioneCorrente else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "schemaVersion \(dati.schemaVersion) più recente dell'app"])
            }
            return dati
        } catch {
            let copia = url.deletingLastPathComponent()
                .appending(path: "alba-illeggibile-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: url, to: copia)
            EventLog.scrivi("ERRORE lettura dati (\(error)). Copia salvata in \(copia.lastPathComponent), riparto da zero")
            return DatiAlba()
        }
    }
}
