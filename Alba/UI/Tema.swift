import CoreText
import SwiftUI
import UIKit

/// Stile "Alba" del mockup approvato (PROGETTO.md §7).
enum Tema {
    static let sfondo = Color(hex: 0x0B1020)
    static let superficie = Color(hex: 0x151B2E)
    static let superficie2 = Color(hex: 0x1E2640)
    static let bordo = Color(hex: 0x232B45)
    static let testo = Color(hex: 0xF2F4F8)
    static let testo2 = Color(hex: 0x9AA3B8)
    static let testo3 = Color(hex: 0x8A93A8)
    static let testoChiaro = Color(hex: 0xC9CFDC)
    static let ambra = Color(hex: 0xFFB547)
    static let suAmbra = Color(hex: 0x1A1206)
    static let ambraTenue = Color(hex: 0x2A2418)
    static let spento = Color(hex: 0x2E3654)
    static let notte = Color(hex: 0x1A1F33)
    static let pericolo = Color(hex: 0xFF8A7A)
    static let successo = Color(hex: 0x7FE0B4)
    static let successoFondo = Color(hex: 0x17302A)
    // Schermate del mattino (sveglia in corso, Emergency)
    static let mattinoSfondo = Color(hex: 0x160F0A)
    static let mattinoSuperficie = Color(hex: 0x24180F)
    static let mattinoCampo = Color(hex: 0x1C130C)
    static let mattinoScuro = Color(hex: 0x3A2A1C)
    static let mattinoAnello = Color(hex: 0x4A3420)
    static let mattinoBordo = Color(hex: 0x6E4A26)
    static let mattinoTesto = Color(hex: 0xFFF6EC)
    static let mattinoTesto2 = Color(hex: 0xC8B8A6)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Font {
    /// Space Grotesk, per orari e titoli.
    static func grotesk(_ size: CGFloat, _ peso: Font.Weight = .semibold) -> Font { famiglia("Space Grotesk", size, peso) }
    /// Inter, per il testo.
    static func inter(_ size: CGFloat, _ peso: Font.Weight = .regular) -> Font { famiglia("Inter", size, peso) }

    private static let famiglieNelBundle = Set(UIFont.familyNames)

    /// I file sono font variabili: si chiede a iOS la famiglia col peso voluto e lui sceglie l'istanza più vicina,
    /// invece di affidarsi a Font.custom col nome della famiglia. Senza il font si usa quello di sistema.
    private static func famiglia(_ nome: String, _ size: CGFloat, _ peso: Font.Weight) -> Font {
        guard famiglieNelBundle.contains(nome) else { return .system(size: size, weight: peso) }
        let descrittore = UIFontDescriptor(fontAttributes: [
            .family: nome,
            .traits: [UIFontDescriptor.TraitKey.weight: peso.perUIKit],
        ])
        return Font(UIFontMetrics.default.scaledFont(for: UIFont(descriptor: descrittore, size: size)) as CTFont)
    }
}

private extension Font.Weight {
    var perUIKit: UIFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

extension View {
    /// Liste e form sullo sfondo Alba.
    func stileAlba() -> some View {
        scrollContentBackground(.hidden).background(Tema.sfondo.ignoresSafeArea())
    }

    /// Riquadro arrotondato del mockup.
    func scheda(_ colore: Color = Tema.superficie, raggio: CGFloat = 18, margine: CGFloat = 16) -> some View {
        padding(margine).background(colore, in: RoundedRectangle(cornerRadius: raggio, style: .continuous))
    }

