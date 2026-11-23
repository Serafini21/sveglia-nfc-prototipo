package com.svegliatag.alba

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlin.math.ceil

/** Mostrata durante una mattina, anche sopra la schermata di blocco. */
@Composable
fun SvegliaInCorsoView(dati: DatiAlba, ora: Long, activity: MainActivity) {
    val m = dati.mattine.firstOrNull { it.inCorso(ora) }
    val crediti = dati.impostazioni.creditiEmergenza
    val nomi = dati.tag.map { it.nome }
    val nomiTag = if (nomi.isEmpty()) "Nessun tag registrato: usa l'Emergency Stop." else nomi.joinToString(" o ") + "."
    Column(
        Modifier.fillMaxSize().background(Tema.mattinoSfondo).statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        if (m != null) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(m.nome, style = inter(15, FontWeight.SemiBold, Tema.ambra))
                Text(Formati.ora(m.orario), style = grotesk(84, colore = Tema.mattinoTesto))
                val trascorso = (ora - m.orario) / SECONDO
                Text(if (trascorso >= 0) "Suona da ${Formati.durata(trascorso)}" else "Risveglio dolce · sveglia tra ${Formati.durata(-trascorso)}",
                     style = inter(15, colore = Tema.mattinoTesto2))
            }
        }

        Box(Modifier.size(236.dp).border(2.dp, Tema.mattinoAnello, CircleShape), contentAlignment = Alignment.Center) {
            Box(Modifier.size(176.dp).border(2.dp, Tema.mattinoBordo, CircleShape), contentAlignment = Alignment.Center) {
                Box(Modifier.size(116.dp).clip(CircleShape).background(Tema.ambra), contentAlignment = Alignment.Center) {
                    Icon(painterResource(R.drawable.ic_nfc), null, tint = Tema.suAmbra, modifier = Modifier.size(48.dp))
                }
            }
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Vai al tag", style = grotesk(30, FontWeight.Bold, Tema.mattinoTesto))
            Text("$nomiTag Sblocca il telefono e appoggia il tag al centro del retro.",
                 style = inter(16, colore = Tema.mattinoTesto2), textAlign = TextAlign.Center)
        }

        if (activity.bloccato) PulsantePrincipale("Sblocca il telefono") { activity.sblocca() }

        if (m != null) Sirena(m, ora)

        Text("I tasti volume sono disattivati finché non usi il tag.", style = inter(13, colore = Tema.mattinoTesto2),
             modifier = Modifier.fillMaxWidth().scheda(Tema.mattinoSuperficie, raggio = 16.dp, margine = 14.dp))

        if (dati.impostazioni.sviluppatore && m?.test == true) {
            PulsanteSecondario("Simula tag (solo test)", colore = Tema.mattinoSuperficie, coloreTesto = Tema.mattinoTesto) {
                StatoUI.esegui({ Motore.spegniConTag(activity.applicationContext, null, simulato = true) })
            }
        }

        Box(
            Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(16.dp))
                .border(1.5.dp, Tema.pericolo, RoundedCornerShape(16.dp))
                .clickable { StatoUI.schermata.value = Schermata.Emergenza },
            contentAlignment = Alignment.Center,
        ) { Text("Emergency Stop · $crediti ${if (crediti == 1) "disponibile" else "disponibili"}", style = inter(15, FontWeight.SemiBold, Tema.pericolo)) }

        Text("Nascondi", style = inter(15, colore = Tema.mattinoTesto2),
             modifier = Modifier.clickable { StatoUI.schermata.value = null }.padding(12.dp))
    }
}

/** Quattro segmenti che si riempiono dall'orario fino alla sirena di sicurezza (T + 5 min). */
@Composable
private fun Sirena(m: Mattina, ora: Long) {
    val quarto = maxOf(1L, (m.inizioCatena - m.orario) / 4)
    val trascorso = ora - m.orario
    val pieni = if (trascorso < 0) 0 else minOf(4L, trascorso / quarto + 1).toInt()
    val attiva = ora >= m.inizioCatena
    Column(Modifier.fillMaxWidth().scheda(Tema.mattinoSuperficie, raggio = 16.dp, margine = 14.dp),
           horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            repeat(4) { i ->
                Box(Modifier.width(34.dp).height(8.dp).clip(RoundedCornerShape(50))
                    .background(if (i < pieni) Tema.pericolo else Tema.mattinoAnello))
            }
        }
        Text(if (attiva) "Sirena attiva: usa il tag" else "Sirena alle ${Formati.ora(m.inizioCatena, secondi = true)}",
             style = inter(13, colore = Tema.mattinoTesto2))
    }
}

