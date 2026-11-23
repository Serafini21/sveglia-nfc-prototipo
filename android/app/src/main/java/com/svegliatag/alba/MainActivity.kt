package com.svegliatag.alba

import android.Manifest
import android.app.KeyguardManager
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import java.util.concurrent.Executors

/** Schermate del mattino, sopra a tutto. */
sealed interface Schermata {
    data object InCorso : Schermata
    data object Emergenza : Schermata
    data class Risveglio(val id: String) : Schermata
}

/** Pagine aperte sopra le schede (al posto delle sheet di iOS). */
sealed interface Pagina {
    data class ModificaSveglia(val sveglia: Sveglia, val nuova: Boolean) : Pagina
    data object Dormire : Pagina
    data object Progressiva : Pagina
    data object Sviluppatore : Pagina
    data object Casa : Pagina
    data object Routine : Pagina
    data object Log : Pagina
    data object NuovoTag : Pagina
    data class ProvaTag(val id: String) : Pagina
}

/** Stato dell'interfaccia condiviso con l'Activity (NFC) e le azioni in background. */
object StatoUI {
    data class Messaggio(val testo: String, val n: Long = System.nanoTime())

    val messaggio = MutableStateFlow<Messaggio?>(null)
    val schermata = MutableStateFlow<Schermata?>(null)
    /** Nome del tag in attesa di essere avvicinato per la registrazione. */
    val registrazione = MutableStateFlow<String?>(null)
    private val coda = Executors.newSingleThreadExecutor()

    fun avvisa(testo: String) { messaggio.value = Messaggio(testo) }

    private val principale = Handler(Looper.getMainLooper())

    /**
     * Esegue un'azione del Motore fuori dal thread principale, in ordine, e mostra la risposta.
     * `poi` riceve la risposta sul thread principale (per chiudere una pagina, per esempio).
     */
    fun esegui(azione: () -> Risposta?, poi: (Risposta) -> Unit = {}) {
        coda.execute {
            try {
                azione()?.let { r ->
                    avvisa(r.messaggio)
                    principale.post { poi(r) }
                }
            } catch (e: Exception) {
                EventLog.scrivi("ERRORE azione: $e")
                avvisa("Errore: ${e.message}")
            }
        }
    }

    /** Mostra "Sveglia in corso" durante una mattina, "Buongiorno" dopo il tag. */
    fun aggiornaSchermata(d: DatiAlba, ora: Long) {
        val inCorso = d.mattine.any { it.inCorso(ora) }
        when (schermata.value) {
            Schermata.Emergenza -> return
            is Schermata.Risveglio -> { if (inCorso) schermata.value = Schermata.InCorso; return }
            else -> {}
        }
        val risveglio = d.mattine.lastOrNull { it.esito == Esito.tag && !it.risveglioVisto }
        schermata.value = when {
            inCorso -> Schermata.InCorso
            risveglio != null -> Schermata.Risveglio(risveglio.id)
            else -> null
        }
    }
}

class Navigazione {
    val pagine = mutableStateListOf<Pagina>()
    fun apri(p: Pagina) { pagine.add(p) }
    fun chiudi() { if (pagine.isNotEmpty()) pagine.removeAt(pagine.lastIndex) }
}

val LocalNav = staticCompositionLocalOf { Navigazione() }

class MainActivity : ComponentActivity() {
    private var nfc: NfcAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        nfc = NfcAdapter.getDefaultAdapter(this)
        // aperta dalla notifica a tutto schermo: subito sopra il blocco, prima di disegnare
        sopraIlBlocco(Store.leggi().mattine.any { it.inCorso(adesso()) })
        apriDa(intent)
        setContent { MaterialTheme(colorScheme = Tema.colori) { Radice(this) } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        apriDa(intent)
    }

    private fun apriDa(i: Intent?) {
        if (i?.getStringExtra(ServizioSveglia.EXTRA_SCHERMATA) == "emergenza") StatoUI.schermata.value = Schermata.Emergenza
    }

    override fun onResume() {
        super.onResume()
        // con Alba aperta ogni tag avvicinato arriva qui (niente app esterne, niente codice segreto)
        nfc?.enableReaderMode(this, { tag -> tagLetto(tag) },
            NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or NfcAdapter.FLAG_READER_NFC_F or
                NfcAdapter.FLAG_READER_NFC_V or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK, null)
        val app = applicationContext
        StatoUI.esegui({ Motore.riallinea(app, "app aperta"); null })
    }

    override fun onPause() {
        nfc?.disableReaderMode(this)
        super.onPause()
    }

    /** Chiamato dal sistema su un thread a parte. */
    private fun tagLetto(tag: Tag) {
        val uid = Regole.uid(tag.id)
        val nome = StatoUI.registrazione.value
        val r = if (nome != null) Motore.registraTag(nome, uid).also { if (it.ok) StatoUI.registrazione.value = null }
                else Motore.spegniConTag(this, uid)
        StatoUI.avvisa(r.messaggio)
    }

    val nfcAttivo: Boolean get() = nfc?.isEnabled == true
    val nfcPresente: Boolean get() = nfc != null

