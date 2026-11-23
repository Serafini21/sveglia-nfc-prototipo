# Report tecnico – prototipo "Sveglia NFC"

Dispositivo di prova: **iPhone 14 Pro, iOS 26.6.2**. Test svolti il 17 e 18 novembre 2026.
Repository: https://github.com/Serafini21/sveglia-nfc-prototipo (pubblico, ramo `main`, commit del codice `83fa65c`).
Fonti di questo report: la checklist `TEST.md`, le tue note dopo ogni giro, il log dell'app (135 righe, riportato per intero nell'Appendice B), i log di GitHub Actions e la ricerca sulla documentazione Apple (Appendice A).

## Sintesi

| Ipotesi del prototipo | Esito |
|---|---|
| 1. Compilazione nel cloud e installazione da Windows con Apple ID gratuito | ✅ funziona, nessuna capability necessaria |
| 2. Sveglia affidabile: app chiusa, telefono bloccato, silenzioso, dopo un riavvio | ✅ (non provati: Non disturbare, risparmio energetico, una notte intera) |
| 3. Catena anti-trucco già programmata, con la sirena dalla 5ª | ✅ con lo Stop e il tasto laterale · ❌ con i **tasti volume** (bug di iOS) |
| 4. App Intent "Spegni sveglia" da Comandi Rapidi o automazione NFC | ✅ senza aprire l'app · ⚠️ il tag funziona solo a telefono **sbloccato** |
| 5. Suoni personalizzati: durata e cambio lungo la catena | ✅ un file da 3 min suona intero e poi va in loop · ✅ un suono diverso per ogni sveglia |

Le tre scoperte più importanti per l'app finale:
1. **Le sveglie non fermate si accumulano.** AlarmKit non spegne mai da sola una sveglia: quella nuova copre la vecchia, che resta "in corso". Il codice deve fermarle tutte a ogni Stop.
2. **I tasti volume zittiscono senza fermare.** Non parte lo `stopIntent` e tutte le sveglie successive della catena scattano mute, sirena compresa. È contrario alla FAQ ufficiale di Apple ed è segnalato come bug (FB22686646). Non si può aggirare con AlarmKit, ma si può rilevare dopo.
3. **Mentre la sveglia suona Face ID non sblocca il telefono**, e l'automazione NFC parte solo a telefono sbloccato. Quindi chi si sveglia col telefono bloccato deve prima premere Stop, poi sbloccare, poi usare il tag.

---

## 1. Risultati dei test

Risoluzione del log: 1 secondo. Nel log vengono registrati gli **stop** e gli **spegnimenti**, non l'istante in cui la sveglia inizia a suonare: i tempi "dopo X s" sono misurati rispetto all'orario programmato.

