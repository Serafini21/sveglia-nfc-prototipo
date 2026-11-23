import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var stato: StatoApp
    @State private var modifica: InModifica?
    @State private var dormire = false

    struct InModifica: Identifiable {
        let sveglia: Sveglia
        let nuova: Bool
        var id: UUID { sveglia.id }
    }

    private var sveglie: [Sveglia] {
        stato.dati.sveglie.filter { $0.test == nil }.sorted { ($0.ora, $0.minuti) < ($1.ora, $1.minuti) }
    }

    var body: some View {
        NavigationStack {
            List {
                Group {
                    HStack {
                        // 5 tocchi sul titolo: modalità sviluppatore
                        Titolo(testo: "Sveglie")
                            .contentShape(Rectangle())
                            .onTapGesture(count: 5) { cambiaSviluppatore() }
                        Spacer()
                        Label("\(Regole.streak(stato.dati.mattine)) giorni", systemImage: "flame")
                            .font(.inter(14, .semibold))
                            .foregroundStyle(Tema.ambra)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Tema.superficie2, in: Capsule())
                            .accessibilityLabel("Streak: \(Regole.streak(stato.dati.mattine)) giorni di fila")
                    }
                    .padding(.top, 8)

                    AvvisiHome()

                    ProssimaScheda()

                    Button { dormire = true } label: {
                        Label("Vado a dormire ora", systemImage: "moon")
                    }
                    .buttonStyle(PulsantePrincipale(altezza: 64))

                    HStack {
                        Text("Le mie sveglie").font(.inter(17, .semibold)).foregroundStyle(Tema.testo)
                        Spacer()
                        Button { modifica = InModifica(sveglia: Sveglia(), nuova: true) } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(PulsanteIcona())
                        .accessibilityLabel("Nuova sveglia")
                    }
                    .padding(.top, 4)

                    if sveglie.isEmpty {
                        Text("Nessuna sveglia. Tocca + per crearne una.")
                            .font(.inter(15)).foregroundStyle(Tema.testo2)
                    }
                    ForEach(sveglie) { s in
                        RigaSveglia(sveglia: s)
                            .contentShape(Rectangle())
                            .onTapGesture { modifica = InModifica(sveglia: s, nuova: false) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { elimina(s) } label: { Label("Elimina", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                Button { copia(s) } label: { Label("Copia", systemImage: "plus.square.on.square") }
                                    .tint(Tema.ambra)
                            }
                    }
                    if !sveglie.isEmpty {
                        Text("Scorri una sveglia a sinistra per eliminarla, a destra per copiarla")
                            .font(.inter(13)).foregroundStyle(Tema.testo3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    if stato.dati.impostazioni.sviluppatore {
                        NavigationLink { SviluppatoreView() } label: {
                            Label("Modalità sviluppatore", systemImage: "hammer").font(.inter(15))
                        }
                        .scheda()
                    }
                }
                .rigaLibera()
            }
            .listStyle(.plain)
            .stileAlba()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $modifica) { m in
                ModificaSvegliaView(sveglia: m.sveglia, nuova: m.nuova).environmentObject(stato)
            }
            .sheet(isPresented: $dormire) {
                DormireView().environmentObject(stato)
            }
        }
    }

    private func elimina(_ s: Sveglia) {
        Task {
            let r = await AlarmEngine.shared.elimina(s.id)
            stato.avvisa(r.messaggio)
        }
    }

    /// La copia si apre nell'editor come sveglia nuova: si salva solo dopo averla sistemata.
    private func copia(_ s: Sveglia) {
        var c = s
        c.id = UUID()
        c.nome = s.nome + " (copia)"
        c.attiva = true
        modifica = InModifica(sveglia: c, nuova: true)
    }

    private func cambiaSviluppatore() {
        let attiva = !stato.dati.impostazioni.sviluppatore
        Task {
            await Store.shared.modifica { $0.impostazioni.sviluppatore = attiva }
            EventLog.scrivi("Modalità sviluppatore \(attiva ? "attivata" : "disattivata")")
            stato.avvisa(attiva ? "Modalità sviluppatore attiva" : "Modalità sviluppatore disattivata")
        }
    }
}

struct RigaSveglia: View {
    @EnvironmentObject var stato: StatoApp
    let sveglia: Sveglia

    private var bloccata: Bool { Regole.svegliaBloccata(sveglia.id, mattine: stato.dati.mattine, ora: Date()) }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(sveglia.ora):\(String(format: "%02d", sveglia.minuti))")
                    .font(.grotesk(30))
                    .foregroundStyle(sveglia.attiva ? Tema.testo : Tema.testo3)
                Text("\(sveglia.nome) · \(Formati.giorni(sveglia))")
                    .font(.inter(14))
                    .foregroundStyle(sveglia.attiva ? Tema.testo2 : Tema.testo3)
            }
            Spacer()
            if bloccata {
                Image(systemName: "lock.fill").foregroundStyle(Tema.ambra).accessibilityLabel("Bloccata")
            }
            Toggle("Attiva", isOn: Binding(get: { sveglia.attiva }, set: { attiva($0) }))
                .labelsHidden()
                .tint(Tema.ambra)
                .disabled(bloccata)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func attiva(_ valore: Bool) {
        var s = sveglia
        s.attiva = valore
        if valore, s.giorni.isEmpty, (s.dataUnaTantum ?? .distantPast) <= Date() {
            s.dataUnaTantum = Regole.prossimoOrario(ora: s.ora, minuti: s.minuti, dopo: Date())
        }
        Task {
            let r = await AlarmEngine.shared.salva(s)
            stato.avvisa(r.messaggio)
        }
    }
}