    /** Durante la sveglia i tasti volume non fanno niente. */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val volume = keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (volume && Store.leggi().mattine.any { it.inCorso(adesso()) }) return true
        return super.onKeyDown(keyCode, event)
    }

    /** Durante la sveglia Alba si mostra sopra la schermata di blocco e accende lo schermo. */
    fun sopraIlBlocco(si: Boolean) {
        setShowWhenLocked(si)
        setTurnScreenOn(si)
    }

    val bloccato: Boolean get() = getSystemService(KeyguardManager::class.java).isKeyguardLocked

    /** Chiede impronta o PIN restando su Alba: dopo lo sblocco il tag si legge. */
    fun sblocca() = getSystemService(KeyguardManager::class.java).requestDismissKeyguard(this, null)
}

@Composable
fun Radice(activity: MainActivity) {
    val dati by Store.dati.collectAsState()
    val schermata by StatoUI.schermata.collectAsState()
    val messaggio by StatoUI.messaggio.collectAsState()
    var ora by remember { mutableLongStateOf(adesso()) }
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val nav = remember { Navigazione() }

    // al primo avvio: senza il permesso notifiche la sveglia a tutto schermo non compare
    val chiediNotifiche = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { concesso ->
        EventLog.scrivi("Permesso notifiche: ${if (concesso) "concesso" else "negato"}")
    }
    LaunchedEffect(Unit) {
        if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            chiediNotifiche.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    // ogni secondo: una mattina può iniziare con l'app aperta
    LaunchedEffect(Unit) {
        while (true) {
            ora = adesso()
            delay(1000)
        }
    }
    val inCorso = dati.mattine.any { it.inCorso(ora) }
    LaunchedEffect(dati, inCorso) { StatoUI.aggiornaSchermata(dati, adesso()) }
    LaunchedEffect(inCorso) { activity.sopraIlBlocco(inCorso) }
    LaunchedEffect(messaggio) {
        val m = messaggio ?: return@LaunchedEffect
        delay(3000)
        if (StatoUI.messaggio.value == m) StatoUI.messaggio.value = null
    }

    CompositionLocalProvider(LocalNav provides nav) {
        Box(Modifier.fillMaxSize().background(Tema.sfondo)) {
            Column(Modifier.fillMaxSize()) {
                Box(Modifier.weight(1f).statusBarsPadding()) {
                    when (tab) {
                        0 -> HomeView(dati, ora, activity)
                        1 -> StatisticheView(dati)
                        2 -> TagView(dati)
                        else -> ImpostazioniView(dati, ora, activity)
                    }
                }
                BarraSchede(tab) { tab = it }
            }
            nav.pagine.lastOrNull()?.let { p ->
                BackHandler { nav.chiudi() }
                Box(Modifier.fillMaxSize().background(Tema.sfondo).statusBarsPadding()) { MostraPagina(p, dati, ora, activity) }
            }
            schermata?.let { s ->
                BackHandler { if (s != Schermata.InCorso) StatoUI.schermata.value = null }
                Box(Modifier.fillMaxSize()) {
                    when (s) {
                        Schermata.InCorso -> SvegliaInCorsoView(dati, ora, activity)
                        Schermata.Emergenza -> EmergenzaView(dati, ora)
                        is Schermata.Risveglio -> RisveglioView(dati, s.id)
                    }
                }
            }
            messaggio?.let { m -> Box(Modifier.statusBarsPadding().align(Alignment.TopCenter)) { Avviso(m.testo) } }
        }
    }
}

@Composable
private fun MostraPagina(p: Pagina, dati: DatiAlba, ora: Long, activity: MainActivity) {
    when (p) {
        is Pagina.ModificaSveglia -> ModificaSvegliaView(p.sveglia, p.nuova, dati, ora)
        Pagina.Dormire -> DormireView(dati)
        Pagina.Progressiva -> ProgressivaView(dati)
        Pagina.Sviluppatore -> SviluppatoreView(dati, ora)
        Pagina.Casa -> ImpostaCasaView()
        Pagina.Routine -> RoutineEditor(dati)
        Pagina.Log -> LogView()
        Pagina.NuovoTag -> NuovoTagView(dati, ora, activity)
        is Pagina.ProvaTag -> ProvaTagView(dati, p.id, ora)
    }
}

@Composable
private fun BarraSchede(tab: Int, scegli: (Int) -> Unit) {
    val colori = NavigationBarItemDefaults.colors(
        selectedIconColor = Tema.ambra, selectedTextColor = Tema.ambra, indicatorColor = Tema.ambraTenue,
        unselectedIconColor = Tema.testo2, unselectedTextColor = Tema.testo2,
    )
    NavigationBar(containerColor = Tema.superficie) {
        NavigationBarItem(tab == 0, { scegli(0) }, { Icon(Icons.Filled.Notifications, null) }, label = { Text("Sveglie") }, colors = colori)
        NavigationBarItem(tab == 1, { scegli(1) }, { Icon(Icons.Filled.DateRange, null) }, label = { Text("Statistiche") }, colors = colori)
        NavigationBarItem(tab == 2, { scegli(2) }, { Icon(painterResource(R.drawable.ic_nfc), null) }, label = { Text("Tag") }, colors = colori)
        NavigationBarItem(tab == 3, { scegli(3) }, { Icon(Icons.Filled.Settings, null) }, label = { Text("Impostazioni") }, colors = colori)
    }
}
