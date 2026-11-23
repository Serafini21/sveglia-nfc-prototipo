package com.svegliatag.alba

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

data class Risposta(val ok: Boolean, val messaggio: String)

/**
 * Porting di AlarmEngine.swift. Ogni operazione è serializzata dal lock: interfaccia, sveglia di sistema,
 * servizio e tag non scrivono mai le mattine insieme. Le funzioni sono bloccanti (file e AlarmManager):
 * dall'interfaccia vanno chiamate fuori dal thread principale.
 *
 * Su Android la sveglia la suona sempre l'app (ServizioSveglia): AlarmManager.setAlarmClock la risveglia
 * all'inizio della mattina anche se è chiusa, e durante la mattina la richiama ogni minuto (se il processo
 * morisse, ripartirebbe entro 60 s). La sirena di sicurezza è lo stesso servizio che da T + 5 min cambia suono.
 */
object Motore {
    private val lock = Any()

    fun riallinea(ctx: Context, motivo: String) = synchronized(lock) { _riallinea(ctx, motivo) }

    fun spegniConTag(ctx: Context, uid: String?, simulato: Boolean = false): Risposta =
        synchronized(lock) { _tag(ctx, uid, simulato) }

    /** fuoriCasa: la posizione (letta dall'app al momento) è certamente oltre 150 m da casa. */
    fun emergenza(ctx: Context, fuoriCasa: Boolean = false): Risposta = synchronized(lock) { _emergenza(ctx, fuoriCasa) }

    fun salva(ctx: Context, s: Sveglia): Risposta = synchronized(lock) { _salva(ctx, s) }

    fun elimina(ctx: Context, id: String): Risposta = synchronized(lock) {
        if (Regole.svegliaBloccata(id, Store.leggi().mattine, adesso())) return BLOCCATA
        Store.modifica { d -> d.copy(sveglie = d.sveglie.filter { it.id != id }) }
        EventLog.scrivi("Sveglia eliminata $id")
        _riallinea(ctx, "sveglia eliminata")
        Risposta(true, "Sveglia eliminata")
    }

    fun impostaProgressiva(ctx: Context, attiva: Boolean) = synchronized(lock) {
        Store.modifica { it.copy(impostazioni = it.impostazioni.copy(progressiva = attiva)) }
        EventLog.scrivi("Progressiva ${if (attiva) "attivata" else "disattivata"}")
        _riallinea(ctx, "progressiva")
    }

    fun registraTag(nome: String, uid: String): Risposta = synchronized(lock) {
        val d = Store.leggi()
        if (Regole.tagBloccati(d.mattine, adesso())) {
            return Risposta(false, "Durante una sveglia e nelle 2 ore prima non puoi aggiungere tag.")
        }
        d.tag.firstOrNull { it.uid == uid }?.let { return Risposta(false, "Questo tag è già registrato come «${it.nome}».") }
        if (d.tag.any { Regole.stessoNome(it.nome, nome) }) return Risposta(false, "Esiste già un tag con questo nome.")
        Store.modifica { it.copy(tag = it.tag + TagNFC(nome = nome, uid = uid, ultimaScansione = adesso())) }
        EventLog.scrivi("Tag registrato: $nome")
        Risposta(true, "Tag «$nome» registrato ✓")
    }

    fun eliminaTag(id: String) = synchronized(lock) {
        val t = Store.leggi().tag.firstOrNull { it.id == id } ?: return@synchronized
        Store.modifica { d -> d.copy(tag = d.tag.filter { it.id != id }) }
        EventLog.scrivi("Tag eliminato: ${t.nome}")
    }

    fun segnaRisveglioVisto(id: String) = synchronized(lock) {
        Store.modifica { d -> d.copy(mattine = d.mattine.map { if (it.id == id) it.copy(risveglioVisto = true) else it }) }
    }

    fun segnaRoutine(mattinaID: String, voce: String, fatta: Boolean) = synchronized(lock) {
        Store.modifica { d ->
            d.copy(mattine = d.mattine.map { m ->
                if (m.id != mattinaID) m
                else m.copy(routineFatte = if (fatta) (m.routineFatte + voce).distinct() else m.routineFatte - voce)
            })
        }
    }

