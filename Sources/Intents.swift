import AlarmKit
import AppIntents
import Foundation

/// Eseguita da Comandi Rapidi (automazione NFC). Non apre l'app: openAppWhenRun è false di default.
struct SpegniSvegliaIntent: AppIntent {
    static let title: LocalizedStringResource = "Spegni sveglia"
    static let description = IntentDescription("Ferma la sveglia che suona e cancella tutta la catena.")

    @Parameter(title: "Nome tag")
    var nomeTag: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let n = Catena.spegniConTag(nomeTag: nomeTag)
        return .result(dialog: "Sveglia spenta, \(n) sveglie cancellate")
    }
}

/// Eseguita dal sistema quando premi "Stop" sulla sveglia: la catena resta programmata.
struct StopSenzaTagIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop senza tag"
    static let isDiscoverable = false

    @Parameter(title: "ID sveglia") var alarmID: String
    @Parameter(title: "Indice") var indice: Int

    init() {}
    init(alarmID: String, indice: Int) {
        self.alarmID = alarmID
        self.indice = indice
    }

    func perform() async throws -> some IntentResult {
        let n = UserDefaults.standard.integer(forKey: "stopSenzaTag") + 1
        UserDefaults.standard.set(n, forKey: "stopSenzaTag")
        // Se nessuno ferma una sveglia, AlarmKit la lascia "in corso" sotto la successiva (si accumulano).
        // Le fermiamo tutte: così dopo uno Stop c'è silenzio fino alla prossima sveglia programmata.
        let manager = AlarmManager.shared
        let sovrapposte = ((try? manager.alarms) ?? []).filter { $0.state == .alerting && $0.id.uuidString != alarmID }
        for a in sovrapposte { try? manager.stop(id: a.id) }
        let restanti = ((try? manager.alarms) ?? []).count
        Log.add("STOP SENZA TAG sulla sveglia n. \(indice) (totale stop senza tag: \(n), fermate anche \(sovrapposte.count) sovrapposte, sveglie ancora programmate: \(restanti))")
        return .result()
    }
}

struct Scorciatoie: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SpegniSvegliaIntent(),
                    phrases: ["Spegni sveglia con \(.applicationName)"],
                    shortTitle: "Spegni sveglia",
                    systemImageName: "alarm")
    }
}
