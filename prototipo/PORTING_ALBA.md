# Porting in Alba: sveglia suonata dall'app + guardiano + catena di sicurezza

Questo documento riassume cosa è stato verificato sul telefono (iPhone 14 Pro, iOS 26.6) con il **Laboratorio** del prototipo il 20 novembre 2026, e cosa va portato in Alba.

Il codice di riferimento, già testato, è in [`prototipo/Sources/Laboratorio.swift`](Sources/Laboratorio.swift), classe `Lab`. I risultati dei singoli test sono in [`prototipo/TEST.md`](TEST.md), giri 3-6.

---

## 1. Il problema che risolve

Con AlarmKit, premendo un **tasto volume** la sveglia si zittisce ma resta "in corso": non suona più niente finché non si preme Stop. Chi vuole imbrogliare può quindi tornare a dormire. Da AlarmKit questo non si può intercettare.

Con il suono emesso **dall'app stessa**, invece, l'app vede ogni pressione dei tasti volume e rialza subito il volume. Questo però funziona solo se l'app è viva, cioè non sospesa. Da qui il guardiano e la catena AlarmKit di sicurezza.

## 2. Schema finale deciso con l'utente

| Momento | Cosa succede |
|---|---|
| Sera | L'utente imposta la sveglia. Il **guardiano** si attiva e tiene l'app viva tutta la notte |
| Orario − 15 min (se la progressiva è attiva) | **L'app** inizia a suonare a -60 dB e sale in modo continuo fino a 0 dB all'orario scelto |
| Orario (se la progressiva è spenta) | L'app suona subito al massimo |
| Orario + 5 min | Parte la **catena AlarmKit di sicurezza**, nascosta nell'interfaccia: sirena "punizione", una sveglia ogni 30 s |
| Tag NFC | Ferma il suono dell'app **e** cancella tutta la catena AlarmKit. Apple Music riparte se era stata la sveglia a fermarla |

- Se l'app è stata chiusa durante la notte, non c'è progressiva: suona solo la catena AlarmKit da +5 minuti. È un compromesso accettato.
- Se l'app è viva ma nessuno usa il tag entro +5 minuti, suonano **entrambe**: l'app e la sirena AlarmKit. È voluto ("punizione"). Lo Stop di AlarmKit ferma solo la sirena, non il suono dell'app.

## 3. Cosa è stato verificato sul telefono

| Cosa | Risultato | Test |
|---|---|---|
| Senza guardiano, schermo bloccato | **Non suona**: l'app viene sospesa e suona solo alla riapertura (ritardo di 72 s nel log) | L2 |
| Con guardiano, schermo bloccato | Suona puntuale (ritardo 0 s), anche usando altre app | L3, L4 |
| Guardiano vivo per tutta la durata del test | Sì, 15 minuti a schermo bloccato con "guardiano vivo" regolare nel log. **La notte intera è ancora da provare** | L10, L13 |
| Chiusura forzata dal multitasking | L'app muore, il guardiano si spegne e la sveglia sparisce (atteso) | L14 |
| Rialzare il volume di sistema dall'app (`MPVolumeView`) | **Funziona su iOS 26**, anche a schermo bloccato e anche tenendo premuto il tasto | L6, L8 |
| Progressiva continua (`AVAudioPlayer.volume`) | Funziona, salita regolare. Partenza ideale **-60 dB**: con -30 dB partiva troppo forte | L9, L10, P1, P2 |
| Apple Music in riproduzione | Va in pausa con `MPMusicPlayerController.systemMusicPlayer.pause()`, se l'utente ha dato il permesso | M4, M5 |
| Spotify o YouTube in riproduzione | **Non si fermano e non si abbassano** (ducking senza effetto) | M6 |
| La sveglia si interrompe? | No, dopo aver tolto il "piano B" (vedi trappola 1) | M7 |
| Uscita audio | Se è collegata una cassa o cuffia Bluetooth, il suono esce **lì** (JBL Flip 6 nel test) | L12 |
| Tag NFC | Funziona solo a telefono **sbloccato** (limite di iOS) | L11, 16 |

## 4. Cosa portare, pezzo per pezzo

### 4.1 Info.plist (`project.yml`)
```yaml
UIBackgroundModes: [audio]   # chiave di Info.plist, nessuna capability a pagamento: va bene col Personal Team
NSAppleMusicUsageDescription: "Alba mette in pausa Apple Music quando suona la sveglia e la fa ripartire quando la spegni."
```

### 4.2 Guardiano (`Lab.avviaGuardiano`, `Lab.preparaAudio`)
- Sessione `AVAudioSession` con categoria `.playback` e opzioni `[.mixWithOthers]`.
  - `mixWithOthers` è necessario: senza, sulla schermata di blocco compaiono i comandi di riproduzione con il tasto pausa, e le altre app audio ci interromperebbero.
- Un `AVAudioPlayer` con il suono della sveglia in loop (`numberOfLoops = -1`) a `volume = 0`. Un audio a volume zero è sufficiente: iOS non controlla se si sente.
- Un `Timer` da 1 secondo, che:
  - fa partire la sveglia all'ora giusta;
  - aggiorna il volume della progressiva;
  - salva `ultimoBattito` in UserDefaults.
