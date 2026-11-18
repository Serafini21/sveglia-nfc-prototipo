import AppIntents
import Foundation

/// Eseguita dall'automazione NFC di Comandi Rapidi. Non apre l'app.
/// Senza il codice segreto giusto viene rifiutata (e registrata come tentativo sospetto).
struct SpegniConTagIntent: AppIntent {
    static let title: LocalizedStringResource = "Spegni sveglia"
    static let description = IntentDescription("Spegne la sveglia di Alba. Da usare nell'automazione NFC con il nome del tag e il codice segreto mostrati nell'app.")

    @Parameter(title: "Nome tag")
    var nomeTag: String?

    @Parameter(title: "Codice segreto")
    var codice: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Spegni sveglia con il tag \(\.$nomeTag) e il codice \(\.$codice)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let r = await AlarmEngine.shared.spegniConTag(nome: nomeTag, codice: codice)
        return .result(dialog: "\(r.messaggio)")
    }
}

/// Lo stopIntent di ogni sveglia: lo chiama iOS col pulsante Stop o col tasto laterale (anche ad app chiusa).
/// Ferma tutte le sveglie in corso e registra lo stop nella mattina; la catena resta programmata.
struct StopSenzaTagIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop senza tag"
    static let isDiscoverable = false

    @Parameter(title: "ID sveglia") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        await AlarmEngine.shared.stop(alarmID: alarmID, pulsanteEmergenza: false)
        return .result()
    }
}

/// Pulsante secondario "Emergenza" della sveglia: ferma le sveglie in corso (conta come uno stop)
/// e apre l'app sulla schermata Emergency Stop.
struct EmergenzaIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Emergenza"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "ID sveglia") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        await AlarmEngine.shared.stop(alarmID: alarmID, pulsanteEmergenza: true)
        await MainActor.run { StatoApp.shared.schermata = .emergenza }
        return .result()
    }
}

struct Scorciatoie: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SpegniConTagIntent(),
                    phrases: ["Spegni la sveglia con \(.applicationName)",
                              "Spegni \(.applicationName)"],
                    shortTitle: "Spegni sveglia",
                    systemImageName: "alarm")
    }
}
