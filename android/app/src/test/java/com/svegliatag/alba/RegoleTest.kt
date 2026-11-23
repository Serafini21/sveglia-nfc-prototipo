package com.svegliatag.alba

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.abs

/** Test delle regole (porting di Tests/main.swift, senza le parti solo iPhone: AlarmKit, volume, scadenza, codice). */
class RegoleTest {
    private val roma = ZoneId.of("Europe/Rome")
    private fun data(g: Int, h: Int, m: Int, s: Int = 0) = ZonedDateTime.of(2026, 11, g, h, m, s, 0, roma).toInstant().toEpochMilli()
    private val t = data(19, 7, 0) // giovedì 19 novembre 2026, 7:00

    private fun mattina(progressiva: Boolean = false) =
        Mattina(svegliaID = "s", nome = "Test", orario = t, parametri = ParametriMattina(progressiva), suoneria = Suoneria.normale.file)

    private fun chiusa(e: Esito, giorno: Int, ora: Int = 7, punti: Int? = null, tts: Long? = null, test: Boolean = false) =
        mattina().copy(orario = data(giorno, ora, 0), esito = e, punteggio = punti, timeToScan = tts, test = test)

    @Test fun progressiva() {
        val inizio = t - 15 * MINUTO
        fun db(minuto: Double) = Regole.dbProgressiva(inizio + (minuto * MINUTO).toLong(), inizio, t)
        fun circa(a: Double, b: Double) = abs(a - b) < 0.01
        assertEquals("parte da -60 dB", -60.0, db(0.0), 0.0)
        assertTrue("parte lenta: -50 dB al minuto 5, -40 al minuto 10", circa(db(5.0), -50.0) && circa(db(10.0), -40.0))
        assertTrue("poi sempre più forte: -27,5 dB al minuto 12,5", circa(db(12.5), -27.5))
        assertTrue("al minuto 10 nessuno scalino", abs((db(10.1) - db(10.0)) - (db(10.0) - db(9.9))) < 0.05)
        val passi = (0..150).map { db(it / 10.0) }
        assertTrue("non scende mai", passi.zipWithNext().all { (a, b) -> a <= b })
        assertTrue("l'ultimo minuto sale più del minuto 10", db(15.0) - db(14.0) > db(11.0) - db(10.0))
        assertEquals("all'orario 0 dB", 0.0, Regole.dbProgressiva(t, inizio, t), 0.0)
        assertEquals("dopo l'orario resta a 0 dB", 0.0, Regole.dbProgressiva(t + 10 * MINUTO, inizio, t), 0.0)
        assertEquals("prima dell'inizio -60 dB", -60.0, Regole.dbProgressiva(inizio - 5 * SECONDO, inizio, t), 0.0)
        assertEquals("senza progressiva subito al massimo", 0.0, Regole.dbProgressiva(t, t, t), 0.0)
    }

    @Test fun finestre() {
        val m = mattina()
        assertFalse("4:59 non bloccata", m.bloccata(data(19, 4, 59)))
        assertTrue("5:00 bloccata e nella finestra di anticipo", m.bloccata(data(19, 5, 0)) && m.nellaFinestraPrima(data(19, 5, 0)))
        assertTrue("7:20 in corso", m.inCorso(data(19, 7, 20)) && !m.nellaFinestraPrima(data(19, 7, 20)))
        assertTrue("fine = T + 5 min + 30 min + 60 s", m.inCorso(data(19, 7, 36, 0)) && !m.inCorso(data(19, 7, 36, 1)))
        assertEquals("sirena a T + 5 min", t + 5 * MINUTO, m.inizioCatena)
        val p = mattina(progressiva = true)
        assertTrue("con progressiva la mattina inizia a T-15", p.inCorso(data(19, 6, 45)) && p.nellaFinestraPrima(data(19, 6, 44)))
        val c = m.copy(esito = Esito.tag)
        assertTrue("mattina chiusa: né bloccata né in corso", !c.bloccata(data(19, 6, 0)) && !c.inCorso(data(19, 7, 5)))
        assertTrue("tag bloccati nelle 2 ore prima", Regole.tagBloccati(listOf(m), data(19, 5, 30)))
        assertFalse("tag liberi la sera prima", Regole.tagBloccati(listOf(m), data(18, 22, 0)))
        assertFalse("le mattine di test non bloccano i tag", Regole.tagBloccati(listOf(m.copy(test = true)), data(19, 6, 0)))
    }

