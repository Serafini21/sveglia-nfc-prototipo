import SwiftUI

/// Modalità sviluppatore nascosta (5 tocchi sul titolo della Home): strumenti per i test sul telefono.
struct SviluppatoreView: View {
    @EnvironmentObject var stato: StatoApp
    @State private var p = ParametriTest()

    private var aperte: [Mattina] {
        stato.dati.mattine.filter { !$0.conclusa }.sorted { $0.orario < $1.orario }
    }

    var body: some View {
        List {
            Section {
                Stepper("Progressiva: un gradino ogni \(p.passoProgressivaSec) s", value: $p.passoProgressivaSec, in: 5...60, step: 5)
                Stepper("Catena: una sveglia ogni \(p.intervalloCatenaSec) s", value: $p.intervalloCatenaSec, in: 10...60, step: 5)
                Stepper("Durata della catena: \(p.durataCatenaMin) min", value: $p.durataCatenaMin, in: 1...30)
            } header: {
                Text("Catena breve (mattine di test)")
            } footer: {
                Text("La progressiva segue l'interruttore della Home (ora \(stato.dati.impostazioni.progressiva ? "attiva" : "spenta")): 15 gradini prima dell'orario. La sirena parte dalla 5ª sveglia. Le mattine di test non contano nelle statistiche.")
            }
            .listRowBackground(Tema.superficie)

            Section("Programma") {
                Stepper("Mattina tra \(p.minutiAllaMattina) min", value: $p.minutiAllaMattina, in: 1...120)
                Button("Programma la mattina di test") { mattinaTest() }
                Stepper("Sveglia tra \(p.giorniAllaSveglia) giorni", value: $p.giorniAllaSveglia, in: 1...14)
                Button("Programma la sveglia tra \(p.giorniAllaSveglia) giorni (test scadenza)") { svegliaLontana() }
                Button("Mini-test progressiva: 4 sveglie a 30 s, +6 dB ciascuna") {
                    Task { let r = await AlarmEngine.shared.minitestProgressiva(); stato.avvisa(r.messaggio) }
                }
            }
            .listRowBackground(Tema.superficie)

            Section("Azioni") {
                Button("Simula tag (solo mattine di test)") {
                    Task { let r = await AlarmEngine.shared.spegniConTag(nome: nil, codice: nil, simulato: true); stato.avvisa(r.messaggio) }
                }
                Button("Riallinea adesso") {
                    Task { await AlarmEngine.shared.riallinea("sviluppatore"); stato.avvisa("Riallineato") }
                }
                Button("Ferma tutte le sveglie e disattivale", role: .destructive) {
                    Task { let r = await AlarmEngine.shared.fermaEDisattivaTutto(); stato.avvisa(r.messaggio) }
                }
            }
            .listRowBackground(Tema.superficie)

            Section("Stato") {
                LabeledContent("Sveglie in AlarmKit", value: "\(stato.kit.count)")
                LabeledContent("Che suonano ora", value: "\(stato.kit.filter { $0.state == .alerting }.count)")
                ForEach(aperte) { m in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(m.nome)\(m.test ? " [TEST]" : "") · \(Formati.quando(m.orario))").font(.subheadline)
                        Text("\(m.sveglie.count) sveglie, progressiva \(m.parametri.progressiva ? "sì" : "no"), catena \(m.parametri.durataCatenaMin) min\(m.ridotta.map { " – ridotta: \($0)" } ?? "")")
                            .font(.caption).foregroundStyle(Tema.testo2)
                    }
                }
            }
            .listRowBackground(Tema.superficie)

            Section {
                NavigationLink { LogView() } label: { Label("Log completo", systemImage: "doc.text") }
                Button("Esci dalla modalità sviluppatore") {
                    Task { await Store.shared.modifica { $0.impostazioni.sviluppatore = false }; stato.avvisa("Modalità sviluppatore disattivata") }
                }
            }
            .listRowBackground(Tema.superficie)
        }
        .stileAlba()
        .navigationTitle("Sviluppatore")
        .onAppear { p = stato.dati.impostazioni.test }
        .onChange(of: p) { _, nuovi in
            Task { await Store.shared.modifica { $0.impostazioni.test = nuovi } }
        }
    }

    private func parametri(progressiva: Bool) -> ParametriMattina {
        ParametriMattina(progressiva: progressiva, passoProgressivaSec: p.passoProgressivaSec,
                         intervalloCatenaSec: p.intervalloCatenaSec, durataCatenaMin: p.durataCatenaMin)
    }

    private func crea(_ nome: String, tra secondi: Double, progressiva: Bool) {
        let t = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + secondi).rounded())
        let c = Calendar.current.dateComponents([.hour, .minute], from: t)
        let s = Sveglia(nome: nome, ora: c.hour ?? 0, minuti: c.minute ?? 0, giorni: [], attiva: true,
                        dataUnaTantum: t, suoneria: Suoneria.normale.rawValue, test: parametri(progressiva: progressiva))
        Task {
            let r = await AlarmEngine.shared.salva(s)
            stato.avvisa(r.messaggio)
        }
    }

    private func mattinaTest() {
        crea("Test", tra: Double(p.minutiAllaMattina * 60), progressiva: stato.dati.impostazioni.progressiva)
    }

    private func svegliaLontana() {
        crea("Test scadenza", tra: Double(p.giorniAllaSveglia * 86400), progressiva: false)
    }
}