/** Posizione letta solo con l'app aperta: per impostare la casa e, nell'Emergency Stop, per sapere se sei fuori casa. */
@Composable
fun rememberPosizione(attiva: Boolean): Pair<Location?, Boolean> {
    val ctx = LocalContext.current
    var posizione by remember { mutableStateOf<Location?>(null) }
    var permesso by remember { mutableStateOf(ctx.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) }
    var negata by remember { mutableStateOf(false) }
    val chiedi = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { r ->
        permesso = r[Manifest.permission.ACCESS_FINE_LOCATION] == true
        negata = !permesso
    }
    LaunchedEffect(attiva) {
        if (attiva && !permesso) chiedi.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
    }
    DisposableEffect(attiva, permesso) {
        val lm = ctx.getSystemService(LocationManager::class.java)
        val ascolta = LocationListener { posizione = it }
        if (attiva && permesso) {
            val provider = if (lm.hasProvider(LocationManager.FUSED_PROVIDER)) LocationManager.FUSED_PROVIDER else LocationManager.GPS_PROVIDER
            try {
                lm.requestLocationUpdates(provider, 1000L, 0f, ascolta, Looper.getMainLooper())
            } catch (e: SecurityException) {
                negata = true
            }
        }
        onDispose { lm.removeUpdates(ascolta) }
    }
    return posizione to negata
}

/** Incertezza della posizione in metri, -1 se non nota. */
val Location.incertezza: Double get() = if (hasAccuracy()) accuracy.toDouble() else -1.0

@Composable
fun EmergenzaView(dati: DatiAlba, ora: Long) {
    val ctx = LocalContext.current.applicationContext
    var frase by remember { mutableStateOf("") }
    var invio by remember { mutableStateOf(false) }
    val obiettivo = dati.mattine.firstOrNull { it.inCorso(ora) }
        ?: dati.mattine.filter { it.nellaFinestraPrima(ora) }.minByOrNull { it.inizio }
    val crediti = dati.impostazioni.creditiEmergenza
    val casa = Regole.casaInVigore(dati.impostazioni, ora)
    // la posizione serve solo se la casa è impostata
    val (posizione, negata) = rememberPosizione(casa != null)
    // solo se è certo (oltre 150 m anche tenendo conto dell'incertezza): altrimenti regole di casa
    val fuoriCasa = posizione?.let { Regole.fuoriCasa(it.latitude, it.longitude, it.incertezza, casa) } ?: false
    val pronta = obiettivo != null && (crediti > 0 || fuoriCasa) && Regole.fraseValida(frase) && !invio

    val descrizione = if (fuoriCasa) "Sei fuori casa: spegni senza tag e senza usare il credito. Lo streak resta in pausa." else {
        var t = if (crediti > 0) "Spegne la sveglia senza tag. Puoi usarlo una volta" else "Emergency Stop già usato"
        Regole.prossimaRicarica(dati.impostazioni)?.let { r ->
            val giorni = maxOf(1L, (r - ora + GIORNO - 1) / GIORNO)
            t += ": si ricarica tra $giorni ${if (giorni == 1L) "giorno" else "giorni"}"
        }
        val streak = Regole.streak(dati.mattine)
        t + ". Usarlo azzera lo streak" + if (streak > 0) " di $streak giorni." else "."
    }

    fun indietro() {
        StatoUI.schermata.value = null
        StatoUI.aggiornaSchermata(Store.leggi(), adesso())
    }

    Column(
        Modifier.fillMaxSize().background(Tema.mattinoSfondo).statusBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Indietro", Tema.mattinoSuperficie) { indietro() }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Emergency Stop", style = grotesk(30, FontWeight.Bold, Tema.mattinoTesto))
            Text(descrizione, style = inter(15, colore = Tema.mattinoTesto2))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            repeat(Costanti.CREDITI_MAX) { i ->
                Box(Modifier.weight(1f).height(10.dp).clip(RoundedCornerShape(50)).background(if (i < crediti) Tema.pericolo else Tema.mattinoScuro))
            }
        }
        if (casa != null) {
            val testo = when {
                fuoriCasa -> "📍 Fuori casa"
                negata -> "Posizione non disponibile: valgono le regole di casa"
                posizione == null -> "Controllo se sei a casa…"
                else -> "🏠 Sei a casa"
            }
            Text(testo, style = inter(14, colore = if (fuoriCasa) Tema.successo else Tema.mattinoTesto2))
        }
        Text(obiettivo?.let { "Ferma «${it.nome}», ${Formati.quando(it.orario)}." } ?: "Nessuna sveglia in corso o nelle prossime 2 ore.",
             style = inter(14, colore = if (obiettivo != null) Tema.mattinoTesto else Tema.mattinoTesto2))

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            EtichettaSezione("1 · Scrivi la frase", Tema.mattinoTesto2)
            Text(Costanti.FRASE_EMERGENZA, style = inter(15, FontWeight.SemiBold, Tema.ambra),
                 modifier = Modifier.fillMaxWidth().scheda(Tema.mattinoSuperficie, raggio = 12.dp, margine = 12.dp))
            CampoTesto(frase, { frase = it }, "Scrivi qui", fondo = Tema.mattinoCampo,
                       bordo = if (Regole.fraseValida(frase)) Tema.successo else Tema.mattinoBordo,
                       coloreTesto = Tema.mattinoTesto, coloreSegnaposto = Tema.mattinoTesto2)
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            EtichettaSezione("2 · Tieni premuto per ${Costanti.SECONDI_EMERGENZA} secondi", Tema.mattinoTesto2)
            PulsanteTenuto(pronta, Costanti.SECONDI_EMERGENZA) {
                invio = true
                val fuori = fuoriCasa
                if (fuori && posizione != null && casa != null) {
                    val metri = Regole.distanza(posizione.latitude, posizione.longitude, casa.latitudine, casa.longitudine)
                    EventLog.scrivi("Emergency: a ${metri.toInt()} m da casa (± ${posizione.incertezza.toInt()} m)")
                }
                StatoUI.esegui({ Motore.emergenza(ctx, fuori) }) { r ->
                    invio = false
                    if (r.ok) indietro()
                }
            }
        }
    }
}