    /** Modalità sviluppatore: cancella lo storico delle mattine chiuse (per ripartire dopo i test). */
    fun azzeraStatistiche(): Risposta = synchronized(lock) {
        val ora = adesso()
        val prima = Store.leggi().mattine.size
        // le mattine future annullate in anticipo restano, altrimenti verrebbero riprogrammate
        Store.modifica { d -> d.copy(mattine = d.mattine.filterNot { it.conclusa && it.orario < ora }) }
        val n = prima - Store.leggi().mattine.size
        EventLog.scrivi("SVILUPPATORE: statistiche azzerate, tolte $n mattine chiuse")
        Risposta(true, "Statistiche azzerate ($n mattine)")
    }

    fun mostraAvviso(testo: String?) = synchronized(lock) { Store.modifica { it.copy(avviso = testo) } }

    /** Modalità sviluppatore: toglie le sveglie di test e le mattine aperte, disattiva tutte le sveglie. */
    fun fermaEDisattivaTutto(ctx: Context): Risposta = synchronized(lock) {
        Store.modifica { d ->
            d.copy(sveglie = d.sveglie.filter { it.test == null }.map { it.copy(attiva = false) },
                   mattine = d.mattine.filter { it.conclusa })
        }
        programmaProssimo(ctx, emptyList(), adesso())
        EventLog.scrivi("SVILUPPATORE: fermate e cancellate tutte le mattine aperte, sveglie disattivate")
        Risposta(true, "Sveglie fermate e disattivate")
    }

    private val BLOCCATA = Risposta(false, "Sveglia bloccata: suona entro 2 ore. Usa il tag o l'Emergency Stop.")

    // Riallineamento

    /**
     * Chiude le mattine finite, toglie quelle non più desiderate, crea le prossime 2, programma la
     * prossima sveglia di sistema e avvia il servizio se una mattina è in corso.
     */
    private fun _riallinea(ctx: Context, motivo: String) {
        val ora = adesso()
        var d = Store.leggi()
        val note = mutableListOf<String>()

        val (imp, notaRicarica) = Regole.ricarica(d.impostazioni, ora)
        notaRicarica?.let { note += it }

        // 1. Mattine finite senza tag né Emergency
        val mattine = d.mattine.map { m ->
            if (!m.conclusa && ora > m.fine) Regole.chiudi(m, Esito.fallita, ora).also { note += "MATTINA ${descr(m)} chiusa: fallita" }
            else m
        }.toMutableList()

        // 2. Mattine aperte non più desiderate (sveglia modificata, disattivata o eliminata), se non bloccate
        val desiderate = Regole.mattineDesiderate(d.sveglie, mattine, ora)
        fun desiderata(m: Mattina) = desiderate.any { it.svegliaID == m.svegliaID && Regole.stessoIstante(it.orario, m.orario) }
        mattine.removeAll { m ->
            (!m.conclusa && ora < m.inizio && !m.bloccata(ora) && !desiderata(m)).also {
                if (it) note += "Mattina ${descr(m)} tolta (sveglia modificata, disattivata o oltre le prossime 2)"
            }
        }

        // 3. Le desiderate: nuove, oppure aggiornate se la sveglia è cambiata e non sono bloccate
        for (des in desiderate) {
            val s = d.sveglie.firstOrNull { it.id == des.svegliaID } ?: continue
            val richiesti = s.test ?: ParametriMattina(progressiva = imp.progressiva)
            val suono = (Suoneria.da(s.suoneria) ?: Suoneria.normale).file
            val i = mattine.indexOfFirst { !it.conclusa && it.svegliaID == s.id && Regole.stessoIstante(it.orario, des.orario) }
            if (i >= 0) {
                val m = mattine[i]
                if ((m.parametri != richiesti || m.suoneria != suono || m.nome != s.nome) && !m.bloccata(ora)) {
                    mattine[i] = m.copy(parametri = richiesti, suoneria = suono, nome = s.nome)
                    note += "Mattina ${descr(m)} aggiornata"
                }
            } else {
                val m = Mattina(svegliaID = s.id, nome = s.nome, orario = des.orario, parametri = richiesti,
                                suoneria = suono, test = s.test != null)
                mattine += m
                note += "Mattina ${descr(m)} programmata (progressiva ${if (richiesti.progressiva) "sì" else "no"})"
            }
        }

        // 4. Le sveglie una tantum finite spariscono (anche quelle annullate in anticipo)
        val finite = Regole.unaTantumFinite(d.sveglie, mattine, ora)

        d = d.copy(mattine = mattine, sveglie = d.sveglie.filterNot { it.id in finite }, impostazioni = imp)
        val finali = d
        Store.modifica {
            it.copy(mattine = finali.mattine, sveglie = finali.sveglie,
                    impostazioni = it.impostazioni.copy(creditiEmergenza = imp.creditiEmergenza,
                                                        ultimaRicarica = imp.ultimaRicarica,
                                                        ultimaDataVista = imp.ultimaDataVista))
        }

        val prossimo = programmaProssimo(ctx, finali.mattine, ora)
        val inCorso = finali.mattine.any { it.inCorso(ora) }
        if (inCorso) ServizioSveglia.avvia(ctx)
        val aperte = finali.mattine.count { !it.conclusa }
        val riga = "Riallinea ($motivo): $aperte mattine aperte, prossima sveglia di sistema " +
            (prossimo?.let { EventLog.data(it) } ?: "nessuna") + if (inCorso) ", MATTINA IN CORSO" else ""
        EventLog.scrivi((listOf(riga) + note).joinToString("\n    "))
    }

