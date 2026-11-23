import SwiftUI

struct ModificaSvegliaView: View {
    @EnvironmentObject var stato: StatoApp
    @Environment(\.dismiss) private var chiudi
    @State private var s: Sveglia
    @State private var orario: Date
    @State private var salvataggio = false
    let nuova: Bool

    init(sveglia: Sveglia, nuova: Bool) {
        _s = State(initialValue: sveglia)
        _orario = State(initialValue: Calendar.current.date(bySettingHour: sveglia.ora, minute: sveglia.minuti,
                                                             second: 0, of: Date()) ?? Date())
        self.nuova = nuova
    }

    private var bloccata: Bool { !nuova && Regole.svegliaBloccata(s.id, mattine: stato.dati.mattine, ora: Date()) }

    /// La sveglia come verrà salvata: senza giorni è una tantum alla prossima occorrenza dell'orario.
    private var bozza: Sveglia {
        var b = s
        let c = Calendar.current.dateComponents([.hour, .minute], from: orario)
        b.ora = c.hour ?? 7
        b.minuti = c.minute ?? 0
        b.dataUnaTantum = b.giorni.isEmpty ? Regole.prossimoOrario(ora: b.ora, minuti: b.minuti, dopo: Date()) : nil
        let nome = b.nome.trimmingCharacters(in: .whitespacesAndNewlines)
        b.nome = nome.isEmpty ? "Sveglia" : nome
        return b
    }

    private var prossima: Date? {
        var b = bozza
        b.attiva = true
        return Regole.occorrenze(b, dopo: Date(), fino: Date().addingTimeInterval(8 * 86400)).first
    }

    private var suoneria: Suoneria { Suoneria(rawValue: s.suoneria) ?? .normale }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intestazione

                    if bloccata { avvisoBloccata }

                    Group {
                        VStack(spacing: 4) {
                            DatePicker("Orario", selection: $orario, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                            Label(prossima.map { "Prossima: \(Formati.quando($0))" } ?? "Nessuna occorrenza",
                                  systemImage: "calendar")
                                .font(.inter(14, .medium))
                                .foregroundStyle(Tema.ambra)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 6) {
                            EtichettaSezione(testo: "Nome")
                            TextField("Nome", text: $s.nome)
                                .font(.inter(16))
                                .padding(.horizontal, 16)
                                .frame(height: 48)
                                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tema.bordo, lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            EtichettaSezione(testo: "Ripeti")
                            SelettoreGiorni(giorni: $s.giorni)
                            if s.giorni.isEmpty {
                                Text("Una volta sola").font(.inter(12)).foregroundStyle(Tema.testo2)
                            }
                        }

                        VStack(spacing: 0) {
                            NavigationLink { SceltaSuoneria(selezione: $s.suoneria) } label: {
                                riga("Suoneria", valore: suoneria.nome, colore: Tema.testo2)
                            }
                            Divider().overlay(Tema.bordo)
                            riga("Suoneria punizione", sotto: "Dopo \(Costanti.ritardoCatena / 60) min senza tag", valore: "Sirena",
                                 colore: Tema.pericolo, freccia: false)
                        }
                        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .disabled(bloccata)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock").foregroundStyle(Tema.ambra)
                        Text("Nelle 2 ore prima servirà il tag per modificarla. Niente snooze.")
                            .font(.inter(13)).foregroundStyle(Tema.testoChiaro)
                    }
                    .scheda(Tema.notte, raggio: 16)

                    if !nuova {
                        Button("Elimina sveglia", role: .destructive) { elimina() }
                            .font(.inter(15, .semibold))
                            .foregroundStyle(Tema.pericolo)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .disabled(bloccata)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 28)
            }
            .background(Tema.sfondo.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var intestazione: some View {
        HStack {
            Button { chiudi() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(PulsanteIcona())
                .accessibilityLabel("Annulla")
            Spacer()
            Text(nuova ? "Nuova sveglia" : "Modifica sveglia").font(.inter(17, .semibold)).foregroundStyle(Tema.testo)
            Spacer()
            Button(salvataggio ? "Salvo…" : "Salva") { salva() }
                .font(.inter(15, .bold))
                .foregroundStyle(Tema.suAmbra)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Tema.ambra.opacity(bloccata ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(bloccata || salvataggio)
        }
    }

    private var avvisoBloccata: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sveglia bloccata", systemImage: "lock.fill").font(.inter(16, .semibold)).foregroundStyle(Tema.ambra)
            Text("Suona entro 2 ore: usa il tag (la annulla in anticipo) o l'Emergency Stop.")
                .font(.inter(14)).foregroundStyle(Tema.testo)
            Button("Emergency Stop") {
                chiudi()
                stato.schermata = .emergenza
            }
            .buttonStyle(PulsanteSecondario(testo: Tema.pericolo))
        }
        .scheda(Tema.ambraTenue)
    }

    private func riga(_ titolo: String, sotto: String? = nil, valore: String, colore: Color, freccia: Bool = true) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(titolo).font(.inter(15)).foregroundStyle(Tema.testo)
                if let sotto { Text(sotto).font(.inter(12)).foregroundStyle(Tema.testo2) }
            }
            Spacer()
            Text(freccia ? "\(valore) ›" : valore).font(.inter(15)).foregroundStyle(colore)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func salva() {
        salvataggio = true
        let b = bozza
        Task {
            let r = await AlarmEngine.shared.salva(b)
            salvataggio = false
            stato.avvisa(r.messaggio)
            if r.ok { chiudi() }
        }
    }

