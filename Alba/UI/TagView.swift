import SwiftUI
import UIKit

struct TagView: View {
    @EnvironmentObject var stato: StatoApp
    @State private var guida = false
    @State private var prova: TagNFC?

    var body: some View {
        NavigationStack {
            List {
                Group {
                    HStack {
                        Titolo(testo: "I miei tag")
                        Spacer()
                        Button { guida = true } label: {
                            Label("Aggiungi", systemImage: "plus")
                                .font(.inter(15, .bold))
                                .foregroundStyle(Tema.suAmbra)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(Tema.ambra, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    if stato.dati.tag.isEmpty {
                        Text("Nessun tag. Aggiungine uno e mettilo lontano dal letto (bagno, cucina).")
                            .font(.inter(15)).foregroundStyle(Tema.testo2)
                    }
                    ForEach(stato.dati.tag) { t in
                        RigaTag(tag: t) { prova = t }
                            .swipeActions {
                                Button(role: .destructive) { elimina(t) } label: { Label("Elimina", systemImage: "trash") }
                            }
                    }
                    if !stato.dati.tag.isEmpty {
                        Text("Qualsiasi tag registrato spegne le sveglie. Scorri a sinistra per eliminarne uno.")
                            .font(.inter(13)).foregroundStyle(Tema.testo2)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        EtichettaSezione(testo: "Codice segreto")
                        CodiceSegreto()
                        Text("Va scritto in ogni automazione NFC. Senza il codice giusto Alba rifiuta lo spegnimento e lo registra come tentativo sospetto.")
                            .font(.inter(13)).foregroundStyle(Tema.testo2)
                    }
                    .scheda()

                    VStack(alignment: .leading, spacing: 8) {
                        EtichettaSezione(testo: "Come funziona")
                        Text("iOS legge il tag con un'automazione di Comandi Rapidi, che esegue l'azione «Spegni sveglia» di Alba. L'automazione parte solo a telefono sbloccato e, mentre la sveglia suona, Face ID non sblocca: premi Stop, sblocca e avvicina il tag entro 60 secondi. Così non hai nessuna penalità.")
                            .font(.inter(14)).foregroundStyle(Tema.testoChiaro)
                    }
                    .scheda()
                }
                .rigaLibera()
            }
            .listStyle(.plain)
            .stileAlba()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $guida) { GuidaTagView().environmentObject(stato) }
            .sheet(item: $prova) { t in ProvaTagView(tag: t).environmentObject(stato) }
        }
    }

    private func elimina(_ t: TagNFC) {
        Task {
            await Store.shared.modifica { $0.tag.removeAll { $0.id == t.id } }
            EventLog.scrivi("Tag eliminato: \(t.nome)")
            stato.avvisa("Tag «\(t.nome)» eliminato. Elimina anche la sua automazione in Comandi Rapidi.")
        }
    }
}

struct RigaTag: View {
    let tag: TagNFC
    let prova: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tag.ultimaScansione == nil ? Tema.testoChiaro : Tema.ambra)
                .frame(width: 48, height: 48)
                .background(tag.ultimaScansione == nil ? Tema.superficie2 : Tema.ambraTenue,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(tag.nome).font(.inter(16, .semibold)).foregroundStyle(Tema.testo)
                Text(tag.ultimaScansione.map { "Ultima scansione: \(Formati.quando($0))" } ?? "Mai scansionato")
                    .font(.inter(13)).foregroundStyle(Tema.testo2)
            }
            Spacer()
            Button(action: prova) {
                if tag.ultimaScansione == nil {
                    Pastiglia(testo: "Prova", colore: Tema.ambra, fondo: Tema.ambraTenue)
                } else {
                    Pastiglia(testo: "Pronto", colore: Tema.successo, fondo: Tema.successoFondo)
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("Prova il tag \(tag.nome)")
        }
        .padding(16)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CodiceSegreto: View {
    @EnvironmentObject var stato: StatoApp
    var body: some View {
        HStack {
            Text(stato.dati.impostazioni.codiceSegreto)
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundStyle(Tema.ambra)
                .textSelection(.enabled)
            Spacer()
            CopiaPulsante(testo: stato.dati.impostazioni.codiceSegreto, cosa: "Codice")
        }
    }
}

struct CopiaPulsante: View {
    @EnvironmentObject var stato: StatoApp
    let testo: String
    let cosa: String
    var body: some View {
        Button {
            UIPasteboard.general.string = testo
            stato.avvisa("\(cosa) copiato")
        } label: {
            Label("Copia", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Copia \(cosa.lowercased())")
    }
}

/// Aggiunta guidata: nome, automazione in Comandi Rapidi, prova.
struct GuidaTagView: View {
    @EnvironmentObject var stato: StatoApp
    @Environment(\.dismiss) private var chiudi
    @State private var passo = 1
    @State private var nome = ""
    @State private var tag: TagNFC?

    private var nomePulito: String { nome.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var doppione: Bool { stato.dati.tag.contains { Regole.stessoNome($0.nome, nomePulito) } }

    var body: some View {
        NavigationStack {
            List {
                switch passo {
                case 1:
                    Section {
                        TextField("Per esempio: Bagno", text: $nome)
                            .textInputAutocapitalization(.words)
                        if doppione { Text("Esiste già un tag con questo nome.").foregroundStyle(Tema.pericolo) }
                    } header: {
                        Text("1 · Dai un nome al tag")
                    } footer: {
                        Text("Il nome serve a riconoscere il tag nell'app e nel log. Lo scriverai uguale nell'automazione.")
                    }
                    Section {
                        Button("Avanti") { registra() }
                            .disabled(nomePulito.isEmpty || doppione)
                    }
                case 2:
                    Section("2 · Crea l'automazione in Comandi Rapidi") {
                        istruzione(1, "Apri l'app **Comandi Rapidi** › scheda **Automazione** › **+**.")
                        istruzione(2, "Scegli **NFC** › **Scansiona** e avvicina il tag. Chiamalo «\(nomePulito)».")
                        istruzione(3, "Seleziona **Esegui immediatamente** (non «Chiedi prima di eseguire») e tocca **Avanti**.")
                        istruzione(4, "Tocca **Nuova automazione vuota** › **Aggiungi azione**, cerca **Alba** e scegli **Spegni sveglia**.")
                        istruzione(5, "Nell'azione tocca **Nome tag** e scrivi il nome qui sotto, poi tocca **Codice segreto** e incolla il codice.")
                        istruzione(6, "Tocca **Fine** in alto a destra.")
                    }
                    Section("Da copiare nell'azione") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Nome tag").font(.caption).foregroundStyle(Tema.testo2)
                                Text(nomePulito).font(.headline)
                            }
                            Spacer()
                            CopiaPulsante(testo: nomePulito, cosa: "Nome")
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Codice segreto").font(.caption).foregroundStyle(Tema.testo2)
                                Text(stato.dati.impostazioni.codiceSegreto)
                                    .font(.system(.headline, design: .monospaced))
                                    .foregroundStyle(Tema.ambra)
                            }
                            Spacer()
                            CopiaPulsante(testo: stato.dati.impostazioni.codiceSegreto, cosa: "Codice")
                        }
                    }
                    Section {
                        Button("Apri Comandi Rapidi") {
                            if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
                        }
                        Button("Fatto, provalo") { passo = 3 }
                            .font(.inter(16, .semibold))
                    }
                default:
                    if let tag {
                        Section("3 · Prova") { ProvaContenuto(tag: tag) }
                    }
                    Section {
                        Button("Fine") { chiudi() }
                    }
                }
            }
            .stileAlba()
            .navigationTitle("Nuovo tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { chiudi() } } }
        }
    }

    private func istruzione(_ n: Int, _ testo: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Tema.ambra, in: Circle())
                .foregroundStyle(Tema.suAmbra)
            Text(testo).foregroundStyle(Tema.testo)
        }
    }

    private func registra() {
        let nuovo = TagNFC(nome: nomePulito)
        tag = nuovo
        passo = 2
        Task {
            await Store.shared.modifica { $0.tag.append(nuovo) }
            EventLog.scrivi("Tag registrato: \(nuovo.nome)")
            stato.avvisa("Tag «\(nuovo.nome)» registrato")
        }
    }
}

struct ProvaTagView: View {
    @EnvironmentObject var stato: StatoApp
    @Environment(\.dismiss) private var chiudi
    let tag: TagNFC