struct ProssimaScheda: View {
    @EnvironmentObject var stato: StatoApp
    @State private var sceltaSuono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EtichettaSezione(testo: "Prossima sveglia")
            if let m = stato.prossima {
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            // l'orario non va mai a capo: semmai va a capo il testo accanto
                            Text(Formati.ora(m.orario))
                                .font(.grotesk(56))
                                .tracking(-1)
                                .foregroundStyle(Tema.testo)
                                .lineLimit(1)
                                .fixedSize()
                            Text(Formati.traQuanto(m.orario, da: ctx.date))
                                .font(.inter(15)).foregroundStyle(Tema.testo2)
                                .lineLimit(2)
                        }
                        Text("\(m.nome) · \(Formati.quando(m.orario))")
                            .font(.inter(14)).foregroundStyle(Tema.testo2)
                        progressiva
                        if stato.guardiano {
                            HStack(spacing: 8) {
                                Label("Guardiano attivo: lascia Alba aperta", systemImage: "moon.zzz")
                                    .font(.inter(13)).foregroundStyle(Tema.testoChiaro)
                                Spacer()
                                Button("Spegni") { Guardiano.shared.annullaVadoALetto() }
                                    .buttonStyle(.plain) // in una riga di List: solo questo bottone reagisce al tocco
                                    .font(.inter(13, .semibold)).foregroundStyle(Tema.ambra)
                                    .frame(minHeight: 44)
                            }
                            if let uscita = stato.uscitaEsterna {
                                Label("Audio su «\(uscita)»: la sveglia suonerà lì", systemImage: "hifispeaker")
                                    .font(.inter(13)).foregroundStyle(Tema.pericolo)
                            }
                        } else {
                            Button {
                                Guardiano.shared.vadoALetto()
                                stato.avvisa("Buonanotte! Lascia Alba aperta in background.")
                            } label: {
                                Label("Vado a letto", systemImage: "bed.double")
                            }
                            .buttonStyle(PulsanteSecondario())
                        }
                        HStack(spacing: 8) {
                            Label(m.bloccata(ctx.date) ? "Bloccata: serve il tag"
                                  : "Bloccata dalle \(Formati.ora(m.inizio.addingTimeInterval(-Costanti.finestraPrima)))",
                                  systemImage: "lock")
                                .font(.inter(13, .medium))
                                .foregroundStyle(m.bloccata(ctx.date) ? Tema.ambra : Tema.testoChiaro)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Tema.superficie2, in: Capsule())
                            if m.test { Pastiglia(testo: "TEST") }
                        }
                        if let r = m.ridotta {
                            Label("Ridotta: \(r)", systemImage: "exclamationmark.triangle")
                                .font(.inter(13)).foregroundStyle(Tema.pericolo)
                        }
                    }
                }
            } else {
                Text("Nessuna sveglia programmata").font(.inter(17, .semibold)).foregroundStyle(Tema.testo2)
                progressiva
            }
        }
        .scheda(raggio: 22, margine: 20)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Tema.bordo, lineWidth: 1))
        .sheet(isPresented: $sceltaSuono) {
            NavigationStack {
                SceltaSuoneria(selezione: suonoProgressiva, titolo: "Suono progressiva")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { sceltaSuono = false } } }
            }
        }
    }

    private var progressiva: some View {
        VStack(alignment: .leading, spacing: 6) {
            InterruttoreProgressiva(sottotitolo: nil)
            if stato.dati.impostazioni.progressiva {
                Button { sceltaSuono = true } label: {
                    HStack {
                        Text("Suono").font(.inter(14)).foregroundStyle(Tema.testo2)
                        Spacer()
                        Text(stato.dati.impostazioni.suoneriaProgressiva.nome).font(.inter(14, .semibold)).foregroundStyle(Tema.testo)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tema.testo3)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain) // in una riga di List: solo questo bottone reagisce al tocco
                .accessibilityLabel("Suono della progressiva: \(stato.dati.impostazioni.suoneriaProgressiva.nome)")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(stato.dati.impostazioni.progressiva ? Tema.ambraTenue : Tema.notte,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Un solo suono per la progressiva di tutte le sveglie; all'orario la sveglia passa alla sua suoneria.
    private var suonoProgressiva: Binding<String> {
        Binding(get: { stato.dati.impostazioni.suoneriaProgressiva.rawValue }, set: { valore in
            stato.dati.impostazioni.suonoProgressiva = valore // riscontro immediato; lo Store conferma subito dopo
            Task { await Store.shared.modifica { $0.impostazioni.suonoProgressiva = valore } }
            EventLog.scrivi("Suono della progressiva: \(valore)")
        })
    }
}

/// Interruttore unico della progressiva: vale per tutte le sveglie e ricorda l'ultima scelta.
struct InterruttoreProgressiva: View {
    @EnvironmentObject var stato: StatoApp
    let sottotitolo: String?

    var body: some View {
        Toggle(isOn: Binding(get: { stato.dati.impostazioni.progressiva }, set: { cambia($0) })) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sveglia progressiva 15 min").font(.inter(15, .semibold)).foregroundStyle(Tema.testo)
                if let sottotitolo { Text(sottotitolo).font(.inter(12)).foregroundStyle(Tema.testo2) }
            }
        }
        .tint(Tema.ambra)
    }

    private func cambia(_ valore: Bool) {
        stato.dati.impostazioni.progressiva = valore // riscontro immediato; lo Store conferma subito dopo
        Task {
            await AlarmEngine.shared.impostaProgressiva(valore)
            stato.avvisa(valore ? "Sveglia progressiva attiva" : "Sveglia progressiva disattivata")
        }
    }
}

struct AvvisiHome: View {
    @EnvironmentObject var stato: StatoApp

    var body: some View {
        if stato.autorizzazione == .notDetermined {
            avviso("Serve il permesso Sveglie.", pulsante: "Concedi") {
                Task { stato.autorizzazione = await AlarmEngine.shared.chiediAutorizzazione(); await stato.attiva() }
            }
        } else if stato.autorizzazione != .authorized {
            avviso("Permesso Sveglie negato: Alba non può suonare.", pulsante: "Apri Impostazioni") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        }
        if let testo = stato.dati.avviso {
            avviso(testo, pulsante: "OK") { Task { await AlarmEngine.shared.chiudiAvviso() } }
        }
        if let s = stato.scadenza, s.timeIntervalSinceNow < 2 * 86400 {
            avviso(s < Date() ? "Alba è scaduta: reinstallala." : "Alba scade \(Formati.quando(s)): reinstallala.", pulsante: nil) {}
        }
        if stato.caricato && stato.dati.tag.isEmpty {
            avviso("Nessun tag: aggiungine uno nella scheda Tag.", pulsante: nil) {}
        }
    }

    private func avviso(_ testo: String, pulsante: String?, azione: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(testo, systemImage: "exclamationmark.triangle.fill")
                .font(.inter(14))
                .foregroundStyle(Tema.testo)
            if let pulsante {
                Button(pulsante, action: azione).buttonStyle(PulsantePrincipale(altezza: 44))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scheda(Tema.ambraTenue)
    }
}
