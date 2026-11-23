package com.svegliatag.alba

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TimePickerDefaults
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun HomeView(dati: DatiAlba, ora: Long, activity: MainActivity) {
    val nav = LocalNav.current
    val sveglie = dati.sveglie.filter { it.test == null }.sortedWith(compareBy({ it.ora }, { it.minuti }))
    var tocchi by remember { mutableIntStateOf(0) }
    var ultimoTocco by remember { mutableStateOf(0L) }

    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                // 5 tocchi sul titolo: modalità sviluppatore
                Titolo("Sveglie", Modifier.clickable(indication = null, interactionSource = null) {
                    val t = adesso()
                    tocchi = if (t - ultimoTocco < 600) tocchi + 1 else 1
                    ultimoTocco = t
                    if (tocchi >= 5) {
                        tocchi = 0
                        val attiva = !dati.impostazioni.sviluppatore
                        StatoUI.esegui({
                            Store.modifica { it.copy(impostazioni = it.impostazioni.copy(sviluppatore = attiva)) }
                            EventLog.scrivi("Modalità sviluppatore ${if (attiva) "attivata" else "disattivata"}")
                            Risposta(true, if (attiva) "Modalità sviluppatore attiva" else "Modalità sviluppatore disattivata")
                        })
                    }
                })
                Spacer(Modifier.weight(1f))
                val streak = Regole.streak(dati.mattine)
                Text("🔥 $streak giorni", style = inter(14, FontWeight.SemiBold, Tema.ambra),
                     modifier = Modifier.clip(RoundedCornerShape(50)).background(Tema.superficie2).padding(horizontal = 12.dp, vertical = 8.dp))
            }
        }
        item { AvvisiHome(dati, ora, activity) }
        item { ProssimaScheda(dati, ora) }
        item { PulsantePrincipale("☾  Vado a dormire ora", altezza = 64.dp) { nav.apri(Pagina.Dormire) } }
        item {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
                Text("Le mie sveglie", style = inter(17, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                PulsanteIcona(Icons.Filled.Add, "Nuova sveglia") { nav.apri(Pagina.ModificaSveglia(Sveglia(), nuova = true)) }
            }
        }
        if (sveglie.isEmpty()) item { Text("Nessuna sveglia. Tocca + per crearne una.", style = inter(15, colore = Tema.testo2)) }
        items(sveglie, key = { it.id }) { s -> RigaSveglia(s, dati, ora) }
        if (dati.impostazioni.sviluppatore) item {
            Text("🔨  Modalità sviluppatore", style = inter(15),
                 modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).clickable { nav.apri(Pagina.Sviluppatore) }
                     .scheda())
        }
    }
}

@Composable
private fun RigaSveglia(s: Sveglia, dati: DatiAlba, ora: Long) {
    val nav = LocalNav.current
    val ctx = LocalContext.current.applicationContext
    val bloccata = Regole.svegliaBloccata(s.id, dati.mattine, ora)
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Tema.superficie)
            .clickable { nav.apri(Pagina.ModificaSveglia(s, nuova = false)) }.padding(horizontal = 18.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text("${s.ora}:${"%02d".format(s.minuti)}", style = grotesk(30, colore = if (s.attiva) Tema.testo else Tema.testo3))
            Text("${s.nome} · ${Formati.giorni(s)}", style = inter(14, colore = if (s.attiva) Tema.testo2 else Tema.testo3))
        }
        if (bloccata) Icon(Icons.Filled.Lock, "Bloccata", tint = Tema.ambra, modifier = Modifier.padding(end = 10.dp))
        Interruttore(s.attiva, abilitato = !bloccata) { valore ->
            var nuova = s.copy(attiva = valore)
            if (valore && s.giorni.isEmpty() && (s.dataUnaTantum ?: 0) <= adesso()) {
                nuova = nuova.copy(dataUnaTantum = Regole.prossimoOrario(s.ora, s.minuti, adesso()))
            }
            StatoUI.esegui({ Motore.salva(ctx, nuova) })
        }
    }
}

