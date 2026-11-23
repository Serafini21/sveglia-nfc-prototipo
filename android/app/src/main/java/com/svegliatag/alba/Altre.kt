package com.svegliatag.alba

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider

// Statistiche

@Composable
fun StatisticheView(dati: DatiAlba) {
    val storico = dati.mattine.filter { it.conclusa }.sortedByDescending { it.orario }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
               verticalArrangement = Arrangement.spacedBy(18.dp)) {
        item { Titolo("Statistiche", Modifier.padding(top = 8.dp)) }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Dato("Giorni di fila", "${Regole.streak(dati.mattine)}", Modifier.weight(1f), Tema.ambra)
                Dato("Mattine riuscite", "${Regole.riuscite(dati.mattine)}/${Regole.conteggiate(dati.mattine)}", Modifier.weight(1f))
                Dato("Media al tag", Regole.mediaTimeToScan(dati.mattine)?.let { Formati.durata(it) } ?: "–", Modifier.weight(1f))
            }
        }
        item { GraficoSettimana(Regole.punteggiGiorni(dati.mattine, ora = adesso())) }
        item { Text("Storico", style = inter(17, FontWeight.SemiBold)) }
        if (storico.isEmpty()) item { Text("Ancora nessuna mattina conclusa.", style = inter(14, colore = Tema.testo2)) }
        items(storico, key = { it.id }) { m -> RigaStorico(m) }
    }
}

/** Barre del punteggio degli ultimi 7 giorni, con il valore sopra e l'iniziale del giorno sotto. */
@Composable
private fun GraficoSettimana(giorni: List<Regole.GiornoPunteggio>) {
    val punti = giorni.mapNotNull { it.punteggio }
    val media = if (punti.isEmpty()) "–" else "${punti.sum() / punti.size}"
    Column(Modifier.fillMaxWidth().scheda(raggio = 20.dp, margine = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row {
            Text("Punteggio · ultimi 7 giorni", style = inter(15, FontWeight.SemiBold), modifier = Modifier.weight(1f))
            Text("media $media", style = inter(13, colore = Tema.testo2))
        }
        Row(Modifier.fillMaxWidth().height(160.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Bottom) {
            giorni.forEach { g ->
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(g.punteggio?.toString() ?: "—", style = inter(11, FontWeight.SemiBold, Tema.testo2))
                    Box(Modifier.fillMaxWidth().height(maxOf(6, (g.punteggio ?: 0) * 110 / 100).dp).clip(RoundedCornerShape(6.dp))
                        .background(if (g.punteggio == null) Tema.superficie2 else Tema.ambra))
                    Text(Formati.iniziale(g.giorno), style = inter(12, colore = Tema.testo2))
                }
            }
        }
    }
}

@Composable
private fun RigaStorico(m: Mattina) {
    val (colore, fondo) = when (m.esito) {
        Esito.tag, Esito.anticipo -> Tema.successo to Tema.successoFondo
        Esito.emergenza, Esito.fuoriCasa -> Tema.ambra to Tema.ambraTenue
        else -> Tema.pericolo to Tema.mattinoSuperficie
    }
    val titolo = "${Formati.giornoStorico(m.orario)} · ${Formati.ora(m.orario)}" + (m.chiusa?.let { " → ${Formati.ora(it)}" } ?: "")
    val dettagli = buildList {
        m.eventi.lastOrNull { it.tipo == TipoEvento.tag || it.tipo == TipoEvento.anticipo }?.nota?.takeIf { it != "-" }?.let { add("Tag $it") }
        m.timeToScan?.let { add("al tag in ${Formati.durata(it)}") }
        if (m.esito == Esito.emergenza) add("streak azzerato")
        m.punteggio?.let { add("$it punti") }
        if (m.test) add("test")
    }.joinToString(" · ")
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Tema.superficie).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(titolo, style = inter(15, FontWeight.SemiBold))
            if (dettagli.isNotEmpty()) Text(dettagli, style = inter(13, colore = Tema.testo2))
        }
        Pastiglia(m.esito?.titolo ?: "", colore, fondo)
    }
}

// Tag

