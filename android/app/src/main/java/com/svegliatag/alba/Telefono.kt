package com.svegliatag.alba

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.nfc.NfcAdapter
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/**
 * Le impostazioni del telefono che servono perché la sveglia suoni sempre (pensate per il Galaxy S23).
 * Ogni controllo dice se è a posto e apre la pagina giusta delle Impostazioni di Android.
 */
object Telefono {
    data class Controllo(val titolo: String, val ok: Boolean, val spiegazione: String, val intent: Intent)

    fun controlli(ctx: Context): List<Controllo> {
        val pkg = Uri.parse("package:${ctx.packageName}")
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val am = ctx.getSystemService(AlarmManager::class.java)
        val pm = ctx.getSystemService(PowerManager::class.java)
        val notifiche = ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED &&
            nm.areNotificationsEnabled()
        val schermoIntero = Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()
        val nfc = NfcAdapter.getDefaultAdapter(ctx)
        return listOf(
            Controllo("Notifiche", notifiche, "Servono per mostrare la sveglia.",
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)),
            Controllo("Notifiche a schermo intero", schermoIntero, "Accendono lo schermo e mostrano la sveglia sopra il blocco.",
                if (Build.VERSION.SDK_INT >= 34) Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg)
                else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)),
            Controllo("Sveglie e promemoria", am.canScheduleExactAlarms(), "Fanno partire Alba all'orario esatto.",
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg)),
            Controllo("Batteria senza restrizioni", pm.isIgnoringBatteryOptimizations(ctx.packageName),
                "Così Samsung non addormenta Alba di notte.",
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg)),
            Controllo("NFC attivo", nfc?.isEnabled == true,
                if (nfc == null) "Questo telefono non ha l'NFC." else "Serve per leggere il tag.",
                Intent(Settings.ACTION_NFC_SETTINGS)),
        )
    }

    fun apri(ctx: Context, intent: Intent) {
        try {
            ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    fun dettagliApp(ctx: Context) =
        apri(ctx, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}")))
}

/** Ascolto delle suonerie nell'app (volume dei contenuti multimediali). */
object Anteprima {
    private var player: MediaPlayer? = null

    fun suona(ctx: Context, file: String) {
        ferma()
        try {
            val p = MediaPlayer()
            p.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            ctx.assets.openFd("suoni/$file").use { p.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            p.prepare()
            p.start()
            player = p
        } catch (e: Exception) {
            EventLog.scrivi("Anteprima: suono $file non disponibile ($e)")
            StatoUI.avvisa("Suono non disponibile in questa build")
        }
    }

    fun ferma() {
        player?.release()
        player = null
    }
}
