# PROGETTO – App "Alba" (sveglia con tag NFC)

Documento di riferimento per lo sviluppo. Raccoglie tutte le decisioni prese su funzioni, regole e soluzioni tecniche. Le soluzioni tecniche sono state verificate con il prototipo (vedi `REPORT_PROTOTIPO.md`).
"Alba" è un nome provvisorio.

---

## 1. Cos'è

È un'app sveglia per iPhone ispirata a "Bright". La sveglia si spegne **solo** avvicinando il telefono a un tag NFC lontano dal letto, quindi bisogna alzarsi. È per uso personale e familiare, senza App Store.

## 2. Vincoli tecnici (non negoziabili)

- **Dispositivo:** iPhone 14 Pro con iOS 26.6.2. **Target minimo: iOS 26.1.**
- **Niente Mac**: lo sviluppatore usa solo Windows. Il progetto si genera con **XcodeGen** (`project.yml`) e si compila su **GitHub Actions** (runner macOS, Xcode 26, build senza firma, `.ipa` come artifact). Al workflow va aggiunto `paths-ignore: ['**.md']`.
- **Apple ID gratuito (Personal Team)**, installazione con **Sideloadly**:
  - nessuna capability a pagamento: niente Core NFC, App Groups, Push, iCloud, Family Controls;
  - **un solo target, nessuna estensione**, quindi niente widget e niente Live Activity con un proprio target;
  - l'app **scade dopo 7 giorni** se non viene reinstallata;
  - massimo 10 App ID nuovi a settimana.
- **Bundle ID definitivo:** `com.svegliatag.alba`. Non va mai più cambiato, perché cambiarlo cancella tutti i dati e consuma un App ID. **Nome visualizzato:** "Alba".
- **Linguaggio:** Swift in **modalità 5**, SwiftUI, AlarmKit, App Intents, CoreLocation, UserNotifications. Nessuna dipendenza esterna.
- **Lettura del tag:** la fa iOS tramite un'**automazione NFC di Comandi Rapidi**, che esegue l'App Intent "Spegni sveglia" dell'app.
- **Tutto offline**: nessun account, nessun server, nessun analytics.

## 3. Comportamenti di iOS verificati dal prototipo (da rispettare nel codice)

