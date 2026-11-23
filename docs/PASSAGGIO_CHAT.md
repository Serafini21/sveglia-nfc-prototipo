# Passaggio a una nuova chat – App «Alba»

Aggiornato al 23 novembre 2026. Contiene tutto quello che serve per continuare il lavoro su Alba in una chat nuova.

## Come usarlo

1. Apri la nuova chat sulla cartella `C:\Users\seraf\Documents\ALBA`: è il repository https://github.com/Serafini21/sveglia-nfc-prototipo (branch `main`). La vecchia copia in `AppData\Local\Claude-Data\…\scratch-workspaces` non va più usata.
2. Allega o incolla questo file e scrivi: «Leggi questo file e riprendi il lavoro su Alba».
3. Poi la nuova chat deve leggere `docs/PROGETTO.md`. È la fonte di verità su funzioni, regole e scelte tecniche.

## Il progetto in breve

«Alba» è una sveglia per iPhone che si spegne **solo** avvicinando il telefono a un tag NFC lontano dal letto. È per uso personale e familiare, senza App Store.

Documenti nel repository:

- `LEGGIMI.md`: cosa c'è in ogni cartella, in parole semplici. Va aggiornato se si aggiungono o spostano file.
- `docs/PROGETTO.md`: riferimento completo, cioè vincoli, architettura, regole e grafica.
- `README.md`: istruzioni d'uso e d'installazione.
- `archivio/REPORT_PROTOTIPO.md`: cosa ha dimostrato il primo prototipo su AlarmKit.
- `archivio/prototipo/PORTING_ALBA.md`: cosa ha dimostrato il «Laboratorio» (guardiano audio, progressiva, volume, Apple Music). È già stato tutto portato in Alba.
- `archivio/TEST_FASE1.md`, `archivio/TEST_FASE2.md`, `archivio/prototipo/TEST.md`: i test fatti sul telefono.

## Regole di lavoro (sempre valide)