@Composable
fun TagView(dati: DatiAlba) {
    val nav = LocalNav.current
    LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
               verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                Titolo("I miei tag", Modifier.weight(1f))
                Box(Modifier.clip(RoundedCornerShape(14.dp)).background(Tema.ambra).clickable { nav.apri(Pagina.NuovoTag) }
                        .padding(horizontal = 14.dp, vertical = 12.dp)) {
                    Text("+ Aggiungi", style = inter(15, FontWeight.Bold, Tema.suAmbra))
                }
            }
        }
        if (dati.tag.isEmpty()) item {
            Text("Nessun tag. Aggiungine uno e mettilo lontano dal letto (bagno, cucina).", style = inter(15, colore = Tema.testo2))
        }
        items(dati.tag, key = { it.id }) { t -> RigaTag(t) }
        if (dati.tag.isNotEmpty()) item { Text("Qualsiasi tag registrato spegne le sveglie.", style = inter(13, colore = Tema.testo2)) }
        item {
            Column(Modifier.fillMaxWidth().scheda(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Come funziona", style = inter(15, FontWeight.SemiBold))
                Text("Con Alba aperta e il telefono sbloccato, appoggia il tag al centro del retro del telefono. " +
                     "Quando suona la sveglia Alba si apre da sola: tocca «Sblocca il telefono» (impronta o PIN), poi avvicina il tag.",
                     style = inter(14, colore = Tema.testoChiaro))
            }
        }
    }
}

@Composable
private fun RigaTag(t: TagNFC) {
    val nav = LocalNav.current
    val provato = t.ultimaScansione != null
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Tema.superficie).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(48.dp).clip(RoundedCornerShape(14.dp)).background(if (provato) Tema.ambraTenue else Tema.superficie2),
            contentAlignment = Alignment.Center) {
            Icon(painterResource(R.drawable.ic_nfc), null, tint = if (provato) Tema.ambra else Tema.testoChiaro)
        }
        Column(Modifier.weight(1f).padding(start = 14.dp)) {
            Text(t.nome, style = inter(16, FontWeight.SemiBold))
            Text(t.ultimaScansione?.let { "Ultima scansione: ${Formati.quando(it)}" } ?: "Mai scansionato", style = inter(13, colore = Tema.testo2))
        }
        Box(Modifier.clickable { nav.apri(Pagina.ProvaTag(t.id)) }.padding(4.dp)) {
            if (provato) Pastiglia("Pronto", Tema.successo, Tema.successoFondo) else Pastiglia("Prova", Tema.ambra, Tema.ambraTenue)
        }
        IconButton({
            StatoUI.esegui({ Motore.eliminaTag(t.id); Risposta(true, "Tag «${t.nome}» eliminato") })
        }) { Icon(Icons.Filled.Delete, "Elimina il tag ${t.nome}", tint = Tema.testo2) }
    }
}