1. Le sveglie AlarmKit suonano ad app chiusa, a telefono bloccato, in silenzioso e dopo un riavvio. Non richiedono capability: bastano `NSAlarmKitUsageDescription` e l'autorizzazione dell'utente.
2. Una sveglia non fermata **non si spegne mai da sola** e resta `.alerting`. Le sveglie successive la **coprono** ma non la fermano, quindi si accumulano. **Qualsiasi punto del codice che ferma una sveglia deve fermare TUTTE quelle `.alerting`.**
3. Regola stop o cancel: `stop(id:)` su una sveglia `.alerting` la rimuove già, quindi per quelle si usa `stop`; per tutte le altre si usa `cancel`.
4. Lo `stopIntent` (`LiveActivityIntent`) viene chiamato con il pulsante Stop di sistema e con il tasto laterale, anche ad app chiusa (iOS avvia l'app in background). **Non** viene chiamato quando la sveglia viene fermata dal nostro codice.
5. **I tasti volume** zittiscono la sveglia senza fermarla e senza chiamare lo `stopIntent`, e tutte le sveglie successive della catena suonano **mute**. È un bug di iOS (FB22686646) e non si può impedire, si può solo rilevare dopo (§6.8).
6. **Mentre la sveglia suona Face ID non sblocca**, e l'automazione NFC parte solo a telefono sbloccato. La sequenza reale al mattino è quindi: Stop, sblocco, tag.
7. Fino a 61 sveglie `.fixed` si programmano insieme in meno di un secondo e senza errori. Il limite reale non è noto (`maximumLimitReached` va gestito).
8. Suoni: WAV PCM nel bundle principale, impostati per singola sveglia (`.named`). Un file da 3 minuti suona intero e poi va in loop. Una crescita di volume **dentro** il file non si percepisce.
9. L'App Intent gira nel processo dell'app ed è eseguibile senza aprirla. Può essere lanciata anche **a mano**, senza tag, da Comandi Rapidi o da Siri.
10. **Laboratorio (20 novembre 2026, dettagli in `prototipo/PORTING_ALBA.md`)**: senza audio in riproduzione iOS sospende l'app pochi secondi dopo che la lasci. Con un audio a volume zero in loop (`UIBackgroundModes = audio`, nessuna capability a pagamento) l'app resta viva a schermo bloccato e suona puntuale. Mentre suona dall'app, i tasti volume si vedono e il volume di sistema si può rialzare (`MPVolumeView`). Apple Music si mette in pausa, Spotify e YouTube no. **Mai disattivare la sessione audio prima della sveglia**: da background non si riattiva.

## 4. Architettura

- **`Store`** (attore): un unico file **JSON `Codable` versionato** in Application Support. Contiene impostazioni, sveglie, tag, mattine e storico, crediti Emergency ed eventi. Tutti gli accessi passano da qui, in modo serializzato, perché intent e UI possono girare insieme. `App.init` deve essere leggero.
- **`EventLog`**: log diagnostico in testo, con data completa e millisecondi, rotazione ed esportazione. Resta anche nell'app finale.
- **`AlarmEngine`**: l'**unico** punto che parla con `AlarmManager`.
  - Pianifica le "mattine" e salva la mappa *UUID sveglia AlarmKit → (mattina, fase, indice, orario, suono)*.
  - Offre `fermaTutteInCorso()`, `cancellaMattina()`, `cancellaTutto()` e `riallinea()`.
  - `riallinea()` confronta le sveglie attese con `AlarmManager.alarms` e corregge le differenze. Va eseguito all'avvio, a ogni intent e su `significantTimeChangeNotification`.
  - Mantiene programmate **almeno le prossime 2 mattine**.
- **`Regole`**: logica pura e testabile. Valutazione della mattina, punteggio, streak, blocco delle modifiche, crediti Emergency, rilevamento dei trucchi.
- **Intents**:
  - `SpegniConTagIntent`, con parametri *nome tag* e *codice segreto*;
  - `StopSenzaTagIntent`, cioè lo `stopIntent`;
  - `EmergenzaIntent`, il pulsante secondario della sveglia che apre l'app sulla schermata Emergency.
- **`Posizione`**: posizione letta solo con l'app aperta (permesso «Mentre usi l'app») per salvare la casa e, nell'Emergency Stop, per sapere se sei fuori casa. Niente geofence né posizione in background (scelta del 23 novembre 2026).
- **`Scadenza`**: legge `ExpirationDate` da `embedded.mobileprovision` e programma le notifiche locali di promemoria.
- **`Guardiano`**: dopo «Vado a letto» tiene l'app viva in background fino alla sveglia e la suona dall'app (§5). È guidato dalle mattine dello Store e da un timer di 1 s; «Vado a letto» resta salvato, quindi alla riapertura dell'app riparte da solo. Se l'app è stata chiusa o sospesa lo segnala alla riapertura, e una notifica "a uomo morto" avvisa entro 20 minuti. `PromemoriaLetto`: una notifica **9 ore prima** di ogni sveglia ricorda di premere «Vado a letto» (non arriva se è già stato premuto).
- **Modalità sviluppatore nascosta** (5 tocchi sul titolo della Home): catena breve, simula tag, log completo con condivisione, pulsanti di test.

## 5. Struttura di una "mattina"

Ogni occorrenza di una sveglia è una **mattina** (schema deciso col Laboratorio, `prototipo/PORTING_ALBA.md`):