/** Pulsante da tenere premuto per un tempo fisso, con barra di avanzamento. */
@Composable
fun PulsanteTenuto(abilitato: Boolean, secondi: Int, azione: () -> Unit) {
    var inizio by remember { mutableStateOf<Long?>(null) }
    var avanzamento by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(inizio) {
        val i = inizio
        if (i == null) { avanzamento = 0f; return@LaunchedEffect }
        while (true) {
            avanzamento = ((adesso() - i) / (secondi * 1000f)).coerceAtMost(1f)
            if (avanzamento >= 1f) {
                inizio = null
                azione()
                break
            }
            delay(50)
        }
    }
    Box(
        Modifier.fillMaxWidth().height(72.dp).clip(RoundedCornerShape(20.dp)).background(Tema.mattinoScuro)
            .alpha(if (abilitato) 1f else 0.4f)
            .pointerInput(abilitato) {
                if (abilitato) detectTapGestures(onPress = {
                    inizio = adesso()
                    tryAwaitRelease()
                    inizio = null
                })
            },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.align(Alignment.CenterStart).fillMaxHeight().fillMaxWidth(avanzamento).background(Tema.pericolo))
        Text(if (inizio == null) "Tieni premuto" else "Tieni premuto · ${ceil(secondi * (1 - avanzamento)).toInt()} s",
             style = inter(17, FontWeight.Bold, Tema.mattinoTesto))
    }
}

