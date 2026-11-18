import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var stato: StatoApp
    @State private var modifica: InModifica?

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
                Section {
                    Text("Alba")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Tema.testo)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 5) { cambiaSviluppatore() }
                        .accessibilityAddTraits(.isHeader)
                }
                .listRowBackground(Color.clear)

                AvvisiHome()

                Section { ProssimaScheda() }
                    .listRowBackground(Tema.superficie)

                Section("Sveglie") {
                    if sveglie.isEmpty {
                        Text("Nessuna sveglia. Tocca + per crearne una.").foregroundStyle(Tema.testo2)
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
                }
                .listRowBackground(Tema.superficie)

                if stato.dati.impostazioni.sviluppatore {
                    Section {
                        NavigationLink { SviluppatoreView() } label: { Label("Modalità sviluppatore", systemImage: "hammer") }
                    }
                    .listRowBackground(Tema.superficie)
                }
            }
            .stileAlba()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { modifica = InModifica(sveglia: Sveglia(), nuova: true) } label: {
                        Image(systemName: "plus").font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel("Nuova sveglia")
                }
            }
            .sheet(item: $modifica) { m in
                ModificaSvegliaView(sveglia: m.sveglia, nuova: m.nuova).environmentObject(stato)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%02d:%02d", sveglia.ora, sveglia.minuti))
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(sveglia.attiva ? Tema.testo : Tema.testo2)
                Text("\(sveglia.nome) · \(Formati.giorni(sveglia))")
                    .font(.subheadline)
                    .foregroundStyle(Tema.testo2)
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
        .padding(.vertical, 4)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROSSIMA SVEGLIA").font(.caption.weight(.semibold)).foregroundStyle(Tema.testo2)
            if let m = stato.prossima {
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Formati.ora(m.orario))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(Tema.ambra)
                        Text("\(m.nome) · \(Formati.quando(m.orario))").foregroundStyle(Tema.testo)
                        Text(Formati.traQuanto(m.orario, da: ctx.date)).font(.subheadline).foregroundStyle(Tema.testo2)
                        if m.bloccata(ctx.date) {
                            Label("Bloccata: suona entro 2 ore", systemImage: "lock.fill")
                                .font(.subheadline).foregroundStyle(Tema.ambra)
                        }
                        if let r = m.ridotta {
                            Label("Programmata ridotta (\(r)): limite di sveglie di iOS", systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(Tema.pericolo)
                        }
                    }
                }
            } else {
                Text("Nessuna sveglia programmata").foregroundStyle(Tema.testo2)
            }
            Divider().overlay(Tema.bordo)
            Toggle(isOn: Binding(get: { stato.dati.impostazioni.progressiva }, set: { cambiaProgressiva($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risveglio progressivo").foregroundStyle(Tema.testo)
                    Text("15 minuti di suono dolce, sempre più forte, prima della sveglia")
                        .font(.caption).foregroundStyle(Tema.testo2)
                }
            }
            .tint(Tema.ambra)
        }
        .padding(.vertical, 6)
    }

    private func cambiaProgressiva(_ valore: Bool) {
        stato.dati.impostazioni.progressiva = valore // riscontro immediato; lo Store conferma subito dopo
        Task {
            await AlarmEngine.shared.impostaProgressiva(valore)
            stato.avvisa(valore ? "Risveglio progressivo attivo" : "Risveglio progressivo disattivato")
        }
    }
}

struct AvvisiHome: View {
    @EnvironmentObject var stato: StatoApp

    var body: some View {
        if stato.autorizzazione == .notDetermined {
            avviso("Alba non ha ancora il permesso di usare le sveglie.", pulsante: "Concedi") {
                Task { stato.autorizzazione = await AlarmEngine.shared.chiediAutorizzazione(); await stato.attiva() }
            }
        } else if stato.autorizzazione != .authorized {
            avviso("Permesso Sveglie negato: Alba non può suonare. Riattivalo in Impostazioni › Alba.", pulsante: "Apri Impostazioni") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        }
        if let testo = stato.dati.avviso {
            avviso(testo, pulsante: "OK") { Task { await AlarmEngine.shared.chiudiAvviso() } }
        }
        if let s = stato.scadenza, s.timeIntervalSinceNow < 2 * 86400 {
            avviso(s < Date() ? "Alba è scaduta: reinstallala con Sideloadly."
                              : "Alba scade \(Formati.quando(s)): reinstallala con Sideloadly.", pulsante: nil) {}
        }
        if stato.caricato && stato.dati.tag.isEmpty {
            avviso("Nessun tag registrato: la sveglia si potrà spegnere solo con l'Emergency Stop. Aggiungine uno nella scheda Tag.",
                   pulsante: nil) {}
        }
    }

    private func avviso(_ testo: String, pulsante: String?, azione: @escaping () -> Void) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(testo, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Tema.testo)
                if let pulsante {
                    Button(pulsante, action: azione)
                        .buttonStyle(.borderedProminent)
                        .tint(Tema.ambra)
                        .foregroundStyle(Tema.suAmbra)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Tema.ambraTenue)
    }
}