1. **Sera**: 9 ore prima della sveglia arriva il promemoria. Con il pulsante **«Vado a letto»** (nella scheda della prossima sveglia; lo premono da sole anche "Vado a dormire ora" e la mattina di test) il **guardiano** tiene Alba viva in background fino alla sveglia, con la suoneria in loop a volume zero. Solo di notte, per non consumare batteria di giorno. «Vado a letto» finisce quando si chiude la sveglia (tag, anticipo, Emergency o fallita).
2. **Progressiva** (solo se l'interruttore è attivo): da T−15 min **l'app** suona il **suono della progressiva** (uno per tutte le sveglie, scelto nella schermata «Sveglia progressiva» che si apre toccandone il titolo in Home). Per **10 minuti sale piano da −60 a −40 dB** (2 dB al minuto), poi negli **ultimi 5 minuti sempre più forte fino a 0 dB** all'orario T, quando passa alla suoneria della sveglia. Con la salita lineare in 15 minuti (−40 dB già al minuto 5) l'utente si svegliava troppo presto. Senza progressiva suona subito al massimo all'orario T.
3. Quando l'app inizia a suonare porta il volume di sistema al 100%, rialza subito il volume se premi i tasti volume e mette in pausa Apple Music, che riparte dopo il tag.
4. **Catena AlarmKit di sicurezza**, programmata la sera insieme alla mattina: da **T+5 min** una sveglia ogni **30 s** per **30 min**, tutte con la **sirena di punizione** ("PUNIZIONE – usa il tag!"). Non compare nell'interfaccia, se non come "Sirena alle …".
5. Passati i 30 minuti di sirena senza tag né Emergency, la mattina è **fallita**.

- Il **tag** ferma il suono dell'app e cancella tutta la catena AlarmKit.
- Se l'app è viva ma nessuno usa il tag entro +5 min, suonano **entrambe**, app e sirena: è voluto. Lo Stop di AlarmKit ferma solo la sirena; la catena resta programmata e risuona alla sveglia successiva.
- Se l'app è stata chiusa (multitasking, riavvio) o non hai premuto «Vado a letto», niente progressiva: suona solo la catena da +5 min. È un compromesso accettato.
- Uscita Bluetooth: il suono dell'app esce dalla cassa o dalle cuffie collegate (la catena AlarmKit dall'altoparlante). Non è risolto: la Home lo segnala.

## 6. Funzionalità e regole

### 6.1 Sveglie
- **Sveglie multiple**: orario, giorni della settimana e nome. Si possono attivare e disattivare.
- **Sveglie una tantum**, create da "Vado a dormire ora": suonano una volta, poi spariscono.
- **Scorrendo** una sveglia nella lista: verso sinistra si elimina, verso destra si copia.
- **Suonerie**: libreria di suoni dell'app (dolci, normali, energici) più la suoneria punizione (sirena, diversa dall'IT-alert). Le suonerie di sistema di iOS non sono disponibili. In futuro, forse, importazione di file audio dell'utente (da verificare).
- **Niente snooze.**
- **Sveglia progressiva di 15 minuti**: un **interruttore unico nella Home**, nella scheda della prossima sveglia. Vale per tutte le sveglie e **ricorda l'ultima scelta**. Compare, già impostato, anche in "Vado a dormire ora".
- Suona anche in silenzioso e ad app chiusa (comportamento nativo di AlarmKit).

### 6.2 "Vado a dormire ora"
- Un pulsante grande nella Home. Premendolo l'app propone gli orari a cicli completi: **adesso + 15 min per addormentarsi + k × 90 min**, con k = 3, 4, 5 e 6. Con k = 5 compare "Consigliato".
- Si sceglie un orario e lo si ritocca con **±1 minuto**. La sveglia è una tantum e segue tutte le regole.

### 6.3 Spegnimento con il tag
- Vale **qualsiasi tag registrato**. Nell'app c'è la lista dei tag, ognuno con nome e ultima scansione.
- **Associazione guidata**: dai un nome al tag e l'app ti guida passo passo a creare l'automazione in Comandi Rapidi: Automazione → NFC → scansione del tag → "Esegui immediatamente" → azione "Spegni sveglia" con *nome tag* e *codice segreto*. Infine si fa una prova.
- **Codice segreto**: generato dall'app una volta sola e mostrato nella guida. Un intent senza il codice giusto viene **rifiutato** e registrato come tentativo sospetto.
- L'intent è accettato solo se c'è una sveglia in corso oppure se si è nelle **2 ore prima** di una mattina (spegnimento anticipato).
- **Tolleranza**: uno Stop seguito dal tag entro **60 s** non è un errore. Non conta come stop senza tag nel punteggio e nelle statistiche, perché a telefono bloccato è l'unica sequenza possibile.
- Dopo il tag compare un riscontro chiaro ("Sveglia spenta") e si apre la schermata "Risveglio riuscito" quando apri l'app.

### 6.4 Spegnimento anticipato
- Se scansioni il tag nelle **2 ore prima** di una mattina, quella mattina viene annullata, fase progressiva compresa.
- Nello storico risulta come "annullata in anticipo" e conta come riuscita.

### 6.5 Blocco delle modifiche
- Nelle **2 ore prima** di una mattina, per modificare, disattivare o eliminare quella sveglia serve il tag. In alternativa si usa l'Emergency Stop.
- Nessun pulsante "Cancella tutte" nell'app normale.

### 6.6 Emergency Stop
- Spegne senza tag. Si usa **tenendo premuto un pulsante per 10 secondi** e **scrivendo la frase** "Sono sveglio e mi alzo".
- **Crediti:** al massimo **1** (prima erano 2). Alla prima installazione ne hai **1**. Dopo averlo usato si ricarica in **7 giorni**.
- Usarlo **azzera lo streak**.
- **Accesso:** dall'app (schermata "Sveglia in corso") oppure dal **pulsante secondario "Emergenza"** sulla sveglia (`secondaryIntent`), che apre l'app direttamente su quella schermata. Il pulsante va verificato con un test.
- **Protezione contro il cambio di data**: si salva l'ultima data vista. Se l'orologio torna indietro, la ricarica non avviene e l'evento viene registrato.

### 6.7 Posizione di casa
- Si registra **una sola posizione** (Impostazioni › Posizione di casa, dalla posizione attuale), con un raggio di **150 m**. Basta il permesso «Mentre usi l'app»: la posizione si legge solo quando apri l'Emergency Stop. Si è fuori casa solo se è certo, cioè oltre 150 m anche togliendo l'incertezza del GPS.
- **Ogni modifica della posizione entra in vigore dopo 12 ore.**
- **A casa**: si applicano le regole normali.
- **Fuori casa**: la sveglia e la catena suonano normalmente. Si spegne con la **procedura Emergency** (10 s + frase), **senza consumare crediti**. Lo streak resta in pausa e nello storico la mattina risulta "fuori casa".
- **Posizione sconosciuta** (permesso tolto o localizzazione spenta): si applicano le **regole di casa**.

### 6.8 Rilevamento dei trucchi
- **Tasti volume**: mentre suona l'app vengono annullati (il volume torna subito al 100%). Sulla catena AlarmKit invece funzionano ancora: se al momento del tag, all'apertura dell'app o al `riallinea()` ci sono sveglie `.alerting` più vecchie di 2 minuti, la mattina è **"fallita – volume"** e lo streak si azzera.
- La schermata "Sveglia in corso" mostra: "Non premere i tasti volume".
- **Intent senza codice**: viene rifiutato e registrato.
- **Cambio di data o ora**: viene registrato. Si applica la protezione dei crediti.
- **Permesso Sveglie revocato o sveglie mancanti**: compare un avviso evidente nella Home e l'evento viene registrato.

### 6.9 Modalità senza tag
- Si attiva dalle Impostazioni, in caso di tag perso o rotto. **Entra in vigore dopo 24 ore.**
- Quando è attiva, la sveglia si spegne con la procedura Emergency senza consumare crediti, come fuori casa.

### 6.10 Statistiche
- **Mattine riuscite**: conteggio delle mattine chiuse col tag o annullate in anticipo.
- **Streak**: giorni consecutivi di risveglio riuscito.
  - Si azzera con Emergency Stop, mattina fallita o fallita – volume.
  - Resta **in pausa** per le mattine fuori casa e in modalità senza tag.
