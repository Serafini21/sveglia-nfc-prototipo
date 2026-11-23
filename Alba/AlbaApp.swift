import AlarmKit
import SwiftUI
import UIKit

@main
struct AlbaApp: App {
    // Leggero: gli intent avviano l'app in background ed eseguono anche questo init.
    init() {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        EventLog.scrivi("Avvio app (build \(build))")
    }

    var body: some Scene {
        WindowGroup {
            Radice()
                .environmentObject(StatoApp.shared)
                .preferredColorScheme(.dark)
                .tint(Tema.ambra)
                .font(.inter(16))
        }
    }
}

enum Schermata: Identifiable, Hashable {
    case inCorso, emergenza, risveglio(UUID)
    var id: String {
        switch self {
        case .inCorso: "inCorso"
        case .emergenza: "emergenza"
        case .risveglio(let id): "risveglio-\(id)"
        }
    }
}

/// Stato osservato dall'interfaccia: copia dei dati dello Store (aggiornata a ogni salvataggio) e stato di AlarmKit.
@MainActor
final class StatoApp: ObservableObject {
    static let shared = StatoApp()

    @Published var dati = DatiAlba() {
        didSet {
            aggiornaSchermata()
            // solo con l'interfaccia caricata: un intent che avvia l'app in background non accende l'audio
            if caricato { Guardiano.shared.aggiorna(dati) }
        }
    }
    @Published var caricato = false
    /// Scritti dal Guardiano.
    @Published var guardiano = false
    @Published var uscitaEsterna: String?
    @Published var kit: [Alarm] = []
    @Published var autorizzazione = AlarmEngine.shared.autorizzazione
    @Published var schermata: Schermata?
    @Published var scadenza: Date?
    @Published var messaggio: String?
    private var avviato = false

    var mattinaInCorso: Mattina? { dati.mattine.first { $0.inCorso(Date()) } }

    /// Prossima mattina aperta (anche di test).
    var prossima: Mattina? {
        let ora = Date()
        return dati.mattine.filter { !$0.conclusa && $0.fine > ora }.min { $0.inizio < $1.inizio }
    }

    func avvio() async {
        guard !avviato else { return }
        avviato = true
        dati = await Store.shared.leggi()
        caricato = true
        let font = ["Space Grotesk", "Inter"].map { famiglia -> String in
            let nomi = UIFont.fontNames(forFamilyName: famiglia)
            return "\(famiglia) \(nomi.isEmpty ? "ASSENTE" : "ok [\(nomi.joined(separator: ", "))]")"
        }
        EventLog.scrivi("Font: " + font.joined(separator: "; "))
        Guardiano.shared.aggiorna(dati)
        if autorizzazione == .notDetermined {
            autorizzazione = await AlarmEngine.shared.chiediAutorizzazione()
        }
        await Guardiano.chiediPermessoMusica()
        await attiva()
        if let s = Scadenza.leggi() {
            scadenza = s
            await Scadenza.programmaPromemoria(scadenza: s)
        }
    }

    func attiva() async {
        await AlarmEngine.shared.riallinea("app aperta")
        aggiornaSchermata()
    }

    /// Mostra "Sveglia in corso" durante una mattina, "Risveglio riuscito" dopo il tag.
    func aggiornaSchermata() {
        guard caricato else { return }
        let inCorso = mattinaInCorso != nil
        switch schermata {
        case .emergenza:
            return
        case .risveglio:
            if inCorso { schermata = .inCorso }
            return
        default:
            break
        }
        if inCorso {
            if schermata != .inCorso { schermata = .inCorso }
        } else if let m = dati.mattine.last(where: { $0.esito == .tag && !$0.risveglioVisto }) {
            schermata = .risveglio(m.id)
        } else if schermata == .inCorso {
            schermata = nil
        }
    }

    func chiudiSchermata() {
        schermata = nil
        aggiornaSchermata()
    }

    func chiudiRisveglio(_ id: UUID) {
        if let i = dati.mattine.firstIndex(where: { $0.id == id }) { dati.mattine[i].risveglioVisto = true }
        schermata = nil
        Task { await AlarmEngine.shared.segnaRisveglioVisto(id) }
    }

    func avvisa(_ testo: String) {
        withAnimation(.spring) { messaggio = testo }
        Task {
            try? await Task.sleep(for: .seconds(3))
            if messaggio == testo { withAnimation(.easeOut) { messaggio = nil } }
        }
    }
}

struct Radice: View {
    @EnvironmentObject var stato: StatoApp
    @Environment(\.scenePhase) private var fase
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab("Sveglie", systemImage: "alarm", value: 0) { HomeView() }
            Tab("Statistiche", systemImage: "chart.bar", value: 1) { StatisticheView() }
            Tab("Tag", systemImage: "wave.3.right", value: 2) { TagView() }
            Tab("Impostazioni", systemImage: "gearshape", value: 3) { ImpostazioniView() }
        }
        .overlay(alignment: .top) { Avviso(testo: stato.messaggio) }
        .background(CursoreVolume().frame(width: 1, height: 1))
        .fullScreenCover(item: $stato.schermata) { s in
            Group {
                switch s {
                case .inCorso: SvegliaInCorsoView()
                case .emergenza: EmergenzaView()
                case .risveglio(let id): RisveglioView(mattinaID: id)
                }
            }
            .environmentObject(stato)
            .overlay(alignment: .top) { Avviso(testo: stato.messaggio) }
        }
        .task { await stato.avvio() }
        .task {
            await AlarmEngine.shared.osserva(
                sveglie: { lista in
                    StatoApp.shared.kit = lista
                    StatoApp.shared.aggiornaSchermata()
                },
                autorizzazione: { a in StatoApp.shared.autorizzazione = a })
        }
        .onChange(of: fase) { _, nuova in
            if nuova == .active && stato.caricato { Task { await stato.attiva() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            EventLog.scrivi("CAMBIO DI DATA/ORA segnalato da iOS")
            Task { await AlarmEngine.shared.riallinea("cambio data/ora") }
        }
    }
}
