package com.svegliatag.alba

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import kotlin.math.pow

/**
 * La sveglia suonata dall'app (porting del Guardiano, senza il trucco dell'audio muto: su Android non serve).
 * Parte all'inizio della mattina: progressiva da -60 dB (se attiva), all'orario la suoneria al massimo,
 * da T + 5 min la sirena. Volume delle sveglie sempre al massimo, le altre app audio si fermano.
 * Ogni secondo rilegge i dati: quando la mattina non è più in corso (tag, Emergency, fine) si ferma.
 */
class ServizioSveglia : Service() {

    companion object {
        const val CANALE_RISVEGLIO = "risveglio"
        const val CANALE_SVEGLIA = "sveglia"
        private const val ID_SERVIZIO = 1
        private const val ID_SVEGLIA = 2
        const val EXTRA_SCHERMATA = "schermata"

        @Volatile var attivo = false
            private set

        fun avvia(ctx: Context) {
            try {
                ctx.startForegroundService(Intent(ctx, ServizioSveglia::class.java))
            } catch (e: Exception) {
                // da background Android può rifiutare: la sveglia di sistema tra 60 s riprova
                EventLog.scrivi("ERRORE avvio del suono: $e (riprovo con la prossima sveglia di sistema)")
            }
        }

        fun creaCanali(ctx: Context) {
            val nm = ctx.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(CANALE_RISVEGLIO, "Risveglio dolce", NotificationManager.IMPORTANCE_LOW).apply {
                description = "La progressiva prima dell'orario"
                setSound(null, null)
            })
            nm.createNotificationChannel(NotificationChannel(CANALE_SVEGLIA, "Sveglia", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "La sveglia all'orario, a tutto schermo"
                setSound(null, null) // il suono lo fa l'app
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            })
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var audio: AudioManager
    private var player: MediaPlayer? = null
    private var file: String? = null
    private var mattinaID: String? = null
    private var focus: AudioFocusRequest? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var svegliaMostrata = false
    private var ultimoMinuto = -1L

    private val attributi = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private val battito = object : Runnable {
        override fun run() {
            if (!attivo) return
            try { controlla() } catch (e: Exception) { EventLog.scrivi("ERRORE nel suono della sveglia: $e") }
            if (attivo) handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        audio = getSystemService(AudioManager::class.java)
        creaCanali(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(ID_SERVIZIO, notifica(CANALE_RISVEGLIO, "Alba", "Sveglia in corso", schermoIntero = false),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        if (!attivo) {
            attivo = true
            handler.post(battito)
        }
        // se il processo muore non ripartire da soli: ci pensa la sveglia di sistema tra 60 s
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        if (attivo) EventLog.scrivi("SUONO: servizio chiuso dal sistema durante la mattina")
        attivo = false
        handler.removeCallbacks(battito)
        rilascia()
        super.onDestroy()
    }

    private fun controlla() {
        val ora = adesso()
        val m = Store.leggi().mattine.filter { it.inCorso(ora) }.minByOrNull { it.inizio }
        if (m == null) {
            ferma()
            return
        }
        if (m.id != mattinaID) inizia(m, ora)

        val suono = when {
            ora >= m.inizioCatena -> SIRENA
            m.parametri.progressiva && ora < m.orario -> Store.leggi().impostazioni.suoneriaProgressiva.file
            else -> m.suoneria
        }
        if (suono != file) {
            prepara(suono)
            EventLog.scrivi("SUONO: ora suona $suono")
        }
        val db = Regole.dbProgressiva(ora, m.inizio, m.orario)
        val g = 10.0.pow(db / 20).toFloat()
        player?.setVolume(g, g)

        // all'orario: notifica a tutto schermo (accende lo schermo sopra il blocco)
        if (ora >= m.orario && !svegliaMostrata) {
            svegliaMostrata = true
            getSystemService(NotificationManager::class.java).notify(ID_SVEGLIA,
                notifica(CANALE_SVEGLIA, "Sveglia «${m.nome}»", "Sblocca il telefono e avvicinalo al tag", schermoIntero = true))
            EventLog.scrivi("SUONO: notifica a tutto schermo")
        }

        // volume delle sveglie sempre al massimo (tasti volume, Non disturbare, Modalità sonno)
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        val attuale = audio.getStreamVolume(AudioManager.STREAM_ALARM)
        if (attuale < max) {
            audio.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
            EventLog.scrivi("SUONO: volume sveglie $attuale/$max, rialzato al massimo")
        }

        val minuto = (ora - m.inizio) / MINUTO
        if (minuto != ultimoMinuto) {
            ultimoMinuto = minuto
            EventLog.scrivi("SUONO minuto $minuto: ${db.toInt()} dB, $suono")
        }
    }

    private fun inizia(m: Mattina, ora: Long) {
        mattinaID = m.id
        svegliaMostrata = false
        ultimoMinuto = -1
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "alba:sveglia")
            .apply { acquire(m.fine - ora + MINUTO) }
        // le altre app audio (Spotify, YouTube...) si fermano finché suona la sveglia
        focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT).setAudioAttributes(attributi).build()
            .also { audio.requestAudioFocus(it) }
        EventLog.scrivi("SUONO: SVEGLIA «${m.nome}» SUONA dall'app (ritardo ${(ora - m.inizio) / 1000} s, progressiva ${if (m.parametri.progressiva) "sì" else "no"})")
    }

    /** Il nuovo player parte prima di fermare il vecchio. Senza il file dell'app usa il suono di sveglia del telefono. */
    private fun prepara(suono: String) {
        val nuovo = MediaPlayer()
        try {
            nuovo.setAudioAttributes(attributi)
            assets.openFd("suoni/$suono").use { nuovo.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            nuovo.isLooping = true
            nuovo.prepare()
        } catch (e: Exception) {
            EventLog.scrivi("SUONO ERRORE con $suono: $e. Uso la suoneria di sveglia del telefono")
            try {
                nuovo.reset()
                nuovo.setAudioAttributes(attributi)
                nuovo.setDataSource(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                nuovo.isLooping = true
                nuovo.prepare()
            } catch (e2: Exception) {
                EventLog.scrivi("SUONO ERRORE anche con la suoneria del telefono: $e2")
                nuovo.release()
                return // riprova al prossimo secondo
            }
        }
        nuovo.setVolume(0f, 0f) // il volume giusto lo mette controlla()
        nuovo.start()
        player?.release()
        player = nuovo
        file = suono
    }

    private fun ferma() {
        EventLog.scrivi("SUONO FERMATO")
        attivo = false
        handler.removeCallbacks(battito)
        rilascia()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        // chiude la mattina se è finita senza tag e programma la prossima
        Thread { Motore.riallinea(applicationContext, "fine del suono") }.start()
    }

    private fun rilascia() {
        player?.release()
        player = null
        file = null
        mattinaID = null
        focus?.let { audio.abandonAudioFocusRequest(it) }
        focus = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        getSystemService(NotificationManager::class.java).cancel(ID_SVEGLIA)
    }

    private fun notifica(canale: String, titolo: String, testo: String, schermoIntero: Boolean): Notification {
        val apri = PendingIntent.getActivity(this, 1,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val emergenza = PendingIntent.getActivity(this, 2,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(EXTRA_SCHERMATA, "emergenza"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return Notification.Builder(this, canale)
            .setSmallIcon(R.drawable.ic_nfc)
            .setContentTitle(titolo)
            .setContentText(testo)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(apri)
            .addAction(Notification.Action.Builder(null, "Emergenza", emergenza).build())
            .apply { if (schermoIntero) setFullScreenIntent(apri, true) }
            .build()
    }
}
