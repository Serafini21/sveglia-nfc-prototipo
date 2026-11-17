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

Note libere:

