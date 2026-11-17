# Sveglia NFC – prototipo tecnico

Prototipo **brutto di proposito** per verificare su iPhone (iOS 26) che:
AlarmKit suoni in modo affidabile, la catena anti-trucco funzioni, un tag NFC (via Comandi Rapidi) spenga tutto e i suoni personalizzati vengano riprodotti.

Cosa c'è nel repository:

| File | A cosa serve |
|---|---|
| `Sources/` | codice dell'app (SwiftUI) |
| `scripts/genera_suoni.py` | crea i 3 suoni (normale, punizione, test lungo 3 min) |
| `project.yml` | descrizione del progetto per XcodeGen (qui si cambia il **Bundle ID**) |
| `.github/workflows/build.yml` | compilazione automatica su GitHub |
| `TEST.md` | checklist dei test da fare sul telefono |

---

## 1. Compilare su GitHub e scaricare il file `.ipa`

La build parte **da sola** a ogni modifica del ramo `main`. Per avviarla a mano:

1. Apri il repository su github.com → scheda **Actions**.
2. A sinistra clicca **Build IPA** → a destra **Run workflow** → **Run workflow**.
3. Aspetta il pallino verde (circa 5-10 minuti).
4. Clicca sulla build completata → in fondo, sezione **Artifacts** → **SvegliaNFC-ipa**. Scarichi uno `.zip`.
5. Estrai lo zip: dentro c'è **`SvegliaNFC.ipa`**.

> Il repository è **pubblico**: per i repository pubblici i minuti macOS di GitHub Actions sono gratuiti e illimitati. Se un giorno lo rendi privato, il piano gratuito dà 2.000 minuti al mese, ma i minuti macOS valgono 10 volte tanto: restano circa 200 minuti macOS, cioè 20-40 build.

## 2. Installare su iPhone da Windows con Sideloadly (Apple ID gratuito)

### Una volta sola, sul PC
1. Installa **Apple Devices** dal Microsoft Store. In alternativa va bene **iTunes**, ma scaricato da apple.com e **non** dallo Store. Serve per i driver che fanno riconoscere l'iPhone.
2. Installa **Sideloadly** da sideloadly.io.
3. Collega l'iPhone con il cavo, sbloccalo e tocca **Autorizza** su "Autorizzare questo computer?".

### Una volta sola, sull'iPhone: Modalità sviluppatore
1. Prova a installare l'app una prima volta (passo successivo). Solo dopo il primo tentativo compare la voce.
2. **Impostazioni → Privacy e sicurezza → Modalità sviluppatore** → attiva → **Riavvia**.
3. Dopo il riavvio conferma con **Attiva** e inserisci il codice.

### Installazione
1. Apri Sideloadly e trascina `SvegliaNFC.ipa` nella finestra.
2. In **Apple account** scrivi il tuo Apple ID e premi **Start**. Inserisci password e codice a due fattori nella finestra di Sideloadly.
   - Consiglio: usa un Apple ID secondario se non vuoi dare la password del tuo principale a un programma di terze parti.
   - Se Sideloadly dice che il Bundle ID è già in uso, cambia `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` (es. `com.tuonome.svegliatag`), oppure lascia che Sideloadly lo cambi dalle opzioni avanzate.
3. Sull'iPhone: **Impostazioni → Generali → VPN e gestione dispositivi** → sotto "App sviluppatore" tocca il tuo Apple ID → **Autorizza**.
4. Apri **Sveglia NFC**, tocca **Chiedi autorizzazione** e consenti le sveglie.

### Scadenza dopo 7 giorni
Con un Apple ID gratuito l'app **smette di aprirsi dopo 7 giorni**. Per rinnovarla ricollega l'iPhone e ripeti l'installazione con Sideloadly, usando lo stesso `.ipa` e lo stesso Apple ID. Se usi lo stesso Bundle ID, i dati e il log restano.
Limiti dell'Apple ID gratuito: al massimo 3 app installate così e 10 nuovi Bundle ID a settimana.

## 3. Automazione NFC in Comandi Rapidi

1. Apri **Comandi Rapidi** → scheda **Automazione** → **+** (o "Nuova automazione").
2. Scegli **NFC** → **Scansiona** → avvicina il tag → dagli un nome (es. `bagno`).
3. Seleziona **Esegui immediatamente** e disattiva "Notifica quando eseguito" se vuoi.
4. **Avanti** → **Nuovo comando rapido vuoto** → **Aggiungi azione** → cerca **Sveglia NFC** → **Spegni sveglia**.
5. Facoltativo: tocca "Nome tag" e scrivi `bagno`, così nel log vedi quale tag è stato usato.
6. **Fine**.

## 4. Provare l'azione a mano (senza tag)

- Nell'app c'è il pulsante **Simula tag**, che esegue esattamente la stessa logica.
- Per provare il percorso reale di Comandi Rapidi: **Comandi Rapidi → Comandi Rapidi** (scheda principale). Nella sezione delle app trovi **Sveglia NFC → Spegni sveglia**. Toccalo: deve comparire "Sveglia spenta, N sveglie cancellate", senza aprire l'app.
- In alternativa, dì a Siri "Spegni sveglia con Sveglia NFC".

Dopo ogni prova apri la scheda **Log** dell'app e usa **Condividi log** per mandarmi il testo.

---

## Note tecniche e limiti scoperti

- **Nessuna capability a pagamento**: AlarmKit richiede solo `NSAlarmKitUsageDescription` in Info.plist. Non c'è Core NFC: il tag lo legge iOS tramite l'automazione.
- **Catena**: tutte le sveglie (principale + riserve ogni 30 s per 30 min = 61) vengono programmate **subito**. Se premi "Stop" sulla sveglia, la successiva è già in coda e non viene riprogrammata niente. Dalla 5ª in poi suona la sirena "punizione".
- **Limite di sveglie**: AlarmKit ha un errore `maximumLimitReached`, ma Apple **non documenta il numero**. Se succede, l'app scrive nel log "LIMITE AlarmKit raggiunto dopo N sveglie" e riprogramma la stessa durata con un intervallo più lungo.
- **Stop senza tag**: ogni sveglia ha uno `stopIntent` che viene eseguito quando premi Stop. Registra l'evento e il contatore. La documentazione non dice se i tasti fisici lo attivano: va verificato con il test.
- **Pulsante Stop**: da iOS 26.1 il pulsante Stop lo disegna il sistema. Con target iOS 26.0 il codice usa il vecchio init, che è deprecato ma funziona.
- **Suoni**: WAV PCM 22 kHz. Normale e punizione durano 25 s, il test lungo 3 min. Apple **non documenta** la durata massima né se un suono breve viene ripetuto in loop: lo dice il test "suono lungo" (vedi TEST.md). Il suono si sceglie **per singola sveglia**, quindi cambiarlo lungo la catena funziona per costruzione. Dentro una stessa sveglia non si può cambiare.
- **Niente estensioni**: niente widget né Live Activity. Apple le richiede solo per le sveglie con countdown, che qui non usiamo.

## Rigenerare il progetto (solo se hai un Mac, facoltativo)
```bash
python3 scripts/genera_suoni.py Sounds && xcodegen generate && open SvegliaNFC.xcodeproj
```