- **Lingua:** italiano, testi brevi e semplici, sia nelle risposte sia nell'app.
- **Niente Mac:** l'utente usa solo Windows. Il progetto si genera con XcodeGen (`project.yml`) e si compila su GitHub Actions.
- **Swift 5**, SwiftUI, **iOS 26.1 minimo**, nessuna dipendenza esterna.
- **Nessuna capability a pagamento** (Personal Team gratuito): niente Core NFC, App Groups, Push, iCloud, widget o estensioni. Un solo target.
- **Bundle ID `com.svegliatag.alba`: non va MAI cambiato**, perché si perderebbero tutti i dati e si consumerebbe un App ID.
- **Pubblicare solo con un okay esplicito.** Niente commit né push finché l'utente non scrive «pubblica», «vai pubblica» o simili. Un push fatto senza okay è già stato bloccato una volta.
- I commit finiscono con la riga `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Privacy:** mai condividere l'email dell'utente e mai scrivere le coordinate di casa nel log (solo la distanza).
- **Modifiche grafiche:** seguono una procedura decisa dall'utente:
  1. l'utente detta una lista di modifiche e io la annoto soltanto;
  2. al suo «ok» le applico al mockup sul canvas;
  3. all'«ok definitivo» le porto nell'app.
- Prima di cambiare qualcosa che ha più soluzioni possibili, fare le domande necessarie.

## Come si compila e s'installa

- Ogni push su `main` avvia il workflow **«Build IPA»** (`.github/workflows/build.yml`, runner `macos-26`). Il workflow:
  1. compila ed esegue i test delle regole (`swiftc` con `Alba/Modello.swift`, `Alba/Regole.swift`, `Tests/main.swift`);
  2. scarica i font;
  3. genera i suoni (`scripts/genera_suoni.py`);
  4. genera il progetto con xcodegen;
  5. compila senza firma e crea l'IPA.
- I file `.md` non avviano la build.
- L'IPA si trova nell'artifact **`Alba-ipa`**. Il numero di build è il `run_number` di GitHub.
- Comandi utili:
  ```powershell
  gh run list --workflow "Build IPA" -L 3
  ```
  ```powershell
  gh run watch <id>
  ```
  ```powershell
  gh run download <id> -n Alba-ipa
  ```
  Per trovare la run di un commit preciso, filtra `headSha` in `gh run list --json`: `--commit` non ha funzionato.
- **Installazione:** con Sideloadly e un Apple ID gratuito. L'app **scade dopo 7 giorni** e va reinstallata. L'app avvisa in anticipo (`Scadenza.swift`).
- Il «Laboratorio» (`archivio/prototipo/`, bundle `com.svegliatag.prototipo`) ha un workflow a parte, «Build prototipo», con artifact `SvegliaNFC-ipa`.

## Stato attuale

- **Ultima build che cambia l'app: 12**, commit `0be8a79`, pubblicata il 23 novembre 2026. Tutti i 100 test passano. L'IPA è stato mandato all'utente.
- **Build 13** (23 novembre 2026): solo riordino della cartella (`archivio/`, `LEGGIMI.md`, questo file, percorsi aggiornati nei due workflow). L'app è uguale alla build 12, quindi non serve reinstallarla.
- **Testata sul telefono:** iPhone 14 Pro con iOS 26.6. I log delle build 10 e 11 dicono:
  - il guardiano resta vivo tutta la notte (segnale «vivo» ogni 10 minuti, nessun buco);
  - la sveglia suona puntuale;
  - il volume viene rialzato;
  - il tag ferma sia l'app sia la catena.
  - La batteria non è stata misurata, perché il telefono era in carica.
- **Ancora da verificare sul telefono:**
  - la curva nuova della progressiva;
  - il suono separato della progressiva;
  - l'Emergency fuori casa (la posizione di casa vale solo 12 ore dopo averla salvata);
  - la grafica della build 12.
- **Compatibilità:** serve **iOS 26.1 o successivo** (AlarmKit). Un iPhone 15 con iOS 18.7.8 non va: deve prima aggiornare a iOS 26.1 o successivo. Portare l'app su iOS 18 è sconsigliato.

## Cosa fa l'app adesso (build 12)

- **Sveglie:** ripetute o una tantum. Sono bloccate nelle 2 ore prima: per modificarle serve il tag. Niente snooze.
- **«Vado a dormire ora»:** propone orari calcolati sui cicli di sonno (15 minuti per addormentarsi, cicli da 90 minuti, consigliati 5). Si può ritoccare l'orario di ±1 minuto. Dopo il salvataggio preme da sola «Vado a letto».
- **Guardiano e «Vado a letto»:**
  - Il guardiano parte solo con il pulsante «Vado a letto».
  - Tiene l'app viva di notte con un audio muto in loop e alla sveglia suona dall'app.
  - Alza il volume di sistema e blocca i tasti volume.
  - Mette in pausa Apple Music e la fa ripartire dopo il tag.
  - Si ferma a sveglia conclusa.
  - Se l'app viene chiusa, una notifica «a uomo morto» avvisa entro 20 minuti.
  - **9 ore prima di ogni sveglia** arriva una notifica che ricorda di premere «Vado a letto».
- **Sveglia progressiva:**
  - parte 15 minuti prima dell'orario;
  - nei primi 10 minuti sale piano, da −60 a −40 dB (−50 dB al minuto 5), poi cresce sempre più forte fino a 0 dB;
  - ha un suono suo, scelto nella schermata «Sveglia progressiva» che si apre toccando la scritta nella Home (default «Alba», tra i suoni dolci);
  - all'orario passa alla suoneria della sveglia.
- **Catena AlarmKit di sicurezza:** parte **5 minuti dopo l'orario** (1 minuto nelle mattine di test) con la sirena. Suona anche se l'app è stata chiusa.
- **Spegnimento con il tag:** un'automazione NFC di Comandi Rapidi esegue l'App Intent «Spegni sveglia», che usa un codice segreto. Uno Stop seguito dal tag entro 60 secondi non costa punti.
- **Emergency Stop:**
  - **massimo 1 credito**, che si ricarica 7 giorni dopo l'uso;
  - richiede di dire una frase e di tenere premuto il pulsante;
  - **fuori casa** (oltre 150 metri dalla posizione di casa) si spegne senza credito;
  - la posizione si legge solo con l'app aperta.
- **Posizione di casa:** si imposta da Impostazioni (precisione ≤ 100 metri). Una nuova posizione vale dopo 12 ore.
- **Altro:** statistiche, punteggio, streak, schermata «Buongiorno!», rilevamento dei trucchi (tasti volume, orologio).
- **Modalità sviluppatore:** si apre con 5 tocchi sul titolo della Home. Offre una mattina di test, il log condivisibile, lo stato del guardiano e altre prove.
- **Home (build 12):**
  - nella riga «Prossima sveglia», in alto a destra, c'è il lucchetto («Bloccata» oppure «dalle HH:MM»);
  - sotto ci sono l'interruttore «Sveglia progressiva 15 min», con chevron che apre le opzioni, e il pulsante «Vado a letto».

## Mappa del codice (`Alba/`)

| File | Cosa contiene |
|---|---|
| `AlbaApp.swift` | Avvio, `StatoApp` (stato condiviso della UI), aggancio del cursore volume |
| `Modello.swift` | Dati `Codable`: sveglie, mattine, tag, impostazioni (`suonoProgressiva`, `casa`…), `Suoneria` |
| `Regole.swift` | Logica pura e testata: costanti, piano della mattina, curva dB, crediti, casa/distanza, punteggi |
| `Store.swift` | Unico file JSON versionato, accesso serializzato |
| `AlarmEngine.swift` | Unico punto che parla con AlarmKit: pianifica, riallinea, ferma, Emergency |
| `Guardiano.swift` | Guardiano audio, «Vado a letto», promemoria 9 h, volume di sistema, Apple Music |
| `Posizione.swift` | Lettura della posizione (solo ad app aperta) |
| `Intents.swift` | App Intent: spegni con tag, Stop, Emergency |
| `Scadenza.swift` | Data di scadenza del certificato e notifiche di promemoria |
| `EventLog.swift` | Log diagnostico esportabile |
| `UI/Home.swift` | Home, `InterruttoreProgressiva`, `ProgressivaView` (opzioni della progressiva) |
| `UI/Dormire.swift` | «Vado a dormire ora» |
| `UI/ModificaSveglia.swift` | Nuova/modifica sveglia, `SceltaSuoneria` |
| `UI/Mattino.swift` | Sveglia in corso, Emergency, risveglio |
| `UI/Impostazioni.swift` | Impostazioni, crediti, `ImpostaCasaView` |
| `UI/Statistiche.swift`, `UI/TagView.swift`, `UI/Sviluppatore.swift`, `UI/Anteprima.swift`, `UI/Tema.swift` | Statistiche, tag, modalità sviluppatore, ascolto delle suonerie, colori e font |

Altri file:

- `Tests/main.swift`: 100 controlli sulle regole.
- `scripts/genera_suoni.py`: 8 suoni WAV.
- `scripts/genera_icona.py`: icona.
- `project.yml`: configurazione XcodeGen. Contiene `UIBackgroundModes: [audio]` e i testi dei permessi di Apple Music e della posizione.

## Trappole tecniche da ricordare

- **AlarmKit:**
  - le sveglie non fermate restano `.alerting` e si accumulano, quindi bisogna fermarle **tutte**;
  - una sveglia `.alerting` si ferma con `stop`, tutte le altre con `cancel`;
  - i tasti volume zittiscono senza fermare (bug di iOS FB22686646);
  - Face ID non sblocca mentre la sveglia suona.
- **Guardiano:**
  - **mai** `setActive(false)` sulla sessione audio prima della sveglia, perché da background non si riattiva;
  - la sessione usa `.playback` + `.mixWithOthers`, più `.duckOthers` solo mentre suona;
  - il volume di sistema si alza con il cursore di un `MPVolumeView` agganciato alla finestra.
- **Compatibilità dei dati:**
  - i nuovi campi di `Impostazioni` e di `ParametriMattina` sono opzionali, così i dati vecchi si leggono ancora;
  - `ritardoCatenaSec == nil` indica una mattina vecchia, con la catena che parte all'orario.
- **Posizione:** si usano `CLServiceSession(authorization: .whenInUse)` e `CLLocationUpdate.liveUpdates()`. Niente geofence né posizione in background (scelta dell'utente: «controllo al momento»).

## Grafica e canvas di design

- Canvas: https://claude.ai/artifact/LBxxxAfXAcQPRT7VomZzWW (privato dell'utente). Ha due pagine:
  - «Mockup approvato»: l'originale, da non toccare;
  - «App attuale (build 11)»: si apre all'avvio ed è allineata alla build 12.
- Schermate della pagina «App attuale»:
  - Home;
  - Sveglia progressiva (opzioni);
  - Vado a dormire ora;
  - Modifica sveglia;
  - I miei tag;
  - Sveglia in corso;
  - Emergency Stop;
  - Buongiorno!;
  - Statistiche;
  - Impostazioni;
  - Posizione di casa.
- Per modificarlo:
  1. leggere prima il canvas (Artifact, azione `read`);
  2. cambiare i file `project/B11-*.dc.html` e, se serve, `project/canvas.json`;
  3. ripubblicare sullo stesso URL.
- Colori e font sono in `docs/PROGETTO.md` §7 e in `Alba/UI/Tema.swift`: ambra `#FFB547`, sfondo notte `#0B1020`, Space Grotesk per titoli e orari, Inter per il testo.

