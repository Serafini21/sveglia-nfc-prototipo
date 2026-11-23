package com.svegliatag.alba

import java.text.Normalizer
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

// Regole di Alba: logica pura (niente Android), provata dai test in src/test.
// Porting di Alba/Regole.swift: stessi numeri e stesse regole, senza AlarmKit.

const val SECONDO = 1_000L
const val MINUTO = 60 * SECONDO
const val ORA = 60 * MINUTO
const val GIORNO = 24 * ORA

/** Tutti i numeri delle regole in un unico punto. Durate in millisecondi se non indicato. */
object Costanti {
    const val GRADINI_PROGRESSIVA = 15                 // progressiva = 15 × passo (15 min)
    const val DB_INIZIALE_PROGRESSIVA = -60.0
    const val DB_FINE_LENTA = -40.0
    const val QUOTA_LENTA = 2.0 / 3                    // parte lenta: i primi 10 dei 15 minuti
    const val RITARDO_CATENA_SEC = 300                 // la sirena di sicurezza parte a T + 5 min
    const val RITARDO_CATENA_TEST_SEC = 60             // mattine di test: T + 1 min
    const val FINESTRA_PRIMA = 2 * ORA                 // blocco modifiche e spegnimento anticipato
    const val MARGINE_FINE = MINUTO                    // dopo la fine della sirena
    const val CREDITI_MAX = 1
    const val CREDITI_INIZIALI = 1
    const val RICARICA_OGNI = 7 * GIORNO
    const val RAGGIO_CASA = 150.0                      // metri
    const val ATTESA_CASA = 12 * ORA                   // una nuova posizione di casa vale dopo 12 ore
    const val TOLLERANZA_OROLOGIO = 5 * MINUTO         // differenze minori non contano come "orologio indietro"
    const val MATTINE_PROGRAMMATE = 2
    const val GIORNI_ORIZZONTE = 8

    // Punteggio giornaliero (secondi)
    const val PUNTEGGIO_PIENO = 100
    const val TTS_GRATIS = 60L
    const val TTS_PASSO = 15L
    const val TTS_PENALITA_MAX = 40
    const val PUNTEGGIO_EMERGENZA = 20
    const val PUNTEGGIO_FALLITA = 0
    const val PUNTEGGIO_ANTICIPO = 100

    const val FRASE_EMERGENZA = "Sono sveglio e mi alzo"
    const val SECONDI_EMERGENZA = 10

    // "Vado a dormire ora"
    const val ADDORMENTARSI = 15 * MINUTO
    const val CICLO_SONNO = 90 * MINUTO
    val CICLI_PROPOSTI = listOf(3, 4, 5, 6)
    const val CICLI_CONSIGLIATI = 5
}

/** Quando l'app inizia a suonare: inizio della progressiva, oppure l'orario. */
val Mattina.inizio: Long
    get() = if (parametri.progressiva) orario - Costanti.GRADINI_PROGRESSIVA * parametri.passoProgressivaSec * SECONDO else orario

/** Quando parte la sirena di sicurezza. */
val Mattina.inizioCatena: Long get() = orario + parametri.ritardoCatenaSec * SECONDO

/** Dopo questo istante, senza tag né Emergency, la mattina è fallita. */
val Mattina.fine: Long get() = inizioCatena + parametri.durataCatenaMin * MINUTO + Costanti.MARGINE_FINE

val Mattina.conclusa: Boolean get() = esito != null
fun Mattina.inCorso(ora: Long) = !conclusa && ora >= inizio && ora <= fine
fun Mattina.nellaFinestraPrima(ora: Long) = !conclusa && ora < inizio && ora >= inizio - Costanti.FINESTRA_PRIMA

/** Nelle 2 ore prima e durante la mattina la sveglia non si può modificare senza tag. */
fun Mattina.bloccata(ora: Long) = !conclusa && ora >= inizio - Costanti.FINESTRA_PRIMA && ora <= fine

object Regole {