/** Aggiunta guidata: nome, poi si avvicina il tag. */
@Composable
fun NuovoTagView(dati: DatiAlba, ora: Long, activity: MainActivity) {
    val nav = LocalNav.current
    var nome by remember { mutableStateOf("") }
    var inAttesa by remember { mutableStateOf<String?>(null) }
    val pulito = nome.trim()
    val doppione = dati.tag.any { Regole.stessoNome(it.nome, pulito) }
    val bloccati = Regole.tagBloccati(dati.mattine, ora)
    val registrato = inAttesa?.let { n -> dati.tag.firstOrNull { it.nome == n } }
    DisposableEffect(Unit) { onDispose { StatoUI.registrazione.value = null } }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Chiudi") { nav.chiudi() }
        Text("Nuovo tag", style = grotesk(28, FontWeight.Bold))
        if (!activity.nfcPresente) {
            AvvisoScheda("Questo telefono non ha l'NFC.", null) {}
        } else if (!activity.nfcAttivo) {
            AvvisoScheda("L'NFC è spento.", "Attiva NFC") { Telefono.apri(activity, Intent(android.provider.Settings.ACTION_NFC_SETTINGS)) }
        }
        when {
            registrato != null -> {
                Column(Modifier.fillMaxWidth().scheda(), horizontalAlignment = Alignment.CenterHorizontally,
                       verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Filled.CheckCircle, null, tint = Tema.successo, modifier = Modifier.size(72.dp))
                    Text("Tag «${registrato.nome}» registrato. Mettilo lontano dal letto.", style = inter(16, FontWeight.SemiBold), textAlign = TextAlign.Center)
                }
                PulsantePrincipale("Fine") { nav.chiudi() }
            }
            inAttesa != null -> {
                Column(Modifier.fillMaxWidth().scheda(), horizontalAlignment = Alignment.CenterHorizontally,
                       verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Icon(painterResource(R.drawable.ic_nfc), null, tint = Tema.ambra, modifier = Modifier.size(72.dp))
                    Text("Appoggia ora il tag «$inAttesa» al centro del retro del telefono.", style = inter(16, FontWeight.SemiBold), textAlign = TextAlign.Center)
                    CircularProgressIndicator(color = Tema.ambra)
                    Text("Se non lo legge, spostalo piano di qualche centimetro.", style = inter(13, colore = Tema.testo2), textAlign = TextAlign.Center)
                }
                PulsanteSecondario("Annulla") { StatoUI.registrazione.value = null; inAttesa = null }
            }
            else -> {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    EtichettaSezione("1 · Dai un nome al tag")
                    CampoTesto(nome, { nome = it }, "Per esempio: Bagno")
                    if (doppione) Text("Esiste già un tag con questo nome.", style = inter(13, colore = Tema.pericolo))
                    if (bloccati) Text("Durante una sveglia e nelle 2 ore prima non puoi aggiungere tag.", style = inter(13, colore = Tema.pericolo))
                }
                PulsantePrincipale("Avanti", abilitato = pulito.isNotEmpty() && !doppione && !bloccati) {
                    inAttesa = pulito
                    StatoUI.registrazione.value = pulito
                }
            }
        }
    }
}

@Composable
fun ProvaTagView(dati: DatiAlba, id: String, ora: Long) {
    val nav = LocalNav.current
    val inizio = remember { adesso() }
    val tag = dati.tag.firstOrNull { it.id == id }
    val riuscita = (tag?.ultimaScansione ?: 0) >= inizio
    val prossima = dati.mattine.filter { !it.conclusa && it.fine > ora }.minByOrNull { it.inizio }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Fine") { nav.chiudi() }
        Text("Prova tag", style = grotesk(28, FontWeight.Bold))
        Column(Modifier.fillMaxWidth().scheda(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (riuscita) Icon(Icons.Filled.CheckCircle, null, tint = Tema.successo, modifier = Modifier.size(72.dp))
            else Icon(painterResource(R.drawable.ic_nfc), null, tint = Tema.ambra, modifier = Modifier.size(72.dp))
            Text(if (riuscita) "Funziona! Alba ha letto il tag «${tag?.nome}»."
                 else "Sblocca il telefono e appoggia ora il tag «${tag?.nome}» al centro del retro.",
                 style = inter(16, FontWeight.SemiBold), textAlign = TextAlign.Center)
            if (!riuscita) CircularProgressIndicator(color = Tema.ambra)
            if (prossima != null && (prossima.nellaFinestraPrima(ora) || prossima.inCorso(ora))) {
                Text("Attenzione: la prova annulla «${prossima.nome}», che è entro 2 ore.",
                     style = inter(13, FontWeight.SemiBold, Tema.pericolo), textAlign = TextAlign.Center)
            }
        }
    }
}

// Impostazioni

