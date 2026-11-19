import SwiftUI

/// Mostrata quando apri l'app durante una mattina.
struct SvegliaInCorsoView: View {
    @EnvironmentObject var stato: StatoApp

    private var nomiTag: String {
        let nomi = stato.dati.tag.map(\.nome)
        return nomi.isEmpty ? "Nessun tag registrato: usa l'Emergency Stop." : nomi.joined(separator: " o ") + "."
    }

    var body: some View {
        let m = stato.mattinaInCorso
        let crediti = stato.dati.impostazioni.creditiEmergenza
        ZStack {
            Tema.mattinoSfondo.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    if let m {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            let trascorso = ctx.date.timeIntervalSince(m.orario)
                            VStack(spacing: 4) {
                                Text(m.nome).font(.inter(15, .semibold)).foregroundStyle(Tema.ambra)
                                Text(Formati.ora(m.orario)).font(.grotesk(84)).tracking(-2).foregroundStyle(Tema.mattinoTesto)
                                Text(trascorso >= 0 ? "Suona da \(Formati.durata(trascorso))"
                                                    : "Risveglio dolce · sveglia tra \(Formati.durata(-trascorso))")
                                    .font(.inter(15).monospacedDigit()).foregroundStyle(Tema.mattinoTesto2)
                            }
                        }
                    }

                    ZStack {
                        Circle().stroke(Tema.mattinoAnello, lineWidth: 2)
                        Circle().stroke(Tema.mattinoBordo, lineWidth: 2).padding(30)
                        Circle().fill(Tema.ambra).padding(60)
                        Image(systemName: "wave.3.right").font(.system(size: 44, weight: .semibold)).foregroundStyle(Tema.suAmbra)
                    }
                    .frame(width: 236, height: 236)
                    .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text("Vai al tag").font(.grotesk(30, .bold)).foregroundStyle(Tema.mattinoTesto)
                        Text("\(nomiTag) Sblocca il telefono e avvicinalo al tag.")
                            .font(.inter(16)).foregroundStyle(Tema.mattinoTesto2)
                            .multilineTextAlignment(.center)
                    }

                    if let m { sirena(m) }

                    Label("Non premere i tasti volume: la sveglia non si ferma, le successive suonano mute e la mattina risulta fallita.",
                          systemImage: "speaker.slash")
                        .font(.inter(13)).foregroundStyle(Tema.pericolo)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scheda(Tema.mattinoSuperficie, raggio: 16, margine: 14)

                    if stato.dati.impostazioni.sviluppatore && m?.test == true {
                        Button("Simula tag (solo test)") {
                            Task {
                                let r = await AlarmEngine.shared.spegniConTag(nome: nil, codice: nil, simulato: true)
                                stato.avvisa(r.messaggio)
                            }
                        }
                        .buttonStyle(PulsanteSecondario(colore: Tema.mattinoSuperficie, testo: Tema.mattinoTesto))
                    }

