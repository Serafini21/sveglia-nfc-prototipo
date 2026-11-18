import SwiftUI

/// Fase 1: riepilogo e storico semplice. Grafici e punteggi dettagliati arrivano in Fase 2.
struct StatisticheView: View {
    @EnvironmentObject var stato: StatoApp

    private var storico: [Mattina] {
        stato.dati.mattine.filter { $0.conclusa }.sorted { $0.orario > $1.orario }
    }

    private var media: String {
        let punti = storico.filter { !$0.test }.prefix(7).compactMap(\.punteggio)
        return punti.isEmpty ? "–" : "\(punti.reduce(0, +) / punti.count)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Dato(titolo: "Streak", valore: "\(Regole.streak(stato.dati.mattine))")
                        Dato(titolo: "Riuscite", valore: "\(Regole.riuscite(stato.dati.mattine))")
                        Dato(titolo: "Media 7 mattine", valore: media)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Tema.superficie)

                Section("Storico") {
                    if storico.isEmpty {
                        Text("Ancora nessuna mattina conclusa.").foregroundStyle(Tema.testo2)
                    }
                    ForEach(storico) { m in RigaStorico(m: m) }
                }
                .listRowBackground(Tema.superficie)
            }
            .stileAlba()
            .navigationTitle("Statistiche")
        }
    }
}

struct RigaStorico: View {
    let m: Mattina

    private var colore: Color {
        switch m.esito ?? .fallita {
        case .tag, .anticipo: Tema.successo
        case .emergenza, .fuoriCasa: Tema.ambra
        default: Tema.pericolo
        }
    }

    private var dettagli: String {
        var parti = ["prevista \(Formati.ora(m.orario))"]
        if let c = m.chiusa { parti.append("spenta \(Formati.ora(c))") }
        if let t = m.timeToScan { parti.append("tag in \(Formati.durata(t))") }
        let stop = m.eventi.filter { $0.tipo == .stop || $0.tipo == .pulsanteEmergenza }.count
        parti.append("stop \(stop)" + ((m.stopPenalizzati ?? 0) > 0 ? " (\(m.stopPenalizzati ?? 0) penalizzati)" : ""))
        if let p = m.punteggio { parti.append("punti \(p)") }
        return parti.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(Formati.giornoBreve(m.orario)) · \(m.nome)").font(.headline).foregroundStyle(Tema.testo)
                if m.test { Text("TEST").font(.caption2.bold()).foregroundStyle(Tema.testo2) }
                Spacer()
                Text(m.esito?.titolo ?? "").font(.subheadline.weight(.semibold)).foregroundStyle(colore)
            }
            Text(dettagli).font(.caption).foregroundStyle(Tema.testo2)
            if let r = m.ridotta { Text("Programmata ridotta: \(r)").font(.caption).foregroundStyle(Tema.pericolo) }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