- **Time-to-scan**: tempo tra l'orario T e il tag.
- **Punteggio giornaliero** (0–100):
  - si parte da 100;
  - −10 per ogni stop senza tag non coperto dalla tolleranza;
  - −1 ogni 15 s oltre il primo minuto di time-to-scan, fino a un massimo di −40;
  - Emergency = 20, fallita = 0, fuori casa = non conteggiata.
  - I valori vanno tenuti in costanti, facili da modificare.
- **Storico**: per ogni mattina, orario previsto, orario di spegnimento, stop ed esito. Esiti possibili: tag, annullata in anticipo, Emergency, fuori casa, fallita, fallita – volume.

### 6.11 Dopo il risveglio
- **Schermata "Risveglio riuscito"**: time-to-scan, punteggio, streak.
- **Routine mattutina**: una checklist modificabile dall'utente.

### 6.12 Scadenza dell'app (Personal Team)
- Nelle Impostazioni compare "L'app scade tra X giorni". Negli ultimi 2 giorni c'è un avviso anche nella Home.
- **Notifiche locali di promemoria** 2 giorni prima e il giorno prima della scadenza. Le notifiche locali non richiedono capability.

### 6.13 Backup
- **Esporta e importa** il JSON dello Store con `fileExporter`/`ShareLink` e `fileImporter`. Niente iCloud.

### 6.14 Futuro (non ora)
- Sveglia intelligente tipo Sleep Cycle, con rilevamento del sonno leggero dal microfono.

## 7. Grafica (stile "Alba", approvato)

Il mockup approvato è sul canvas di design. Le schermate esportate verranno fornite per la Fase 2. Le schermate sono:
- **Home – Sveglie**: prossima sveglia con interruttore della progressiva, pulsante "Vado a dormire ora", lista delle sveglie;
- **Vado a dormire ora**;
- **Modifica sveglia**;
- **I miei tag**, con la guida;
- **Sveglia in corso**;
- **Emergency Stop**;
- **Risveglio riuscito**;
- **Statistiche**;
- **Impostazioni**.

**Barra in basso:** Sveglie · Statistiche · Tag · Impostazioni. L'icona delle Impostazioni è un **ingranaggio**.

**Colori:**

| Ruolo | Colore |
|---|---|
| Sfondo | `#0B1020` |
| Superficie | `#151B2E` |
| Superficie 2 / pulsanti secondari | `#1E2640` |
| Bordi e divisori | `#232B45` |
| Testo | `#F2F4F8` |
| Testo secondario | `#9AA3B8` |
| Accento ambra | `#FFB547`, testo sopra `#1A1206` |
| Fondo ambra tenue | `#2A2418` |
| Pericolo / Emergency | `#FF8A7A` |
| Successo | `#7FE0B4` su `#17302A` |
| Schermate del mattino (sveglia in corso, Emergency) | sfondo caldo `#160F0A`, superfici `#24180F` |

**Font:** Space Grotesk per orari e titoli, Inter per il testo (licenza OFL, da includere nel bundle).
**Forme:** angoli arrotondati da 14 a 22 px, interruttori ambra, touch target ≥ 44 pt.

## 8. Fasi di sviluppo

1. **Fase 1 – Il cuore**: Store, EventLog, AlarmEngine, mattine con catena e sirena, tag con codice segreto, Stop/tag/tolleranza, blocco delle modifiche, Emergency base con crediti, rilevamento dei trucchi, scadenza con promemoria, storico base. UI essenziale ma già nei colori Alba. **Più i test mancanti** (notte vera, Full immersion, scadenza, più di 61 sveglie, pulsante secondario, mini-test della progressiva).
2. **Fase 2 – Esperienza completa**: tutta la grafica del mockup, "Vado a dormire ora", sveglia progressiva, suonerie vere, statistiche, streak, punteggio, routine, schermata di risveglio.
3. **Fase 3 – Contorno**: posizione di casa (fatta nella build 11), modalità senza tag, backup, rifiniture.
