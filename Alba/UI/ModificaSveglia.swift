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

    var body: some View {
        NavigationStack {
            Form {
                if bloccata {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Sveglia bloccata", systemImage: "lock.fill").font(.headline).foregroundStyle(Tema.ambra)
                            Text("Suona entro 2 ore. Per modificarla, disattivarla o eliminarla avvicina il tag: la mattina viene annullata in anticipo (conta come riuscita) e la sveglia si sblocca. In alternativa usa l'Emergency Stop.")
                                .foregroundStyle(Tema.testo)
                            Button("Emergency Stop") {
                                chiudi()
                                stato.schermata = .emergenza
                            }
                            .buttonStyle(.bordered)
                            .tint(Tema.pericolo)
                        }
                    }
                    .listRowBackground(Tema.ambraTenue)
                }

                Group {
                    Section {
                        DatePicker("Orario", selection: $orario, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        Label {
                            Text(prossima.map { "Prossima: \(Formati.quando($0))" } ?? "Nessuna occorrenza")
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .foregroundStyle(Tema.ambra)
                    }

                    Section {
                        SelettoreGiorni(giorni: $s.giorni)
                    } header: {
                        Text("Ripeti")
                    } footer: {
                        Text(s.giorni.isEmpty ? "Nessun giorno scelto: suona una volta sola, poi sparisce." : "Suona nei giorni evidenziati.")
                    }

                    Section("Nome") {
                        TextField("Nome", text: $s.nome)
                    }

                    Section {
                        Picker("Suoneria", selection: $s.suoneria) {
                            ForEach(Suoneria.allCases) { Text($0.nome).tag($0.rawValue) }
                        }
                    } footer: {
                        Text("Dalla 5ª sveglia della catena (circa 2 minuti dopo l'orario, se non hai ancora usato il tag) suona la sirena di punizione.")
                    }

                    Section {
                        Text("Nelle 2 ore prima della sveglia non potrai modificarla, disattivarla o eliminarla senza il tag (o l'Emergency Stop).")
                            .font(.footnote)
                            .foregroundStyle(Tema.testo2)
                    }
                }
                .disabled(bloccata)
                .listRowBackground(Tema.superficie)
            }
            .stileAlba()
            .navigationTitle(nuova ? "Nuova sveglia" : "Modifica sveglia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { chiudi() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(salvataggio ? "Salvo…" : "Salva") { salva() }
                        .disabled(bloccata || salvataggio)
                }
            }
        }
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
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(scelto ? Tema.ambra : Tema.superficie2, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(scelto ? Tema.suAmbra : Tema.testo)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(g.nome)
                .accessibilityAddTraits(scelto ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
