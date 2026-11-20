# Checklist test sul telefono

Dopo ogni test: scheda **Log** → **Condividi log** e incolla il testo nella chat.
Prima dei test con la catena, per non aspettare 30 minuti, tocca **Catena breve: 3 minuti**: sono 7 sveglie, dalla 5ª alla 7ª con la sirena.

| # | Test | Come | Risultato atteso | Risultato |
|---|---|---|---|---|
| 1 | Installazione | Sideloadly → autorizza il profilo → apri l'app → "Chiedi autorizzazione" | L'app si apre, stato "concessa", nel log compaiono "Avvio app" e "Autorizzazione: concessa" | |
| 2 | Sveglia ad app chiusa, bloccato, in silenzioso | "Test: sveglia tra 1 minuto" → chiudi l'app dal multitasking → interruttore silenzioso attivo → blocca il telefono | Dopo circa 1 minuto suona a schermo intero con il suono "normale" (bip-bip), anche in silenzioso | |
| 3 | Stop dal pulsante di sistema | Durante il test 2 premi **Stop** sulla sveglia | Si ferma e dopo **30 s** suona la sveglia 2/7. Nel log: "STOP SENZA TAG sulla sveglia n. 1" e il contatore sale | |
| 4 | Stop con i tasti fisici | Quando suona, premi il **tasto laterale** (poi in un altro giro i **tasti volume**) | Annota cosa succede: si ferma? Riparte dopo 30 s? Nel log compare "STOP SENZA TAG"? | |
| 5 | Suoneria punizione | Lascia andare la catena breve fermando ogni volta con Stop | Le sveglie 1-4 hanno il bip normale. **Dalla 5ª** suona la sirena e il titolo è "PUNIZIONE 5/7 - usa il tag!" | |
| 6 | Simula tag | Durante una sveglia apri l'app → **Simula tag** | La sveglia si ferma, "Sveglie programmate: 0", nel log "SPEGNIMENTO COL TAG" e "Cancellate N sveglie (tag)" | |
| 7 | Azione di Comandi Rapidi a mano | Avvia la catena, poi in Comandi Rapidi tocca **Spegni sveglia** (vedi README §4) | Compare "Sveglia spenta, N sveglie cancellate" senza aprire l'app. Nell'app: 0 sveglie | |
| 8a | Tag vero, telefono sbloccato | Quando suona, sblocca e avvicina il tag | Si ferma tutto entro pochi secondi, nel log c'è il nome del tag | |
| 8b | Tag vero, telefono bloccato | Quando suona, **senza sbloccare**, avvicina il tag | Annota: funziona? iOS chiede di sbloccare? Quanto ci mette? | |
| 9 | Dopo un riavvio | Imposta una sveglia tra 5 minuti → spegni e riaccendi l'iPhone → sbloccalo una volta → bloccalo | Suona all'orario. Annota anche se suona **senza** aver mai sbloccato dopo il riavvio | |
| 10 | Durata del suono lungo | "Test suono lungo (3 min) tra 1 minuto" e **non** fermarla. Cronometra | Il volume cresce. Ogni 30 s ci sono bip acuti: 1 bip a 0:30, 2 a 1:00 … 5 a 2:30. Annota: dopo quanto si interrompe? Ricomincia piano (loop)? La sveglia si spegne da sola? | |
| 11 | Sveglia non fermata (sovrapposizione) | Catena breve, **non toccare niente** | Annota: la sveglia 1 suona finché arriva la 2? Si sovrappongono? Quanto dura una singola sveglia se nessuno la ferma? | |
| 12 | Limite di sveglie | Durata 30 min, intervallo 30 s → "Imposta sveglia" | Nel log: "Catena programmata: 61 sveglie…" oppure "LIMITE AlarmKit raggiunto dopo N sveglie" (in quel caso mandami N) | |

## Giro 2 (dopo i risultati del 17 novembre)

