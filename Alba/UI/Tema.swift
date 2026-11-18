import SwiftUI

/// Colori dello stile "Alba" (PROGETTO.md §7). I font Space Grotesk e Inter arrivano con la grafica completa (Fase 2).
enum Tema {
    static let sfondo = Color(hex: 0x0B1020)
    static let superficie = Color(hex: 0x151B2E)
    static let superficie2 = Color(hex: 0x1E2640)
    static let bordo = Color(hex: 0x232B45)
    static let testo = Color(hex: 0xF2F4F8)
    static let testo2 = Color(hex: 0x9AA3B8)
    static let ambra = Color(hex: 0xFFB547)
    static let suAmbra = Color(hex: 0x1A1206)
    static let ambraTenue = Color(hex: 0x2A2418)
    static let pericolo = Color(hex: 0xFF8A7A)
    static let successo = Color(hex: 0x7FE0B4)
    static let successoFondo = Color(hex: 0x17302A)
    static let mattinoSfondo = Color(hex: 0x160F0A)
    static let mattinoSuperficie = Color(hex: 0x24180F)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension View {
    /// Liste e form sullo sfondo Alba.
    func stileAlba() -> some View {
        scrollContentBackground(.hidden).background(Tema.sfondo.ignoresSafeArea())
    }
}

/// Date e durate in italiano.
enum Formati {
    private static func formatter(_ formato: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = formato
        return f
    }
    private static let hm = formatter("HH:mm")
    private static let hms = formatter("HH:mm:ss")
    private static let lungo = formatter("EEEE d MMMM")
    private static let breve = formatter("EEE d MMM")

    static func ora(_ d: Date, secondi: Bool = false) -> String { (secondi ? hms : hm).string(from: d) }

    /// "oggi, giovedì 19 novembre alle 07:00" / "domani, ..." / "sabato 21 novembre alle 07:00"
    static func quando(_ d: Date) -> String {
        let cal = Calendar.current
        let prefisso = cal.isDateInToday(d) ? "oggi, " : cal.isDateInTomorrow(d) ? "domani, " : ""
        return "\(prefisso)\(lungo.string(from: d)) alle \(ora(d))"
    }

    static func giornoBreve(_ d: Date) -> String { breve.string(from: d) }

    static func durata(_ secondi: TimeInterval) -> String {
        let t = Int(max(0, secondi))
        return t < 3600 ? String(format: "%d:%02d", t / 60, t % 60) : "\(t / 3600) h \(t % 3600 / 60) min"
    }

    static func traQuanto(_ d: Date, da: Date = Date()) -> String {
        let s = Int(d.timeIntervalSince(da))
        if s < 60 { return s < 0 ? "in corso" : "tra meno di un minuto" }
        let h = s / 3600, m = s % 3600 / 60
        return h > 0 ? "tra \(h) h \(m) min" : "tra \(m) min"
    }

    static func giorni(_ s: Sveglia) -> String {
        if s.giorni.isEmpty { return s.dataUnaTantum.map { "una volta, \(giornoBreve($0))" } ?? "una volta" }
        let insieme = Set(s.giorni)
        if insieme.count == 7 { return "ogni giorno" }
        if insieme == [2, 3, 4, 5, 6] { return "lun–ven" }
        if insieme == [1, 7] { return "sab e dom" }
        let nomi = [2: "lun", 3: "mar", 4: "mer", 5: "gio", 6: "ven", 7: "sab", 1: "dom"]
        return [2, 3, 4, 5, 6, 7, 1].filter { insieme.contains($0) }.compactMap { nomi[$0] }.joined(separator: ", ")
    }
}

/// Riscontro visivo immediato in alto (i test del prototipo hanno mostrato tocchi ripetuti senza riscontro).
struct Avviso: View {
    let testo: String?
    var body: some View {
        if let testo {
            Text(testo)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Tema.suAmbra)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Tema.ambra, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16).padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

/// Valore grande con etichetta (statistiche, risveglio).
struct Dato: View {
    let titolo: String
    let valore: String
    var body: some View {
        VStack(spacing: 4) {
            Text(valore).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Tema.ambra)
            Text(titolo).font(.caption).foregroundStyle(Tema.testo2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
