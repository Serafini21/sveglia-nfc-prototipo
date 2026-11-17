import AlarmKit
import SwiftUI

@main
struct SvegliaNFCApp: App {
    init() { Log.add("Avvio app") }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Sveglia", systemImage: "alarm") { SvegliaView() }
                Tab("Log", systemImage: "doc.text") { LogView() }
            }
        }
    }
}

struct SvegliaView: View {
    @State private var auth = AlarmManager.shared.authorizationState
    @State private var sveglie: [Alarm] = []
    @State private var orario = Date()
    @AppStorage("intervallo") private var intervallo = 30
    @AppStorage("durata") private var durata = 30
    @AppStorage("stopSenzaTag") private var stopSenzaTag = 0
    @State private var nomeTag = "prova"

    var body: some View {
        NavigationStack {
            Form {
                Section("Autorizzazione AlarmKit") {
                    Text("Stato: \(testo(auth))")
                    if auth != .authorized {
                        Button("Chiedi autorizzazione") {
                            Task {
                                do { auth = try await AlarmManager.shared.requestAuthorization() }
                                catch { Log.add("ERRORE autorizzazione: \(error)") }
                                Log.add("Autorizzazione: \(testo(auth))")
                            }
                        }
                    }
                }

                Section("Sveglia") {
                    DatePicker("Orario", selection: $orario, displayedComponents: .hourAndMinute)
                    Button("Imposta sveglia") { programma(prossima(orario)) }
                    Button("Test: sveglia tra 1 minuto") { programma(.now.addingTimeInterval(60)) }
                    Button("Test suono lungo (3 min) tra 1 minuto") {
                        Task { await Catena.programmaSingola(data: .now.addingTimeInterval(60), suono: Catena.suonoLungo); aggiorna() }
                    }
                }

                Section("Catena") {
                    Stepper("Intervallo: \(intervallo) s", value: $intervallo, in: 10...300, step: 10)
                    Stepper("Durata totale: \(durata) min", value: $durata, in: 1...120)
                    Button("Catena breve: 3 minuti") { durata = 3; intervallo = 30 }
                    Text("Suoneria punizione dalla \(Catena.primaPunizione)ª sveglia")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Stato") {
                    Text("Sveglie programmate: \(sveglie.count)")
                    if let p = sveglie.compactMap(Catena.data).filter({ $0 > .now }).min() {
                        Text("Prossima: \(p.formatted(date: .abbreviated, time: .standard))")
                    }
                    if sveglie.contains(where: { $0.state == .alerting }) {
                        Text("SVEGLIA IN CORSO").foregroundStyle(.red).bold()
                    }
                    Text("Stop senza tag (totale): \(stopSenzaTag)")
                }

                Section("Spegnimento") {
                    TextField("Nome tag", text: $nomeTag)
                    Button("Simula tag") { Catena.spegniConTag(nomeTag: nomeTag); aggiorna() }
                    Button("Cancella tutte le sveglie", role: .destructive) {
                        Catena.cancellaTutto(motivo: "pulsante di sicurezza"); aggiorna()
                    }
                }
            }
            .navigationTitle("Sveglia NFC (prototipo)")
            .task {
                for await lista in AlarmManager.shared.alarmUpdates { sveglie = lista }
            }
            .task {
                for await stato in AlarmManager.shared.authorizationUpdates { auth = stato }
            }
            .onAppear { aggiorna() }
        }
    }

    private func programma(_ data: Date) {
        Task { await Catena.programma(inizio: data, intervallo: intervallo, durataMinuti: durata); aggiorna() }
    }

    private func aggiorna() {
        sveglie = (try? AlarmManager.shared.alarms) ?? []
        stopSenzaTag = UserDefaults.standard.integer(forKey: "stopSenzaTag")
    }

    /// Prossima occorrenza dell'orario scelto (oggi se nel futuro, altrimenti domani).
    private func prossima(_ d: Date) -> Date {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return Calendar.current.nextDate(after: .now, matching: c, matchingPolicy: .nextTime) ?? d
    }

    private func testo(_ s: AlarmManager.AuthorizationState) -> String {
        switch s {
        case .authorized: "concessa"
        case .denied: "NEGATA (abilitala in Impostazioni)"
        case .notDetermined: "non ancora richiesta"
        @unknown default: "sconosciuto"
        }
    }
}

struct LogView: View {
    @State private var testo = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                // più recenti in alto
                Text(testo.split(separator: "\n").reversed().joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem { Button("Aggiorna") { testo = Log.leggi() } }
                ToolbarItem { ShareLink("Condividi log", item: testo) }
            }
            .onAppear { testo = Log.leggi() }
            .refreshable { testo = Log.leggi() }
        }
    }
}