    /**
     * Volume della progressiva in dB. Su 15 minuti:
     * - minuti 0–10: molto piano, da -60 a -40 dB;
     * - minuti 10–15: sempre più forte, da -40 a 0 dB, con la stessa pendenza all'inizio (niente scalino).
     * Senza progressiva (inizio = orario) subito 0 dB.
     */
    fun dbProgressiva(ora: Long, inizio: Long, orario: Long): Double {
        val durata = (orario - inizio).toDouble()
        val p = if (durata <= 0) 1.0 else min(1.0, max(0.0, (ora - inizio) / durata))
        val da = Costanti.DB_INIZIALE_PROGRESSIVA
        val lenta = Costanti.DB_FINE_LENTA
        val quota = Costanti.QUOTA_LENTA
        if (p <= quota) return da + (lenta - da) * p / quota
        val q = (p - quota) / (1 - quota)
        val pendenza = (lenta - da) / quota * (1 - quota)
        return lenta + pendenza * q + (-lenta - pendenza) * q * q
    }

    // Quali mattine programmare

    /** Giorno della settimana come su iPhone: 1 = domenica ... 7 = sabato. */
    fun giornoSettimana(d: LocalDate): Int = d.dayOfWeek.value % 7 + 1

    private fun istante(giorno: LocalDate, ora: Int, minuti: Int, zona: ZoneId): Long =
        ZonedDateTime.of(giorno, LocalTime.of(ora, minuti), zona).toInstant().toEpochMilli()

    private fun giornoDi(t: Long, zona: ZoneId): LocalDate = Instant.ofEpochMilli(t).atZone(zona).toLocalDate()

    /** Prossime occorrenze di una sveglia attiva in (dopo, fino]. */
    fun occorrenze(s: Sveglia, dopo: Long, fino: Long, zona: ZoneId = ZoneId.systemDefault()): List<Long> {
        if (!s.attiva) return emptyList()
        s.dataUnaTantum?.let { return if (it > dopo && it <= fino) listOf(it) else emptyList() }
        if (s.giorni.isEmpty()) return emptyList()
        val risultato = mutableListOf<Long>()
        var giorno = giornoDi(dopo, zona)
        val ultimo = giornoDi(fino, zona)
        while (!giorno.isAfter(ultimo)) {
            val t = istante(giorno, s.ora, s.minuti, zona)
            if (t > dopo && t <= fino && giornoSettimana(giorno) in s.giorni) risultato += t
            giorno = giorno.plusDays(1)
        }
        return risultato
    }

    /** Prossimo orario utile per ora:minuti (oggi se ancora nel futuro, altrimenti domani). */
    fun prossimoOrario(ora: Int, minuti: Int, dopo: Long, zona: ZoneId = ZoneId.systemDefault()): Long {
        val oggi = giornoDi(dopo, zona)
        for (k in 0L..2L) {
            val t = istante(oggi.plusDays(k), ora, minuti, zona)
            if (t > dopo) return t
        }
        return dopo
    }

    data class Desiderata(val svegliaID: String, val orario: Long)

    /**
     * Le mattine che devono essere programmate adesso: le prossime 2 di tutte le sveglie normali più tutte
     * quelle delle sveglie di test. Esclude le mattine già chiuse (per esempio annullate in anticipo).
     */
    fun mattineDesiderate(sveglie: List<Sveglia>, mattine: List<Mattina>, ora: Long,
                          zona: ZoneId = ZoneId.systemDefault()): List<Desiderata> {
        val fino = ora + Costanti.GIORNI_ORIZZONTE * GIORNO
        fun giaChiusa(id: String, t: Long) = mattine.any { it.svegliaID == id && it.conclusa && stessoIstante(it.orario, t) }
        val normali = mutableListOf<Desiderata>()
        val test = mutableListOf<Desiderata>()
        for (s in sveglie) {
            val fineS = if (s.test != null) ora + 366 * GIORNO else fino
            for (t in occorrenze(s, ora, fineS, zona)) {
                if (giaChiusa(s.id, t)) continue
                if (s.test != null) test += Desiderata(s.id, t) else normali += Desiderata(s.id, t)
            }
        }
        return (normali.sortedBy { it.orario }.take(Costanti.MATTINE_PROGRAMMATE) + test).sortedBy { it.orario }
    }

    fun stessoIstante(a: Long, b: Long) = kotlin.math.abs(a - b) < SECONDO

    /**
     * Sveglie una tantum da togliere: la loro mattina è chiusa (anche annullata in anticipo, quindi prima
     * dell'orario), oppure l'orario è passato senza mattine aperte.
     */
    fun unaTantumFinite(sveglie: List<Sveglia>, mattine: List<Mattina>, ora: Long): Set<String> =
        sveglie.filter { s ->
            val t = s.dataUnaTantum ?: return@filter false
            if (mattine.any { !it.conclusa && it.svegliaID == s.id }) return@filter false
            t < ora || mattine.any { it.conclusa && it.svegliaID == s.id && stessoIstante(it.orario, t) }
        }.map { it.id }.toSet()

