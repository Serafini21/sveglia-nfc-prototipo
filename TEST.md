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