@Composable
fun ImpostazioniView(dati: DatiAlba, ora: Long, activity: MainActivity) {
    val nav = LocalNav.current
    val ctx = LocalContext.current
    val imp = dati.impostazioni
    val controlli = remember(ora / 5000) { Telefono.controlli(ctx) }
    val versione = remember { ctx.packageManager.getPackageInfo(ctx.packageName, 0).longVersionCode }
    val testoCasa = when {
        imp.casa != null && imp.casa.dal > ora -> "nuova dal ${Formati.giornoBreve(imp.casa.dal)} ${Formati.ora(imp.casa.dal)}"
        imp.casa == null -> "non impostata"
        else -> "impostata"
    }
    val base = ParametriMattina(progressiva = false)

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Titolo("Impostazioni", Modifier.padding(top = 8.dp))

        Sezione("Telefono", "Senza queste impostazioni Samsung può addormentare Alba e la sveglia non suona. Tocca una riga per aprire la pagina giusta.") {
            controlli.forEachIndexed { i, c ->
                RigaValore(c.titolo, if (c.ok) "✓ a posto" else "da attivare", if (c.ok) Tema.successo else Tema.pericolo) {
                    Telefono.apri(activity, c.intent)
                }
                if (i < controlli.lastIndex) HorizontalDivider(color = Tema.bordo)
            }
            HorizontalDivider(color = Tema.bordo)
            Column(Modifier.fillMaxWidth().clickable { Telefono.dettagliApp(activity) }.padding(16.dp)) {
                Text("App mai in sospensione", style = inter(15))
                Text("Impostazioni › Batteria › Limiti utilizzo in background › App mai in sospensione › aggiungi Alba.",
                     style = inter(13, colore = Tema.testo2))
            }
            HorizontalDivider(color = Tema.bordo)
            Column(Modifier.fillMaxWidth().padding(16.dp)) {
                Text("Non disturbare e Modalità sonno", style = inter(15))
                Text("Lascia consentite le sveglie (è così di base). Non usare mai «Arresto forzato» su Alba: cancella le sveglie.",
                     style = inter(13, colore = Tema.testo2))
            }
        }

        Sezione("Emergency Stop", "Uno alla volta: si ricarica 7 giorni dopo averlo usato.") {
            RigaValore("Crediti", "${imp.creditiEmergenza}/${Costanti.CREDITI_MAX}")
            Regole.prossimaRicarica(imp)?.let { RigaValore("Prossima ricarica", Formati.quando(it)) }
        }

        Sezione("Posizione di casa", "Fuori casa (oltre ${Costanti.RAGGIO_CASA.toInt()} m) l'Emergency Stop non usa il credito.") {
            RigaValore("Casa", testoCasa) { nav.apri(Pagina.Casa) }
        }

        Sezione("Regole anti-trucco") {
            RigaValore("Sirena senza tag", "dopo ${Costanti.RITARDO_CATENA_SEC / 60} min")
            RigaValore("Durata della sirena", "${base.durataCatenaMin} min")
            RigaValore("Blocco modifiche", "${Costanti.FINESTRA_PRIMA / ORA} h prima")
            RigaValore("Tasti volume", "disattivati")
        }

        Sezione {
            RigaValore("Routine del mattino", "${dati.routine.size} voci") { nav.apri(Pagina.Routine) }
        }

        Sezione("Diagnostica") {
            RigaValore("Log", "") { nav.apri(Pagina.Log) }
            HorizontalDivider(color = Tema.bordo)
            RigaValore("Esporta log", "") { condividiLog(activity) }
            HorizontalDivider(color = Tema.bordo)
            RigaValore("Versione", "1.0 (build $versione)")
        }

        if (imp.sviluppatore) Sezione { RigaValore("Modalità sviluppatore", "") { nav.apri(Pagina.Sviluppatore) } }
    }
}

fun condividiLog(activity: MainActivity) {
    val file = EventLog.fileDaCondividere(activity)
    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.file", file)
    val invia = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_STREAM, uri)
        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    activity.startActivity(Intent.createChooser(invia, "Esporta log"))
}

