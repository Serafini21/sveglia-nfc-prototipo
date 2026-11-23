# Alba per Android (Galaxy S23)

La stessa sveglia dell'iPhone: si spegne solo avvicinando il telefono a un tag NFC lontano dal letto.
Pensata per il Samsung Galaxy S23 (Android 13 o più recente). Stesse regole, stessi suoni e colori dell'app iPhone.

## Cosa cambia rispetto all'iPhone

- **Niente «Vado a letto» e niente guardiano**: Android sveglia Alba all'orario anche se è chiusa.
- **Niente Comandi Rapidi e niente codice segreto**: il tag lo legge Alba direttamente.
- **Niente scadenza dei 7 giorni**: l'APK non scade, non serve reinstallarlo.
- **Niente Stop**: la sveglia suona finché non usi il tag o l'Emergency Stop. Sopra la schermata di blocco tocchi
  «Sblocca il telefono» (impronta o PIN) e avvicini il tag.
- **Tasti volume**: durante la sveglia non fanno niente; se il volume viene abbassato, Alba lo rimette al massimo.
- **Nuovo**: durante una sveglia e nelle 2 ore prima non si possono aggiungere tag.

La mattina: progressiva facoltativa da 15 minuti prima, all'orario la suoneria al massimo e la schermata a tutto
schermo, da T + 5 minuti la sirena, fino a 30 minuti. Le regole di Emergency Stop, posizione di casa, punteggio e
streak sono le stesse dell'iPhone.

## Build (GitHub Actions)

A ogni push su `main` che tocca `android/` il workflow **Build APK**:
1. esegue i test delle regole (`app/src/test`);
2. genera i suoni (`scripts/genera_suoni.py`, lo stesso dell'iPhone) e scarica i font;
3. compila e firma `Alba.apk` (artifact **Alba-apk**).

La firma usa i secrets `ALBA_KEYSTORE_BASE64` e `ALBA_KEYSTORE_PASSWORD`. La chiave originale è sul PC in
`C:\Users\seraf\Documents\ALBA-chiave-android`: **non perderla e non cambiarla**. Con una chiave diversa il telefono
rifiuta l'aggiornamento e bisogna disinstallare Alba, perdendo i dati. Lo stesso vale per l'ID `com.svegliatag.alba`.

## Installazione sul S23

1. Su GitHub apri l'ultima build **Build APK** con il pallino verde, scarica **Alba-apk** ed estrai `Alba.apk`.
2. Copia `Alba.apk` sul telefono (cavo, Google Drive o email a te stesso).
3. Sul telefono: *Impostazioni › Sicurezza e privacy › Blocco automatico* → **spento** (altrimenti l'installazione
   viene bloccata). Puoi riattivarlo dopo, ma va rispento a ogni aggiornamento.
4. Apri `Alba.apk` da *Archivio* e consenti **Installa app sconosciute** per *Archivio*.
5. Per aggiornare: installa il nuovo `Alba.apk` sopra il vecchio. Dati e log restano.

## Configurazione al primo avvio

1. Consenti le **notifiche**.
2. Nella scheda **Impostazioni › Telefono** tutte le righe devono dire «✓ a posto». Tocca quelle rosse:
   - **Notifiche a schermo intero**: accendono lo schermo e mostrano la sveglia sopra il blocco;
   - **Batteria senza restrizioni**: rispondi «Consenti»;
   - **NFC attivo**.
3. In *Impostazioni di Android › Batteria › Limiti utilizzo in background › App mai in sospensione* aggiungi Alba.
4. In **Non disturbare** e **Modalità sonno** lascia consentite le sveglie (è così di base).
5. Scheda **Tag** › **Aggiungi**: dai un nome, poi appoggia il tag **al centro del retro** del telefono.
6. Tocca **Prova** sul tag: deve comparire «Funziona!».

Non usare mai **Arresto forzato** su Alba: cancella le sveglie programmate. Chiuderla dal multitasking invece va bene.

## Da provare la prima volta

Nella modalità sviluppatore (5 tocchi sul titolo «Sveglie») programma una **mattina di test tra 2 minuti**,
blocca il telefono e aspetta: deve accendersi lo schermo, suonare, e il tag deve spegnerla dopo lo sblocco.
Poi una notte vera e una prova dopo aver riavviato il telefono (le sveglie devono esserci ancora).

## File

| File | Cosa fa |
|---|---|
| `app/src/main/java/.../Modello.kt` | Cosa viene salvato: sveglie, tag, mattine, impostazioni. |
| `Regole.kt` | Le regole: orari, punteggio, crediti, distanza da casa (stesse dell'iPhone). |
| `Store.kt` | Salva e legge i dati sul telefono; il diario degli eventi (log). |
| `Motore.kt` | Programma le sveglie di sistema e gestisce tag, Emergency, salvataggi. |
| `ServizioSveglia.kt` | Suona la sveglia: progressiva, suoneria, sirena, volume al massimo. |
| `AlbaApp.kt` | Avvio dell'app; riprogramma dopo riavvio, aggiornamento, cambio d'ora. |
| `MainActivity.kt` | Lettura del tag NFC, schermata sopra il blocco, schede e navigazione. |
| `Home.kt`, `Mattino.kt`, `Altre.kt` | Le schermate. |
| `Telefono.kt` | Controlli delle impostazioni del telefono; ascolto delle suonerie. |
| `Tema.kt`, `Formati.kt` | Colori, caratteri, date in italiano. |
| `app/src/test/.../RegoleTest.kt` | I controlli automatici sulle regole. |
