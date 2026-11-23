# Cosa c'è in questa cartella

Questa cartella è il progetto «Alba», cioè la sveglia che si spegne con il tag NFC. È collegata a GitHub, dove l'app viene compilata.

## Da leggere

| Cosa | A cosa serve |
|---|---|
| `LEGGIMI.md` | Questa guida. |
| `README.md` | Come installare e usare l'app. |
| `docs/PROGETTO.md` | Tutte le regole e le scelte del progetto. |
| `docs/PASSAGGIO_CHAT.md` | Il riassunto da dare a una chat nuova per riprendere il lavoro. |
| `Alba.ipa` | L'app da installare con Sideloadly. Esiste solo su questo PC; la versione nuova si scarica da GitHub. |
| `android/README.md` | La versione Android (Galaxy S23): installazione, impostazioni del telefono, differenze dall'iPhone. |

## Il codice (non serve aprirlo)

Queste cartelle servono a GitHub per creare l'app. Non spostarle e non rinominarle, altrimenti la build si rompe.

| Cosa | A cosa serve |
|---|---|
| `Alba/` | Il codice dell'app. |
| `Alba/UI/` | Le schermate: Home, «Vado a dormire ora», sveglia in corso, impostazioni… |
| `Alba/Assets.xcassets/` | L'icona dell'app. |
| `Tests/` | I controlli automatici sulle regole, eseguiti prima di ogni build. |
| `scripts/` | Programmi che creano i suoni e l'icona durante la build. |
| `project.yml` | La «ricetta» del progetto: nome, versione di iOS, permessi. |
| `android/` | L'app Android, separata da quella iPhone: codice, test e «ricetta» Gradle. Usa gli stessi suoni (`scripts/`). |
| `.github/` | Le istruzioni per GitHub su come compilare l'app (`build.yml` iPhone, `android.yml` Android). |
| `.git/` e `.gitignore` | Servono a Git per tenere la cronologia. Non toccarli. |

### I file del codice, uno per uno

| File | Cosa fa |
|---|---|
| `AlbaApp.swift` | Avvia l'app. |
| `Modello.swift` | Cosa viene salvato: sveglie, tag, mattine, impostazioni. |
| `Regole.swift` | Le regole: orari, punteggio, crediti, distanza da casa. |
| `Store.swift` | Salva e legge i dati sul telefono. |
| `AlarmEngine.swift` | Programma e ferma le sveglie di sistema (AlarmKit). |
| `Guardiano.swift` | Tiene l'app sveglia di notte e suona la sveglia. |
| `Posizione.swift` | Legge la posizione per sapere se sei a casa. |
| `Intents.swift` | Le azioni usate da Comandi Rapidi e dal tag. |
| `Scadenza.swift` | Avvisa quando l'app sta per scadere (dopo 7 giorni). |
| `EventLog.swift` | Il diario degli eventi, utile per capire cosa è successo di notte. |
| `UI/Home.swift` | La schermata principale. |
| `UI/Dormire.swift` | «Vado a dormire ora». |
| `UI/ModificaSveglia.swift` | Crea o modifica una sveglia. |
| `UI/Mattino.swift` | Sveglia in corso, Emergency Stop, «Buongiorno!». |
| `UI/Impostazioni.swift` | Impostazioni e posizione di casa. |
| `UI/Statistiche.swift` | Statistiche e punteggio. |
| `UI/TagView.swift` | I tuoi tag e la guida per aggiungerli. |
| `UI/Sviluppatore.swift` | Modalità sviluppatore, con 5 tocchi sul titolo. |
| `UI/Anteprima.swift` | Ascolto delle suonerie. |
| `UI/Tema.swift` | Colori e caratteri. |

## Archivio

`archivio/` contiene il lavoro finito, tenuto solo come riferimento. Non fa parte dell'app.

| Cosa | A cosa serve |
|---|---|
| `archivio/REPORT_PROTOTIPO.md` | Cosa ha dimostrato il primo prototipo. |
| `archivio/TEST_FASE1.md`, `archivio/TEST_FASE2.md` | I test fatti sul telefono nelle fasi 1 e 2. |
| `archivio/prototipo/` | Il «Laboratorio», già portato tutto in Alba. |