    /**
     * Una sola sveglia di sistema (sempre la stessa PendingIntent, che sostituisce la precedente):
     * l'inizio della prossima mattina, oppure tra 60 s se una mattina è in corso.
     */
    private fun programmaProssimo(ctx: Context, mattine: List<Mattina>, ora: Long): Long? {
        val am = ctx.getSystemService(AlarmManager::class.java)
        val scatta = PendingIntent.getBroadcast(ctx, 0, Intent(ctx, AllarmeReceiver::class.java),
                                                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val prossimo = if (mattine.any { it.inCorso(ora) }) ora + MINUTO
                       else mattine.filter { !it.conclusa && it.inizio > ora }.minOfOrNull { it.inizio }
        if (prossimo == null) {
            am.cancel(scatta)
            return null
        }
        val mostra = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        try {
            am.setAlarmClock(AlarmManager.AlarmClockInfo(prossimo, mostra), scatta)
        } catch (e: SecurityException) {
            EventLog.scrivi("ERRORE: permesso sveglie esatte mancante ($e)")
            Store.modifica { it.copy(avviso = "Alba non ha il permesso di programmare le sveglie: controlla le impostazioni del telefono.") }
        }
        return prossimo
    }

    // Tag, Emergency

    private fun _tag(ctx: Context, uid: String?, simulato: Boolean): Risposta {
        val ora = adesso()
        val d = Store.leggi()
        val nome: String
        if (simulato) {
            EventLog.scrivi("SIMULA TAG (modalità sviluppatore)")
            nome = "-"
        } else {
            val tag = d.tag.firstOrNull { it.uid == uid }
            if (tag == null) {
                EventLog.scrivi("TAG SCONOSCIUTO $uid: rifiutato")
                return Risposta(false, "Questo tag non è registrato in Alba.")
            }
            nome = tag.nome
            Store.modifica { dati -> dati.copy(tag = dati.tag.map { if (it.id == tag.id) it.copy(ultimaScansione = ora) else it }) }
        }

        val mattine = d.mattine.toMutableList()
        val risposta: Risposta
        val i = mattine.indexOfFirst { it.inCorso(ora) }
        val j = mattine.indices.filter { mattine[it].nellaFinestraPrima(ora) }.minByOrNull { mattine[it].inizio }
        when {
            i >= 0 -> {
                if (simulato && !mattine[i].test) return Risposta(false, "«Simula tag» funziona solo sulle mattine di test.")
                val m = Regole.chiudi(mattine[i].copy(eventi = mattine[i].eventi + EventoMattina(ora, TipoEvento.tag, nome)), Esito.tag, ora)
                mattine[i] = m
                EventLog.scrivi("SPEGNIMENTO COL TAG \"$nome\" – mattina ${descr(m)}: time-to-scan ${m.timeToScan} s, punteggio ${m.punteggio}")
                risposta = Risposta(true, "Sveglia spenta ✓ Buona giornata!")
            }
            j != null -> {
                if (simulato && !mattine[j].test) return Risposta(false, "«Simula tag» funziona solo sulle mattine di test.")
                val m = Regole.chiudi(mattine[j].copy(eventi = mattine[j].eventi + EventoMattina(ora, TipoEvento.anticipo, nome)), Esito.anticipo, ora)
                mattine[j] = m
                EventLog.scrivi("SPEGNIMENTO ANTICIPATO COL TAG \"$nome\" – mattina ${descr(m)} annullata")
                risposta = Risposta(true, "Sveglia ${Formati.quando(m.orario)} annullata in anticipo ✓")
            }
            else -> {
                EventLog.scrivi("TAG \"$nome\" riconosciuto: nessuna sveglia da spegnere")
                return Risposta(false, "Tag «$nome» riconosciuto ✓ Nessuna sveglia da spegnere adesso.")
            }
        }
        Store.modifica { it.copy(mattine = mattine) }
        _riallinea(ctx, "tag")
        return risposta
    }

    private fun _emergenza(ctx: Context, fuoriCasa: Boolean): Risposta {
        val ora = adesso()
        val d = Store.leggi()
        var imp = Regole.ricarica(d.impostazioni, ora).first
        if (!fuoriCasa && imp.creditiEmergenza <= 0) {
            EventLog.scrivi("EMERGENCY rifiutato: nessun credito")
            return Risposta(false, "Nessun credito Emergency: usa il tag.")
        }
        val mattine = d.mattine.toMutableList()
        val i = mattine.indexOfFirst { it.inCorso(ora) }.takeIf { it >= 0 }
            ?: mattine.indices.filter { mattine[it].nellaFinestraPrima(ora) }.minByOrNull { mattine[it].inizio }
            ?: return Risposta(false, "Nessuna sveglia in corso o nelle prossime 2 ore.")
        val evento = EventoMattina(ora, TipoEvento.emergenza, if (fuoriCasa) "fuori casa" else null)
        // fuori casa: nessun credito, streak in pausa
        mattine[i] = Regole.chiudi(mattine[i].copy(eventi = mattine[i].eventi + evento),
                                   if (fuoriCasa) Esito.fuoriCasa else Esito.emergenza, ora)
        if (!fuoriCasa) imp = imp.copy(creditiEmergenza = imp.creditiEmergenza - 1)
        val finale = imp
        Store.modifica {
            it.copy(mattine = mattine,
                    impostazioni = it.impostazioni.copy(creditiEmergenza = finale.creditiEmergenza,
                                                        ultimaRicarica = finale.ultimaRicarica,
                                                        ultimaDataVista = finale.ultimaDataVista))
        }
        EventLog.scrivi("${if (fuoriCasa) "EMERGENCY FUORI CASA (nessun credito)" else "EMERGENCY STOP"} – mattina ${descr(mattine[i])} chiusa, crediti rimasti ${finale.creditiEmergenza}/${Costanti.CREDITI_MAX}")
        _riallinea(ctx, "emergenza")
        if (fuoriCasa) return Risposta(true, "Sveglia spenta: sei fuori casa, nessun credito usato. Lo streak resta in pausa.")
        return Risposta(true, "Sveglia spenta con l'Emergency Stop. Crediti rimasti: ${finale.creditiEmergenza}/${Costanti.CREDITI_MAX}. Lo streak riparte da zero.")
    }

    // Sveglie

    private fun _salva(ctx: Context, s: Sveglia): Risposta {
        val d = Store.leggi()
        if (d.sveglie.any { it.id == s.id } && Regole.svegliaBloccata(s.id, d.mattine, adesso())) return BLOCCATA
        Store.modifica { dati ->
            val i = dati.sveglie.indexOfFirst { it.id == s.id }
            dati.copy(sveglie = if (i >= 0) dati.sveglie.toMutableList().also { it[i] = s } else dati.sveglie + s)
        }
        EventLog.scrivi("Sveglia salvata: ${s.nome} ${"%02d:%02d".format(s.ora, s.minuti)} giorni ${s.giorni} attiva ${s.attiva}" +
            (s.dataUnaTantum?.let { " una tantum ${EventLog.data(it)}" } ?: "") + if (s.test != null) " [TEST]" else "")
        _riallinea(ctx, "sveglia salvata")
        val m = Store.leggi().mattine.filter { it.svegliaID == s.id && !it.conclusa }.minByOrNull { it.orario }
        if (m != null) return Risposta(true, "Salvata ✓ Suona ${Formati.quando(m.orario)}")
        return Risposta(true, if (s.attiva) "Salvata ✓" else "Salvata ✓ (disattivata)")
    }

    private fun descr(m: Mattina) = "«${m.nome}» ${EventLog.data(m.orario).take(16)}" + if (m.test) " [TEST]" else ""
}