    /// Riga di una List mostrata come scheda libera, senza separatori.
    func rigaLibera() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
    }
}

/// Etichetta maiuscola delle sezioni ("PROSSIMA SVEGLIA").
struct EtichettaSezione: View {
    let testo: String
    var colore = Tema.testo2
    var body: some View {
        Text(testo.uppercased())
            .font(.inter(13, .semibold))
            .tracking(0.6)
            .foregroundStyle(colore)
    }
}

/// Titolo grande delle schede principali.
struct Titolo: View {
    let testo: String
    var body: some View {
        Text(testo)
            .font(.grotesk(32, .bold))
            .tracking(-0.5)
            .foregroundStyle(Tema.testo)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Pulsante ambra pieno (azione principale).
struct PulsantePrincipale: ButtonStyle {
    var altezza: CGFloat = 60
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(17, .bold))
            .foregroundStyle(Tema.suAmbra)
            .frame(maxWidth: .infinity, minHeight: altezza)
            .background(Tema.ambra.opacity(configuration.isPressed ? 0.75 : 1),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Pulsante scuro (azione secondaria).
struct PulsanteSecondario: ButtonStyle {
    var colore = Tema.superficie2
    var testo = Tema.testo
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(15, .semibold))
            .foregroundStyle(testo)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(colore.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Pulsante quadrato da 44 pt con icona.
struct PulsanteIcona: ButtonStyle {
    var colore = Tema.superficie2
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Tema.testo)
            .frame(width: 44, height: 44)
            .background(colore.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Pastiglia colorata (esito, stato del tag).
struct Pastiglia: View {
    let testo: String
    var colore = Tema.testoChiaro
    var fondo = Tema.superficie2
    var body: some View {
        Text(testo)
            .font(.inter(12, .semibold))
            .foregroundStyle(colore)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(fondo, in: Capsule())
    }
}

/// Valore grande con etichetta (statistiche, risveglio).
struct Dato: View {
    let titolo: String
    let valore: String
    var coloreValore = Tema.testo
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(valore)
                .font(.grotesk(26))
                .foregroundStyle(coloreValore)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(titolo).font(.inter(12)).foregroundStyle(Tema.testo2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scheda(raggio: 16, margine: 14)
        .accessibilityElement(children: .combine)
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
    private static let hm = formatter("H:mm")
    private static let hms = formatter("H:mm:ss")
    private static let lungo = formatter("EEEE d MMMM")
    private static let breve = formatter("EEE d MMM")
    private static let settimana = formatter("EEE")

    static func ora(_ d: Date, secondi: Bool = false) -> String { (secondi ? hms : hm).string(from: d) }

    /// "oggi, giovedì 19 novembre alle 7:00" / "domani, ..." / "sabato 21 novembre alle 7:00"
    static func quando(_ d: Date) -> String {
        let cal = Calendar.current
        let prefisso = cal.isDateInToday(d) ? "oggi, " : cal.isDateInTomorrow(d) ? "domani, " : ""
        return "\(prefisso)\(lungo.string(from: d)) alle \(ora(d))"
    }

    static func giornoBreve(_ d: Date) -> String { breve.string(from: d) }

    /// "Oggi", "Ieri", "Lun"...
    static func giornoStorico(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Oggi" }
        if cal.isDateInYesterday(d) { return "Ieri" }
        return settimana.string(from: d).capitalized
    }

    /// Iniziale del giorno della settimana: L M M G V S D.
    static func iniziale(_ d: Date) -> String {
        ["D", "L", "M", "M", "G", "V", "S"][Calendar.current.component(.weekday, from: d) - 1]
    }

    static func durata(_ secondi: TimeInterval) -> String {
        let t = Int(max(0, secondi))
        return t < 3600 ? String(format: "%d:%02d", t / 60, t % 60) : "\(t / 3600) h \(t % 3600 / 60) min"
    }

    /// "7 h 30", "6 h"
    static func ore(_ secondi: TimeInterval) -> String {
        let m = Int(secondi) / 60
        return m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60)"
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
        if insieme.count == 7 { return "Ogni giorno" }
        if insieme == [2, 3, 4, 5, 6] { return "Lun – Ven" }
        if insieme == [1, 7] { return "Sab, Dom" }
        let nomi = [2: "Lun", 3: "Mar", 4: "Mer", 5: "Gio", 6: "Ven", 7: "Sab", 1: "Dom"]
        return [2, 3, 4, 5, 6, 7, 1].filter { insieme.contains($0) }.compactMap { nomi[$0] }.joined(separator: ", ")
    }
}

/// Riscontro visivo immediato in alto (i test del prototipo hanno mostrato tocchi ripetuti senza riscontro).
struct Avviso: View {
    let testo: String?
    var body: some View {
        if let testo {
            Text(testo)
                .font(.inter(15, .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Tema.suAmbra)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Tema.ambra, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 16).padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
    }
}