@Composable
private fun ProssimaScheda(dati: DatiAlba, ora: Long) {
    val nav = LocalNav.current
    val m = dati.mattine.filter { !it.conclusa && it.fine > ora }.minByOrNull { it.inizio }
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(Tema.superficie)
            .border(1.dp, Tema.bordo, RoundedCornerShape(22.dp)).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (m != null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                EtichettaSezione("Prossima sveglia")
                Spacer(Modifier.weight(1f))
                if (m.test) Pastiglia("TEST")
                // da che ora la sveglia si blocca, poi «Bloccata» in ambra
                val bloccata = m.bloccata(ora)
                Icon(Icons.Filled.Lock, null, tint = if (bloccata) Tema.ambra else Tema.testo2,
                     modifier = Modifier.padding(start = 8.dp, end = 4.dp).width(14.dp))
                Text(if (bloccata) "Bloccata" else Formati.ora(m.inizio - Costanti.FINESTRA_PRIMA),
                     style = inter(13, FontWeight.Medium, if (bloccata) Tema.ambra else Tema.testo2))
            }
            Row(verticalAlignment = Alignment.Bottom) {
                Text(Formati.ora(m.orario), style = grotesk(56), maxLines = 1)
                Text(Formati.traQuanto(m.orario, ora), style = inter(15, colore = Tema.testo2),
                     modifier = Modifier.padding(start = 12.dp, bottom = 10.dp))
            }
            Text("${m.nome} · ${Formati.quando(m.orario)}", style = inter(14, colore = Tema.testo2))
        } else {
            EtichettaSezione("Prossima sveglia")
            Text("Nessuna sveglia programmata", style = inter(17, FontWeight.SemiBold, Tema.testo2))
        }
        Box(Modifier.clip(RoundedCornerShape(16.dp))
                .background(if (dati.impostazioni.progressiva) Tema.ambraTenue else Tema.notte)
                .padding(horizontal = 14.dp, vertical = 6.dp)) {
            InterruttoreProgressiva(dati) { nav.apri(Pagina.Progressiva) }
        }
    }
}

/** Interruttore unico della progressiva: vale per tutte le sveglie e ricorda l'ultima scelta. */
@Composable
fun InterruttoreProgressiva(dati: DatiAlba, titolo: String = "Sveglia progressiva 15 min", apri: (() -> Unit)? = null) {
    val ctx = LocalContext.current.applicationContext
    Row(verticalAlignment = Alignment.CenterVertically) {
        Row(
            Modifier.weight(1f).heightIn(min = 44.dp)
                .then(if (apri != null) Modifier.clickable(role = Role.Button, onClick = apri) else Modifier),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(titolo, style = inter(15, FontWeight.SemiBold))
            if (apri != null) Text("  ›", style = inter(15, FontWeight.SemiBold, Tema.testo3))
        }
        Interruttore(dati.impostazioni.progressiva) { valore ->
            StatoUI.esegui({
                Motore.impostaProgressiva(ctx, valore)
                Risposta(true, if (valore) "Sveglia progressiva attiva" else "Sveglia progressiva disattivata")
            })
        }
    }
}

/** Opzioni della progressiva: interruttore e suono, uno per tutte le sveglie. */
@Composable
fun ProgressivaView(dati: DatiAlba) {
    val nav = LocalNav.current
    val ctx = LocalContext.current
    DisposableEffect(Unit) { onDispose { Anteprima.ferma() } }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Indietro") { nav.chiudi() }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Sveglia progressiva", style = grotesk(28, FontWeight.Bold))
            Text("Parte 15 minuti prima dell'orario: per 10 minuti sale piano, negli ultimi 5 sempre più forte. All'orario passa alla suoneria della sveglia.",
                 style = inter(15, colore = Tema.testo2))
        }
        Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Tema.superficie).padding(horizontal = 16.dp, vertical = 6.dp)) {
            InterruttoreProgressiva(dati, "Attiva")
        }
        Column(Modifier.alpha(if (dati.impostazioni.progressiva) 1f else 0.4f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            EtichettaSezione("Suono")
            ListaSuonerie(dati.impostazioni.suoneriaProgressiva.name) { s ->
                Anteprima.suona(ctx, s.file)
                StatoUI.esegui({
                    Store.modifica { it.copy(impostazioni = it.impostazioni.copy(suonoProgressiva = s.name)) }
                    EventLog.scrivi("Suono della progressiva: ${s.name}")
                    null
                })
            }
            Text("Tocca un suono per ascoltarlo.", style = inter(13, colore = Tema.testo2))
        }
    }
}

