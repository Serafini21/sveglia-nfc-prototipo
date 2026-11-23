package com.svegliatag.alba

import kotlinx.serialization.Serializable
import java.util.UUID

// Modello dati di Alba per Android: tutto in un unico file JSON (vedi Store).
// Orari in millisecondi dal 1970 (System.currentTimeMillis), durate dove indicato.
// Campi nuovi: sempre con un valore predefinito, così i file vecchi si leggono ancora.

fun nuovoId(): String = UUID.randomUUID().toString()
fun adesso(): Long = System.currentTimeMillis()

@Serializable
data class DatiAlba(
    val schemaVersion: Int = VERSIONE,
    val impostazioni: Impostazioni = Impostazioni(),
    val sveglie: List<Sveglia> = emptyList(),
    val tag: List<TagNFC> = emptyList(),
    val mattine: List<Mattina> = emptyList(),
    val routine: List<VoceRoutine> = emptyList(),
    /** Avviso da mostrare in Home finché l'utente non lo chiude. */
    val avviso: String? = null,
) {
    companion object { const val VERSIONE = 1 }
}

@Serializable
data class Impostazioni(
    val progressiva: Boolean = false,
    val creditiEmergenza: Int = Costanti.CREDITI_INIZIALI,
    val ultimaRicarica: Long = adesso(),
    val ultimaDataVista: Long = adesso(),
    val sviluppatore: Boolean = false,
    val test: ParametriTest = ParametriTest(),
    /** Suono dei 15 minuti di progressiva (nome di Suoneria). null = «Alba». */
    val suonoProgressiva: String? = null,
    /** Posizione di casa: ogni modifica vale dopo 12 ore, fino ad allora vale la precedente. */
    val casa: Casa? = null,
    val casaPrecedente: Casa? = null,
) {
    val suoneriaProgressiva: Suoneria get() = Suoneria.da(suonoProgressiva) ?: Suoneria.dolce
}

@Serializable
data class Casa(val latitudine: Double, val longitudine: Double, /** da quando vale */ val dal: Long)

/** Parametri della "catena breve" della modalità sviluppatore. */
@Serializable
data class ParametriTest(
    val passoProgressivaSec: Int = 10,
    val durataCatenaMin: Int = 3,
    val minutiAllaMattina: Int = 2,
)

@Serializable
data class Sveglia(
    val id: String = nuovoId(),
    val nome: String = "Sveglia",
    val ora: Int = 7,
    val minuti: Int = 0,
    /** Giorni come su iPhone: 1 = domenica ... 7 = sabato. Vuoto = una volta sola. */
    val giorni: List<Int> = emptyList(),
    val attiva: Boolean = true,
    /** Sveglia una tantum: istante esatto dell'unica mattina. Dopo quella mattina sparisce. */
    val dataUnaTantum: Long? = null,
    val suoneria: String = Suoneria.normale.name,
    /** Solo modalità sviluppatore: le sveglie di test non contano nelle statistiche. */
    val test: ParametriMattina? = null,
)

/** Suonerie dell'app. I nomi sono salvati nel JSON e sono i file in assets/suoni: non rinominarli. */
@Suppress("EnumEntryName")
enum class Suoneria(val nome: String, val categoria: Categoria) {
    dolce("Alba", Categoria.Dolci),
    chiaro("Mattino chiaro", Categoria.Dolci),
    brezza("Brezza", Categoria.Dolci),
    normale("Classica", Categoria.Normali),
    campanelli("Campanelli", Categoria.Normali),
    energica("Energica", Categoria.Energiche),
    allegro("Allegro", Categoria.Energiche);

    val file: String get() = "$name.wav"

    enum class Categoria(val nome: String) { Dolci("Dolci"), Normali("Normali"), Energiche("Energiche") }

    companion object {
        fun da(nome: String?): Suoneria? = entries.firstOrNull { it.name == nome }
    }
}

/** Sirena di sicurezza: parte a T + 5 min se la sveglia non è ancora spenta. */
const val SIRENA = "punizione.wav"

@Serializable
data class TagNFC(
    val id: String = nuovoId(),
    val nome: String,
    /** Identificativo del chip letto dal telefono (esadecimale). */
    val uid: String,
    val aggiunto: Long = adesso(),
    val ultimaScansione: Long? = null,
)

@Serializable
data class VoceRoutine(val id: String = nuovoId(), val testo: String)

@Serializable
data class ParametriMattina(
    val progressiva: Boolean,
    /** La progressiva dura Costanti.GRADINI_PROGRESSIVA × passo: 15 min. */
    val passoProgressivaSec: Int = 60,
    /** Quanto suona la sirena di sicurezza prima che la mattina risulti fallita. */
    val durataCatenaMin: Int = 30,
    /** Dopo quanti secondi dall'orario parte la sirena di sicurezza. */
    val ritardoCatenaSec: Int = Costanti.RITARDO_CATENA_SEC,
)

@Suppress("EnumEntryName")
@Serializable
enum class TipoEvento { tag, anticipo, emergenza }

@Serializable
data class EventoMattina(val data: Long, val tipo: TipoEvento, val nota: String? = null)

@Suppress("EnumEntryName")
@Serializable
enum class Esito(val titolo: String) {
    tag("Tag"),
    anticipo("Annullata in anticipo"),
    emergenza("Emergency"),
    fuoriCasa("Fuori casa"),
    fallita("Fallita");

    val riuscita: Boolean get() = this == tag || this == anticipo
    /** Fuori casa mette lo streak in pausa. */
    val inPausa: Boolean get() = this == fuoriCasa
}

/** Ogni occorrenza di una sveglia: progressiva facoltativa, suoneria all'orario, sirena da T + 5 min. */
@Serializable
data class Mattina(
    val id: String = nuovoId(),
    val svegliaID: String,
    val nome: String,
    /** Orario T della sveglia. */
    val orario: Long,
    val parametri: ParametriMattina,
    /** File della suoneria (es. "normale.wav"). */
    val suoneria: String,
    val test: Boolean = false,
    val eventi: List<EventoMattina> = emptyList(),
    val esito: Esito? = null,
    val chiusa: Long? = null,
    /** Secondi dall'orario al tag. */
    val timeToScan: Long? = null,
    val punteggio: Int? = null,
    val risveglioVisto: Boolean = false,
    val routineFatte: List<String> = emptyList(),
)
