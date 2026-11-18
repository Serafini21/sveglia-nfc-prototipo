import SwiftUI

/// Mostrata quando apri l'app durante una mattina.
struct SvegliaInCorsoView: View {
    @EnvironmentObject var stato: StatoApp

    var body: some View {
        let m = stato.mattinaInCorso
        ZStack {
            Tema.mattinoSfondo.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Tema.ambra)
                    .accessibilityHidden(true)
                Text("Sblocca e avvicina al tag")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Tema.testo)
                if let m {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let trascorso = ctx.date.timeIntervalSince(m.orario)
                        VStack(spacing: 4) {
                            Text(Formati.durata(abs(trascorso)))
                                .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Tema.ambra)
                            Text(trascorso >= 0 ? "dalla sveglia delle \(Formati.ora(m.orario))"
                                                : "alla sveglia delle \(Formati.ora(m.orario)) (risveglio dolce)")
                                .foregroundStyle(Tema.testo2)
                        }
                    }
                    let stop = m.eventi.filter { $0.tipo == .stop || $0.tipo == .pulsanteEmergenza }.count
                    Text("Stop premuti: \(stop)").foregroundStyle(Tema.testo2)
                }
                Label("Non premere i tasti volume: la sveglia non si ferma, le successive suonano mute e la mattina risulta fallita.",
                      systemImage: "speaker.slash.fill")
                    .font(.callout)
                    .foregroundStyle(Tema.pericolo)
                    .padding()
                    .background(Tema.mattinoSuperficie, in: RoundedRectangle(cornerRadius: 18))
                Spacer()
                if stato.dati.impostazioni.sviluppatore && m?.test == true {
                    Button("Simula tag (solo test)") {
                        Task {
                            let r = await AlarmEngine.shared.spegniConTag(nome: nil, codice: nil, simulato: true)
                            stato.avvisa(r.messaggio)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Button { stato.schermata = .emergenza } label: {
                    Text("Emergency Stop").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .tint(Tema.pericolo)
                Button("Nascondi") { stato.schermata = nil }
                    .foregroundStyle(Tema.testo2)
                    .frame(minHeight: 44)
            }
            .padding()
        }
    }
}

struct EmergenzaView: View {
    @EnvironmentObject var stato: StatoApp
    @State private var frase = ""
    @State private var invio = false

    private var obiettivo: Mattina? {
        let ora = Date()
        return stato.dati.mattine.first { $0.inCorso(ora) }
            ?? stato.dati.mattine.filter { $0.nellaFinestraPrima(ora) }.min { $0.inizio < $1.inizio }
    }
    private var crediti: Int { stato.dati.impostazioni.creditiEmergenza }
    private var pronta: Bool { obiettivo != nil && crediti > 0 && Regole.fraseValida(frase) && !invio }

    var body: some View {
        ZStack {
            Tema.mattinoSfondo.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Emergency Stop").font(.largeTitle.bold()).foregroundStyle(Tema.pericolo)
                    Text("Spegne la sveglia senza tag. Usa un credito e azzera lo streak.").foregroundStyle(Tema.testo2)

                    HStack {
                        Text("Crediti").foregroundStyle(Tema.testo)
                        Spacer()
                        Text("\(crediti)/\(Costanti.creditiMax)").font(.title2.bold()).foregroundStyle(Tema.ambra)
                    }
                    .padding()
                    .background(Tema.mattinoSuperficie, in: RoundedRectangle(cornerRadius: 18))
                    if let r = Regole.prossimaRicarica(stato.dati.impostazioni) {
                        Text("Prossima ricarica: \(Formati.quando(r))").font(.caption).foregroundStyle(Tema.testo2)
                    }

                    if let m = obiettivo {
                        Text("Ferma: «\(m.nome)», \(Formati.quando(m.orario))").foregroundStyle(Tema.testo)
                    } else {
                        Text("Nessuna sveglia in corso o nelle prossime 2 ore.").foregroundStyle(Tema.testo2)
                    }

                    Text("1. Scrivi «\(Costanti.fraseEmergenza)»").font(.headline).foregroundStyle(Tema.testo)
                    TextField(Costanti.fraseEmergenza, text: $frase)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Tema.mattinoSuperficie, in: RoundedRectangle(cornerRadius: 14))

                    Text("2. Tieni premuto per \(Int(Costanti.secondiEmergenza)) secondi").font(.headline).foregroundStyle(Tema.testo)
                    PulsanteTenuto(abilitato: pronta, durata: Costanti.secondiEmergenza) { conferma() }

                    Button("Annulla") { stato.chiudiSchermata() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Tema.testo2)
                }
                .padding()
            }
        }
    }

    private func conferma() {
        invio = true
        Task {
            let r = await AlarmEngine.shared.emergenza()
            invio = false
            stato.avvisa(r.messaggio)
            if r.ok { stato.chiudiSchermata() }
        }
    }
}

/// Pulsante da tenere premuto per un tempo fisso, con barra di avanzamento.
struct PulsanteTenuto: View {
    let abilitato: Bool
    let durata: Double
    let azione: () -> Void
    @State private var inizio: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: inizio == nil)) { ctx in
            let avanzamento = inizio.map { min(1, ctx.date.timeIntervalSince($0) / durata) } ?? 0
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Tema.mattinoSuperficie)
                RoundedRectangle(cornerRadius: 18)
                    .fill(Tema.pericolo.opacity(0.85))
                    .scaleEffect(x: avanzamento, y: 1, anchor: .leading)
                Text(inizio == nil ? "Tieni premuto" : "Tieni premuto… \(Int((durata * (1 - avanzamento)).rounded(.up))) s")
                    .font(.headline)
                    .foregroundStyle(Tema.testo)
            }
            .frame(height: 64)
        }
        .opacity(abilitato ? 1 : 0.4)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: durata, maximumDistance: 60) {
            inizio = nil
            azione()
        } onPressingChanged: { premuto in
            inizio = premuto && abilitato ? Date() : nil
        }
        .allowsHitTesting(abilitato)
        .accessibilityLabel("Conferma Emergency Stop tenendo premuto per \(Int(durata)) secondi")
    }
}

struct RisveglioView: View {
    @EnvironmentObject var stato: StatoApp
    let mattinaID: UUID

    var body: some View {
        let m = stato.dati.mattine.first { $0.id == mattinaID }
        ZStack {
            Tema.sfondo.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "sun.max.fill").font(.system(size: 80)).foregroundStyle(Tema.ambra).accessibilityHidden(true)
                Text("Risveglio riuscito").font(.largeTitle.bold()).foregroundStyle(Tema.testo)
                if let m {
                    HStack {
                        Dato(titolo: "Time-to-scan", valore: Formati.durata(m.timeToScan ?? 0))
                        Dato(titolo: "Punteggio", valore: "\(m.punteggio ?? 0)")
                        Dato(titolo: "Streak", valore: "\(Regole.streak(stato.dati.mattine))")
                    }
                    .padding()
                    .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 22))
                    if let n = m.stopPenalizzati, n > 0 {
                        Text("Stop senza tag: \(n) (−\(n * Costanti.penalitaStop) punti)").foregroundStyle(Tema.testo2)
                    }
                    if m.test {
                        Text("Mattina di test: non conta nelle statistiche.").font(.footnote).foregroundStyle(Tema.testo2)
                    }
                }
                Spacer()
                Button { stato.chiudiRisveglio(mattinaID) } label: {
                    Text("Buona giornata").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tema.ambra)
                .foregroundStyle(Tema.suAmbra)
            }
            .padding()
        }
    }
}
