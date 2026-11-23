package com.svegliatag.alba

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Date e durate in italiano (porting di Formati in Tema.swift). */
object Formati {
    private fun formato(p: String) = DateTimeFormatter.ofPattern(p, Locale.ITALIAN)
    private val hm = formato("H:mm")
    private val hms = formato("H:mm:ss")
    private val lungo = formato("EEEE d MMMM")
    private val breve = formato("EEE d MMM")
    private val settimana = formato("EEE")

    private fun z(t: Long): ZonedDateTime = Instant.ofEpochMilli(t).atZone(ZoneId.systemDefault())

    fun ora(t: Long, secondi: Boolean = false): String = (if (secondi) hms else hm).format(z(t))

    /** "oggi, giovedì 19 novembre alle 7:00" / "domani, ..." / "sabato 21 novembre alle 7:00" */
    fun quando(t: Long): String {
        val g = z(t).toLocalDate()
        val oggi = LocalDate.now()
        val prefisso = when (g) { oggi -> "oggi, "; oggi.plusDays(1) -> "domani, "; else -> "" }
        return "$prefisso${lungo.format(z(t))} alle ${ora(t)}"
    }

    fun giornoBreve(t: Long): String = breve.format(z(t))

    /** "Oggi", "Ieri", "Lun"... */
    fun giornoStorico(t: Long): String {
        val g = z(t).toLocalDate()
        val oggi = LocalDate.now()
        return when (g) {
            oggi -> "Oggi"
            oggi.minusDays(1) -> "Ieri"
            else -> settimana.format(z(t)).replaceFirstChar { it.uppercase() }
        }
    }

    /** Iniziale del giorno della settimana: L M M G V S D. */
    fun iniziale(d: LocalDate): String = listOf("D", "L", "M", "M", "G", "V", "S")[Regole.giornoSettimana(d) - 1]

    fun giornoBreve(d: LocalDate): String = breve.format(d)

    /** Durata in secondi: "1:05", oppure "1 h 20 min". */
    fun durata(secondi: Long): String {
        val t = maxOf(0L, secondi)
        return if (t < 3600) "%d:%02d".format(t / 60, t % 60) else "${t / 3600} h ${t % 3600 / 60} min"
    }

    /** "7 h 30", "6 h" */
    fun ore(ms: Long): String {
        val m = ms / MINUTO
        return if (m % 60 == 0L) "${m / 60} h" else "${m / 60} h ${m % 60}"
    }

    fun traQuanto(t: Long, da: Long = adesso()): String {
        val s = (t - da) / SECONDO
        if (s < 60) return if (s < 0) "in corso" else "tra meno di un minuto"
        val h = s / 3600
        val m = s % 3600 / 60
        return if (h > 0) "tra $h h $m min" else "tra $m min"
    }

    fun giorni(s: Sveglia): String {
        if (s.giorni.isEmpty()) return s.dataUnaTantum?.let { "una volta, ${giornoBreve(it)}" } ?: "una volta"
        val insieme = s.giorni.toSet()
        if (insieme.size == 7) return "Ogni giorno"
        if (insieme == setOf(2, 3, 4, 5, 6)) return "Lun – Ven"
        if (insieme == setOf(1, 7)) return "Sab, Dom"
        val nomi = mapOf(2 to "Lun", 3 to "Mar", 4 to "Mer", 5 to "Gio", 6 to "Ven", 7 to "Sab", 1 to "Dom")
        return listOf(2, 3, 4, 5, 6, 7, 1).filter { it in insieme }.mapNotNull { nomi[it] }.joinToString(", ")
    }
}
