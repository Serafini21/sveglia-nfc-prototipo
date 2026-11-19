import Foundation

// Modello dati di Alba: tutto finisce in un unico file JSON (vedi Store).
// Solo Foundation: questo file viene compilato anche nei test delle regole.
// shortcut: i decoder sono quelli sintetizzati, quindi un campo nuovo non opzionale rompe la lettura
// dei file vecchi. Dalla Fase 2: campi nuovi opzionali, oppure schemaVersion + migrazione in Store.carica.

struct DatiAlba: Codable, Equatable {
    static let versioneCorrente = 1
    var schemaVersion = DatiAlba.versioneCorrente
    var impostazioni = Impostazioni()
    var sveglie: [Sveglia] = []
    var tag: [TagNFC] = []
    var mattine: [Mattina] = []
    var routine: [VoceRoutine] = []
    /// Sveglie del mini-test della progressiva: non appartengono a nessuna mattina.
    var sveglieTest: [SvegliaProgrammata] = []
    /// Avviso da mostrare in Home (sveglie mancanti, permesso revocato...), finché l'utente non lo chiude.
    var avviso: String?
}

struct Impostazioni: Codable, Equatable {
    var progressiva = false
    var codiceSegreto = Regole.nuovoCodice()
    var creditiEmergenza = Costanti.creditiIniziali
    var ultimaRicarica = Date()
    var ultimaDataVista = Date()
    var sviluppatore = false
    var test = ParametriTest()
}

/// Parametri della "catena breve" della modalità sviluppatore.
struct ParametriTest: Codable, Equatable {
    var passoProgressivaSec = 10
    var intervalloCatenaSec = 30
    var durataCatenaMin = 3
    var minutiAllaMattina = 2
    var giorniAllaSveglia = 8
}

struct Sveglia: Codable, Equatable, Identifiable {
    var id = UUID()
    var nome = "Sveglia"
    var ora = 7
    var minuti = 0
    /// Giorni della settimana come Calendar.weekday: 1 = domenica ... 7 = sabato. Vuoto = una volta sola.
    var giorni: [Int] = []
    var attiva = true
    /// Sveglia una tantum: data e ora esatte dell'unica mattina. Dopo quella mattina la sveglia sparisce.
    var dataUnaTantum: Date?
    var suoneria = Suoneria.normale.rawValue
    /// Solo modalità sviluppatore: parametri della catena breve. Le sveglie di test vengono sempre
    /// programmate, anche oltre le prossime 2 mattine, e non contano nelle statistiche.
    var test: ParametriMattina?
}

/// Suonerie dell'app. I valori rawValue sono salvati nel JSON: non rinominarli.
enum Suoneria: String, Codable, CaseIterable, Identifiable {
    case dolce, chiaro, brezza, normale, campanelli, energica, allegro
    var id: String { rawValue }
    var file: String { "\(rawValue).wav" }
    var nome: String {
        switch self {
        case .dolce: "Alba"
        case .chiaro: "Mattino chiaro"
        case .brezza: "Brezza"
        case .normale: "Classica"
        case .campanelli: "Campanelli"
        case .energica: "Energica"
        case .allegro: "Allegro"
        }
    }
    var categoria: Categoria {
        switch self {
        case .dolce, .chiaro, .brezza: .dolci
        case .normale, .campanelli: .normali
        case .energica, .allegro: .energiche
        }
    }

    enum Categoria: String, CaseIterable, Identifiable {
        case dolci, normali, energiche
        var id: String { rawValue }
        var nome: String { rawValue.capitalized }
    }
}

enum Suoni {
    static let punizione = "punizione.wav"
    /// Suono dolce a volume crescente: livello 1 (circa -30 dB) ... 15 (0 dB).
    static func progressiva(_ livello: Int) -> String { String(format: "dolce_%02d.wav", livello) }
}

struct TagNFC: Codable, Equatable, Identifiable {
    var id = UUID()
    var nome: String
    var aggiunto = Date()
    var ultimaScansione: Date?
}

struct VoceRoutine: Codable, Equatable, Identifiable {
    var id = UUID()
    var testo: String
}

struct ParametriMattina: Codable, Equatable {
    var progressiva: Bool
    var passoProgressivaSec = 60
    var intervalloCatenaSec = 30
    var durataCatenaMin = 30
}

enum Fase: String, Codable {
    case progressiva, principale, catena, test
}

/// Una sveglia AlarmKit programmata: la mappa UUID → (fase, indice, orario, suono).
struct SvegliaProgrammata: Codable, Equatable, Identifiable {
    var id: UUID
    var fase: Fase
    var indice: Int
    var orario: Date
    var suono: String
}

enum TipoEvento: String, Codable {
    case stop              // pulsante Stop o tasto laterale (stopIntent)
    case pulsanteEmergenza // pulsante secondario "Emergenza" sulla sveglia
    case tag
    case anticipo
    case emergenza         // Emergency Stop confermato
    case volume            // sveglie zittite con i tasti volume (rilevato)
}

struct EventoMattina: Codable, Equatable {
    var data: Date
    var tipo: TipoEvento
    var fase: Fase?
    var indice: Int?
    var nota: String?
}

enum Esito: String, Codable {
    case tag, anticipo, emergenza, fuoriCasa, fallita, fallitaVolume

    var titolo: String {
        switch self {
        case .tag: "Tag"
        case .anticipo: "Annullata in anticipo"
        case .emergenza: "Emergency"
        case .fuoriCasa: "Fuori casa"
        case .fallita: "Fallita"
        case .fallitaVolume: "Fallita – volume"
        }
    }
    var riuscita: Bool { self == .tag || self == .anticipo }
    /// Fuori casa (e in futuro la modalità senza tag) mette lo streak in pausa.
    var inPausa: Bool { self == .fuoriCasa }
}

/// Ogni occorrenza di una sveglia: progressiva (facoltativa), principale e catena anti-trucco.
struct Mattina: Codable, Equatable, Identifiable {
    var id = UUID()
    var svegliaID: UUID
    var nome: String
    /// Orario T della sveglia principale.
    var orario: Date
    /// Parametri chiesti dalle impostazioni al momento della programmazione.
    var richiesti: ParametriMattina
    /// Parametri davvero programmati (diversi da `richiesti` se il limite di AlarmKit ha imposto una riduzione).
    var parametri: ParametriMattina
    var suoneria: String
    var test = false
    var ridotta: String?
    var sveglie: [SvegliaProgrammata] = []
    var eventi: [EventoMattina] = []
    var esito: Esito?
    var chiusa: Date?
    var timeToScan: TimeInterval?
    var stopPenalizzati: Int?
    var punteggio: Int?
    var risveglioVisto = false
    /// Voci della routine spuntate dopo il risveglio (Fase 2: opzionale, i file della Fase 1 non lo hanno).
    var routineFatte: [UUID]?
}