Cosa abbiamo scoperto nel giro 1:
- Se una sveglia non viene fermata, AlarmKit **non** la spegne: quando arriva la successiva, la vecchia resta "in corso" sotto la nuova, e le sveglie si accumulano. Per questo, premendo Stop, ripartiva "subito" una sveglia vecchia (nel log: stop n.6 e poi n.2). Gli "Errore cancellazione Code=0" erano innocui: compariva un errore per ogni sveglia accumulata.
- Ora, quando premi Stop, l'app ferma anche le sveglie accumulate sotto. Dopo uno Stop dovrebbe esserci silenzio fino alla prossima sveglia programmata, cioè al massimo 30 s.
- La catena da 61 sveglie è accettata e non c'è nessun limite.
- La carta d'identità elettronica quasi certamente presenta all'iPhone un identificativo **diverso a ogni lettura**, per privacy. Per questo l'automazione NFC non riconosce mai "lo stesso tag". Con un vero tag NTAG il problema non c'è.

| # | Test | Come | Risultato atteso | Risultato |
|---|---|---|---|---|
| 13 | Stop con sveglie accumulate | Catena breve, lascia suonare senza toccare per circa 1,5 min (si accumulano 3-4 sveglie), poi premi **Stop** una volta | Silenzio fino alla prossima sveglia programmata. Nel log: "fermate anche N sovrapposte" con N ≥ 1 | |
| 14 | Tasto laterale (accensione) | Quando suona premi il tasto laterale | Come Stop: nel log "STOP SENZA TAG" e silenzio fino alla prossima | |
| 15 | **Buco del volume** | Quando suona premi un tasto **volume** e poi **non toccare niente per 5 minuti** | Annota: suona di nuovo qualcosa in quei 5 minuti? Se resta tutto muto, il volume è un modo per imbrogliare | |
| 16 | Tag vero | Come i test 8a e 8b, con il tag NTAG | La sveglia si ferma. Nel log: "SPEGNIMENTO COL TAG" con il nome del tag e "sveglie in corso: N" | |
| 17 | Suono lungo | Il test 10 non è stato fatto | Vedi il test 10 | |

Note libere:


## Giro 3: Laboratorio (sveglia dall'app, senza AlarmKit)

Nuova scheda **Laboratorio**, la prima a sinistra. Qui la sveglia la suona l'app stessa, non AlarmKit.
**Durante questi test tieni una sveglia di riserva**: questa sveglia funziona solo se l'app è viva.
Nel log tutte le righe del Laboratorio iniziano con `LAB`. La riga "LAB SVEGLIA SUONA (ritardo N s)" dice quanto in ritardo è partita.