    fun svegliaBloccata(id: String, mattine: List<Mattina>, ora: Long) =
        mattine.any { it.svegliaID == id && it.bloccata(ora) }

    /** Durante una mattina e nelle 2 ore prima non si aggiungono tag (si potrebbe registrare un tag vicino al letto). */
    fun tagBloccati(mattine: List<Mattina>, ora: Long) = mattine.any { !it.test && it.bloccata(ora) }

    // Valutazione della mattina

    fun timeToScan(orario: Long, tag: Long): Long = max(0L, (tag - orario) / SECONDO)

    fun punteggio(esito: Esito, timeToScan: Long?): Int? = when (esito) {
        Esito.tag -> {
            val oltre = max(0L, (timeToScan ?: 0L) - Costanti.TTS_GRATIS)
            val lentezza = min(Costanti.TTS_PENALITA_MAX.toLong(), oltre / Costanti.TTS_PASSO).toInt()
            max(0, Costanti.PUNTEGGIO_PIENO - lentezza)
        }
        Esito.anticipo -> Costanti.PUNTEGGIO_ANTICIPO
        Esito.emergenza -> Costanti.PUNTEGGIO_EMERGENZA
        Esito.fallita -> Costanti.PUNTEGGIO_FALLITA
        Esito.fuoriCasa -> null
    }

    /** Chiude la mattina con l'esito e calcola time-to-scan e punteggio. */
    fun chiudi(m: Mattina, esito: Esito, ora: Long): Mattina {
        val tts = if (esito == Esito.tag) timeToScan(m.orario, ora) else null
        return m.copy(esito = esito, chiusa = ora, timeToScan = tts, punteggio = punteggio(esito, tts))
    }

    // Statistiche

    /** Mattine riuscite consecutive (le ultime). Emergency e fallite azzerano, fuori casa mette in pausa. */
    fun streak(mattine: List<Mattina>): Int {
        var n = 0
        for (m in mattine.filter { !it.test && it.esito != null }.sortedBy { it.orario }) {
            val e = m.esito ?: continue
            if (e.inPausa) continue
            n = if (e.riuscita) n + 1 else 0
        }
        return n
    }

    fun riuscite(mattine: List<Mattina>) = mattine.count { !it.test && it.esito?.riuscita == true }

    /** Mattine che contano nelle statistiche: chiuse, non di test, non fuori casa. */
    fun conteggiate(mattine: List<Mattina>) = mattine.count { !it.test && it.esito != null && it.esito != Esito.fuoriCasa }

    /** Media del tempo al tag (secondi) delle ultime 30 mattine chiuse col tag. */
    fun mediaTimeToScan(mattine: List<Mattina>): Long? {
        val tempi = mattine.filter { !it.test && it.esito == Esito.tag }
            .sortedByDescending { it.orario }.take(30).mapNotNull { it.timeToScan }
        return if (tempi.isEmpty()) null else tempi.sum() / tempi.size
    }

    data class GiornoPunteggio(val giorno: LocalDate, val punteggio: Int?)

    /** Punteggio degli ultimi `giorni` giorni (oggi compreso, dal più vecchio): l'ultima mattina conteggiata di ogni giorno. */
    fun punteggiGiorni(mattine: List<Mattina>, giorni: Int = 7, ora: Long,
                       zona: ZoneId = ZoneId.systemDefault()): List<GiornoPunteggio> {
        val oggi = giornoDi(ora, zona)
        return (giorni - 1 downTo 0).map { k ->
            val giorno = oggi.minusDays(k.toLong())
            val delGiorno = mattine.filter { !it.test && it.punteggio != null && giornoDi(it.orario, zona) == giorno }
            GiornoPunteggio(giorno, delGiorno.maxByOrNull { it.orario }?.punteggio)
        }
    }

    // Vado a dormire ora

    data class Ciclo(val cicli: Int, val orario: Long, val durata: Long)

