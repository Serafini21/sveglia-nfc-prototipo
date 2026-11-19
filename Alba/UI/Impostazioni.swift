import SwiftUI
import UIKit
import UserNotifications

struct ImpostazioniView: View {
    @EnvironmentObject var stato: StatoApp
    @State private var notifiche: UNAuthorizationStatus?
    @State private var fileLog: URL?

    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }

    private var scadenza: String {
        guard let s = stato.scadenza else { return "Scadenza sconosciuta" }
        if s < Date() { return "Scaduta: reinstallala con Sideloadly" }
        let giorni = Int((s.timeIntervalSinceNow / 86400).rounded(.up))
        return "L'app scade tra \(giorni) \(giorni == 1 ? "giorno" : "giorni") (\(Formati.quando(s)))"
    }

    private var testoNotifiche: String {
        guard let notifiche else { return "…" }
        return switch notifiche {
        case .authorized, .provisional, .ephemeral: "attive"
        case .denied: "negate (attivale in Impostazioni › Alba)"
        case .notDetermined: "non ancora richieste"
        default: "…"
        }
    }

    private var testoSveglie: String {
        switch stato.autorizzazione {
        case .authorized: "concesso"
        case .denied: "NEGATO"
        case .notDetermined: "non ancora richiesto"
        @unknown default: "sconosciuto"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("App") {
                    Label(scadenza, systemImage: "clock.badge.exclamationmark")
                    LabeledContent("Promemoria scadenza", value: testoNotifiche)
                    if notifiche == .notDetermined, let s = stato.scadenza {
                        Button("Attiva i promemoria") {
                            Task {
                                await Scadenza.programmaPromemoria(scadenza: s)
                                notifiche = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                            }
                        }
                    }
                    LabeledContent("Versione", value: "1.0 (build \(build))")
                }
                .listRowBackground(Tema.superficie)

                Section("Sveglie") {
                    LabeledContent("Permesso Sveglie", value: testoSveglie)
                    if stato.autorizzazione != .authorized {
                        Button("Apri le Impostazioni di iOS") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }
                .listRowBackground(Tema.superficie)

                Section {
                    LabeledContent("Crediti", value: "\(stato.dati.impostazioni.creditiEmergenza)/\(Costanti.creditiMax)")
                    if let r = Regole.prossimaRicarica(stato.dati.impostazioni) {
                        LabeledContent("Prossima ricarica", value: Formati.quando(r))
                    }
                } header: {
                    Text("Emergency Stop")
                } footer: {
                    Text("1 credito ogni 7 giorni, al massimo 2. Si usa tenendo premuto 10 secondi e scrivendo la frase. Azzera lo streak.")
                }
                .listRowBackground(Tema.superficie)

                Section {
                    LabeledContent("Risuona dopo uno stop", value: "\(ParametriMattina(progressiva: false).intervalloCatenaSec) s")
                    LabeledContent("Durata della catena", value: "\(ParametriMattina(progressiva: false).durataCatenaMin) min")
                    LabeledContent("Sirena dalla sveglia n°", value: "\(Costanti.primaPunizione)")
                    LabeledContent("Blocco modifiche", value: "\(Int(Costanti.finestraPrima / 3600)) h prima")
                    LabeledContent("Tolleranza Stop → tag", value: "\(Int(Costanti.tolleranzaStopTag)) s")
                } header: {
                    Text("Regole anti-trucco")
                }
                .listRowBackground(Tema.superficie)

                Section {
                    NavigationLink { RoutineEditor() } label: {
                        LabeledContent("Routine del mattino", value: "\(stato.dati.routine.count) voci")
                    }
                } footer: {
                    Text("La checklist compare nella schermata «Buongiorno!» dopo il tag.")
                }
                .listRowBackground(Tema.superficie)

                Section("Diagnostica") {
                    NavigationLink { LogView() } label: { Label("Log", systemImage: "doc.text") }
                    if let fileLog {
                        ShareLink(item: fileLog) { Label("Esporta log", systemImage: "square.and.arrow.up") }
                    }
                }
                .listRowBackground(Tema.superficie)

                if stato.dati.impostazioni.sviluppatore {
                    Section {
                        NavigationLink { SviluppatoreView() } label: { Label("Modalità sviluppatore", systemImage: "hammer") }
                    }
                    .listRowBackground(Tema.superficie)
                }
            }
            .font(.inter(16))
            .stileAlba()
            .navigationTitle("Impostazioni")
            .task {
                fileLog = EventLog.fileDaCondividere()
                notifiche = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            }
        }
    }
}

/// Checklist del mattino: aggiungi, elimina (scorrendo) e riordina le voci.
struct RoutineEditor: View {
    @EnvironmentObject var stato: StatoApp
    @State private var nuova = ""

    var body: some View {
        List {
            Section {
                if stato.dati.routine.isEmpty {
                    Text("Nessuna voce. Per esempio: bevi un bicchiere d'acqua, apri le finestre.")
                        .foregroundStyle(Tema.testo2)
                }
                ForEach(stato.dati.routine) { v in Text(v.testo).foregroundStyle(Tema.testo) }
                    .onDelete { posizioni in
                        let ids = posizioni.map { stato.dati.routine[$0].id }
                        Task { await Store.shared.modifica { $0.routine.removeAll { ids.contains($0.id) } } }
                    }
                    .onMove { da, a in
                        var r = stato.dati.routine
                        r.move(fromOffsets: da, toOffset: a)
                        let nuovoOrdine = r
                        Task { await Store.shared.modifica { $0.routine = nuovoOrdine } }
                    }
            }
            .listRowBackground(Tema.superficie)

            Section {
                HStack {
                    TextField("Nuova voce", text: $nuova)
                        .submitLabel(.done)
                        .onSubmit { aggiungi() }
                    Button("Aggiungi") { aggiungi() }
                        .disabled(nuova.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .listRowBackground(Tema.superficie)
        }
        .font(.inter(16))
        .stileAlba()
        .navigationTitle("Routine del mattino")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func aggiungi() {
        let testo = nuova.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testo.isEmpty else { return }
        nuova = ""
        Task { await Store.shared.modifica { $0.routine.append(VoceRoutine(testo: testo)) } }
    }
}

struct LogView: View {
    @State private var voci: [String] = []
    @State private var file: URL?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(voci.indices, id: \.self) { i in
                    Text(voci[i])
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Tema.testo)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(Tema.sfondo.ignoresSafeArea())
        .navigationTitle("Log (più recenti in alto)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { carica() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Aggiorna")
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let file {
                    ShareLink(item: file) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Esporta log")
                }
            }
        }
        .onAppear { carica() }
    }

    /// Le righe che iniziano con spazi appartengono alla voce precedente (note del riallineamento).
    private func carica() {
        var elenco: [String] = []
        for riga in EventLog.leggi().split(separator: "\n") {
            if riga.hasPrefix(" "), !elenco.isEmpty { elenco[elenco.count - 1] += "\n" + riga } else { elenco.append(String(riga)) }
        }
        voci = Array(elenco.suffix(2000).reversed())
        file = EventLog.fileDaCondividere()
    }
}