| # | Test | Esito | Note (tue osservazioni incrociate con il log) |
|---|---|---|---|
| 1 | Installazione | OK | Primo avvio 17/11 16:18:37, autorizzazione AlarmKit concessa alle 16:18:53. Sideloadly senza problemi. Nessuna capability richiesta. |
| 2 | Sveglia ad app chiusa, telefono bloccato, silenzioso | OK | Il log lo conferma in modo indipendente. Alle 16:23:52 compaiono nello stesso secondo "Avvio app" e "STOP SENZA TAG n. 1": l'app era chiusa e iOS l'ha avviata in background per eseguire lo `stopIntent`. La sveglia era delle 16:23:40. Stessa cosa alle 16:46:06, con la sveglia delle 16:46:00. |
| 3 | Stop dal pulsante di sistema, poi risuona dopo 30 s | OK | Catena delle 16:28:13: stop alle 16:28:16, 16:28:47, 16:29:17, 16:29:46 e 16:30:18. Ogni sveglia è stata fermata 3-5 s dopo l'orario programmato, quindi l'intervallo di 30 s è rispettato. |
| 4 | Stop con i tasti fisici | PARZIALE | **Tasto laterale: OK**, si comporta come Stop e lo `stopIntent` parte. **Volume: NO**, la sveglia si zittisce ma resta "in corso" e lo `stopIntent` non parte. Nel log della catena delle 16:57:50 il primo stop arriva solo alle 16:59:31, 101 s dopo. Poi gli stop arrivano nell'ordine n. 5, 6, 2: sveglie accumulate (vedi test 11). |
| 5 | Sirena "punizione" dalla 5ª | OK | L'hai sentita ("la 5 di punizione ha già suonato"). STOP sulla n. 5 alle 16:30:18. |
| 6 | Simula tag | OK | Ferma e cancella sempre tutto, per esempio 59 sveglie alle 16:24:45. Gli "Errore cancellazione Code=0" sono innocui, sono 25 in tutto il log e sono stati corretti nel giro 2 (vedi più sotto). Dalle 16:21:37 alle 16:21:46 ci sono 8 "Simula tag" in 9 secondi senza sveglie: tocchi ripetuti, senza conseguenze. |
| 7 | Azione di Comandi Rapidi eseguita a mano | OK (dal log) | Non me l'hai segnalato esplicitamente, ma il log lo prova. Il 18/11 alle 02:34:35 e alle 02:36:06 compare `SPEGNIMENTO COL TAG "-"`: il trattino vuol dire "parametro vuoto" e può arrivare solo dall'App Intent lanciata da Comandi Rapidi, perché "Simula tag" passa sempre il testo del campo. Entrambe le volte ha fermato una catena che stava suonando, cancellando 7 sveglie. |
| 8a | Tag vero, telefono sbloccato | (vedi 16) | Nel giro 1 avevi solo la **carta d'identità**: Comandi Rapidi la legge, ma l'automazione non parte mai. Quasi certamente la carta presenta un identificativo diverso a ogni lettura, per privacy. Non è utilizzabile come tag. |
| 8b | Tag vero, telefono bloccato | (vedi 16) | — |
| 9 | Dopo un riavvio | OK (da tua osservazione) | **Nel log non c'è traccia di questo test**: il log che mi hai mandato finisce il 18/11 alle 14:34:55 e non contiene una sequenza riconducibile al riavvio. L'esito si basa solo su quello che hai visto tu. |
| 10 | Suono lungo | non fatto nel giro 1 | Rifatto come test 17. |
| 11 | Sveglia non fermata | OK (comportamento capito) | **Il log contraddice la tua impressione.** Ti sembrava che ogni sveglia suonasse 30 s e poi si spegnesse da sola. In realtà venivano solo coperte dalla successiva. Catena delle 16:51:05: alle 16:55:17 hai fermato la n. 7, e alle 16:55:26 lo spegnimento col tag dà 6 errori Code=0, cioè **6 sveglie erano ancora "in corso"** sotto. Hai scritto che l'ultima ha suonato per circa 2 minuti: dal log risulta circa 72 s (n. 7 programmata alle 16:54:05, fermata alle 16:55:17). |
| 12 | Limite di sveglie | OK | "Catena programmata: 61 sveglie", nessun "LIMITE". Programmare 61 sveglie richiede meno di 1 secondo: alle 16:22:31 la cancellazione e la nuova programmazione stanno nello stesso secondo. Accettate anche catene con intervallo di 10 s (19 sveglie). |
| 13 | Stop con sveglie accumulate (dopo la correzione) | OK | 18/11 alle 14:16:31: "STOP SENZA TAG n. 4 … fermate anche 3 sovrapposte". La n. 5 è arrivata regolarmente (stop alle 14:17:09). La correzione funziona. |
| 14 | Tasto laterale | OK | Probabilmente corrisponde alle 14:18:02: due "STOP SENZA TAG" nello stesso secondo, n. 6 e n. 7, entrambi con "0 sovrapposte". Una sola pressione ha fermato tutte e due le sveglie in corso e iOS ha chiamato lo `stopIntent` di **ciascuna**, come dice la FAQ Apple (Q8). |
| 15 | Buco del volume | NO | Catena delle 14:19:15. Alle 14:22:24 lo spegnimento col tag riporta "**sveglie in corso: 7**": tutte e 7 sono scattate mute, nessuno `stopIntent` è partito e la sirena delle sveglie 5-7 non si è sentita (me l'hai confermato). Nei 5 minuti di attesa non ha suonato nulla. |
| 16 | Tag vero (NTAG) | PARZIALE | Funziona **solo a telefono sbloccato**. Se il telefono era già sbloccato, anche se sulla schermata di blocco, quando parte la sveglia, il tag funziona. Se era bloccato, Face ID non sblocca finché la sveglia suona. Nel log: alle 14:24:44 Stop e alle 14:24:51 tag "Prova"; alle 14:26:25 Stop e alle 14:26:34 tag "Prova". Lo Stop arriva sempre 7-9 s prima del tag, quindi probabilmente la sequenza reale è: Stop per zittire, sblocco, tag. Al momento del tag risultava "sveglie in corso: 1", cioè la sveglia successiva era già partita e il tag l'ha fermata. |
| 17 | Suono lungo (3 min) | OK | Sveglia delle 14:30:33, fermata alle 14:34:55: ha suonato ininterrottamente per **4 min 22 s**. Il file da 3 min suona intero, poi ricomincia da capo. La sveglia non si spegne da sola. Hai scritto "almeno 5 min", ma dal log risulta circa 4 min e mezzo. La crescita di volume dentro il file **non si percepisce**: si sente salire solo nei primi secondi (vedi §2.6). |

**Altre cose che emergono dal log e che non avevi notato:**
- **Ordine degli stop non cronologico.** Quando più sveglie sono accumulate, quella sullo schermo non è necessariamente l'ultima. Per esempio alle 17:00:14 hai fermato la n. 5, alle 17:00:26 la n. 6 e alle 17:01:02 la n. 2. Così si spiega la sensazione che "dopo lo stop parte subito la successiva": riemergeva una sveglia vecchia. Da quando lo Stop le ferma tutte, il problema è sparito.
- **25 "Errore cancellazione Code=0"**, tutti fino al 18/11 alle 02:36. Ne compariva uno per ogni sveglia accumulata, perché il vecchio codice prima la fermava (e questo la rimuove) e poi provava a cancellarla. Dopo la reinstallazione con la correzione (18/11 alle 14:13:24, "Avvio app") non ce ne sono più. Ne segue anche che il test notturno delle 02:3x è stato fatto con la build vecchia.
- **Spegnimenti col nome tag "Ca"** alle 16:39:22 e 16:40:35. Quello delle 16:40:35 ha cancellato 19 sveglie mentre suonava. Non è chiaro da dove venissero: dal campo dell'app modificato, oppure da un'azione di Comandi Rapidi con parametro "Ca". Non incide sui risultati.
- **"prima alle 14:13:00" scritto alle 14:24:58.** Era quasi certamente il giorno dopo: il selettore d'orario era rimasto su 14:13 e "Imposta sveglia" sceglie la prossima occorrenza. Il log mostra l'ora ma non la data, quindi sembra un orario passato. L'hai riprogrammata 4 s dopo.
- **Programmazioni ripetute**: 8 riprogrammazioni di 61 sveglie in 18 s (16:22:22–16:22:40) e 8 "Simula tag" in 9 s. Indicano che l'app non dava abbastanza riscontro visivo dopo il tocco. Non c'è un bug, ma per l'app finale serve una conferma visibile.
- **Totali del log**: 27 stop senza tag, 25 spegnimenti col tag, 26 catene programmate, 5 avvii dell'app, nessun limite AlarmKit raggiunto.

---

## 2. Cosa abbiamo verificato su AlarmKit e iOS

### 2.1 Personal Team (Apple ID gratuito)
- **Funziona.** AlarmKit **non richiede nessuna capability né entitlement**: basta la chiave `NSAlarmKitUsageDescription` nell'Info.plist e l'autorizzazione dell'utente (`AlarmManager.shared.requestAuthorization()`).
- Le App Intents non richiedono capability.
- Non usiamo né NFC (Core NFC), né App Groups, né Push, né iCloud, né estensioni. Non c'è stato **nessun problema** di firma, capability o permessi. L'unico permesso chiesto è quello delle sveglie, concesso al primo avvio.

### 2.2 Affidabilità della sveglia
| Condizione | Esito |
|---|---|
| App chiusa dal multitasking | ✅ verificato anche dal log: iOS riavvia l'app in background per lo `stopIntent` |
| Telefono bloccato | ✅ |
| Modalità silenziosa (interruttore) | ✅ suona lo stesso |
| Dopo un riavvio del telefono | ✅ (da tua osservazione, non presente nel log) |
| Non disturbare / Full immersion / Riposo | ❓ **non testato**. Secondo Apple le sveglie AlarmKit superano silenzioso e Full immersion |
| Risparmio energetico | ❓ non testato |
| Una notte intera (ore di inattività, telefono in carica) | ❓ **non testato**: tutti i test sono durati da 1 a 5 minuti |
| Sveglia non fermata | suona **all'infinito** (osservati fino a 4 min 22 s), non si spegne mai da sola |

### 2.3 Catena di sveglie
- **Quante insieme:** 61 sveglie programmate in un colpo solo (30 min ogni 30 s, più quella principale), **nessun errore**. Il limite reale non è stato trovato. La FAQ Apple (Q1) dice che non c'è un numero fisso: dipende dallo stato del dispositivo, e superarlo dà `AlarmManager.AlarmError.maximumLimitReached`. Il prototipo gestisce questo errore: lo registra, cancella e riprova con un intervallo più lungo. Non è mai scattato.
- **Velocità:** programmare o cancellare 61 sveglie richiede meno di 1 secondo.
- **Intervallo:** 30 s rispettati, perché gli stop arrivano 3-5 s dopo l'orario programmato. Funzionano anche gli intervalli di 10 s.
- **Tipo di pianificazione usato:** `Alarm.Schedule.fixed(Date)`, cioè una data e ora assoluta per ogni sveglia, tutte programmate subito. Niente viene riprogrammato dopo uno stop.
- **Comportamento chiave, l'accumulo:** se una sveglia non viene fermata resta nello stato `.alerting`. Quando scatta la successiva, il suo suono e il suo schermo **coprono** quelli della precedente, che però resta "in corso". Si possono accumulare tutte le sveglie della catena (7 su 7 nel test 15). Lo Stop dell'utente ferma solo la sveglia mostrata, e quale venga mostrata non è prevedibile.
- **Soluzione adottata e verificata:** lo `stopIntent` ferma via codice tutte le altre sveglie in `.alerting` (`AlarmManager.stop(id:)`). Dopo uno Stop c'è silenzio fino alla sveglia programmata successiva.
- **Regola tecnica scoperta:** `stop(id:)` su una sveglia singola che sta suonando la **rimuove** già, quindi un successivo `cancel(id:)` dà `com.apple.AlarmKit.Alarm Code=0`. Regola corretta: `stop` se è `.alerting`, altrimenti `cancel`.

### 2.4 Lo `stopIntent`: quando viene chiamato
| Azione | `stopIntent` chiamato? | Note |
|---|---|---|
| Pulsante o scorrimento Stop di sistema | ✅ sempre, in tutti i casi osservati | Anche ad app chiusa: iOS avvia l'app in background (nel log "Avvio app" nello stesso secondo) |
| Tasto laterale | ✅ | Ferma **tutte** le sveglie in corso e chiama lo `stopIntent` di **ciascuna** (14:18:02, due chiamate nello stesso secondo) |
| Tasti volume | ❌ mai | Zittiscono soltanto: la sveglia resta `.alerting` e le successive scattano **mute**, compresa la sirena |
| `AlarmManager.stop(id:)` chiamato dal nostro codice | ❌ | Le 3 sveglie fermate via codice alle 14:16:31 non hanno generato uno `stopIntent`. Bene così, non c'è il rischio di un ciclo |

Contesto (ricerca, Appendice A): la FAQ ufficiale di AlarmKit dice che i tasti fisici fermano tutte le sveglie in corso (Q7/Q8) e che alla chiusura parte lo `stopIntent` (Q4). Il comportamento del volume su iOS 26 è quindi un **bug**, segnalato da altri sviluppatori: il primo caso è di settembre 2025, è stato riconfermato a febbraio 2026 e nel maggio 2026 un altro sviluppatore l'ha segnalato come FB22686646, inoltrato dal supporto tecnico Apple al team competente. Non ci sono date per una correzione. Non esiste un'API per intercettare i tasti volume.

### 2.5 Suoni personalizzati
- **API:** `AlertConfiguration.AlertSound.named("file.wav")` (nel codice `.named(suono)`), con il file nel **bundle principale** dell'app.
- **Formato verificato:** WAV PCM 16 bit, mono, 22.050 Hz. **Altri formati (CAF, AIFF, M4A/AAC, MP3) non sono stati provati.** La documentazione Apple sui suoni di notifica ammette AIFF, WAV e CAF con PCM lineare, IMA4, µLaw o aLaw: probabilmente vale anche qui, ma non è verificato.
- **Posizione:** verificata solo nel bundle. Non è verificato se si possano usare suoni copiati dopo l'installazione (per esempio in `Library/Sounds`), che servirebbero per scegliere o caricare suonerie dall'app.
- **Durata massima reale:** **non trovata.** Un file da **3 minuti suona per intero**, poi **ricomincia in loop** senza interruzioni, e la sveglia continua finché non viene fermata (4 min 22 s osservati). Uno sviluppatore sui forum riporta che i suoni oltre circa 30 s vengono sostituiti da quello di sistema, ma **da noi non succede**. File più lunghi di 3 min non sono stati provati.
- **Suono diverso per ogni sveglia:** ✅. Il suono si sceglie per singola sveglia (`sound:` in `AlarmConfiguration`), quindi la sirena dalla 5ª funziona per costruzione ed è stata sentita. Dentro una singola sveglia, invece, il suono non si può cambiare.
- **Peso:** WAV 22 kHz mono = circa 44 KB/s. Il file da 3 min pesa 7,9 MB ed è quasi tutto il peso dell'IPA (8 MB). Un file da 15 min in questo formato peserebbe circa 40 MB.
- I suoni del prototipo sono generati da `scripts/genera_suoni.py`:
  - **normale:** bip doppio a 880 Hz, 25 s;
  - **punizione:** sirena a onda quadra che spazza 700-1600 Hz ogni 0,35 s, con effetto martellante, 25 s. È diversa dall'IT-alert, che è un tono fisso modulato;
  - **test lungo:** 180 s, ampiezza che sale linearmente da 0,05 a 0,90 (circa da -26 dB a -1 dB), con N bip a 1500 Hz ogni 30 s come segnatempo.

### 2.6 Verso una sveglia progressiva di 15 minuti
Cosa sappiamo:
- Un suono lungo viene riprodotto per intero e poi ripetuto, quindi la durata non è un ostacolo, almeno fino a 3 min.
- La crescita di volume **dentro il file non si è percepita** in 3 minuti. Si sente salire solo nei primi secondi, quasi certamente per la **dissolvenza in entrata di iOS** all'inizio di ogni sveglia. I bip segnatempo a volume pieno ogni 30 s possono aver mascherato la crescita.
- Ipotesi da verificare: sugli iPhone con Face ID le **"Funzioni di rilevamento dell'attenzione"** abbassano il volume degli avvisi quando guardi lo schermo, e durante il test probabilmente lo guardavi.
- Il volume massimo è comunque limitato dal volume di sistema (suoneria e avvisi). Il file può solo restare uguale o scendere rispetto a quel livello. Non verificato se AlarmKit usi proprio il volume della suoneria.

Approcci possibili, in ordine di fattibilità:
1. **Catena di sveglie con file sempre più forti (consigliato).** Per esempio 15 sveglie a 1 minuto l'una dall'altra, ciascuna con lo stesso suono reso più forte di qualche dB. Ogni nuova sveglia copre la precedente, come abbiamo verificato con l'accumulo. Usa solo comportamenti già verificati.
   - Ogni sveglia ricomincia con la dissolvenza di iOS, quindi si sente un piccolo "respiro" a ogni gradino.
   - Le sveglie si sommano a quelle della catena anti-trucco: 15 + 61 = 76, oltre le 61 verificate.
   - Lo Stop deve fermarle tutte, come già fa.
2. **Un unico file da 15 min con volume crescente.** Più semplice da programmare, ma non è verificato che oltre 3 min funzioni, la crescita dentro il file non si è percepita e pesa circa 40 MB in WAV 22 kHz. Andrebbe compresso, per esempio IMA4 in CAF o AAC, formati non verificati.
3. **Audio riprodotto dall'app stessa in background.** L'app resta viva con un audio silenzioso e alza il volume quando vuole. È complesso, non è verificato (AlarmKit potrebbe interrompere il nostro audio, iOS può chiudere l'app di notte) e consuma batteria. Da evitare se 1 basta.

Prima di progettarla serve un **mini-test** che non abbiamo fatto: 4 sveglie a 30 s, ciascuna più forte di circa 6 dB, ascoltate col telefono girato. In parallelo, un file da 15 min per verificare durata e percezione.

---

## 3. Spegnimento con il tag

- **App Intent "Spegni sveglia" da Comandi Rapidi:** ✅ funziona **senza aprire l'app** (`openAppWhenRun` è `false` di default) e mostra "Sveglia spenta, N sveglie cancellate". Ferma la sveglia che suona e cancella tutta la catena.
- **Esecuzione in background:** l'intent gira nel processo dell'app principale. Se l'app è chiusa, iOS la avvia in background, e in quel caso viene eseguito anche `App.init`. Non serve nessuna estensione né App Group.
- **Automazione NFC:**
  - **telefono sbloccato:** ✅ funziona;
  - **telefono già sbloccato quando parte la sveglia, anche se fermo sulla schermata di blocco:** ✅ funziona;
  - **telefono bloccato:** ❌ l'automazione non parte. Mentre la sveglia suona **Face ID non sblocca**, quindi bisogna fermare o zittire la sveglia e sbloccare il telefono. È un limite di iOS: le automazioni NFC richiedono il telefono sbloccato.
- **Ritardo:** **non misurato con precisione.** Il log ha risoluzione di 1 s e non registra l'istante in cui il tag viene avvicinato. Dati indiretti:
  - nel test notturno, 15 s e 17 s tra l'orario della sveglia e lo spegnimento, tempo che comprende sbloccare e avvicinare il telefono;
  - nel test 16, 7-9 s tra lo Stop e il tag;
  - non hai segnalato ritardi percepibili.
- **Parametro "Nome tag":** probabilmente arriva. Durante il test 16 il log mostra "Prova" con la P maiuscola, diverso dal valore predefinito "prova" del campo nell'app: se nell'automazione hai scritto "Prova", il parametro arriva correttamente. Senza parametro l'intent riceve `nil` e il log mostra "-" (02:34 e 02:36). **Da confermare:** che nome hai inserito nell'automazione?
- **Problemi e limiti trovati:**
  1. Serve il telefono sbloccato. Con il telefono bloccato, la sequenza onesta è: Stop (registrato come "stop senza tag"), sblocco, tag entro 30 s, prima o durante la sveglia successiva.
  2. La **carta d'identità** elettronica non funziona come tag, probabilmente per l'identificativo casuale. Serve un tag NTAG (NTAG213/215/216).
  3. **L'intent si può lanciare senza tag**: a mano da Comandi Rapidi, da Siri o da Spotlight, come nel test 7. iOS non dice all'intent chi l'ha avviato. È un modo per imbrogliare che va mitigato nell'app finale (§6).
  4. La frase per Siri ("Spegni sveglia con Sveglia NFC") è dichiarata senza localizzazione italiana: Siri in italiano potrebbe non riconoscerla. Comandi Rapidi e l'automazione non ne dipendono.
  5. Mancano un "debounce" e un riscontro visivo: più esecuzioni ravvicinate sono innocue, ma senza conferma visibile l'utente ripete il tocco.

---

## 4. Build e installazione

### 4.1 Pipeline attuale
- **Repository pubblico** su GitHub: i runner macOS standard sono **gratuiti e illimitati** per i repository pubblici. Su un repository privato il piano gratuito dà 2.000 minuti al mese e i minuti macOS valgono 10 volte tanto, quindi circa 200 minuti macOS.
- **Workflow** `.github/workflows/build.yml` ("Build IPA"). Parte a ogni push su `main` oppure a mano (*Actions → Build IPA → Run workflow*). Passi:
  1. Seleziona l'Xcode 26 più recente.
  2. Genera i suoni con Python (`scripts/genera_suoni.py Sounds`), installa XcodeGen con Homebrew ed esegue `xcodegen generate`.
  3. Compila senza firma:
     ```
     xcodebuild -project SvegliaNFC.xcodeproj -scheme SvegliaNFC -configuration Release \
       -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \
       CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
     ```
  4. Crea `Payload/SvegliaNFC.app`, controlla che ci sia `Metadata.appintents` (serve a Comandi Rapidi per vedere l'azione) e lo comprime in `SvegliaNFC.ipa`.
  5. Carica l'artifact **SvegliaNFC-ipa**: uno zip con dentro l'IPA di circa 8 MB, conservato 90 giorni (predefinito).
- **Ambiente dell'ultima build riuscita:** runner `macos-26` (immagine `macos-26-arm64`, versione 20261112.0504.1), **Xcode 26.6** (build 17F113), SDK **iPhoneOS 26.5**, XcodeGen **2.46.0**, Python 3 del runner. Nessun warning di compilazione Swift nell'ultima build.
- **Tempi e minuti** (4 esecuzioni):

  | Build | Attesa del runner | Durata del job | Di cui compilazione | Esito |
  |---|---|---|---|---|
  | 17/11, primo commit | ~5 s | 1 min 21 s | 39 s | ✅ |
  | 17/11, correzione accumulo | ~5 min | 1 min 14 s | 47 s | ✅ |
  | 18/11, README | ~5 min | 58 s | 30 s | ✅ |
  | 18/11, README | **mai partita** | — | — | ❌ annullata dopo 15 min: "The job was not acquired by Runner… capacity constraints macOS arm64" |

  Minuti di calcolo consumati in tutto: circa 3,5 minuti macOS, gratuiti. **Rischio:** la coda dei runner macOS arm64 può durare diversi minuti o fallire del tutto, e in quel caso basta rilanciare. Anche le modifiche ai soli file `.md` avviano una build inutile.

### 4.2 Bundle ID, Sideloadly, limiti
- **Bundle ID:** `com.svegliatag.prototipo`, una riga in `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`). Sideloadly l'ha accettato senza problemi.
- **Sideloadly:** nessun problema segnalato. Su Windows serve **Apple Devices** dal Microsoft Store, oppure iTunes scaricato da apple.com. Sull'iPhone servono la **Modalità sviluppatore** e l'autorizzazione del profilo in *Impostazioni → Generali → VPN e gestione dispositivi*. Sideloadly chiede password e codice a due fattori dell'Apple ID: per sicurezza meglio un Apple ID secondario.
- **Limiti dell'Apple ID gratuito:**
  - **l'app scade dopo 7 giorni** dall'ultima installazione e smette di aprirsi;
  - **al massimo 3 app** installate così;
  - **al massimo 10 nuovi App ID ogni 7 giorni**: ogni estensione (widget, Live Activity) e ogni cambio di Bundle ID ne consuma uno.

  Il prototipo ne usa **1**. L'app finale con un nuovo Bundle ID ne userà un altro. Il prototipo si può disinstallare per liberare uno dei 3 posti.
- **Non verificato:**
  - cosa succede alle sveglie programmate e alle App Intents quando l'app scade, cioè se suonano ancora e se Stop e tag funzionano;
  - se le sveglie programmate sopravvivono alla reinstallazione.

  Il log e i dati invece sopravvivono alla reinstallazione con lo stesso Bundle ID: il log del 17/11 c'era ancora dopo la reinstallazione del 18/11.

### 4.3 Cosa devi fare ogni volta per aggiornare l'app
1. La modifica viene caricata su `main`, da me o da te. La build parte da sola, altrimenti: *Actions → Build IPA → Run workflow*.
2. Aspetta il pallino verde: 1-2 minuti di build più l'eventuale attesa del runner, fino a circa 5 minuti. Se dopo 15 minuti non è partita, rilanciala.
3. Scarica l'artifact *SvegliaNFC-ipa* dalla pagina della build, in fondo alla sezione *Artifacts*, ed estrai `SvegliaNFC.ipa`. In alternativa lo scarico io con `gh run download`.
4. Collega l'iPhone con il cavo e sbloccalo. In Sideloadly trascina l'IPA, usa **lo stesso Apple ID** e premi **Start**. Inserisci il codice a due fattori se te lo chiede.
5. L'app si installa sopra la precedente: log e impostazioni restano, e il conteggio dei 7 giorni riparte. Di norma non serve autorizzare di nuovo il profilo.
6. Ripeti l'installazione almeno ogni 6 giorni anche senza modifiche, altrimenti l'app scade.

---

## 5. Stato del codice

### 5.1 Struttura
```
.github/workflows/build.yml   build nel cloud (XcodeGen + xcodebuild senza firma + .ipa)
project.yml                   progetto XcodeGen: target, Info.plist, Bundle ID, iOS 26.0
scripts/genera_suoni.py       genera i 3 WAV (solo libreria standard Python, con auto-verifica)
Sources/App.swift             (137 righe) UI SwiftUI: scheda "Sveglia" e scheda "Log"
Sources/Logica.swift          (130 righe) log persistente + logica della catena di sveglie
Sources/Intents.swift         (54 righe) App Intents: "Spegni sveglia", stopIntent, scorciatoia
README.md                     istruzioni per build, installazione, automazione NFC, risultati
TEST.md                       checklist dei test (giro 1: 1-12, giro 2: 13-17)
.gitignore                    esclude i file generati: Sounds/, Generated/, *.xcodeproj, build/, Payload/, *.ipa
```
I file generati a ogni build sono `Sounds/*.wav`, `Generated/Info.plist` e `SvegliaNFC.xcodeproj`. Il file `.pbxproj` non è mai scritto a mano.

Cosa fa ciascun componente:
- **`Log`** (Logica.swift): accoda righe con data e ora a `Documents/log.txt`, protetto da un `NSLock`, e lo rilegge per la schermata Log. Il file sopravvive a chiusura e reinstallazione.
- **`DatiSveglia: AlarmMetadata`**: contiene l'indice e il totale della catena. AlarmKit richiede un tipo di metadata per `AlarmAttributes`.
- **`Catena`** (Logica.swift):
  - `programma(inizio:intervallo:durataMinuti:)` cancella tutto, poi programma `durata*60/intervallo + 1` sveglie `.fixed`. Dalla 5ª (`primaPunizione = 5`) usa il suono punizione. Su `maximumLimitReached` allarga l'intervallo e riprova, fino a 4 tentativi.
  - `programmaUna(...)` costruisce `AlarmPresentation.Alert` (titolo "Sveglia i/N" oppure "PUNIZIONE i/N - usa il tag!"), `AlarmAttributes` (arancione o rosso) e `.alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)`.
  - `cancellaTutto` applica la regola: `stop` se `.alerting`, altrimenti `cancel`.
  - `spegniConTag` è la logica unica condivisa da App Intent e "Simula tag".
- **`SpegniSvegliaIntent`** (Intents.swift): `AppIntent` con parametro opzionale `nomeTag`, restituisce un dialogo. È esposta da `Scorciatoie: AppShortcutsProvider`.
- **`StopSenzaTagIntent`** (Intents.swift): è un `LiveActivityIntent`, perché lo `stopIntent` di AlarmKit richiede questo tipo. Riceve `alarmID` e `indice` come parametri, perché l'oggetto `Alarm` non restituisce i metadata. Incrementa il contatore in `UserDefaults`, ferma tutte le altre sveglie `.alerting` e scrive nel log.
- **UI** (App.swift): `Form` con autorizzazione, orario e test rapidi, impostazioni della catena (`@AppStorage`), stato (osserva `alarmUpdates` e `authorizationUpdates`), "Simula tag" e "Cancella tutte". C'è poi la scheda Log con `ShareLink`.

Configurazione chiave (`project.yml`):
- target iOS **26.0**, solo iPhone, solo verticale;
- Swift in **modalità 5**;
- Info.plist generato con `NSAlarmKitUsageDescription` in italiano;
- **nessun entitlement**, **nessuna estensione**.

### 5.2 Cosa si può riutilizzare e cosa riscrivere
| Riutilizzabile così com'è o quasi | Da riscrivere |
|---|---|
| Pipeline CI (`build.yml`) e schema `project.yml`: provati e stabili | Tutta la UI: è volutamente brutta e da test |
| Costruzione di una sveglia AlarmKit (`programmaUna`): attributi, suono per sveglia, `stopIntent` con parametri | Persistenza: contatori in `UserDefaults` e log in testo. Serve un modello dati vero (§6) |
| Regola stop-o-cancel e "ferma tutte le `.alerting`" nello `stopIntent`: verificate sul dispositivo | Formato del log: servono data completa, millisecondi e rotazione del file |
| Gestione di `maximumLimitReached` | `Alert` con il vecchio `stopButton`, deprecato da 26.1: con un target ≥ 26.1 si usa il nuovo init |
| Schema App Intent con parametro e `AppShortcutsProvider` | "Simula tag" e "Cancella tutte" vanno tolti o nascosti in una modalità sviluppatore |
| Log persistente con condivisione: indispensabile senza Xcode | Selettore d'orario: oggi sceglie silenziosamente il giorno dopo |
| Generatore di suoni, utile per suoni di test e per livelli di volume calibrati | Frase Siri da localizzare in italiano |

### 5.3 Dipendenze e strumenti
- **Nessuna dipendenza esterna:** niente Swift Package Manager, niente CocoaPods. Framework Apple usati: SwiftUI, AlarmKit, AppIntents e Foundation.
- **Strumenti:**
  - nel cloud: XcodeGen 2.46 (Homebrew), Xcode 26.6 e Python 3 sul runner GitHub;
  - sul PC Windows: `git`, `gh` (GitHub CLI), Sideloadly e Apple Devices.
- **Versione minima di iOS:** 26.0. AlarmKit esiste solo da iOS 26.

---

## 6. Problemi aperti e raccomandazioni

### 6.1 Bug noti e comportamenti strani
1. **Tasti volume** (iOS, FB22686646): zittiscono la sveglia e tutte le successive senza fermarle e senza chiamare lo `stopIntent`. Non si può aggirare dentro AlarmKit e va ricontrollato a ogni aggiornamento di iOS con il test 15. Se Apple lo allinea alla FAQ, il buco si chiude da solo grazie alla catena.
2. **Accumulo delle sveglie** in `.alerting`: gestito dal codice. Nell'app finale **qualsiasi** punto che ferma una sveglia deve fermarle tutte.
3. **Face ID bloccato durante la sveglia** e **NFC solo da sbloccato**: limite di iOS.
4. Nel log del prototipo manca la data negli orari "prima alle …".
5. Il vecchio init `AlarmPresentation.Alert(title:stopButton:…)` è deprecato da iOS 26.1. Funziona, ma il sistema ignora lo `stopButton`: il pulsante Stop lo disegna iOS.

### 6.2 Cose non verificate (da provare prima o durante lo sviluppo)
| Da verificare | Perché conta |
|---|---|
| Una **notte vera**: catena completa all'ora reale, telefono bloccato in carica per ore, Full immersion Riposo attiva | È il caso d'uso reale: finora solo test di pochi minuti |
| **Non disturbare / Full immersion**, **risparmio energetico** | Apple dice che le sveglie AlarmKit li superano, ma non l'abbiamo visto |
| **Scadenza dei 7 giorni**: suonano le sveglie già programmate? Funzionano Stop e tag se l'app non si apre più? | Con l'Apple ID gratuito è il rischio più grave: un'app scaduta potrebbe non svegliarti |
| Le sveglie programmate **sopravvivono alla reinstallazione** con Sideloadly? | Ogni rinnovo settimanale è una reinstallazione |
| Più di 61 sveglie insieme (122 per due giorni, 76 con la progressiva) | Definisce l'orizzonte di pianificazione |
| Sveglie programmate **in background** (per esempio da un evento di geofence) | Lo stop e la cancellazione in background sono verificati, la programmazione no |
| Pulsante secondario della sveglia (`secondaryIntent` con comportamento `.custom`) dalla schermata di blocco | Possibile Emergency Stop direttamente dalla sveglia |
| Suoni più lunghi di 3 min, altri formati (CAF/IMA4, AAC), suoni in `Library/Sounds` | Sveglia progressiva, peso dell'app, suonerie scelte dall'utente |
| Mini-test della progressiva: 4 sveglie con file sempre più forti; rilevamento dell'attenzione spento | Scelta dell'approccio al §2.6 |
| Cosa succede se l'utente revoca il permesso Sveglie o cambia data e ora di sistema | Modi per imbrogliare |
| Ritardo reale del tag, misurato con log in millisecondi | Esperienza al mattino |
| Prova del "guardiano in background" (audio silenzioso più controllo delle sveglie bloccate) | Unica idea per chiudere il buco del volume. È stata messa da parte in attesa del fix di Apple |

### 6.3 Rischi tecnici per l'app completa
1. **Scadenza a 7 giorni** del Personal Team. Se un rinnovo salta, l'app non si apre e il comportamento delle sveglie non è noto.
   - **Mitigazione:** l'app legge la data di scadenza da `embedded.mobileprovision` (incluso da Sideloadly nell'app firmata), la mostra e programma una **notifica locale** di promemoria 1-2 giorni prima. Le notifiche locali non richiedono capability. Tecnica nota, non provata qui.
   - In alternativa: il rinnovo automatico di Sideloadly via Wi-Fi o SideStore, entrambi da verificare.
2. **Modi per imbrogliare che il codice non può impedire, ma può rilevare:**
   - tasti volume;
   - eseguire "Spegni sveglia" a mano da Comandi Rapidi o Siri senza il tag;
   - cancellare l'app, che fa sparire le sveglie;
   - revocare il permesso Sveglie;
   - spegnere il telefono;
   - cambiare data e ora per aggirare le regole a tempo, cioè ricarica settimanale e blocco delle 2 ore;
   - lasciare scadere l'app.
3. **Il limite di sveglie** non è noto oltre 61, e la FAQ dice che dipende dallo stato del dispositivo.
4. **Coda dei runner macOS** su GitHub: a volte una build non parte (ci è successo una volta) e va rilanciata.
5. **Nessun debugger:** ogni errore si scopre solo dal log. Ogni ciclo di correzione costa una build, da 1 a 6 minuti, più una reinstallazione.
6. **Concorrenza:** le App Intents possono girare mentre la UI è aperta, oppure avviare l'app da zero in background (`App.init` viene eseguito). Tutto l'accesso ai dati deve passare da un unico punto serializzato, e `App.init` deve restare leggero.

### 6.4 Raccomandazioni su architettura e approccio

**Principi da mantenere:**
- **Un solo target app, nessuna estensione, nessun App Group.** Le App Intents girano nel processo dell'app (verificato), quindi condividono già file e dati. Così si consuma 1 solo App ID.
- **Nessuna capability a pagamento.** La posizione "Sempre" non richiede entitlement: bastano le chiavi Info.plist `NSLocationWhenInUseUsageDescription` e `NSLocationAlwaysAndWhenInUseUsageDescription`. Il monitoraggio di una regione non richiede `UIBackgroundModes`.
- **Stessa pipeline:** XcodeGen, GitHub Actions senza firma e Sideloadly. Aggiungere `paths-ignore: ['**.md']` al workflow per non compilare a ogni modifica dei documenti.
- **Target iOS 26.1** invece di 26.0, così si usa il nuovo init di `Alert` senza API deprecate. L'unico dispositivo è già su 26.6.2.
- **Swift in modalità 5:** evita cicli di correzione degli errori di concorrenza stretta di Swift 6 senza un Mac.

**Moduli suggeriti:**
1. **`AlarmEngine`**: l'unico punto che parla con `AlarmManager`.
   - Pianifica una "mattina": sveglia principale, eventuale fase progressiva e catena anti-trucco con la sirena.
   - Offre `fermaTutteInCorso()`, con la regola stop-o-cancel, `cancellaTutto()` e `riallinea()`.
   - Salva nello store la mappa *UUID sveglia → (mattina, indice, orario, suono)*, perché `Alarm` restituisce solo id, programmazione e stato.
   - `riallinea()` confronta le sveglie attese con `AlarmManager.alarms`. Va eseguito a ogni avvio dell'app, a ogni intent, a ogni evento di geofence e su `significantTimeChangeNotification`.
   - Se mancano sveglie che dovrebbero esserci (app cancellata e reinstallata, permesso revocato), lo registra.
2. **`Store`**: un attore che legge e scrive un file **JSON `Codable` versionato** in Application Support. Contiene impostazioni, mattine e storico, crediti dell'Emergency Stop ed eventi.
   - Il JSON è più semplice di SwiftData da esportare e da migrare senza Xcode, e i volumi sono piccoli: pochi record al giorno.
   - **Backup ed esportazione:** il file JSON esportato con `fileExporter` o `ShareLink` e reimportato con `fileImporter`. Niente iCloud, che è una capability.
   - Serve perché cancellare l'app o cambiare il Bundle ID cancella tutti i dati.
3. **`EventLog`**: il log diagnostico testuale del prototipo, migliorato con data completa, millisecondi, rotazione ed esportazione. Va tenuto anche nell'app finale.
4. **Intents:**
   - `SpegniConTag`. Per ridurre l'uso senza tag:
     - parametro **codice segreto** configurato una volta nell'automazione NFC;
     - accettato solo se c'è una sveglia in corso o se si è nella finestra della mattina;
     - ogni esecuzione registrata.
   - `StopSenzaTag` (lo `stopIntent`): ferma tutte le sveglie in corso e registra.
   - `EmergencyStop`: dall'app oppure, se il test lo conferma, come pulsante secondario della sveglia con `secondaryIntent`.
5. **`Regole`** (logica pura, testabile con piccoli controlli):
   - **Valutazione della mattina:**
     - quanti stop senza tag;
     - quando è arrivato il tag;
     - Emergency Stop usato;
     - **sospetto trucco col volume**: al momento del tag o alla riapertura ci sono sveglie `.alerting` più vecchie di 1-2 minuti (verificato nel test 15: "in corso: 7").
   - **Periodo di tolleranza:** uno Stop seguito dal tag entro N minuti **non** va punito, perché a telefono bloccato è l'unica sequenza possibile (Stop, sblocco, tag).
   - **Blocco delle modifiche nelle 2 ore prima della sveglia:**
     - la UI non permette di modificare o cancellare;
     - l'unica uscita sono il tag o l'Emergency Stop;
     - anche gli intent devono rispettarlo;
     - va rimosso il pulsante "Cancella tutte".
   - **Emergency Stop con ricarica settimanale:** crediti e data dell'ultima ricarica nello store. Contro il trucco di cambiare data, salvare l'ultima data vista e non ricaricare se l'orologio torna indietro.
   - **"Vado a dormire ora":** sveglia = adesso + tempo per addormentarsi (per esempio 15 min) + k × 90 min. Si propongono più opzioni, per esempio k = 4, 5 o 6, e si programma la mattina come una sveglia normale con `.fixed`. Nessun rischio tecnico nuovo.
6. **`Geofence`**: `CLMonitor` (iOS 17+) con una `CircularGeographicCondition` attorno a casa.
   - Il permesso va chiesto in due passi: prima "Mentre usi l'app", poi "Sempre". Serve la posizione precisa.
   - Gli eventi possono arrivare con **minuti** di ritardo e con un raggio minimo realistico di 100-200 m: non usarli per decisioni al secondo.
   - Un evento avvia l'app in background: verificare che da lì si possano programmare o cancellare sveglie AlarmKit.
   - iOS ogni tanto chiede all'utente se continuare a concedere la posizione "Sempre".

**Pianificazione delle sveglie:**
- Usare sveglie `.fixed`, come nel prototipo.
- Tenere programmato un **orizzonte di almeno 2 mattine**. Una mattina "solo volume" non esegue nessun nostro codice: senza `stopIntent` e senza tag, la mattina dopo resterebbe senza sveglie.
- Dopo il tag, l'Emergency Stop, l'ultimo stop o la riapertura dell'app, `riallinea()` aggiunge la mattina successiva.
- Prima va verificato che 122 o più sveglie siano accettate. In alternativa si può valutare `Alarm.Schedule.relative` con ripetizione settimanale, solo per la sveglia principale come rete di sicurezza.

**Sveglia mostrata all'utente:**
- Titolo esplicito, per esempio "Sblocca e avvicina al tag" e, dalla 5ª, "PUNIZIONE – usa il tag!".
- Suoni veri, normalizzati, in WAV o CAF, con un occhio al peso dell'IPA.
- Livelli di volume pre-calcolati per la progressiva (§2.6).

**Modalità sviluppatore nascosta** (per esempio 5 tocchi sul titolo): catena breve, simula tag, log completo. Senza Xcode è l'unico modo per diagnosticare.

---

## Appendice A – Fonti principali della ricerca
- FAQ AlarmKit di Apple (Q1 limite, Q4 stopIntent, Q6 ordine, Q7/Q8 tasti fisici): https://developer.apple.com/forums/thread/797158
- Volume e tasti volume in AlarmKit: https://developer.apple.com/forums/thread/800265 · https://developer.apple.com/forums/thread/810865 · https://developer.apple.com/forums/thread/805937 · https://developer.apple.com/forums/thread/817926
- StopIntent e sveglie doppie: https://developer.apple.com/forums/thread/803735
- iOS 26.1 e lo stop della sveglia (MacRumors): https://www.macrumors.com/2025/10/08/ios-26-1-beta-stop-silencing-alarms-accident/
- Rilevare i tasti volume (nessuna API ufficiale): https://developer.apple.com/forums/thread/107241
- App simili basate su AlarmKit: PuckAlarm (github.com/DanielBordencea/PuckAlarm), Tagdawn (tagdawn.app), Fluid Friction (fluidfriction.app), Fajr Buddy (App Store)

## Appendice B – Log completo dell'app (17/11 16:18 → 18/11 14:34)

```
[17 Nov at 16:18:37] Avvio app
[17 Nov at 16:18:53] Autorizzazione: concessa
[17 Nov at 16:21:37] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:21:38] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:21:42] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:21:42] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:21:42] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:21:44] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:21:46] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:21:46] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:22:22] Catena programmata: 61 sveglie ogni 30 s per 30 min, prima alle 16:23:21
[17 Nov at 16:22:23] Cancellate 61 sveglie (nuova programmazione)
[17 Nov at 16:22:23] Catena programmata: 61 sveglie ogni 30 s per 30 min, prima alle 16:23:23
[17 Nov at 16:22:27] Cancellate 61 sveglie (nuova programmazione)
[17 Nov at 16:22:27] Catena programmata: 61 sveglie ogni 30 s per 30 min, prima alle 16:23:27
[17 Nov at 16:22:31] Cancellate 61 sveglie (nuova programmazione)
[17 Nov at 16:22:31] Catena programmata: 61 sveglie ogni 30 s per 30 min, prima alle 16:23:31
[17 Nov at 16:22:32] Cancellate 61 sveglie (nuova programmazione)
[17 Nov at 16:22:32] Catena programmata: 61 sveglie ogni 30 s per 30 min, prima alle 16:23:32
[17 Nov at 16:22:34] Cancellate 61 sveglie (nuova programmazione)
[17 Nov at 16:22:34] Catena programmata: 61 sveglie ogni 30 s per 30 min, prima alle 16:23:33
[17 Nov at 16:22:34] Cancellate 61 sveglie (nuova programmazione)
[17 Nov at 16:22:34] Catena programmata: 61 sveglie ogni 30 s per 30 min, prima alle 16:23:34
[17 Nov at 16:22:37] Avvio app
[17 Nov at 16:22:40] Cancellate 61 sveglie (nuova programmazione)
[17 Nov at 16:22:40] Catena programmata: 61 sveglie ogni 30 s per 30 min, prima alle 16:23:40
[17 Nov at 16:23:52] Avvio app
[17 Nov at 16:23:52] STOP SENZA TAG sulla sveglia n. 1 (totale stop senza tag: 1, sveglie ancora programmate: 60)
[17 Nov at 16:24:12] STOP SENZA TAG sulla sveglia n. 2 (totale stop senza tag: 2, sveglie ancora programmate: 59)
[17 Nov at 16:24:45] SPEGNIMENTO COL TAG "prova" (sveglia in corso: si)
[17 Nov at 16:24:45] Errore cancellazione 56C04967-AFE5-4853-8BCD-C635828862E9: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:24:45] Cancellate 59 sveglie (tag)
[17 Nov at 16:27:14] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 16:28:13
[17 Nov at 16:28:16] STOP SENZA TAG sulla sveglia n. 1 (totale stop senza tag: 3, sveglie ancora programmate: 6)
[17 Nov at 16:28:47] STOP SENZA TAG sulla sveglia n. 2 (totale stop senza tag: 4, sveglie ancora programmate: 5)
[17 Nov at 16:29:17] STOP SENZA TAG sulla sveglia n. 3 (totale stop senza tag: 5, sveglie ancora programmate: 4)
[17 Nov at 16:29:46] STOP SENZA TAG sulla sveglia n. 4 (totale stop senza tag: 6, sveglie ancora programmate: 3)
[17 Nov at 16:30:18] STOP SENZA TAG sulla sveglia n. 5 (totale stop senza tag: 7, sveglie ancora programmate: 2)
[17 Nov at 16:30:46] SPEGNIMENTO COL TAG "prova" (sveglia in corso: si)
[17 Nov at 16:30:46] Errore cancellazione B7D36580-DAD6-41A6-B40A-5F66CCB531DE: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:30:46] Cancellate 2 sveglie (tag)
[17 Nov at 16:36:57] Catena programmata: 19 sveglie ogni 10 s per 3 min, prima alle 16:37:57
[17 Nov at 16:38:24] STOP SENZA TAG sulla sveglia n. 2 (totale stop senza tag: 8, sveglie ancora programmate: 18)
[17 Nov at 16:38:39] STOP SENZA TAG sulla sveglia n. 4 (totale stop senza tag: 9, sveglie ancora programmate: 17)
[17 Nov at 16:38:58] SPEGNIMENTO COL TAG "prova" (sveglia in corso: si)
[17 Nov at 16:38:58] Errore cancellazione 98BAC44F-D460-4256-9C89-7DAC9066C809: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:38:59] Errore cancellazione 06A705F5-D292-4231-83DE-3CC9D4BB79D9: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:38:59] Errore cancellazione 81D78E10-7E84-41A8-80D7-A8D36D5B7EEF: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:38:59] Errore cancellazione 3957150B-5236-411D-BEF4-921210417E4B: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:38:59] Errore cancellazione 539F4D0A-A4C7-4436-B0D1-EBCB86D08EC8: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:38:59] Cancellate 17 sveglie (tag)
[17 Nov at 16:39:22] SPEGNIMENTO COL TAG "Ca" (sveglia in corso: no)
[17 Nov at 16:39:30] Catena programmata: 19 sveglie ogni 10 s per 3 min, prima alle 16:40:30
[17 Nov at 16:40:35] SPEGNIMENTO COL TAG "Ca" (sveglia in corso: si)
[17 Nov at 16:40:35] Errore cancellazione 87CA12FE-3F77-4F49-8111-6F468DD30A23: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:40:35] Cancellate 19 sveglie (tag)
[17 Nov at 16:40:45] Catena programmata: 19 sveglie ogni 10 s per 3 min, prima alle 16:41:45
[17 Nov at 16:42:15] STOP SENZA TAG sulla sveglia n. 1 (totale stop senza tag: 10, sveglie ancora programmate: 18)
[17 Nov at 16:42:25] STOP SENZA TAG sulla sveglia n. 2 (totale stop senza tag: 11, sveglie ancora programmate: 17)
[17 Nov at 16:42:45] STOP SENZA TAG sulla sveglia n. 6 (totale stop senza tag: 12, sveglie ancora programmate: 16)
[17 Nov at 16:42:46] STOP SENZA TAG sulla sveglia n. 7 (totale stop senza tag: 13, sveglie ancora programmate: 15)
[17 Nov at 16:42:55] SPEGNIMENTO COL TAG "prova" (sveglia in corso: si)
[17 Nov at 16:42:55] Errore cancellazione 8CB0EF62-EF7A-4DD3-9CBD-3A57AFC79A2D: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:42:55] Errore cancellazione 1BEB6FB4-6F6B-4F17-8B1C-95B13EF5B536: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:42:55] Errore cancellazione 72FDECE9-5E53-4534-98BB-7F5745574390: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:42:55] Cancellate 15 sveglie (tag)
[17 Nov at 16:43:23] Catena programmata: 19 sveglie ogni 10 s per 3 min, prima alle 16:46:00
[17 Nov at 16:43:25] Cancellate 19 sveglie (nuova programmazione)
[17 Nov at 16:43:25] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 16:46:00
[17 Nov at 16:46:06] Avvio app
[17 Nov at 16:46:06] STOP SENZA TAG sulla sveglia n. 1 (totale stop senza tag: 14, sveglie ancora programmate: 6)
[17 Nov at 16:46:11] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:46:11] Cancellate 6 sveglie (tag)
[17 Nov at 16:46:37] Catena programmata: 61 sveglie ogni 30 s per 30 min, prima alle 16:47:36
[17 Nov at 16:46:41] SPEGNIMENTO COL TAG "prova" (sveglia in corso: no)
[17 Nov at 16:46:41] Cancellate 61 sveglie (tag)
[17 Nov at 16:47:14] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 16:48:14
[17 Nov at 16:49:19] STOP SENZA TAG sulla sveglia n. 1 (totale stop senza tag: 15, sveglie ancora programmate: 6)
[17 Nov at 16:49:59] SPEGNIMENTO COL TAG "prova" (sveglia in corso: si)
[17 Nov at 16:49:59] Errore cancellazione EDF8D39A-44FC-42F2-90C0-B1A68CE5BE0A: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:49:59] Errore cancellazione 06F30309-52E1-4F06-B196-09F29AB75090: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:49:59] Errore cancellazione 4E5BEDA0-A384-43AF-9C94-578274B1C478: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:49:59] Cancellate 6 sveglie (tag)
[17 Nov at 16:50:04] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 16:51:04
[17 Nov at 16:50:05] Cancellate 7 sveglie (nuova programmazione)
[17 Nov at 16:50:05] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 16:51:05
[17 Nov at 16:55:17] STOP SENZA TAG sulla sveglia n. 7 (totale stop senza tag: 16, sveglie ancora programmate: 6)
[17 Nov at 16:55:26] SPEGNIMENTO COL TAG "prova" (sveglia in corso: si)
[17 Nov at 16:55:26] Errore cancellazione 859433D0-B78D-41E7-9CD8-2CFD10197224: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:55:26] Errore cancellazione BAE8F242-13A3-4C7B-A895-C54346000C7A: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:55:26] Errore cancellazione E3EC518B-67B7-429D-946B-B7BE3637C1A9: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:55:26] Errore cancellazione E4C4062A-68EB-4E5D-B246-421F1B6F89DC: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:55:26] Errore cancellazione 12D2C3C5-8F38-43B7-BC44-48F3022D1FD0: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:55:26] Errore cancellazione 19DFB619-B16E-40B8-B8EC-8C670D789294: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 16:55:26] Cancellate 6 sveglie (tag)
[17 Nov at 16:56:50] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 16:57:50
[17 Nov at 16:59:31] STOP SENZA TAG sulla sveglia n. 1 (totale stop senza tag: 17, sveglie ancora programmate: 6)
[17 Nov at 17:00:14] STOP SENZA TAG sulla sveglia n. 5 (totale stop senza tag: 18, sveglie ancora programmate: 5)
[17 Nov at 17:00:26] STOP SENZA TAG sulla sveglia n. 6 (totale stop senza tag: 19, sveglie ancora programmate: 4)
[17 Nov at 17:01:02] STOP SENZA TAG sulla sveglia n. 2 (totale stop senza tag: 20, sveglie ancora programmate: 3)
[17 Nov at 17:01:10] SPEGNIMENTO COL TAG "prova" (sveglia in corso: si)
[17 Nov at 17:01:10] Errore cancellazione F4BF4EF3-B0F3-4B26-BE9E-98391AA0CDF3: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 17:01:10] Errore cancellazione 87E5F944-58DD-4EA2-9A38-F69C431E4FD5: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 17:01:10] Errore cancellazione F7FFABCE-5300-48FA-AE52-02BB2DAE647E: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[17 Nov at 17:01:10] Cancellate 3 sveglie (tag)
[18 Nov at 02:33:20] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 2:34:20
[18 Nov at 02:34:35] SPEGNIMENTO COL TAG "-" (sveglia in corso: si)
[18 Nov at 02:34:35] Errore cancellazione E3D19FAF-2A5F-499C-95B9-2BB25E570A7B: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[18 Nov at 02:34:35] Cancellate 7 sveglie (tag)
[18 Nov at 02:34:49] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 2:35:49
[18 Nov at 02:36:06] SPEGNIMENTO COL TAG "-" (sveglia in corso: si)
[18 Nov at 02:36:06] Errore cancellazione BED85EB9-E024-437A-8777-FE52DC6749FE: Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"
[18 Nov at 02:36:06] Cancellate 7 sveglie (tag)
[18 Nov at 14:13:24] Avvio app
[18 Nov at 14:13:58] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 14:14:58
[18 Nov at 14:16:31] STOP SENZA TAG sulla sveglia n. 4 (totale stop senza tag: 21, fermate anche 3 sovrapposte, sveglie ancora programmate: 3)
[18 Nov at 14:17:09] STOP SENZA TAG sulla sveglia n. 5 (totale stop senza tag: 22, fermate anche 0 sovrapposte, sveglie ancora programmate: 2)
[18 Nov at 14:18:02] STOP SENZA TAG sulla sveglia n. 6 (totale stop senza tag: 23, fermate anche 0 sovrapposte, sveglie ancora programmate: 0)
[18 Nov at 14:18:02] STOP SENZA TAG sulla sveglia n. 7 (totale stop senza tag: 24, fermate anche 0 sovrapposte, sveglie ancora programmate: 0)
[18 Nov at 14:18:12] SPEGNIMENTO COL TAG "prova" (sveglie in corso: 0)
[18 Nov at 14:18:15] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 14:19:15
[18 Nov at 14:22:24] SPEGNIMENTO COL TAG "prova" (sveglie in corso: 7)
[18 Nov at 14:22:24] Cancellate 7 sveglie (tag)
[18 Nov at 14:23:16] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 14:24:16
[18 Nov at 14:24:44] STOP SENZA TAG sulla sveglia n. 1 (totale stop senza tag: 25, fermate anche 0 sovrapposte, sveglie ancora programmate: 6)
[18 Nov at 14:24:51] SPEGNIMENTO COL TAG "Prova" (sveglie in corso: 1)
[18 Nov at 14:24:51] Cancellate 6 sveglie (tag)
[18 Nov at 14:24:58] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 14:13:00
[18 Nov at 14:25:02] Cancellate 7 sveglie (nuova programmazione)
[18 Nov at 14:25:03] Catena programmata: 7 sveglie ogni 30 s per 3 min, prima alle 14:26:02
[18 Nov at 14:26:25] STOP SENZA TAG sulla sveglia n. 1 (totale stop senza tag: 26, fermate anche 0 sovrapposte, sveglie ancora programmate: 6)
[18 Nov at 14:26:34] SPEGNIMENTO COL TAG "Prova" (sveglie in corso: 1)
[18 Nov at 14:26:34] Cancellate 6 sveglie (tag)
[18 Nov at 14:29:33] Sveglia singola alle 14:30:33 con test_lungo_3min.wav
[18 Nov at 14:34:55] STOP SENZA TAG sulla sveglia n. 1 (totale stop senza tag: 27, fermate anche 0 sovrapposte, sveglie ancora programmate: 0)
```