/** Salva la posizione attuale come casa. Vale dopo 12 ore: fino ad allora resta quella di prima. */
@Composable
fun ImpostaCasaView() {
    val nav = LocalNav.current
    val (posizione, negata) = rememberPosizione(true)
    // con ± 100 m la casa sarebbe troppo incerta
    val precisa = posizione != null && posizione.incertezza in 0.0..100.0
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Indietro") { nav.chiudi() }
        Text("Posizione di casa", style = grotesk(28, FontWeight.Bold))
        Column(Modifier.fillMaxWidth().scheda(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            when {
                posizione != null -> {
                    Text("Precisione: ± ${posizione.incertezza.toInt()} m", style = inter(15))
                    if (!precisa) Text("Aspetta qualche secondo, meglio vicino a una finestra.", style = inter(13, colore = Tema.testo2))
                }
                negata -> Text("Permesso posizione negato: attivalo in Impostazioni › App › Alba › Autorizzazioni.", style = inter(14, colore = Tema.testo2))
                else -> Text("Cerco la posizione…", style = inter(14, colore = Tema.testo2))
            }
        }
        PulsantePrincipale("Salva questa posizione come casa", abilitato = precisa) {
            val p = posizione ?: return@PulsantePrincipale
            val t = adesso()
            StatoUI.esegui({
                Store.modifica { it.copy(impostazioni = Regole.impostaCasa(it.impostazioni, p.latitude, p.longitude, t)) }
                val dal = t + Costanti.ATTESA_CASA
                // senza coordinate nel log: il log si condivide
                EventLog.scrivi("POSIZIONE DI CASA impostata (± ${p.incertezza.toInt()} m), vale dal ${EventLog.data(dal)}")
                Risposta(true, "Casa salvata: vale dal ${Formati.giornoBreve(dal)} alle ${Formati.ora(dal)}")
            }) { nav.chiudi() }
        }
        Text("Fallo da casa. La nuova posizione vale dopo 12 ore: fino ad allora resta quella di prima.", style = inter(13, colore = Tema.testo2))
    }
}

@Composable
fun LogView() {
    val nav = LocalNav.current
    val ctx = LocalContext.current
    var versione by remember { mutableIntStateOf(0) }
    // le righe che iniziano con spazi appartengono alla voce precedente (note del riallineamento)
    val voci = remember(versione) {
        val elenco = mutableListOf<String>()
        EventLog.leggi().lines().filter { it.isNotEmpty() }.forEach { r ->
            if (r.startsWith(" ") && elenco.isNotEmpty()) elenco[elenco.lastIndex] += "\n" + r else elenco += r
        }
        elenco.takeLast(2000).reversed()
    }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Indietro") { nav.chiudi() }
            Text("Log (più recenti in alto)", style = inter(17, FontWeight.SemiBold), modifier = Modifier.weight(1f).padding(start = 12.dp))
            IconButton({ versione++ }) { Icon(Icons.Filled.Refresh, "Aggiorna", tint = Tema.testo) }
            IconButton({ condividiLog(ctx as MainActivity) }) { Icon(Icons.Filled.Share, "Esporta log", tint = Tema.testo) }
        }
        SelectionContainer {
            LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                       verticalArrangement = Arrangement.spacedBy(6.dp)) {
                items(voci) { Text(it, style = inter(11).copy(fontFamily = FontFamily.Monospace, fontSize = 11.sp)) }
            }
        }
    }
}

// Modalità sviluppatore

