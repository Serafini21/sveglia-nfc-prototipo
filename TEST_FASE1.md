# Test della Fase 1 – Alba

Compila **Risultato** (OK / NO / PARZIALE) e **Note** per ogni test. Alla fine esporta il log da *Impostazioni › Esporta log* e mandamelo: ogni evento è registrato con data e millisecondi.

## Preparazione (una volta sola)

1. Installa Alba (test 1).
2. Al primo avvio concedi il permesso **Sveglie** e, quando richiesto, le **notifiche**.
3. Scheda **Tag** › **Aggiungi tag**: dai un nome (per esempio «Bagno») e segui la guida per creare l'automazione NFC con **nome tag** e **codice segreto**. Alla fine fai la **Prova**: deve comparire «Funziona!».
4. Attiva la **modalità sviluppatore**: tocca 5 volte di fila il titolo «Alba» nella Home. In fondo alla Home compare «Modalità sviluppatore».
5. In *Sviluppatore* imposta la **catena breve**: progressiva un gradino ogni **10 s**, catena una sveglia ogni **30 s**, durata **3 min**. Le mattine di test non contano nelle statistiche.

Promemoria delle mattine di test (*Sviluppatore › Mattina tra N min › Programma la mattina di test*):
- con la progressiva accesa nella Home, i 15 gradini partono 150 s prima dell'orario. Quindi scegli almeno 4 minuti;
- la sirena parte dalla 5ª sveglia, cioè 2 minuti dopo l'orario;
- dopo 3 minuti + 60 s senza tag la mattina è «fallita».

---

