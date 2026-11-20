import SwiftUI

/// "Vado a dormire ora": orari a cicli completi di sonno, ritocco di ±1 minuto, sveglia una tantum.
struct DormireView: View {
    @EnvironmentObject var stato: StatoApp
    @Environment(\.dismiss) private var chiudi
    @State private var adesso = Date()
    @State private var scelta = Costanti.cicliConsigliati
    @State private var ritocco = 0
    @State private var salvo = false

    private var opzioni: [Regole.Ciclo] { Regole.cicliSonno(da: adesso) }
    private var orario: Date {
        let base = opzioni.first { $0.cicli == scelta }?.orario ?? adesso
        return base.addingTimeInterval(Double(ritocco * 60))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button { chiudi() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(PulsanteIcona())
                    .accessibilityLabel("Indietro")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Buonanotte").font(.grotesk(28, .bold)).foregroundStyle(Tema.testo)
                    Text("Sono le \(Formati.ora(adesso)). Calcolo 15 min per addormentarti e cicli di sonno da 90 min. Scegli quando svegliarti.")
                        .font(.inter(15)).foregroundStyle(Tema.testo2)
                }

                VStack(spacing: 10) {
                    ForEach(opzioni, id: \.cicli) { o in opzione(o) }
                }

                VStack(alignment: .leading, spacing: 10) {
                    EtichettaSezione(testo: "Ritocca l'orario")
                    HStack {
                        Button("−") { ritocco -= 1 }
                            .buttonStyle(PulsanteIcona())
                            .accessibilityLabel("Un minuto prima")
                        Spacer()
                        VStack(spacing: 2) {
                            Text(Formati.ora(orario)).font(.grotesk(40)).foregroundStyle(Tema.testo)
                            Text("± 1 minuto per tocco").font(.inter(12)).foregroundStyle(Tema.testo2)
                        }
                        Spacer()
                        Button("+") { ritocco += 1 }
                            .buttonStyle(PulsanteIcona())
                            .accessibilityLabel("Un minuto dopo")
                    }
                }
                .scheda()

                InterruttoreProgressiva(sottotitolo: "Come l'ultima volta")
                    .padding(.horizontal, 4)

                Button(salvo ? "Imposto…" : "Imposta sveglia alle \(Formati.ora(orario))") { salva() }
                    .buttonStyle(PulsantePrincipale())
                    .disabled(salvo)
            }
            .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 28)
        }
        .background(Tema.sfondo.ignoresSafeArea())
        .onAppear { adesso = Date() }
    }

    private func opzione(_ o: Regole.Ciclo) -> some View {
        let scelto = o.cicli == scelta
        return Button {
            scelta = o.cicli
            ritocco = 0
        } label: {
            HStack {
                Text(Formati.ora(o.orario))
                    .font(.grotesk(28))
                    .foregroundStyle(scelto ? Tema.ambra : Tema.testo)
                    .lineLimit(1)
                    .fixedSize()
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(o.cicli) cicli · \(Formati.ore(o.durata))")
                        .font(.inter(14, scelto ? .semibold : .regular))
                        .foregroundStyle(scelto ? Tema.testo : Tema.testo2)
                    if o.cicli == Costanti.cicliConsigliati {
                        Text("Consigliato").font(.inter(12)).foregroundStyle(Tema.ambra)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(scelto ? Tema.ambraTenue : Tema.superficie, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(scelto ? Tema.ambra : Tema.bordo, lineWidth: scelto ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(scelto ? .isSelected : [])
    }

    private func salva() {
        salvo = true
        let t = orario
        let c = Calendar.current.dateComponents([.hour, .minute], from: t)
        let s = Sveglia(nome: "Vado a dormire", ora: c.hour ?? 7, minuti: c.minute ?? 0, giorni: [], attiva: true,
                        dataUnaTantum: t, suoneria: Suoneria.normale.rawValue)
        Task {
            let r = await AlarmEngine.shared.salva(s)
            salvo = false
            stato.avvisa(r.messaggio)
            if r.ok {
                Guardiano.shared.vadoALetto() // si va a dormire adesso: guardiano acceso fino alla sveglia
                chiudi()
            }
        }
    }
}
