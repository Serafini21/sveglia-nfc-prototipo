# Alba – sveglia che si spegne con un tag NFC

App per iPhone (iOS 26.1+): la sveglia si spegne solo avvicinando il telefono a un tag NFC lontano dal letto. È per uso personale, installata con un Apple ID gratuito tramite Sideloadly, senza Mac.

- Progetto completo e regole: [`docs/PROGETTO.md`](docs/PROGETTO.md)
- Cosa abbiamo verificato con il prototipo: [`REPORT_PROTOTIPO.md`](REPORT_PROTOTIPO.md)
- Checklist dei test: [`TEST_FASE1.md`](TEST_FASE1.md) e [`TEST_FASE2.md`](TEST_FASE2.md)
- Il prototipo è in [`prototipo/`](prototipo/) come riferimento e non fa parte della build.

## Build (GitHub Actions)

A ogni push su `main` il workflow **Build IPA**:
1. esegue i test delle regole (`Tests/main.swift`, compilati con `swiftc`);
2. genera i suoni (`scripts/genera_suoni.py`) e il progetto Xcode (XcodeGen, da `project.yml`);
3. compila senza firma e crea `Alba.ipa`.

Le modifiche ai soli file `.md` non avviano la build. Si può avviare anche a mano: *Actions › Build IPA › Run workflow*. Il numero della build compare in *Impostazioni › Versione*.

## Installazione e aggiornamento (Windows)

1. Apri la build più recente con il pallino verde, scarica l'artifact **Alba-ipa** ed estrai `Alba.ipa`.
2. Collega l'iPhone con il cavo e sbloccalo. In **Sideloadly** trascina `Alba.ipa`, usa sempre lo **stesso Apple ID** e premi **Start**.
3. Alla prima installazione autorizza il profilo in *Impostazioni › Generali › VPN e gestione dispositivi*. Serve anche la **Modalità sviluppatore** attiva.
4. Reinstalla almeno ogni 6 giorni, anche senza modifiche: con l'Apple ID gratuito l'app scade dopo 7. Alba mostra la scadenza in *Impostazioni* e manda un promemoria 2 giorni prima e il giorno prima.

Il Bundle ID è `com.svegliatag.alba` e **non va mai cambiato**: cambiarlo cancellerebbe tutti i dati e consumerebbe uno dei 10 App ID settimanali. Reinstallando sopra la versione precedente, dati e log restano.

## Configurazione al primo avvio

1. Concedi il permesso **Sveglie** (obbligatorio) e le **notifiche** (servono per i promemoria di scadenza).
2. Scheda **Tag** › **Aggiungi tag**. La guida mostra il **codice segreto**, uguale per tutti i tag, con i pulsanti per copiarlo.
3. Crea l'automazione in **Comandi Rapidi**:
   1. *Automazione* › **+** › **NFC** › **Scansiona** e avvicina il tag; usa lo stesso nome dato in Alba.
   2. Scegli **Esegui immediatamente**, poi **Avanti** › **Nuova automazione vuota** › **Aggiungi azione** e cerca **Alba** › **Spegni sveglia**.
   3. Nell'azione compila **Nome tag**, uguale a quello registrato in Alba, e **Codice segreto**, incollato dall'app. Tocca **Fine**.
4. Torna in Alba e tocca **Prova**: avvicinando il tag deve comparire «Funziona!».

Il tag funziona solo a **telefono sbloccato**, e mentre la sveglia suona Face ID non sblocca. Quindi la sequenza è: **Stop**, sblocco, tag entro **60 secondi** (senza penalità). Senza il codice giusto l'azione viene rifiutata e registrata come tentativo sospetto.

## Come funziona una mattina

- **Progressiva** (interruttore nella Home): 15 sveglie, una al minuto, da 15 minuti prima, con il suono dolce sempre più forte (da −30 a 0 dB).
- **Principale** all'orario, poi la **catena**: una sveglia ogni 30 s per 30 minuti. Dalla 5ª, cioè dopo circa 2 minuti, suona la **sirena di punizione**.
- **Stop** (pulsante o tasto laterale) ferma tutto ciò che suona, ma la catena continua: serve il tag. I **tasti volume** non fermano la sveglia: le successive suonano mute e la mattina risulta «fallita – volume».
- **Tag** nelle 2 ore prima: la mattina viene annullata in anticipo e conta come riuscita. Nelle stesse 2 ore la sveglia non si può modificare senza tag.
- **Emergency Stop**: dall'app o dal pulsante **Emergenza** sulla sveglia. Si scrive «Sono sveglio e mi alzo» e si tiene premuto 10 s. Ha 2 crediti al massimo (1 all'inizio, +1 ogni 7 giorni) e azzera lo streak.
- Alba tiene programmate le **prossime 2 mattine**. Se iOS rifiuta così tante sveglie, la seconda viene ridotta e il log lo segnala.

## Modalità sviluppatore

Tocca 5 volte il titolo «Sveglie» nella Home. Contiene:
- catena breve configurabile;
- «mattina di test tra N minuti»;
- «sveglia tra N giorni» (per il test della scadenza);
- mini-test della progressiva;
- simula tag (solo sulle mattine di test);
- stato di AlarmKit e log completo.

## Struttura

```
Alba/                 codice dell'app (un solo target, nessuna estensione)
  Modello.swift         dati salvati (JSON versionato)
  Regole.swift          logica pura: piano della mattina, esiti, punteggio, streak, crediti, blocco
  Store.swift           attore che legge e scrive alba.json in modo atomico
  EventLog.swift        log con millisecondi e rotazione a 500 KB
  AlarmEngine.swift     unico punto che usa AlarmKit: programma, riallinea, Stop, tag, Emergency
  Intents.swift         Spegni sveglia (tag), stopIntent, pulsante Emergenza, frase per Siri
  Scadenza.swift        scadenza da embedded.mobileprovision e promemoria
  UI/                   schermate SwiftUI nei colori Alba
Tests/main.swift      test delle regole (girano su GitHub Actions prima della build)
scripts/genera_suoni.py   suoni WAV generati a ogni build
docs/PROGETTO.md      progetto di riferimento
prototipo/            codice del prototipo (solo riferimento)
```