| # | Test | Come | Risultato atteso | Risultato |
|---|---|---|---|---|
| L1 | Guardiano OFF, app in primo piano | Guardiano spento, "Test: tra 1 minuto", resta nell'app con lo schermo acceso | Suona dopo circa 1 minuto, ritardo 0 s | |
| L2 | Guardiano OFF, schermo bloccato | Guardiano spento, "Test: tra 1 minuto", blocca subito il telefono, aspetta 3 minuti, poi sblocca e riapri l'app | Mi aspetto che **non** suoni finché non riapri l'app (ritardo molto alto nel log) | |
| L3 | Guardiano ON, schermo bloccato | Attiva il guardiano, "Test: tra 1 minuto", blocca il telefono | Suona a schermo bloccato, ritardo 0-1 s | |
| L4 | Guardiano ON + altra app | Come L3, ma prima di bloccare apri un'altra app (es. Safari) | Suona comunque | |
| L5 | Guardiano ON + musica | Come L3, ma con Spotify o YouTube in riproduzione | Annota: la nostra sveglia suona sopra la musica? Nel log c'è "interruzione audio"? | |
| L6 | **Tasti volume** | "Subito al massimo", "Blocca il volume" attivo. Quando suona premi volume giù più volte, anche a schermo bloccato | Nel log "tasto volume … -> …" e subito dopo "volume di sistema impostato a 100%: ora è 100%". Il suono **non** deve abbassarsi | |
| L7 | Volume senza blocco | Come L6, ma con "Blocca il volume" **spento** | Il volume scende normalmente: serve come confronto | |
| L8 | Pulsante "alza volume" | Abbassa il volume, poi tocca "Prova: alza volume di sistema al massimo" | Il volume sale al massimo (se non sale, il trucco non funziona su iOS 26) | |
| L9 | Progressiva 1 minuto | Progressiva "1 minuto", "Test: tra 1 minuto" | Parte appena udibile e sale in modo **continuo**, senza scalini, fino al massimo in 60 s | |
| L10 | Progressiva 15 minuti | Progressiva "15 minuti" | Salita lenta e continua. Nel log c'è una riga per ogni minuto con il volume | |
| L11 | Tag | Mentre suona, avvicina il tag (o usa l'azione di Comandi Rapidi) | Si ferma. Nel log "LAB sveglia dell'app FERMATA (tag …)" | |
| L12 | Cuffie | Collega auricolari Bluetooth, poi fai suonare | Annota da dove esce il suono. Il log scrive l'uscita audio | |
| L13 | **Notte intera** | La sera: guardiano ON, sveglia all'orario vero, progressiva 15 min, telefono in carica e bloccato | Suona al mattino. Nel log trovi "guardiano vivo" ogni 10 minuti per tutta la notte. Se manca un tratto, lì l'app è stata chiusa | |
| L14 | Chiusura forzata | Guardiano ON, poi chiudi l'app scorrendola via dal multitasking e riaprila | Nel log "app riaperta dopo una CHIUSURA … ultimo segno di vita alle …". La sveglia dell'app **non** suona più (limite noto) | |
| L15 | Batteria | Dopo la notte del test L13 | Annota quanta batteria ha consumato il guardiano: il log riporta la batteria ogni 10 minuti | |

## Giro 4: musica

Quando la sveglia dell'app parte, l'app ora prende l'audio "in esclusiva": la musica delle altre app dovrebbe andare in pausa. Dopo lo spegnimento col tag la musica può ripartire, e il guardiano torna in sottofondo.

| # | Test | Come | Risultato atteso | Risultato |
|---|---|---|---|---|
| M1 | Musica, schermo bloccato | Guardiano ON, Spotify/YouTube in riproduzione, "Test: tra 1 minuto", blocca il telefono | La musica si mette in pausa e suona solo la sveglia. Nel log c'è "musica di altre app: ferma", oppure "piano B" seguito dall'esito | |
| M2 | Comandi sulla schermata di blocco | Durante M1 guarda la schermata di blocco | Annota: compare un riquadro di riproduzione con il tasto pausa? Se sì, premilo: la sveglia deve ripartire entro 1 s (nel log "audio FERMO" e poi "ripartito") | |
| M3 | Dopo il tag | Spegni col tag o con "Ferma" | Nel log "guardiano ripartito in sottofondo". Annota se la musica riparte da sola | |

## Giro 5: taratura della progressiva

Dal log del test L10: la progressiva partiva da -30 dB, cioè il 3% del volume, ma con il volume di sistema portato al 100%, ed era troppo forte. Ora la partenza si sceglie con "Partenza progressiva" (predefinita -50 dB). Nel log ogni minuto il volume dell'app è scritto in dB.

| # | Test | Come | Risultato atteso | Risultato |
|---|---|---|---|---|
| P1 | Scegliere la partenza | Progressiva "1 minuto", prova -60, -50 e -40 dB, ognuna con "Test: tra 1 minuto" | Annota quale partenza è "appena udibile ma c'è" da sveglio, nella stanza silenziosa | |
| P2 | Progressiva 15 min con la partenza scelta | Come L10, con la partenza scelta in P1 | Il primo minuto è un sussurro, poi la salita è continua fino al massimo | |
