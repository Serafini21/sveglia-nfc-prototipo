import Foundation
import UserNotifications

/// Scadenza dell'app firmata con Apple ID gratuito (7 giorni) e promemoria con notifiche locali.
enum Scadenza {
    /// Data letta da embedded.mobileprovision (messo da Sideloadly nell'app firmata), nil se assente o illeggibile.
    static func leggi() -> Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            EventLog.scrivi("Scadenza sconosciuta: embedded.mobileprovision assente")
            return nil
        }
        guard let dati = try? Data(contentsOf: url), let data = Regole.scadenza(profilo: dati) else {
            EventLog.scrivi("Scadenza sconosciuta: embedded.mobileprovision illeggibile")
            return nil
        }
        return data
    }

    /// Promemoria alle 20:00 di 2 giorni e di 1 giorno prima della scadenza.
    static func programmaPromemoria(scadenza: Date) async {
        let centro = UNUserNotificationCenter.current()
        do {
            let ok = try await centro.requestAuthorization(options: [.alert, .sound, .badge])
            if !ok { EventLog.scrivi("Notifiche non autorizzate: niente promemoria di scadenza") }
        } catch {
            EventLog.scrivi("ERRORE permesso notifiche: \(error)")
        }
        let id = ["alba-scadenza-2", "alba-scadenza-1"]
        centro.removePendingNotificationRequests(withIdentifiers: id)
        let cal = Calendar.current
        var programmati: [String] = []
        for (k, giorni) in [2, 1].enumerated() {
            let giorno = scadenza.addingTimeInterval(-Double(giorni) * 86400)
            // alle 20:00 del giorno 2 (o 1) giorni prima: sempre prima della scadenza, mai di notte
            let quando = cal.date(bySettingHour: 20, minute: 0, second: 0, of: giorno) ?? giorno
            guard quando > Date() else { continue }
            let c = UNMutableNotificationContent()
            c.title = giorni == 1 ? "Alba scade domani" : "Alba scade tra 2 giorni"
            c.body = "Reinstallala con Sideloadly: se scade non si apre più e le sveglie potrebbero non funzionare."
            c.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: quando), repeats: false)
            do {
                try await centro.add(UNNotificationRequest(identifier: id[k], content: c, trigger: trigger))
                programmati.append(EventLog.data(quando))
            } catch {
                EventLog.scrivi("ERRORE promemoria scadenza: \(error)")
            }
        }
        EventLog.scrivi("Scadenza app: \(EventLog.data(scadenza)); promemoria: \(programmati.isEmpty ? "nessuno" : programmati.joined(separator: ", "))")
    }
}