- Se il player si ferma da solo (`!isPlaying`), il timer prova a fargli ripartire con `play()` e scrive nel log "audio FERMO" e "ripartito".
- Osserva `AVAudioSession.interruptionNotification`: quando l'interruzione finisce (`.ended`) chiama `setActive(true)` e poi `play()`.
- Osserva `routeChangeNotification` e scrive nel log l'uscita audio.

**Da aggiungere rispetto al Laboratorio** (non ancora testato):
- Salvare in modo persistente "guardiano attivo" e l'orario della prossima sveglia. Alla riapertura dell'app, ripristinarli automaticamente: il Laboratorio invece li perde.
- Se alla riapertura `ultimoBattito` è vecchio, segnalarlo all'utente ("Alba è stata chiusa alle …").
- La sera, quando c'è una sveglia per domani e il guardiano è spento, mostrare un avviso "Lascia Alba aperta in background".
- Opzionale: un avviso "Metti in pausa la musica prima di dormire" se `isOtherAudioPlaying` è vero quando si attiva il guardiano (vale per Spotify e YouTube, vedi M6).

### 4.3 Sveglia e progressiva (`Lab.inizia`, `Lab.aggiornaVolume`)
- Volume lineare in dB, come lo percepisce l'orecchio: `volume = 10^(dbIniziale·(1−p)/20)`, con `p` da 0 a 1 in 15 minuti e `dbIniziale = -60`.
- All'inizio della sveglia il volume di sistema va portato al 100% (vedi 4.4). È la progressiva del player a renderla dolce.
- Nel log conviene scrivere il volume in dB minuto per minuto: in percentuale i valori bassi risultano tutti "0%".

### 4.4 Volume bloccato (`Lab.volumeCambiato`, `Lab.impostaVolumeSistema`, `CursoreVolume`)
- KVO su `AVAudioSession.sharedInstance().outputVolume`, con il callback riportato sul main thread.
- Mentre la sveglia suona, se il volume scende sotto 0,99 va riportato a 1.
- Per cambiare il volume si imposta il `value` dell'`UISlider` dentro un `MPVolumeView`, con un ritardo di 0,05 s.
- Il `MPVolumeView` **deve stare nella gerarchia delle viste** (nel Laboratorio: `.background(CursoreVolume()...)` sulla TabView principale, 1×1 punto, opacità 0,01). Se manca, il cursore non si trova.

### 4.5 Musica (`Lab.zittisciAltreApp`, `Lab.ferma`)
- Quando la sveglia parte: se `systemMusicPlayer.playbackState == .playing`, chiamare `pause()` e ricordarselo.
- Allo spegnimento col tag, se era stata la sveglia a metterla in pausa, chiamare `systemMusicPlayer.play()`.
- Serve il permesso `MPMediaLibrary.requestAuthorization`: va chiesto durante la configurazione iniziale.
- Spotify e YouTube: non c'è niente di affidabile da fare da background.

### 4.6 Catena AlarmKit di sicurezza
- È la stessa catena già presente in Alba, ma programmata da **orario + 5 min**, con la sirena "punizione" e una sveglia ogni 30 s. Non va mostrata nell'interfaccia.
- Si programma insieme alla sveglia dell'app, cioè la sera, e non quando l'app inizia a suonare: se l'app muore deve esserci già.
- Il tag ferma il suono dell'app e cancella tutta la catena AlarmKit.
- Dal prototipo, giro 2 (vale ancora):
  - le sveglie AlarmKit non fermate **si accumulano**;
  - nello `stopIntent` vanno fermate anche quelle accumulate sotto;
  - su una sveglia che sta suonando basta `stop()`: un `cancel()` dopo restituirebbe l'errore Code=0.

## 5. Trappole già scoperte (da non ripetere)

1. **Mai disattivare la sessione audio (`setActive(false)`) mentre la sveglia deve suonare.** Da background non si riattiva: errore `560557684`, cioè `cannotInterruptOthers`. La sveglia è rimasta muta per 28 s finché l'utente non ha aperto l'app. `setActive(false, .notifyOthersOnDeactivation)` va chiamato solo **dopo** lo spegnimento col tag.
2. **Non usare una sessione "esclusiva" (senza `mixWithOthers`) per zittire la musica.** Da background non ha nessun effetto.
3. **Senza guardiano non esiste sveglia dell'app**, nemmeno a schermo appena bloccato: resta solo la catena AlarmKit.
4. **Il volume di sistema è uno solo.** Rialzandolo al 100% si alza anche la musica delle altre app, che non si riesce a fermare (Spotify, YouTube).
5. **Uscita Bluetooth:** con una cassa o cuffie collegate, il suono dell'app esce lì e non dall'altoparlante. Non è risolto: va almeno scritto nel log e segnalato all'utente. Una soluzione possibile (categoria `.playAndRecord` con `overrideOutputAudioPort(.speaker)`) non è testata e potrebbe richiedere il permesso del microfono. La catena AlarmKit invece suona dall'altoparlante.

## 6. Ancora da verificare dopo il porting
- **Una notte intera con il guardiano (L13):** il log deve avere un "guardiano vivo" ogni 10 minuti senza buchi, e serve il consumo di batteria (L15).
- **Il ripristino automatico del guardiano** alla riapertura dell'app.
- **Il comportamento insieme alla catena di sicurezza:** a +5 minuti suonano sia l'app sia AlarmKit, e il tag deve fermare entrambe.
- **Dopo un riavvio del telefono:** l'app non è viva finché non la apri, quindi deve suonare la catena AlarmKit.