/** Modalità sviluppatore nascosta (5 tocchi sul titolo della Home): strumenti per i test sul telefono. */
@Composable
fun SviluppatoreView(dati: DatiAlba, ora: Long) {
    val nav = LocalNav.current
    val ctx = LocalContext.current.applicationContext
    val p = dati.impostazioni.test
    var confermaAzzera by remember { mutableStateOf(false) }
    fun cambia(nuovi: ParametriTest) = StatoUI.esegui({ Store.modifica { it.copy(impostazioni = it.impostazioni.copy(test = nuovi)) }; null })
    val aperte = dati.mattine.filter { !it.conclusa }.sortedBy { it.orario }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Indietro") { nav.chiudi() }
        Text("Sviluppatore", style = grotesk(28, FontWeight.Bold))

        Sezione("Catena breve (mattine di test)",
                "La progressiva segue l'interruttore della Home (ora ${if (dati.impostazioni.progressiva) "attiva" else "spenta"}). " +
                "La sirena parte ${Costanti.RITARDO_CATENA_TEST_SEC} s dopo l'orario. Le mattine di test non contano nelle statistiche.") {
            Passo("Progressiva: ${p.passoProgressivaSec * Costanti.GRADINI_PROGRESSIVA} s",
                  { cambia(p.copy(passoProgressivaSec = maxOf(2, p.passoProgressivaSec - 2))) },
                  { cambia(p.copy(passoProgressivaSec = minOf(60, p.passoProgressivaSec + 2))) })
            Passo("Durata della sirena: ${p.durataCatenaMin} min",
                  { cambia(p.copy(durataCatenaMin = maxOf(1, p.durataCatenaMin - 1))) },
                  { cambia(p.copy(durataCatenaMin = minOf(30, p.durataCatenaMin + 1))) })
        }

        Sezione("Programma") {
            Passo("Mattina tra ${p.minutiAllaMattina} min",
                  { cambia(p.copy(minutiAllaMattina = maxOf(1, p.minutiAllaMattina - 1))) },
                  { cambia(p.copy(minutiAllaMattina = minOf(120, p.minutiAllaMattina + 1))) })
            RigaValore("Programma la mattina di test", "") {
                val t = (adesso() + p.minutiAllaMattina * MINUTO) / SECONDO * SECONDO
                val z = java.time.Instant.ofEpochMilli(t).atZone(java.time.ZoneId.systemDefault())
                val s = Sveglia(nome = "Test", ora = z.hour, minuti = z.minute, dataUnaTantum = t,
                                test = ParametriMattina(progressiva = dati.impostazioni.progressiva, passoProgressivaSec = p.passoProgressivaSec,
                                                        durataCatenaMin = p.durataCatenaMin, ritardoCatenaSec = Costanti.RITARDO_CATENA_TEST_SEC))
                StatoUI.esegui({ Motore.salva(ctx, s) })
            }
        }

        Sezione("Azioni") {
            RigaValore("Simula tag (solo mattine di test)", "") { StatoUI.esegui({ Motore.spegniConTag(ctx, null, simulato = true) }) }
            RigaValore("Riallinea adesso", "") { StatoUI.esegui({ Motore.riallinea(ctx, "sviluppatore"); Risposta(true, "Riallineato") }) }
            RigaValore("Ferma tutte le sveglie e disattivale", "", Tema.pericolo) { StatoUI.esegui({ Motore.fermaEDisattivaTutto(ctx) }) }
            RigaValore("Azzera statistiche e storico", "", Tema.pericolo) { confermaAzzera = true }
        }

        Sezione("Stato") {
            RigaValore("Suono della sveglia", if (ServizioSveglia.attivo) "attivo" else "spento")
            aperte.forEach { m ->
                Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                    Text("${m.nome}${if (m.test) " [TEST]" else ""} · ${Formati.quando(m.orario)}", style = inter(14))
                    Text("inizio ${Formati.ora(m.inizio, true)}, sirena ${Formati.ora(m.inizioCatena, true)}, progressiva ${if (m.parametri.progressiva) "sì" else "no"}, sirena ${m.parametri.durataCatenaMin} min" +
                         if (m.inCorso(ora)) " – IN CORSO" else "", style = inter(12, colore = Tema.testo2))
                }
            }
        }

        Sezione {
            RigaValore("Log completo", "") { nav.apri(Pagina.Log) }
            RigaValore("Esci dalla modalità sviluppatore", "") {
                StatoUI.esegui({
                    Store.modifica { it.copy(impostazioni = it.impostazioni.copy(sviluppatore = false)) }
                    Risposta(true, "Modalità sviluppatore disattivata")
                }) { nav.chiudi() }
            }
        }
    }

    if (confermaAzzera) {
        AlertDialog(
            onDismissRequest = { confermaAzzera = false },
            text = { Text("Cancellare tutte le mattine passate? Streak, punteggi e storico ripartono da zero.") },
            confirmButton = {
                TextButton({ confermaAzzera = false; StatoUI.esegui({ Motore.azzeraStatistiche() }) }) { Text("Azzera", color = Tema.pericolo) }
            },
            dismissButton = { TextButton({ confermaAzzera = false }) { Text("Annulla") } },
            containerColor = Tema.superficie,
        )
    }
}

@Composable
private fun Passo(testo: String, meno: () -> Unit, piu: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(start = 16.dp, end = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(testo, style = inter(15), modifier = Modifier.weight(1f))
        TextButton(meno) { Text("−", style = grotesk(22, colore = Tema.ambra)) }
        Spacer(Modifier.size(4.dp))
        TextButton(piu) { Text("+", style = grotesk(22, colore = Tema.ambra)) }
    }
}