    var body: some View {
        NavigationStack {
            List { ProvaContenuto(tag: tag) }
                .stileAlba()
                .navigationTitle("Prova tag")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { chiudi() } } }
        }
    }
}

/// Aspetta che l'automazione esegua l'azione con questo tag e il codice giusto (aggiorna "ultima scansione").
struct ProvaContenuto: View {
    @EnvironmentObject var stato: StatoApp
    let tag: TagNFC
    @State private var inizio = Date()

    private var riuscita: Bool {
        guard let ultima = stato.dati.tag.first(where: { $0.id == tag.id })?.ultimaScansione else { return false }
        return ultima >= inizio
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: riuscita ? "checkmark.circle.fill" : "wave.3.right.circle")
                .font(.system(size: 72))
                .foregroundStyle(riuscita ? Tema.successo : Tema.ambra)
                .accessibilityHidden(true)
            Text(riuscita ? "Funziona! Alba ha ricevuto il tag «\(tag.nome)» con il codice giusto."
                          : "Sblocca il telefono e avvicina ora il tag «\(tag.nome)» alla parte alta del telefono.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tema.testo)
            if !riuscita {
                ProgressView()
                Text("Se compare «Codice segreto mancante o sbagliato» o «non è registrato», correggi nome e codice nell'azione. Se non compare nulla, controlla che l'automazione sia attiva e su «Esegui immediatamente».")
                    .font(.footnote)
                    .foregroundStyle(Tema.testo2)
                    .multilineTextAlignment(.center)
            }
            if let m = stato.prossima, m.nellaFinestraPrima(Date()) || m.inCorso(Date()) {
                Text("Attenzione: la sveglia «\(m.nome)» è entro 2 ore. Questa prova la spegne (spegnimento anticipato).")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Tema.pericolo)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .listRowBackground(Tema.superficie)
        .onAppear { inizio = Date() }
    }
}