@Composable
fun RisveglioView(dati: DatiAlba, mattinaID: String) {
    val m = dati.mattine.firstOrNull { it.id == mattinaID }
    val fatte = m?.routineFatte.orEmpty().toSet()
    var modifica by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxSize().background(Tema.sfondo).statusBarsPadding().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.size(56.dp).clip(RoundedCornerShape(18.dp)).background(Tema.ambra), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Check, null, tint = Tema.suAmbra)
            }
            Text("Buongiorno!", style = grotesk(32, FontWeight.Bold))
            if (m != null) {
                val tag = m.eventi.lastOrNull { it.tipo == TipoEvento.tag }?.nota
                val alle = m.chiusa?.let { " alle ${Formati.ora(it)}" } ?: ""
                Text(if (tag != null && tag != "-") "Sveglia spenta col tag $tag$alle." else "Sveglia spenta$alle.",
                     style = inter(15, colore = Tema.testo2))
            }
        }
        if (m != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Dato("Tempo al tag", Formati.durata(m.timeToScan ?: 0), Modifier.weight(1f))
                Dato("Punteggio", "${m.punteggio ?: 0}", Modifier.weight(1f), Tema.ambra)
                Dato("Giorni di fila", "${Regole.streak(dati.mattine)}", Modifier.weight(1f))
            }
            if (m.test) Text("Mattina di test: non conta nelle statistiche.", style = inter(13, colore = Tema.testo3))
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row {
                Text("Routine del mattino", style = inter(17, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                if (dati.routine.isNotEmpty()) {
                    Text("${dati.routine.count { it.id in fatte }} di ${dati.routine.size}", style = inter(13, colore = Tema.testo2))
                }
            }
            if (modifica) {
                ModificaRoutine(dati)
            } else if (dati.routine.isEmpty()) {
                Text("Acqua, finestre, doccia… aggiungi le tue voci.", style = inter(14, colore = Tema.testo2))
            } else {
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Tema.superficie)) {
                    dati.routine.forEachIndexed { i, voce ->
                        val fatta = voce.id in fatte
                        Row(
                            Modifier.fillMaxWidth().heightIn(min = 56.dp)
                                .clickable { StatoUI.esegui({ Motore.segnaRoutine(mattinaID, voce.id, !fatta); null }) }
                                .padding(horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(Modifier.size(22.dp).clip(RoundedCornerShape(6.dp))
                                    .background(if (fatta) Tema.ambra else Tema.superficie)
                                    .border(2.dp, if (fatta) Tema.ambra else Tema.testo2, RoundedCornerShape(6.dp)),
                                contentAlignment = Alignment.Center) {
                                if (fatta) Icon(Icons.Filled.Check, null, tint = Tema.suAmbra, modifier = Modifier.size(16.dp))
                            }
                            Spacer(Modifier.width(12.dp))
                            Text(voce.testo, style = inter(15, colore = if (fatta) Tema.testo3 else Tema.testo).copy(
                                textDecoration = if (fatta) TextDecoration.LineThrough else null))
                        }
                        if (i < dati.routine.lastIndex) HorizontalDivider(color = Tema.bordo)
                    }
                }
            }
            Text(if (modifica) "Fatto" else if (dati.routine.isEmpty()) "Crea la routine" else "Modifica routine",
                 style = inter(14, FontWeight.SemiBold, Tema.ambra),
                 modifier = Modifier.clickable { modifica = !modifica }.padding(vertical = 12.dp))
        }

        PulsanteSecondario("Chiudi") {
            StatoUI.schermata.value = null
            StatoUI.esegui({ Motore.segnaRisveglioVisto(mattinaID); null })
        }
    }
}

/** Checklist del mattino: aggiungi, elimina e sposta in alto le voci. */
@Composable
fun ModificaRoutine(dati: DatiAlba) {
    var nuova by remember { mutableStateOf("") }
    fun aggiungi() {
        val testo = nuova.trim()
        if (testo.isEmpty()) return
        nuova = ""
        StatoUI.esegui({ Store.modifica { it.copy(routine = it.routine + VoceRoutine(testo = testo)) }; null })
    }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Tema.superficie)) {
            if (dati.routine.isEmpty()) {
                Text("Nessuna voce. Per esempio: bevi un bicchiere d'acqua, apri le finestre.",
                     style = inter(14, colore = Tema.testo2), modifier = Modifier.padding(16.dp))
            }
            dati.routine.forEachIndexed { i, v ->
                Row(Modifier.fillMaxWidth().padding(start = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(v.testo, style = inter(15), modifier = Modifier.weight(1f))
                    if (i > 0) IconButton({
                        StatoUI.esegui({
                            Store.modifica { d -> d.copy(routine = d.routine.toMutableList().also { java.util.Collections.swap(it, i, i - 1) }) }
                            null
                        })
                    }) { Icon(Icons.Filled.KeyboardArrowUp, "Sposta in alto", tint = Tema.testo2) }
                    IconButton({ StatoUI.esegui({ Store.modifica { d -> d.copy(routine = d.routine.filter { it.id != v.id }) }; null }) }) {
                        Icon(Icons.Filled.Delete, "Elimina", tint = Tema.pericolo)
                    }
                }
                if (i < dati.routine.lastIndex) HorizontalDivider(color = Tema.bordo)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f)) { CampoTesto(nuova, { nuova = it }, "Nuova voce") }
            Box(Modifier.width(110.dp)) { PulsanteSecondario("Aggiungi", abilitato = nuova.isNotBlank()) { aggiungi() } }
        }
    }
}

@Composable
fun RoutineEditor(dati: DatiAlba) {
    val nav = LocalNav.current
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        PulsanteIcona(Icons.AutoMirrored.Filled.ArrowBack, "Indietro") { nav.chiudi() }
        Text("Routine del mattino", style = grotesk(28, FontWeight.Bold))
        ModificaRoutine(dati)
    }
}