    private func elimina() {
        let id = s.id
        Task {
            let r = await AlarmEngine.shared.elimina(id)
            stato.avvisa(r.messaggio)
            if r.ok { chiudi() }
        }
    }
}

struct SelettoreGiorni: View {
    @Binding var giorni: [Int]

    private struct Giorno: Identifiable {
        let id: Int
        let lettera: String
        let nome: String
    }
    private let settimana = [
        Giorno(id: 2, lettera: "L", nome: "lunedì"), Giorno(id: 3, lettera: "M", nome: "martedì"),
        Giorno(id: 4, lettera: "M", nome: "mercoledì"), Giorno(id: 5, lettera: "G", nome: "giovedì"),
        Giorno(id: 6, lettera: "V", nome: "venerdì"), Giorno(id: 7, lettera: "S", nome: "sabato"),
        Giorno(id: 1, lettera: "D", nome: "domenica"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(settimana) { g in
                let scelto = giorni.contains(g.id)
                Button {
                    if scelto { giorni.removeAll { $0 == g.id } } else { giorni.append(g.id); giorni.sort() }
                } label: {
                    Text(g.lettera)
                        .font(.inter(15, scelto ? .bold : .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(scelto ? Tema.ambra : Tema.superficie2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(scelto ? Tema.suAmbra : Tema.testoChiaro)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(g.nome)
                .accessibilityAddTraits(scelto ? .isSelected : [])
            }
        }
    }
}

/// Libreria delle suonerie con anteprima al tocco.
struct SceltaSuoneria: View {
    @Binding var selezione: String
    var titolo = "Suoneria"

    var body: some View {
        List {
            ForEach(Suoneria.Categoria.allCases) { categoria in
                Section(categoria.nome) {
                    ForEach(Suoneria.allCases.filter { $0.categoria == categoria }) { s in
                        Button {
                            selezione = s.rawValue
                            Anteprima.shared.suona(s.file)
                        } label: {
                            HStack {
                                Text(s.nome).font(.inter(16)).foregroundStyle(Tema.testo)
                                Spacer()
                                if s.rawValue == selezione {
                                    Image(systemName: "checkmark").foregroundStyle(Tema.ambra).accessibilityLabel("Scelta")
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Tema.superficie)
            }
            Section {
                Button("Ascolta la sirena di punizione") { Anteprima.shared.suona(Suoni.punizione) }
                    .font(.inter(15)).foregroundStyle(Tema.pericolo)
            } footer: {
                Text("Tocca per scegliere e ascoltare.")
            }
            .listRowBackground(Tema.superficie)
        }
        .stileAlba()
        .navigationTitle(titolo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onDisappear { Anteprima.shared.ferma() }
    }
}