### 1. Installazione con il nuovo Bundle ID
**Come:** puoi disinstallare prima il prototipo «Sveglia NFC» (libera uno dei 3 posti dell'Apple ID gratuito) oppure installare Alba accanto. In Sideloadly usa `Alba.ipa` e lo stesso Apple ID.
**Atteso:**
- l'app si chiama «Alba» e si apre;
- chiede il permesso Sveglie;
- *Impostazioni* mostra «L'app scade tra 7 giorni (…)» e la build;
- *Promemoria scadenza: attive* dopo che hai accettato le notifiche;
- in Comandi Rapidi, cercando «Alba», compare l'azione **Spegni sveglia**.

**Risultato:** ______ **Note:** ____________________

### 2. Mattina completa breve
**Come:** accendi «Risveglio progressivo» nella Home. In *Sviluppatore* imposta «Mattina tra 4 min» e tocca **Programma la mattina di test**. Blocca il telefono e aspetta senza toccare nulla per circa 2 minuti dopo l'orario. Poi premi Stop, sblocca e usa il tag.
**Atteso:**
- 15 sveglie «Buongiorno ☀︎» ogni 10 s, sempre più forti;
- all'orario, «Sblocca e avvicina al tag» con il pulsante **Emergenza**;
- poi una sveglia ogni 30 s; dalla 5ª (+2 min), «PUNIZIONE – usa il tag!» con la sirena;
- dopo il tag: «Sveglia spenta ✓», e aprendo Alba compare «Risveglio riuscito».

**Risultato:** ______ **Note (si sente salire la progressiva? la sirena arriva alla 5ª?):** ____________________

### 3. Stop, sblocco, tag entro 60 s: nessuna penalità
**Come:** spegni la progressiva. Programma una mattina di test tra 2 min a telefono bloccato. Quando suona la principale premi **Stop** (o il tasto laterale), sblocca con Face ID e usa il tag entro 60 s.
**Atteso:**
- «Risveglio riuscito» con punteggio **100**;
- in *Statistiche* l'esito è **Tag**, con «stop 1» e nessuno «penalizzato».

**Risultato:** ______ **Note:** ____________________

### 4. Codice sbagliato o azione lanciata a mano
**Come:** mentre suona una mattina di test, prova tre casi:
- **a.** apri Comandi Rapidi ed esegui a mano l'azione «Spegni sveglia» **senza** codice;
- **b.** con un codice sbagliato (modifica temporaneamente l'automazione oppure creane una di prova);
- **c.** con un nome tag non registrato.

**Atteso:**
- a e b: «Codice segreto mancante o sbagliato: spegnimento rifiutato», e la sveglia continua;
- c: «Il tag «…» non è registrato in Alba»;
- nel log «TAG RIFIUTATO … TENTATIVO SOSPETTO».

Alla fine spegni col tag vero.
**Risultato:** a ______ b ______ c ______ **Note:** ____________________

### 5. Spegnimento anticipato nelle 2 ore prima
**Come:** crea una sveglia **normale** (dal + della Home) per tra circa 1 ora, poi usa il tag.
**Atteso:**
- «Sveglia … annullata in anticipo ✓»;
- la sveglia una tantum sparisce (una ripetuta passa alla prossima occorrenza);
- *Statistiche* mostra «Annullata in anticipo» e lo streak sale.

**Risultato:** ______ **Note:** ____________________

### 6. Blocco delle modifiche nelle 2 ore prima
**Come:** con una sveglia normale entro 2 ore, prova a modificarla, disattivarla e a eliminarla scorrendo verso sinistra.
**Atteso:**
- lucchetto nella lista e interruttore bloccato;
- l'eliminazione risponde «Sveglia bloccata…»;
- l'editor mostra il riquadro «Sveglia bloccata» con il pulsante Emergency Stop, e **Salva** è disabilitato;
- dopo il tag (spegnimento anticipato) la sveglia si sblocca.

**Risultato:** ______ **Note:** ____________________

### 7. Trucco del volume
**Come:** mattina di test tra 2 min, con il telefono **sbloccato** sulla Home. Quando suona la principale premi un **tasto volume** (non Stop). Aspetta circa 2 minuti e mezzo, poi usa il tag oppure apri Alba.
**Atteso:**
- le sveglie successive suonano mute;
- l'esito è **«Fallita – volume»**, con punteggio 0 e streak a 0;
- nel log c'è «Fallita – volume» con il numero di sveglie «in corso».

**Risultato:** ______ **Note:** ____________________

### 8. Emergency Stop: pulsante della sveglia e app
Alla prima installazione hai **1 credito**: fai prima la parte **a**, che non lo consuma.
**a. Pulsante «Emergenza» sulla sveglia.** Durante una mattina di test, a telefono bloccato, tocca **Emergenza** sulla sveglia.
**Atteso:** la sveglia si ferma (nel log «PULSANTE EMERGENZA»), poi Face ID e Alba si apre direttamente su **Emergency Stop**. Tocca *Annulla* e spegni col tag.
**Da annotare:** il tocco ferma la sveglia? Serve sbloccare? L'app si apre sulla schermata giusta? ____________________

**b. Dall'app.** Durante una mattina di test apri Alba › **Emergency Stop**, scrivi «Sono sveglio e mi alzo» e tieni premuto 10 s.
**Atteso:**
- sveglia spenta;
- esito **Emergency**, crediti da 1 a 0, streak a 0;
- in *Impostazioni*, «Prossima ricarica» tra 7 giorni.

**Risultato:** a ______ b ______ **Note:** ____________________

### 9. Due mattine programmate insieme (oltre 61 sveglie)
**Come:** accendi la progressiva e crea una sveglia normale ripetuta tutti i giorni (oppure due sveglie per domani). Apri *Sviluppatore › Stato*.
**Atteso:** 2 mattine aperte da 76 sveglie ciascuna («Sveglie in AlarmKit: 152»), **oppure** una mattina «ridotta». Nel log cerca le righe «Riallinea» e «LIMITE AlarmKit»: mandamele. Poi rimetti le sveglie come vuoi.
**Risultato (quante sveglie accettate?):** ______ **Note:** ____________________

### 10. Notte vera
**Come:** sveglia normale all'ora reale con la progressiva accesa, telefono bloccato in carica e Full immersion **Riposo** attiva.
**Atteso:** progressiva da 15 minuti prima, poi principale e catena; Stop, sblocco e tag; «Risveglio riuscito».
**Risultato:** ______ **Note (come ti sei svegliato, eventuali problemi):** ____________________

### 11. Non disturbare e risparmio energetico
**Come:** una mattina di test con **Non disturbare** attivo, poi un'altra con **Risparmio energetico** attivo.
**Atteso:** suona normalmente in entrambi i casi.
**Risultato:** Non disturbare ______ Risparmio energetico ______ **Note:** ____________________

### 12. Le sveglie sopravvivono alla reinstallazione?
**Come:** programma una mattina di test tra 15 minuti e reinstalla subito la stessa `Alba.ipa` con Sideloadly. **Non aprire Alba** e aspetta l'orario.
**Atteso / da annotare:** suona lo stesso? Dopo, apri Alba: se le sveglie erano sparite compare l'avviso «Mancavano N sveglie…» e nel log «SVEGLIE MANCANTI».
**Risultato:** ______ **Note:** ____________________

### 13. Scadenza
**a. Promemoria.** In *Impostazioni* leggi la data di scadenza.
**Atteso:** una notifica «Alba scade tra 2 giorni» alle 20:00 di due giorni prima e una «Alba scade domani» alle 20:00 del giorno prima.
**Risultato:** ______

**b. Facoltativo, da fare per ultimo.** Subito dopo un'installazione, in *Sviluppatore* scegli «Sveglia tra 8 giorni» e tocca **Programma la sveglia tra 8 giorni**. Poi **non reinstallare** per 8 giorni: l'app scade al 7°.
**Da annotare:** l'8° giorno la sveglia suona? Stop e tag funzionano? L'app si apre? Poi reinstalla.
**Risultato:** ______ **Note:** ____________________

### 14. Mini-test della progressiva
**Come:** *Sviluppatore › Mini-test progressiva*: 4 sveglie ogni 30 s a partire da 1 minuto dopo, ognuna circa 6 dB più forte della precedente. Ascolta col telefono a faccia in giù, senza guardarlo. Alla fine premi Stop, che le ferma tutte.
Fallo due volte:
- con le **Funzioni di rilevamento dell'attenzione** accese (*Impostazioni › Face ID e codice*);
- poi con quelle funzioni spente.

**Atteso / da annotare:** si sentono 4 gradini sempre più forti? C'è un «respiro» a ogni gradino?
**Risultato:** acceso ______ spento ______ **Note:** ____________________