/** Suonerie divise per categoria, con la spunta su quella scelta. */
@Composable
fun ListaSuonerie(scelta: String, scegli: (Suoneria) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Suoneria.Categoria.entries.forEach { categoria ->
            val suoni = Suoneria.entries.filter { it.categoria == categoria }
            Text(categoria.nome, style = inter(12, colore = Tema.testo3), modifier = Modifier.padding(start = 4.dp))
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Tema.superficie)) {
                suoni.forEachIndexed { i, s ->
                    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable { scegli(s) }.padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically) {
                        Text(s.nome, style = inter(16), modifier = Modifier.weight(1f))
                        if (s.name == scelta) Icon(Icons.Filled.Check, "Scelta", tint = Tema.ambra)
                    }
                    if (i < suoni.lastIndex) HorizontalDivider(color = Tema.bordo)
                }
            }
        }
    }
}

@Composable
private fun AvvisiHome(dati: DatiAlba, ora: Long, activity: MainActivity) {
    // ricontrollati ogni 5 secondi: l'utente può tornare dalle Impostazioni di Android
    val controlli = remember(ora / 5000) { Telefono.controlli(activity) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        controlli.filter { !it.ok }.take(2).forEach { c ->
            AvvisoScheda("${c.titolo}: da attivare. ${c.spiegazione}", "Attiva") { Telefono.apri(activity, c.intent) }
        }
        dati.avviso?.let { AvvisoScheda(it, "OK") { StatoUI.esegui({ Motore.mostraAvviso(null); null }) } }
        if (dati.tag.isEmpty()) AvvisoScheda("Nessun tag: aggiungine uno nella scheda Tag.", null) {}
    }
}

