import Foundation

/// Log diagnostico in testo (Documents/alba-log.txt): data completa con millisecondi, rotazione a ~500 KB.
/// Sincrono e protetto da un lock: si può chiamare da qualsiasi punto, anche dagli intent in background.
enum EventLog {
    static let url = URL.documentsDirectory.appending(path: "alba-log.txt")
    static let precedente = URL.documentsDirectory.appending(path: "alba-log.1.txt")
    static let maxByte = 500_000
    private static let lock = NSLock()
    private static let formato: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func scrivi(_ testo: String) {
        lock.lock(); defer { lock.unlock() }
        let riga = Data("\(formato.string(from: Date())) \(testo)\n".utf8)
        let fm = FileManager.default
        if let byte = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int), byte > maxByte {
            try? fm.removeItem(at: precedente)
            try? fm.moveItem(at: url, to: precedente)
        }
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(riga)
            try? h.close()
        } else {
            try? riga.write(to: url)
        }
    }

    static func data(_ d: Date) -> String {
        lock.lock(); defer { lock.unlock() }
        return formato.string(from: d)
    }

    /// Log completo: prima il file ruotato, poi quello attuale.
    static func leggi() -> String {
        lock.lock(); defer { lock.unlock() }
        let vecchio = (try? String(contentsOf: precedente, encoding: .utf8)) ?? ""
        let attuale = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return vecchio + attuale
    }

    /// Copia del log completo in un file temporaneo, da condividere con ShareLink.
    static func fileDaCondividere() -> URL {
        let dest = URL.temporaryDirectory.appending(path: "Alba-log.txt")
        try? Data(leggi().utf8).write(to: dest, options: .atomic)
        return dest
    }
}