    /** Orari a cicli completi: dal minuto intero successivo + 15 min per addormentarsi + k × 90 min. */
    fun cicliSonno(da: Long): List<Ciclo> {
        val base = (da + MINUTO - 1) / MINUTO * MINUTO
        return Costanti.CICLI_PROPOSTI.map { k ->
            val durata = k * Costanti.CICLO_SONNO
            Ciclo(k, base + Costanti.ADDORMENTARSI + durata, durata)
        }
    }

    // Crediti Emergency

    /**
     * Ricarica di 1 credito ogni 7 giorni, fino al massimo. Se l'orologio è tornato indietro rispetto
     * all'ultima data vista non ricarica e restituisce una nota da registrare.
     */
    fun ricarica(imp: Impostazioni, ora: Long): Pair<Impostazioni, String?> {
        if (ora < imp.ultimaDataVista - Costanti.TOLLERANZA_OROLOGIO) {
            return imp to "OROLOGIO INDIETRO: ora ${EventLog.data(ora)}, ultima data vista ${EventLog.data(imp.ultimaDataVista)}. Ricarica Emergency sospesa"
        }
        val i = imp.copy(ultimaDataVista = max(imp.ultimaDataVista, ora))
        if (i.creditiEmergenza >= Costanti.CREDITI_MAX) {
            // il conteggio dei 7 giorni parte quando si usa un credito
            return i.copy(creditiEmergenza = Costanti.CREDITI_MAX, ultimaRicarica = ora) to null
        }
        val settimane = ((ora - i.ultimaRicarica) / Costanti.RICARICA_OGNI).toInt()
        if (settimane > 0) {
            val r = i.copy(creditiEmergenza = min(Costanti.CREDITI_MAX, i.creditiEmergenza + settimane),
                           ultimaRicarica = i.ultimaRicarica + settimane * Costanti.RICARICA_OGNI)
            return r to "Ricarica Emergency: crediti ${r.creditiEmergenza}/${Costanti.CREDITI_MAX}"
        }
        return i to null
    }

    fun prossimaRicarica(imp: Impostazioni): Long? =
        if (imp.creditiEmergenza >= Costanti.CREDITI_MAX) null else imp.ultimaRicarica + Costanti.RICARICA_OGNI

    // Posizione di casa

    /** La casa che vale adesso: l'ultima impostata se sono passate 12 ore, altrimenti quella di prima. */
    fun casaInVigore(imp: Impostazioni, ora: Long): Casa? {
        val c = imp.casa
        if (c != null && c.dal <= ora) return c
        return imp.casaPrecedente
    }

    /** Nuova posizione di casa: vale tra 12 ore (così non la si sposta la sera per spegnere gratis la mattina dopo). */
    fun impostaCasa(imp: Impostazioni, latitudine: Double, longitudine: Double, ora: Long): Impostazioni =
        imp.copy(casaPrecedente = casaInVigore(imp, ora),
                 casa = Casa(latitudine, longitudine, ora + Costanti.ATTESA_CASA))

    /** Distanza in metri tra due punti (formula dell'emisenoverso). */
    fun distanza(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val g = Math.PI / 180
        val a = sin((lat2 - lat1) * g / 2).pow(2) + cos(lat1 * g) * cos(lat2 * g) * sin((lon2 - lon1) * g / 2).pow(2)
        return 2 * 6_371_000 * asin(min(1.0, sqrt(a)))
    }

    /** Fuori casa solo se è certo: anche togliendo l'incertezza della posizione si è oltre i 150 m. */
    fun fuoriCasa(latitudine: Double, longitudine: Double, accuratezza: Double, casa: Casa?): Boolean {
        if (casa == null || accuratezza < 0) return false
        return distanza(latitudine, longitudine, casa.latitudine, casa.longitudine) - accuratezza > Costanti.RAGGIO_CASA
    }

    // Nomi e frase

    private fun normalizza(s: String): String =
        Normalizer.normalize(s, Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "")
            .lowercase(Locale.ITALIAN)
            .split(Regex("[^\\p{L}\\p{N}]+"))
            .filter { it.isNotEmpty() }
            .joinToString(" ")

    fun stessoNome(a: String, b: String?) = b != null && normalizza(a) == normalizza(b)

    fun fraseValida(s: String) = normalizza(s) == normalizza(Costanti.FRASE_EMERGENZA)

    /** Identificativo del chip NFC in esadecimale (es. "04A1B2C3D4E5F6"). */
    fun uid(byte: ByteArray): String = byte.joinToString("") { "%02X".format(it) }
}
