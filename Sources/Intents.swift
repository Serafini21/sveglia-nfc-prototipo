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
        let restanti = ((try? AlarmManager.shared.alarms) ?? []).count
        Log.add("STOP SENZA TAG sulla sveglia n. \(indice) (totale stop senza tag: \(n), sveglie ancora programmate: \(restanti))")
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