                    Button { stato.schermata = .emergenza } label: {
                        Text("Emergency Stop · \(crediti) \(crediti == 1 ? "disponibile" : "disponibili")")
                            .font(.inter(15, .semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(Tema.pericolo)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Tema.pericolo, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    Button("Nascondi") { stato.schermata = nil }
                        .font(.inter(15)).foregroundStyle(Tema.mattinoTesto2)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 24).padding(.top, 48).padding(.bottom, 28)
            }
        }
    }

    /// Quattro segmenti che si riempiono fino alla sirena (5ª sveglia della catena).
    private func sirena(_ m: Mattina) -> some View {
        let stop = m.eventi.filter { ($0.tipo == .stop || $0.tipo == .pulsanteEmergenza) && $0.fase != .progressiva }.count
        let passo = Double(m.parametri.intervalloCatenaSec)
        let oraSirena = m.orario.addingTimeInterval(Double(Costanti.primaPunizione - 1) * passo)
        return TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let trascorso = ctx.date.timeIntervalSince(m.orario)
            let pieni = trascorso < 0 ? 0 : min(4, Int(trascorso / passo) + 1)
            let attiva = ctx.date >= oraSirena
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i < pieni ? Tema.pericolo : Tema.mattinoAnello)
                            .frame(width: 34, height: 8)
                    }
                }
                .accessibilityHidden(true)
                Text(attiva ? "Sirena attiva · stop senza tag: \(stop)"
                            : "Stop senza tag: \(stop) · sirena alle \(Formati.ora(oraSirena, secondi: true))")
                    .font(.inter(13)).foregroundStyle(Tema.mattinoTesto2)
            }
            .frame(maxWidth: .infinity)
            .scheda(Tema.mattinoSuperficie, raggio: 16, margine: 14)
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

    private var descrizione: String {
        var t = "Spegne la sveglia senza tag. Ne hai \(crediti) su \(Costanti.creditiMax)"
        if let r = Regole.prossimaRicarica(stato.dati.impostazioni) {
            let giorni = max(1, Int((r.timeIntervalSinceNow / 86400).rounded(.up)))
            t += ", il prossimo si ricarica tra \(giorni) \(giorni == 1 ? "giorno" : "giorni")"
        }
        let streak = Regole.streak(stato.dati.mattine)
        return t + ". Usarlo azzera lo streak" + (streak > 0 ? " di \(streak) giorni." : ".")
    }

    var body: some View {
        ZStack {
            Tema.mattinoSfondo.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Button { stato.chiudiSchermata() } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(PulsanteIcona(colore: Tema.mattinoSuperficie))
                        .accessibilityLabel("Indietro")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Stop").font(.grotesk(30, .bold)).foregroundStyle(Tema.mattinoTesto)
                        Text(descrizione).font(.inter(15)).foregroundStyle(Tema.mattinoTesto2)
                    }

                    HStack(spacing: 10) {
                        ForEach(0..<Costanti.creditiMax, id: \.self) { i in
                            Capsule().fill(i < crediti ? Tema.pericolo : Tema.mattinoScuro).frame(height: 10)
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Emergency Stop disponibili: \(crediti) su \(Costanti.creditiMax)")

                    if let m = obiettivo {
                        Text("Ferma «\(m.nome)», \(Formati.quando(m.orario)).").font(.inter(14)).foregroundStyle(Tema.mattinoTesto)
                    } else {
                        Text("Nessuna sveglia in corso o nelle prossime 2 ore.").font(.inter(14)).foregroundStyle(Tema.mattinoTesto2)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        EtichettaSezione(testo: "1 · Scrivi la frase", colore: Tema.mattinoTesto2)
                        Text(Costanti.fraseEmergenza)
                            .font(.inter(15, .semibold)).foregroundStyle(Tema.ambra)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scheda(Tema.mattinoSuperficie, raggio: 12, margine: 12)
                        TextField("", text: $frase, prompt: Text("Scrivi qui").foregroundColor(Tema.mattinoTesto2))
                            .font(.inter(16))
                            .foregroundStyle(Tema.mattinoTesto)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(Tema.mattinoCampo, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Regole.fraseValida(frase) ? Tema.successo : Tema.mattinoBordo, lineWidth: 1.5))
                            .accessibilityLabel("Frase di conferma")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        EtichettaSezione(testo: "2 · Tieni premuto per \(Int(Costanti.secondiEmergenza)) secondi", colore: Tema.mattinoTesto2)
                        PulsanteTenuto(abilitato: pronta, durata: Costanti.secondiEmergenza) { conferma() }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 28)
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
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Tema.mattinoScuro)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Tema.pericolo)
                    .scaleEffect(x: avanzamento, y: 1, anchor: .leading)
                Text(inizio == nil ? "Tieni premuto" : "Tieni premuto · \(Int((durata * (1 - avanzamento)).rounded(.up))) s")
                    .font(.inter(17, .bold))
                    .foregroundStyle(Tema.mattinoTesto)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(height: 72)
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
    @State private var modificaRoutine = false

    var body: some View {
        let m = stato.dati.mattine.first { $0.id == mattinaID }
        let fatte = Set(m?.routineFatte ?? [])
        let routine = stato.dati.routine
        ZStack {
            Tema.sfondo.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Tema.suAmbra)
                            .frame(width: 56, height: 56)
                            .background(Tema.ambra, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .accessibilityHidden(true)
                        Text("Buongiorno!").font(.grotesk(32, .bold)).foregroundStyle(Tema.testo)
                        if let m { Text(sottotitolo(m)).font(.inter(15)).foregroundStyle(Tema.testo2) }
                    }

                    if let m {
                        HStack(spacing: 10) {
                            Dato(titolo: "Tempo al tag", valore: Formati.durata(m.timeToScan ?? 0))
                            Dato(titolo: "Punteggio", valore: "\(m.punteggio ?? 0)", coloreValore: Tema.ambra)
                            Dato(titolo: "Giorni di fila", valore: "\(Regole.streak(stato.dati.mattine))")
                        }
                        if let n = m.stopPenalizzati, n > 0 {
                            Text("Stop senza tag: \(n) (−\(n * Costanti.penalitaStop) punti)").font(.inter(14)).foregroundStyle(Tema.testo2)
                        }
                        if m.test {
                            Text("Mattina di test: non conta nelle statistiche.").font(.inter(13)).foregroundStyle(Tema.testo3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Routine del mattino").font(.inter(17, .semibold)).foregroundStyle(Tema.testo)
                            Spacer()
                            if !routine.isEmpty {
                                Text("\(routine.filter { fatte.contains($0.id) }.count) di \(routine.count)")
                                    .font(.inter(13)).foregroundStyle(Tema.testo2)
                            }
                        }
                        if routine.isEmpty {
                            Text("Aggiungi le cose da fare appena sveglio: acqua, finestre, doccia…")
                                .font(.inter(14)).foregroundStyle(Tema.testo2)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(routine) { voce in
                                    let fatta = fatte.contains(voce.id)
                                    Button {
                                        Task { await AlarmEngine.shared.segnaRoutine(mattinaID, voce: voce.id, fatta: !fatta) }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: fatta ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 22))
                                                .foregroundStyle(fatta ? Tema.ambra : Tema.testo2)
                                            Text(voce.testo)
                                                .font(.inter(15))
                                                .strikethrough(fatta)
                                                .foregroundStyle(fatta ? Tema.testo3 : Tema.testo)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .frame(minHeight: 56)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(fatta ? .isSelected : [])
                                    if voce.id != routine.last?.id { Divider().overlay(Tema.bordo) }
                                }
                            }
                            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        Button(routine.isEmpty ? "Crea la routine" : "Modifica routine") { modificaRoutine = true }
                            .font(.inter(14, .semibold)).foregroundStyle(Tema.ambra)
                            .frame(minHeight: 44)
                    }

                    Button("Chiudi") { stato.chiudiRisveglio(mattinaID) }
                        .buttonStyle(PulsanteSecondario())
                }
                .padding(.horizontal, 20).padding(.top, 48).padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $modificaRoutine) {
            NavigationStack { RoutineEditor() }.environmentObject(stato)
        }
    }

    private func sottotitolo(_ m: Mattina) -> String {
        let tag = m.eventi.last { $0.tipo == .tag }?.nota
        let alle = m.chiusa.map { " alle \(Formati.ora($0))" } ?? ""
        if let tag, tag != "-" { return "Sveglia spenta col tag \(tag)\(alle)." }
        return "Sveglia spenta\(alle)."
    }
}
