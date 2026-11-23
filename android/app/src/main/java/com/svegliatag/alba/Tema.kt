package com.svegliatag.alba

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Stile "Alba" del mockup approvato (PROGETTO.md §7), stessi colori dell'app iPhone. */
object Tema {
    val sfondo = Color(0xFF0B1020)
    val superficie = Color(0xFF151B2E)
    val superficie2 = Color(0xFF1E2640)
    val bordo = Color(0xFF232B45)
    val testo = Color(0xFFF2F4F8)
    val testo2 = Color(0xFF9AA3B8)
    val testo3 = Color(0xFF8A93A8)
    val testoChiaro = Color(0xFFC9CFDC)
    val ambra = Color(0xFFFFB547)
    val suAmbra = Color(0xFF1A1206)
    val ambraTenue = Color(0xFF2A2418)
    val notte = Color(0xFF1A1F33)
    val pericolo = Color(0xFFFF8A7A)
    val successo = Color(0xFF7FE0B4)
    val successoFondo = Color(0xFF17302A)
    // Schermate del mattino (sveglia in corso, Emergency)
    val mattinoSfondo = Color(0xFF160F0A)
    val mattinoSuperficie = Color(0xFF24180F)
    val mattinoCampo = Color(0xFF1C130C)
    val mattinoScuro = Color(0xFF3A2A1C)
    val mattinoAnello = Color(0xFF4A3420)
    val mattinoBordo = Color(0xFF6E4A26)
    val mattinoTesto = Color(0xFFFFF6EC)
    val mattinoTesto2 = Color(0xFFC8B8A6)

    val colori = darkColorScheme(
        primary = ambra, onPrimary = suAmbra, secondary = ambra, onSecondary = suAmbra,
        background = sfondo, onBackground = testo, surface = superficie, onSurface = testo,
        surfaceVariant = superficie2, onSurfaceVariant = testo2, outline = bordo, error = pericolo,
        surfaceContainerHigh = superficie2, surfaceContainer = superficie, surfaceContainerHighest = superficie2,
    )
}

/** Space Grotesk (orari e titoli) e Inter (testo), scaricati dal workflow in assets/fonts. Senza, i font di sistema. */
object Caratteri {
    var grotesk: FontFamily = FontFamily.Default
        private set
    var inter: FontFamily = FontFamily.Default
        private set

    fun init(ctx: Context) {
        val presenti = runCatching { ctx.assets.list("fonts")?.toSet() }.getOrNull().orEmpty()
        if ("SpaceGrotesk.ttf" in presenti) grotesk = famiglia(ctx, "SpaceGrotesk.ttf")
        if ("Inter.ttf" in presenti) inter = famiglia(ctx, "Inter.ttf")
        EventLog.scrivi("Font: Space Grotesk ${if ("SpaceGrotesk.ttf" in presenti) "ok" else "ASSENTE"}, Inter ${if ("Inter.ttf" in presenti) "ok" else "ASSENTE"}")
    }

    // font variabili: ogni peso è la stessa famiglia con l'asse "wght" impostato
    @OptIn(ExperimentalTextApi::class)
    private fun famiglia(ctx: Context, file: String) =
        FontFamily(listOf(400, 500, 600, 700).map { Font("fonts/$file", ctx.assets, FontWeight(it)) })
}

fun inter(size: Int, peso: FontWeight = FontWeight.Normal, colore: Color = Tema.testo) =
    TextStyle(fontFamily = Caratteri.inter, fontSize = size.sp, fontWeight = peso, color = colore)

fun grotesk(size: Int, peso: FontWeight = FontWeight.SemiBold, colore: Color = Tema.testo) =
    TextStyle(fontFamily = Caratteri.grotesk, fontSize = size.sp, fontWeight = peso, color = colore)

/** Riquadro arrotondato del mockup. */
fun Modifier.scheda(colore: Color = Tema.superficie, raggio: Dp = 18.dp, margine: Dp = 16.dp) =
    this.clip(RoundedCornerShape(raggio)).background(colore).padding(margine)

@Composable
fun Titolo(testo: String, modifier: Modifier = Modifier) {
    Text(testo, style = grotesk(32, FontWeight.Bold), modifier = modifier.semantics { heading() })
}

/** Etichetta maiuscola delle sezioni ("PROSSIMA SVEGLIA"). */
@Composable
fun EtichettaSezione(testo: String, colore: Color = Tema.testo2) {
    Text(testo.uppercase(), style = inter(13, FontWeight.SemiBold, colore).copy(letterSpacing = 0.6.sp))
}

/** Pulsante ambra pieno (azione principale). */
@Composable
fun PulsantePrincipale(testo: String, modifier: Modifier = Modifier, altezza: Dp = 60.dp, abilitato: Boolean = true,
                       icona: ImageVector? = null, onClick: () -> Unit) {
    Row(
        modifier.fillMaxWidth().heightIn(min = altezza).clip(RoundedCornerShape(20.dp)).background(Tema.ambra)
            .alpha(if (abilitato) 1f else 0.4f)
            .clickable(enabled = abilitato, role = Role.Button, onClick = onClick).padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icona != null) Icon(icona, null, tint = Tema.suAmbra, modifier = Modifier.padding(end = 8.dp))
        Text(testo, style = inter(17, FontWeight.Bold, Tema.suAmbra), textAlign = TextAlign.Center)
    }
}