    @Test fun punteggioEsiti() {
        assertEquals("tag in 30 s = 100", 100, Regole.punteggio(Esito.tag, 30))
        assertEquals("tag in 2 min = 96", 96, Regole.punteggio(Esito.tag, 120))
        assertEquals("lentezza al massimo -40", 60, Regole.punteggio(Esito.tag, 3600))
        assertEquals("Emergency = 20", 20, Regole.punteggio(Esito.emergenza, null))
        assertEquals("fallita = 0", 0, Regole.punteggio(Esito.fallita, null))
        assertNull("fuori casa non conteggiata", Regole.punteggio(Esito.fuoriCasa, null))
        val m = Regole.chiudi(mattina(), Esito.tag, t + 40 * SECONDO)
        assertTrue("chiusa col tag dopo 40 s", m.esito == Esito.tag && m.timeToScan == 40L && m.punteggio == 100)
        val p = Regole.chiudi(mattina(progressiva = true), Esito.tag, t - 2 * MINUTO)
        assertEquals("tag durante la progressiva: time-to-scan 0", 0L, p.timeToScan)
    }

    @Test fun streakERiuscite() {
        val storia = listOf(chiusa(Esito.tag, 10), chiusa(Esito.emergenza, 11), chiusa(Esito.tag, 12),
                            chiusa(Esito.fuoriCasa, 13), chiusa(Esito.anticipo, 14), chiusa(Esito.fallita, 9, test = true))
        assertEquals("Emergency azzera, fuori casa in pausa, test ignorate", 2, Regole.streak(storia))
        assertEquals("fallita azzera", 0, Regole.streak(storia + chiusa(Esito.fallita, 15)))
        assertEquals("riuscite: tag + anticipo, escluse le test", 3, Regole.riuscite(storia))
    }

    @Test fun creditiEmergency() {
        val imp = Impostazioni(creditiEmergenza = 0, ultimaRicarica = data(1, 12, 0), ultimaDataVista = data(1, 12, 0))
        assertEquals("6 giorni: nessuna ricarica", 0, Regole.ricarica(imp, data(7, 12, 0)).first.creditiEmergenza)
        val r = Regole.ricarica(imp, data(8, 12, 0))
        assertTrue("7 giorni: +1", r.first.creditiEmergenza == 1 && r.second != null)
        assertEquals("mai oltre 1", 1, Regole.ricarica(imp, data(29, 12, 0)).first.creditiEmergenza)
        val ri = Regole.ricarica(imp.copy(ultimaDataVista = data(20, 12, 0)), data(10, 12, 0))
        assertTrue("orologio indietro: niente ricarica", ri.first.creditiEmergenza == 0 && ri.second?.contains("OROLOGIO") == true)
        assertEquals("al massimo il conteggio riparte da adesso", data(20, 12, 0),
                     Regole.ricarica(imp.copy(creditiEmergenza = 1), data(20, 12, 0)).first.ultimaRicarica)
        assertEquals("alla prima installazione 1 credito", 1, Impostazioni().creditiEmergenza)
    }

    @Test fun occorrenzeEMattineDesiderate() {
        val feriali = Sveglia(nome = "Lavoro", ora = 7, minuti = 0, giorni = listOf(2, 3, 4, 5, 6))
        val sabato = data(21, 9, 0)
        val occ = Regole.occorrenze(feriali, sabato, sabato + 8 * GIORNO, roma)
        assertEquals("da sabato la prossima feriale è lunedì 23 alle 7:00", data(23, 7, 0), occ.first())
        assertEquals("5 feriali in 8 giorni", 5, occ.size)

        val unaVolta = Sveglia(nome = "Una", ora = 6, minuti = 30, dataUnaTantum = data(19, 6, 30))
        val des = Regole.mattineDesiderate(listOf(feriali, unaVolta), emptyList(), data(18, 22, 0), roma)
        assertEquals("solo le prossime 2 mattine", listOf(data(19, 6, 30), data(19, 7, 0)), des.map { it.orario })

        val annullata = mattina().copy(svegliaID = feriali.id, orario = data(19, 7, 0), esito = Esito.anticipo)
        val des2 = Regole.mattineDesiderate(listOf(feriali), listOf(annullata), data(19, 6, 0), roma)
        assertEquals("una mattina annullata in anticipo non viene riprogrammata", data(20, 7, 0), des2.first().orario)

        val lontana = Sveglia(nome = "Test", dataUnaTantum = data(28, 7, 0), test = ParametriMattina(false))
        val des3 = Regole.mattineDesiderate(listOf(feriali, lontana), emptyList(), data(19, 8, 0), roma)
        assertTrue("le sveglie di test sono sempre programmate", des3.size == 3 && des3.last().orario == data(28, 7, 0))

        assertTrue("sveglia disattivata: nessuna mattina", Regole.occorrenze(feriali.copy(attiva = false), sabato, data(30, 0, 0), roma).isEmpty())
        assertEquals("orario passato: domani", data(20, 7, 0), Regole.prossimoOrario(7, 0, data(19, 8, 0), roma))
        assertEquals("giorni come su iPhone: domenica = 1", 1, Regole.giornoSettimana(LocalDate.of(2026, 11, 22)))
    }

