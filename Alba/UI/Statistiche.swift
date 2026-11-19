import SwiftUI

struct StatisticheView: View {
    @EnvironmentObject var stato: StatoApp

    private var storico: [Mattina] {
        stato.dati.mattine.filter { $0.conclusa }.sorted { $0.orario > $1.orario }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Titolo(testo: "Statistiche").padding(.top, 8)

                    HStack(spacing: 10) {
                        Dato(titolo: "Giorni di fila", valore: "\(Regole.streak(stato.dati.mattine))", coloreValore: Tema.ambra)
                        Dato(titolo: "Mattine riuscite",
                             valore: "\(Regole.riuscite(stato.dati.mattine))/\(Regole.conteggiate(stato.dati.mattine))")
                        Dato(titolo: "Media al tag", valore: Regole.mediaTimeToScan(stato.dati.mattine).map(Formati.durata) ?? "–")
                    }

                    GraficoSettimana(giorni: Regole.punteggiGiorni(stato.dati.mattine, ora: Date()))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Storico").font(.inter(17, .semibold)).foregroundStyle(Tema.testo)
                        if storico.isEmpty {
                            Text("Ancora nessuna mattina conclusa.").font(.inter(14)).foregroundStyle(Tema.testo2)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(storico) { m in
                                    RigaStorico(m: m)
                                    if m.id != storico.last?.id { Divider().overlay(Tema.bordo) }
                                }
                            }
                            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 28)
            }
            .background(Tema.sfondo.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Barre del punteggio degli ultimi 7 giorni, con il valore sopra e l'iniziale del giorno sotto.
struct GraficoSettimana: View {
    let giorni: [Regole.GiornoPunteggio]

    private var media: String {
        let p = giorni.compactMap(\.punteggio)
        return p.isEmpty ? "–" : "\(p.reduce(0, +) / p.count)"
    }

    private var descrizione: String {
        giorni.map { g in
            let valore = g.punteggio.map { p in "\(p)" } ?? "nessuna mattina"
            return "\(Formati.giornoBreve(g.giorno)): \(valore)"
        }
        .joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Punteggio · ultimi 7 giorni").font(.inter(15, .semibold)).foregroundStyle(Tema.testo)
                Spacer()
                Text("media \(media)").font(.inter(13)).foregroundStyle(Tema.testo2)
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(giorni, id: \.giorno) { g in
                    VStack(spacing: 6) {
                        Text(g.punteggio.map { p in "\(p)" } ?? "—").font(.inter(11, .semibold)).foregroundStyle(Tema.testo2)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(g.punteggio == nil ? Tema.superficie2 : Tema.ambra)
                            .frame(height: max(6, CGFloat(g.punteggio ?? 0) / 100 * 110))
                        Text(Formati.iniziale(g.giorno)).font(.inter(12)).foregroundStyle(Tema.testo2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 160, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Punteggi: \(descrizione)")
        }
        .scheda(raggio: 20, margine: 18)
    }
}

struct RigaStorico: View {
    let m: Mattina

    private var colori: (Color, Color) {
        switch m.esito ?? .fallita {
        case .tag, .anticipo: (Tema.successo, Tema.successoFondo)
        case .emergenza, .fuoriCasa: (Tema.ambra, Tema.ambraTenue)
        case .fallita, .fallitaVolume: (Tema.pericolo, Tema.mattinoSuperficie)
        }
    }

    private var titolo: String {
        var t = "\(Formati.giornoStorico(m.orario)) · \(Formati.ora(m.orario))"
        if let c = m.chiusa { t += " → \(Formati.ora(c))" }
        return t
    }

    private var dettagli: String {
        var parti: [String] = []
        if let tag = m.eventi.last(where: { $0.tipo == .tag || $0.tipo == .anticipo })?.nota, tag != "-" { parti.append("Tag \(tag)") }
        if let t = m.timeToScan { parti.append("al tag in \(Formati.durata(t))") }
        if let n = m.stopPenalizzati, n > 0 { parti.append("\(n) stop senza tag") }
        if m.esito == .emergenza { parti.append("streak azzerato") }
        if let p = m.punteggio { parti.append("\(p) punti") }
        if m.test { parti.append("test") }
        return parti.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titolo).font(.inter(15, .semibold)).foregroundStyle(Tema.testo)
                if !dettagli.isEmpty { Text(dettagli).font(.inter(13)).foregroundStyle(Tema.testo2) }
                if let r = m.ridotta { Text("Programmata ridotta: \(r)").font(.inter(12)).foregroundStyle(Tema.pericolo) }
            }
            Spacer()
            Pastiglia(testo: m.esito?.titolo ?? "", colore: colori.0, fondo: colori.1)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