/** Pulsante scuro (azione secondaria). */
@Composable
fun PulsanteSecondario(testo: String, modifier: Modifier = Modifier, colore: Color = Tema.superficie2,
                       coloreTesto: Color = Tema.testo, abilitato: Boolean = true, onClick: () -> Unit) {
    Box(
        modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).background(colore)
            .alpha(if (abilitato) 1f else 0.4f)
            .clickable(enabled = abilitato, role = Role.Button, onClick = onClick).padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) { Text(testo, style = inter(15, FontWeight.SemiBold, coloreTesto), textAlign = TextAlign.Center) }
}

/** Pulsante quadrato da 44 dp con icona. */
@Composable
fun PulsanteIcona(icona: ImageVector, descrizione: String, colore: Color = Tema.superficie2, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp).clip(RoundedCornerShape(14.dp)).background(colore)
            .clickable(role = Role.Button, onClickLabel = descrizione, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icona, descrizione, tint = Tema.testo) }
}

/** Pastiglia colorata (esito, stato del tag). */
@Composable
fun Pastiglia(testo: String, colore: Color = Tema.testoChiaro, fondo: Color = Tema.superficie2) {
    Text(testo, style = inter(12, FontWeight.SemiBold, colore),
         modifier = Modifier.clip(RoundedCornerShape(50)).background(fondo).padding(horizontal = 9.dp, vertical = 5.dp))
}

/** Valore grande con etichetta (statistiche, risveglio). */
@Composable
fun Dato(titolo: String, valore: String, modifier: Modifier = Modifier, coloreValore: Color = Tema.testo) {
    Column(modifier.scheda(raggio = 16.dp, margine = 14.dp)) {
        Text(valore, style = grotesk(26, colore = coloreValore), maxLines = 1)
        Text(titolo, style = inter(12, colore = Tema.testo2))
    }
}

@Composable
fun Interruttore(attivo: Boolean, abilitato: Boolean = true, onCambia: (Boolean) -> Unit) {
    Switch(
        checked = attivo, onCheckedChange = onCambia, enabled = abilitato,
        colors = SwitchDefaults.colors(
            checkedThumbColor = Tema.suAmbra, checkedTrackColor = Tema.ambra,
            uncheckedThumbColor = Tema.testo2, uncheckedTrackColor = Tema.superficie2, uncheckedBorderColor = Tema.bordo,
        ),
    )
}

/** Campo di testo nello stile Alba. */
@Composable
fun CampoTesto(valore: String, onCambia: (String) -> Unit, segnaposto: String, modifier: Modifier = Modifier,
               fondo: Color = Tema.superficie, bordo: Color = Tema.bordo, coloreTesto: Color = Tema.testo,
               coloreSegnaposto: Color = Tema.testo3) {
    BasicTextField(
        value = valore, onValueChange = onCambia, singleLine = true,
        textStyle = inter(16, colore = coloreTesto), cursorBrush = SolidColor(Tema.ambra),
        modifier = modifier.fillMaxWidth(),
        decorationBox = { campo ->
            Box(
                Modifier.fillMaxWidth().heightIn(min = 50.dp).clip(RoundedCornerShape(14.dp)).background(fondo)
                    .border(1.5.dp, bordo, RoundedCornerShape(14.dp)).padding(horizontal = 14.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (valore.isEmpty()) Text(segnaposto, style = inter(16, colore = coloreSegnaposto))
                campo()
            }
        },
    )
}

/** Riscontro visivo immediato in alto. */
@Composable
fun Avviso(testo: String) {
    Text(
        testo, style = inter(15, FontWeight.SemiBold, Tema.suAmbra), textAlign = TextAlign.Center,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp).fillMaxWidth()
            .clip(RoundedCornerShape(18.dp)).background(Tema.ambra).padding(horizontal = 18.dp, vertical = 12.dp),
    )
}

/** Riga con titolo a sinistra e valore a destra, nelle liste delle impostazioni. */
@Composable
fun RigaValore(titolo: String, valore: String, coloreValore: Color = Tema.testo2, onClick: (() -> Unit)? = null) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(titolo, style = inter(15), modifier = Modifier.weight(1f))
        Text(if (onClick != null) "$valore ›" else valore, style = inter(15, colore = coloreValore), textAlign = TextAlign.End)
    }
}

/** Gruppo di righe su una scheda, con intestazione e nota facoltative. */
@Composable
fun Sezione(titolo: String? = null, nota: String? = null, contenuto: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(top = 8.dp)) {
        if (titolo != null) Box(Modifier.padding(start = 4.dp, bottom = 6.dp)) { EtichettaSezione(titolo) }
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Tema.superficie)) { contenuto() }
        if (nota != null) Text(nota, style = inter(13, colore = Tema.testo2), modifier = Modifier.padding(start = 4.dp, top = 6.dp))
    }
}

/** Pallino numerato delle istruzioni. */
@Composable
fun Numero(n: Int) {
    Box(Modifier.size(28.dp).clip(CircleShape).background(Tema.ambra), contentAlignment = Alignment.Center) {
        Text("$n", style = inter(15, FontWeight.Bold, Tema.suAmbra))
    }
}
