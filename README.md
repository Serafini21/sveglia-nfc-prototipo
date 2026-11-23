# Alba – sveglia che si spegne con un tag NFC

App per iPhone (iOS 26.1+): la sveglia si spegne solo avvicinando il telefono a un tag NFC lontano dal letto. È per uso personale, installata con un Apple ID gratuito tramite Sideloadly, senza Mac.

- Cosa c'è in ogni cartella: [`LEGGIMI.md`](LEGGIMI.md)
- Progetto completo e regole: [`docs/PROGETTO.md`](docs/PROGETTO.md)
- Lavoro finito (primo prototipo, Laboratorio, test delle fasi 1 e 2): [`archivio/`](archivio/), non fa parte della build.

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

- **«Vado a letto»** (nella scheda della prossima sveglia): accende il **guardiano**, che tiene Alba viva in background fino alla sveglia (audio a volume zero). 9 ore prima di ogni sveglia arriva un promemoria per premerlo. **Non chiudere Alba dal multitasking**: se si chiude arriva una notifica.
- **La sveglia la suona l'app**, con la suoneria scelta. Con la **progressiva** (interruttore nella Home, con il suo suono) parte 15 minuti prima a −60 dB: per 10 minuti sale piano fino a −40 dB, poi sempre più forte fino al massimo all'orario, quando passa alla suoneria. I tasti volume non funzionano e Apple Music va in pausa.
- **Posizione di casa** (Impostazioni): fuori casa, oltre 150 m, l'Emergency Stop non usa il credito e lo streak resta in pausa. Una nuova posizione vale dopo 12 ore.
- **Sirena di sicurezza**: dall'orario + 5 minuti, una sveglia AlarmKit ogni 30 s per 30 minuti. Suona anche se Alba è stata chiusa o se non hai premuto «Vado a letto».
- **Stop** sulla sirena ferma solo la sirena, che risuona 30 s dopo: serve il tag. I **tasti volume** sulla sirena la zittiscono ma la mattina risulta «fallita – volume».
- **Tag** nelle 2 ore prima: la mattina viene annullata in anticipo e conta come riuscita. Nelle stesse 2 ore la sveglia non si può modificare senza tag.
- **Emergency Stop**: dall'app o dal pulsante **Emergenza** sulla sveglia. Si scrive «Sono sveglio e mi alzo» e si tiene premuto 10 s. Ha 1 credito al massimo, che si ricarica 7 giorni dopo averlo usato, e azzera lo streak. Fuori casa non consuma il credito.
- Alba tiene programmate le **prossime 2 mattine**. Se iOS rifiuta così tante sveglie, la seconda viene ridotta e il log lo segnala.

## Modalità sviluppatore

Tocca 5 volte il titolo «Sveglie» nella Home. Contiene:
- catena breve configurabile;
- «mattina di test tra N minuti»;
- «sveglia tra N giorni» (per il test della scadenza);
- stato del guardiano e uscita audio, prova del volume al massimo;
- simula tag (solo sulle mattine di test);
- stato di AlarmKit e log completo.

## Struttura

Vedi [`LEGGIMI.md`](LEGGIMI.md): spiega ogni cartella e ogni file del codice in parole semplici.