## Cronologia in breve

1. **Prototipo AlarmKit**: ha verificato cosa fa iOS (`archivio/REPORT_PROTOTIPO.md`).
2. **Fase 1**: il cuore dell'app (Store, AlarmEngine, tag, Emergency, regole con test).
3. **Fase 2**: grafica del mockup, «Vado a dormire ora», suonerie, statistiche.
4. **Laboratorio** (20 novembre 2026): guardiano audio, sveglia suonata dall'app, progressiva continua, volume, Apple Music.
5. **Build 10**: Laboratorio portato in Alba, guardiano solo con «Vado a letto», promemoria 9 ore prima, catena di sicurezza da +5 minuti, icona.
6. **Build 11** (scelte dell'utente):
   - progressiva più lenta;
   - suono della progressiva separato e unico;
   - posizione di casa con «controllo al momento»;
   - Emergency con 1 credito.
7. **Build 12** (prima tornata di modifiche grafiche):
   - le opzioni della progressiva si aprono toccandone la scritta;
   - il lucchetto è in alto a destra nella scheda (risposta «A» dell'utente);
   - tolto «Come l'ultima volta» da «Vado a dormire ora».

## Possibili prossimi passi (solo se l'utente li chiede)

- Nuove modifiche grafiche, con la procedura in tre passi (lista → ok sul mockup → ok definitivo nell'app).
- Analisi del prossimo log del telefono. Da controllare:
  - la curva nuova;
  - le righe «ora suona …»;
  - l'Emergency fuori casa dopo le 12 ore.
- Guida scritta per installare Alba sull'iPhone di un amico. È stata offerta ma non ancora richiesta. L'amico deve avere iOS 26.1 o successivo.
- Fase 3 di `docs/PROGETTO.md`: modalità senza tag, backup, rifiniture.

## Trascrizione completa della chat precedente

Se serve un dettaglio preciso (testo esatto, codice, errori), la trascrizione è su questo PC:
`C:\Users\seraf\.claude\projects\C--Users-seraf-AppData-Local-Claude-Data-claude-pzs8sxrjxfjjc-scratch-workspaces-37f3ecce-4817-490f-b5a7-fe533131bb0c-9d4b4582-198c-42ab-be02-d9b54ba00700-scratch-2026-11-17-8021b6\d870f908-71dd-414f-9624-f5b0d78cb383.jsonl`