@Composable
fun AvvisoScheda(testo: String, pulsante: String?, azione: () -> Unit) {
    Column(Modifier.fillMaxWidth().scheda(Tema.ambraTenue), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row {
            Icon(Icons.Filled.Warning, null, tint = Tema.ambra, modifier = Modifier.padding(end = 8.dp))
            Text(testo, style = inter(14))
        }
        if (pulsante != null) PulsantePrincipale(pulsante, altezza = 44.dp, onClick = azione)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ModificaSvegliaView(iniziale: Sveglia, nuova: Boolean, dati: DatiAlba, ora: Long) {
    val nav = LocalNav.current
    val ctx = LocalContext.current
    var s by remember { mutableStateOf(iniziale) }
    var salvo by remember { mutableStateOf(false) }
    var sceltaSuoneria by remember { mutableStateOf(false) }
    val orario = rememberTimePickerState(iniziale.ora, iniziale.minuti, is24Hour = true)
    val bloccata = !nuova && Regole.svegliaBloccata(s.id, dati.mattine, ora)
    DisposableEffect(Unit) { onDispose { Anteprima.ferma() } }

    // La sveglia come verrà salvata: senza giorni è una tantum alla prossima occorrenza dell'orario.
    fun bozza(): Sveglia {
        val una = if (s.giorni.isEmpty()) Regole.prossimoOrario(orario.hour, orario.minute, adesso()) else null
        return s.copy(ora = orario.hour, minuti = orario.minute, dataUnaTantum = una, nome = s.nome.trim().ifEmpty { "Sveglia" })
    }
    val prossima = Regole.occorrenze(bozza().copy(attiva = true), adesso(), adesso() + 8 * GIORNO).firstOrNull()
    val suoneria = Suoneria.da(s.suoneria) ?: Suoneria.normale

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Annulla") { nav.chiudi() }
            Text(if (nuova) "Nuova sveglia" else "Modifica sveglia", style = inter(17, FontWeight.SemiBold),
                 textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            Box(Modifier.clip(RoundedCornerShape(14.dp)).background(Tema.ambra).alpha(if (bloccata || salvo) 0.4f else 1f)
                    .clickable(enabled = !bloccata && !salvo) {
                        salvo = true
                        val b = bozza()
                        StatoUI.esegui({ Motore.salva(ctx.applicationContext, b) }) { r ->
                            salvo = false
                            if (r.ok) nav.chiudi()
                        }
                    }.padding(horizontal = 16.dp, vertical = 12.dp)) {
                Text(if (salvo) "Salvo…" else "Salva", style = inter(15, FontWeight.Bold, Tema.suAmbra))
            }
        }

        if (bloccata) {
            Column(Modifier.fillMaxWidth().scheda(Tema.ambraTenue), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("🔒 Sveglia bloccata", style = inter(16, FontWeight.SemiBold, Tema.ambra))
                Text("Suona entro 2 ore: usa il tag (la annulla in anticipo) o l'Emergency Stop.", style = inter(14))
                PulsanteSecondario("Emergency Stop", coloreTesto = Tema.pericolo) {
                    nav.chiudi()
                    StatoUI.schermata.value = Schermata.Emergenza
                }
            }
        }

        Column(Modifier.alpha(if (bloccata) 0.4f else 1f), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                TimePicker(orario, colors = TimePickerDefaults.colors(
                    clockDialColor = Tema.superficie, selectorColor = Tema.ambra, clockDialSelectedContentColor = Tema.suAmbra,
                    clockDialUnselectedContentColor = Tema.testo, timeSelectorSelectedContainerColor = Tema.ambraTenue,
                    timeSelectorUnselectedContainerColor = Tema.superficie, timeSelectorSelectedContentColor = Tema.ambra,
                    timeSelectorUnselectedContentColor = Tema.testo))
                Text(prossima?.let { "Prossima: ${Formati.quando(it)}" } ?: "Nessuna occorrenza",
                     style = inter(14, FontWeight.Medium, Tema.ambra))
            }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                EtichettaSezione("Nome")
                CampoTesto(s.nome, { if (!bloccata) s = s.copy(nome = it) }, "Nome")
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                EtichettaSezione("Ripeti")
                SelettoreGiorni(s.giorni) { if (!bloccata) s = s.copy(giorni = it) }
                if (s.giorni.isEmpty()) Text("Una volta sola", style = inter(12, colore = Tema.testo2))
            }

            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Tema.superficie)) {
                RigaValore("Suoneria", suoneria.nome) { if (!bloccata) sceltaSuoneria = !sceltaSuoneria }
                HorizontalDivider(color = Tema.bordo)
                Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Suoneria punizione", style = inter(15))
                        Text("Dopo ${Costanti.RITARDO_CATENA_SEC / 60} min senza tag", style = inter(12, colore = Tema.testo2))
                    }
                    Text("Sirena", style = inter(15, colore = Tema.pericolo))
                }
            }
            if (sceltaSuoneria) {
                ListaSuonerie(s.suoneria) {
                    s = s.copy(suoneria = it.name)
                    Anteprima.suona(ctx, it.file)
                }
                PulsanteSecondario("Ascolta la sirena di punizione", coloreTesto = Tema.pericolo) { Anteprima.suona(ctx, SIRENA) }
            }
        }

        Row(Modifier.fillMaxWidth().scheda(Tema.notte, raggio = 16.dp)) {
            Text("🔒  Nelle 2 ore prima servirà il tag per modificarla. Niente snooze.", style = inter(13, colore = Tema.testoChiaro))
        }

        if (!nuova) {
            PulsanteSecondario("Duplica sveglia", abilitato = !bloccata) {
                nav.chiudi()
                nav.apri(Pagina.ModificaSveglia(bozza().copy(id = nuovoId(), nome = "${s.nome} (copia)", attiva = true), nuova = true))
            }
            PulsanteSecondario("Elimina sveglia", coloreTesto = Tema.pericolo, abilitato = !bloccata) {
                StatoUI.esegui({ Motore.elimina(ctx.applicationContext, s.id) }) { if (it.ok) nav.chiudi() }
            }
        }
    }
}