    @Test fun unaTantumFinite() {
        val ora = data(19, 11, 30)
        val s = Sveglia(nome = "Una", ora = 12, minuti = 0, dataUnaTantum = data(19, 12, 0))
        fun di(esito: Esito?) = mattina().copy(svegliaID = s.id, orario = s.dataUnaTantum!!, esito = esito)
        assertEquals("annullata in anticipo: sparisce subito", setOf(s.id), Regole.unaTantumFinite(listOf(s), listOf(di(Esito.anticipo)), ora))
        assertTrue("mattina ancora aperta: resta", Regole.unaTantumFinite(listOf(s), listOf(di(null)), data(19, 12, 10)).isEmpty())
        assertTrue("ancora da suonare: resta", Regole.unaTantumFinite(listOf(s), emptyList(), ora).isEmpty())
        assertEquals("orario passato senza mattine aperte: sparisce", setOf(s.id), Regole.unaTantumFinite(listOf(s), emptyList(), data(19, 12, 1)))
        val altroOrario = di(Esito.tag).copy(orario = data(18, 12, 0))
        assertTrue("una mattina chiusa a un altro orario non conta", Regole.unaTantumFinite(listOf(s), listOf(altroOrario), ora).isEmpty())
    }

    @Test fun dormireEStatistiche() {
        val cicli = Regole.cicliSonno(data(18, 23, 30))
        assertEquals("proposte da 3 a 6 cicli", listOf(3, 4, 5, 6), cicli.map { it.cicli })
        assertTrue("23:30 → 4:15 (3 cicli), 7:15 (5 cicli)", cicli[0].orario == data(19, 4, 15) && cicli[2].orario == data(19, 7, 15))
        assertEquals("dal minuto intero successivo", data(19, 4, 16), Regole.cicliSonno(data(18, 23, 30, 20))[0].orario)

        val storia = listOf(chiusa(Esito.tag, 13, punti = 90, tts = 60), chiusa(Esito.tag, 17, punti = 80, tts = 120),
                            chiusa(Esito.tag, 17, ora = 9, punti = 70, tts = 180), chiusa(Esito.fuoriCasa, 18),
                            chiusa(Esito.fallita, 19, punti = 0), chiusa(Esito.tag, 19, ora = 6, punti = 100, tts = 5, test = true))
        assertEquals("conteggiate: senza test e fuori casa", 4, Regole.conteggiate(storia))
        assertEquals("media al tag", 120L, Regole.mediaTimeToScan(storia))
        val settimana = Regole.punteggiGiorni(storia, ora = data(19, 12, 0), zona = roma)
        assertEquals("7 giorni, da 6 giorni fa a oggi", LocalDate.of(2026, 11, 13), settimana.first().giorno)
        assertEquals("ultima mattina del giorno, test esclusi", listOf(90, null, null, null, 70, null, 0), settimana.map { it.punteggio })
    }

    @Test fun posizioneDiCasa() {
        assertEquals("0,001° di latitudine ≈ 111 m", 111.2, Regole.distanza(45.0, 9.0, 45.001, 9.0), 1.0)
        var imp = Regole.impostaCasa(Impostazioni(), 45.0, 9.0, data(19, 20, 0))
        assertNull("la prima casa non vale prima di 12 ore", Regole.casaInVigore(imp, data(20, 7, 59)))
        val prima = Regole.casaInVigore(imp, data(20, 8, 0))
        assertEquals("dopo 12 ore vale", 45.0, prima!!.latitudine, 0.0)
        imp = Regole.impostaCasa(imp, 46.0, 9.0, data(21, 22, 0))
        assertEquals("spostata la sera: la mattina dopo vale ancora la vecchia", prima, Regole.casaInVigore(imp, data(22, 7, 0)))
        assertEquals("poi vale la nuova", 46.0, Regole.casaInVigore(imp, data(22, 10, 0))!!.latitudine, 0.0)

        val casa = Casa(45.0, 9.0, data(1, 0, 0))
        assertTrue("222 m ± 20: fuori casa", Regole.fuoriCasa(45.002, 9.0, 20.0, casa))
        assertFalse("222 m ± 100: non è certo", Regole.fuoriCasa(45.002, 9.0, 100.0, casa))
        assertFalse("111 m: a casa", Regole.fuoriCasa(45.001, 9.0, 5.0, casa))
        assertFalse("posizione non valida", Regole.fuoriCasa(46.0, 9.0, -1.0, casa))
        assertFalse("casa non impostata", Regole.fuoriCasa(46.0, 9.0, 10.0, null))
    }

    @Test fun nomiFraseUid() {
        assertTrue("nomi tag", Regole.stessoNome("Bagno", " bagno ") && !Regole.stessoNome("Bagno", "Cucina"))
        assertTrue("frase con maiuscole e punteggiatura", Regole.fraseValida("sono sveglio e mi alzo.") && Regole.fraseValida("Sono  sveglio e mi alzo!"))
        assertFalse("frase incompleta rifiutata", Regole.fraseValida("Sono sveglio"))
        assertEquals("uid in esadecimale", "04A1FF", Regole.uid(byteArrayOf(0x04, 0xA1.toByte(), 0xFF.toByte())))
    }
}
