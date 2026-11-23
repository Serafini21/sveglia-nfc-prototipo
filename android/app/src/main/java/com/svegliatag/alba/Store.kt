package com.svegliatag.alba

import android.content.Context
import android.util.AtomicFile
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Unico punto di accesso ai dati: un file JSON in filesDir, scritto in modo atomico.
 * Le modifiche alle mattine passano dal Motore (che le serializza); l'interfaccia osserva `dati`.
 */
object Store {
    private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true; prettyPrint = true }
    private lateinit var file: AtomicFile
    private val stato = MutableStateFlow(DatiAlba())
    val dati: StateFlow<DatiAlba> = stato

    @Synchronized
    fun init(ctx: Context) {
        if (::file.isInitialized) return
        file = AtomicFile(File(ctx.filesDir, "alba.json"))
        stato.value = carica(ctx)
    }

    fun leggi(): DatiAlba = stato.value

    @Synchronized
    fun modifica(cambia: (DatiAlba) -> DatiAlba) {
        val nuovi = cambia(stato.value)
        salva(nuovi)
        stato.value = nuovi
    }

    private fun salva(d: DatiAlba) {
        val out = try { file.startWrite() } catch (e: Exception) {
            EventLog.scrivi("ERRORE salvataggio dati: $e"); return
        }
        try {
            out.write(json.encodeToString(DatiAlba.serializer(), d).toByteArray())
            file.finishWrite(out)
        } catch (e: Exception) {
            file.failWrite(out)
            EventLog.scrivi("ERRORE salvataggio dati: $e")
        }
    }

    /**
     * Legge il file. Se manca parte da zero; se è illeggibile o di una versione futura lo mette da parte
     * (alba-illeggibile-<data>.json) invece di sovrascriverlo, così i dati non vanno persi.
     */
    private fun carica(ctx: Context): DatiAlba {
        if (!file.baseFile.exists()) {
            EventLog.scrivi("Dati: nessun file, primo avvio")
            return DatiAlba().also { salva(it) }
        }
        return try {
            val d = json.decodeFromString(DatiAlba.serializer(), String(file.readFully()))
            require(d.schemaVersion <= DatiAlba.VERSIONE) { "schemaVersion ${d.schemaVersion} più recente dell'app" }
            d
        } catch (e: Exception) {
            val copia = File(ctx.filesDir, "alba-illeggibile-${adesso() / 1000}.json")
            runCatching { file.baseFile.copyTo(copia, overwrite = true) }
            EventLog.scrivi("ERRORE lettura dati ($e). Copia salvata in ${copia.name}, riparto da zero")
            DatiAlba()
        }
    }
}

/** Log diagnostico in testo (filesDir/alba-log.txt), data con millisecondi, rotazione a ~500 KB. */
object EventLog {
    private const val MAX_BYTE = 500_000L
    private var file: File? = null
    private var precedente: File? = null
    private val formato = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS")

    @Synchronized
    fun init(ctx: Context) {
        file = File(ctx.filesDir, "alba-log.txt")
        precedente = File(ctx.filesDir, "alba-log.1.txt")
    }

    fun data(t: Long): String = formato.format(Instant.ofEpochMilli(t).atZone(ZoneId.systemDefault()))

    @Synchronized
    fun scrivi(testo: String) {
        val f = file ?: return
        val p = precedente ?: return
        try {
            if (f.length() > MAX_BYTE) {
                p.delete()
                f.renameTo(p)
            }
            f.appendText("${data(adesso())} $testo\n")
        } catch (_: Exception) {
            // il log non deve mai far cadere l'app
        }
    }

    /** Log completo: prima il file ruotato, poi quello attuale. */
    @Synchronized
    fun leggi(): String {
        val p = precedente ?: return ""
        val f = file ?: return ""
        return (if (p.exists()) p.readText() else "") + (if (f.exists()) f.readText() else "")
    }

    /** Copia del log completo da condividere (cartella cache, esposta dal FileProvider). */
    fun fileDaCondividere(ctx: Context): File {
        val dest = File(ctx.cacheDir, "condivisi/Alba-log.txt")
        dest.parentFile?.mkdirs()
        dest.writeText(leggi())
        return dest
    }
}
