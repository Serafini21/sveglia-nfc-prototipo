package com.svegliatag.alba

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlbaApp : Application() {
    override fun onCreate() {
        super.onCreate()
        EventLog.init(this)
        val versione = packageManager.getPackageInfo(packageName, 0).longVersionCode
        EventLog.scrivi("Avvio app (build $versione)")
        Store.init(this)
        ServizioSveglia.creaCanali(this)
        Caratteri.init(this)
    }
}

/** La sveglia di sistema (setAlarmClock): all'inizio di una mattina e ogni minuto mentre è in corso. */
class AllarmeReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        Motore.riallinea(ctx, "sveglia di sistema")
    }
}

/** Accensione, aggiornamento dell'app, cambio di ora o fuso: Android cancella o sposta le sveglie, si riprogramma. */
class AvvioReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val motivo = intent.action?.substringAfterLast('.') ?: "avvio"
        val attesa = goAsync()
        Thread {
            try { Motore.riallinea(ctx, motivo) } finally { attesa.finish() }
        }.start()
    }
}