@Composable
fun SelettoreGiorni(giorni: List<Int>, cambia: (List<Int>) -> Unit) {
    val settimana = listOf(2 to "L", 3 to "M", 4 to "M", 5 to "G", 6 to "V", 7 to "S", 1 to "D")
    val nomi = mapOf(2 to "lunedì", 3 to "martedì", 4 to "mercoledì", 5 to "giovedì", 6 to "venerdì", 7 to "sabato", 1 to "domenica")
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        settimana.forEach { (id, lettera) ->
            val scelto = id in giorni
            Box(
                Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp))
                    .background(if (scelto) Tema.ambra else Tema.superficie2)
                    .clickable(onClickLabel = nomi[id]) { cambia(if (scelto) giorni - id else (giorni + id).sorted()) },
                contentAlignment = Alignment.Center,
            ) {
                Text(lettera, style = inter(15, if (scelto) FontWeight.Bold else FontWeight.SemiBold, if (scelto) Tema.suAmbra else Tema.testoChiaro))
            }
        }
    }
}

/** "Vado a dormire ora": orari a cicli completi di sonno, ritocco di ±1 minuto, sveglia una tantum. */
@Composable
fun DormireView(dati: DatiAlba) {
    val nav = LocalNav.current
    val ctx = LocalContext.current.applicationContext
    val adessoAperta = remember { adesso() }
    var scelta by remember { mutableIntStateOf(Costanti.CICLI_CONSIGLIATI) }
    var ritocco by remember { mutableIntStateOf(0) }
    var salvo by remember { mutableStateOf(false) }
    val opzioni = remember { Regole.cicliSonno(adessoAperta) }
    val orario = (opzioni.firstOrNull { it.cicli == scelta }?.orario ?: adessoAperta) + ritocco * MINUTO

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Indietro") { nav.chiudi() }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Buonanotte", style = grotesk(28, FontWeight.Bold))
            Text("Sono le ${Formati.ora(adessoAperta)}. Calcolo 15 min per addormentarti e cicli di sonno da 90 min. Scegli quando svegliarti.",
                 style = inter(15, colore = Tema.testo2))
        }
        opzioni.forEach { o ->
            val scelto = o.cicli == scelta
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(if (scelto) Tema.ambraTenue else Tema.superficie)
                    .border(if (scelto) 2.dp else 1.dp, if (scelto) Tema.ambra else Tema.bordo, RoundedCornerShape(18.dp))
                    .clickable { scelta = o.cicli; ritocco = 0 }.padding(horizontal = 18.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(Formati.ora(o.orario), style = grotesk(28, colore = if (scelto) Tema.ambra else Tema.testo), modifier = Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.End) {
                    Text("${o.cicli} cicli · ${Formati.ore(o.durata)}",
                         style = inter(14, if (scelto) FontWeight.SemiBold else FontWeight.Normal, if (scelto) Tema.testo else Tema.testo2))
                    if (o.cicli == Costanti.CICLI_CONSIGLIATI) Text("Consigliato", style = inter(12, colore = Tema.ambra))
                }
            }
        }
        Column(Modifier.fillMaxWidth().scheda(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            EtichettaSezione("Ritocca l'orario")
            Row(verticalAlignment = Alignment.CenterVertically) {
                PulsanteTesto("−", "Un minuto prima") { ritocco -= 1 }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(Formati.ora(orario), style = grotesk(40))
                    Text("± 1 minuto per tocco", style = inter(12, colore = Tema.testo2))
                }
                PulsanteTesto("+", "Un minuto dopo") { ritocco += 1 }
            }
        }
        Box(Modifier.padding(horizontal = 4.dp)) { InterruttoreProgressiva(dati) }
        PulsantePrincipale(if (salvo) "Imposto…" else "Imposta sveglia alle ${Formati.ora(orario)}", abilitato = !salvo) {
            salvo = true
            val t = java.time.Instant.ofEpochMilli(orario).atZone(java.time.ZoneId.systemDefault())
            val s = Sveglia(nome = "Vado a dormire", ora = t.hour, minuti = t.minute, dataUnaTantum = orario)
            StatoUI.esegui({ Motore.salva(ctx, s) }) { r ->
                salvo = false
                if (r.ok) nav.chiudi()
            }
        }
    }
}

@Composable
private fun PulsanteTesto(testo: String, descrizione: String, onClick: () -> Unit) {
    Box(Modifier.clip(RoundedCornerShape(14.dp)).background(Tema.superficie2)
            .clickable(onClickLabel = descrizione, onClick = onClick).padding(horizontal = 18.dp, vertical = 8.dp)) {
        Text(testo, style = grotesk(24))
    }
}
