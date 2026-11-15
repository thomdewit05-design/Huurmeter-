import SwiftUI
import WWSKit
import HuurmeterCore

/// Functie 8: stappenplannen voor de Huurcommissie met uw eigen termijnen.
struct StappenplanView: View {
    let woning: Woning
    private let plannen = try? Stappenplannen.laad()

    var body: some View {
        List {
            if let plannen {
                Section {
                    ForEach(plannen.procedures) { p in
                        NavigationLink {
                            ProcedureView(woning: woning, procedure: p, plannen: plannen)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.titel).font(.headline)
                                Text(p.situatie).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Een verzoek bij de Huurcommissie kost u \(Opmaak.euro(plannen.leges.huurder)). Krijgt u gelijk, dan krijgt u dit terug.")
                }
            } else {
                Text("De stappenplannen konden niet worden geladen.")
            }
        }
        .huisstijlAchtergrond()
        .navigationTitle("Naar de Huurcommissie")
    }
}

private struct ProcedureView: View {
    let woning: Woning
    let procedure: Stappenplannen.Procedure
    let plannen: Stappenplannen
    @State private var anker = Date()

    private var termijnen: StappenplanTermijnen { procedure.termijnen(anker: Dag(anker), vandaag: Dag(Date())) }

    var body: some View {
        List {
            Section {
                DatePicker(procedure.anker, selection: $anker, displayedComponents: .date)
            } footer: {
                Text(procedure.situatie)
            }

            Section("Uw termijnen") {
                if let o = termijnen.overzichtUiterlijk {
                    rij("Overzicht verhuurder uiterlijk", o.description, bron: procedure.overzichtUiterlijk?.bron)
                }
                if let v = termijnen.vroegst {
                    rij(procedure.id == "huurverlaging" ? "Vroegste ingangsdatum voorstel" : "Verzoek mogelijk vanaf",
                        v.description, bron: procedure.vroegste?.bron)
                }
                rij(procedure.id == "bezwaarHuurverhoging" ? "Bezwaar uiterlijk" : "Verzoek uiterlijk",
                    termijnen.uiterlijk.description, bron: procedure.uiterste.bron)
                Group {
                    if termijnen.verlopen {
                        Label("Deze termijn is verstreken.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Huisstijl.signaal)
                    } else {
                        Label("Nog \(termijnen.dagenOver) dagen", systemImage: "clock")
                    }
                }
                .font(.subheadline.weight(.semibold))
            }

            Section("Stappen") {
                ForEach(Array(procedure.stappen.enumerated()), id: \.offset) { i, stap in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.headline)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Huisstijl.limoen))
                            .foregroundStyle(Huisstijl.opLimoen)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stap.titel).font(.headline)
                            Text(stap.tekst)
                            if let b = stap.bron {
                                Text("Bron: \(b)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Stap \(i + 1): \(stap.titel). \(stap.tekst)")
                }
            }

            Section {
                Link(destination: URL(string: "https://www.huurcommissie.nl")!) {
                    Label("Naar huurcommissie.nl", systemImage: "arrow.up.right.square")
                }
            } footer: {
                Text("Huurmeter is niet van de Huurcommissie. Controleer de termijnen in uw eigen situatie; bij twijfel kunt u terecht bij het Juridisch Loket of een huurteam.")
            }
        }
        .huisstijlAchtergrond()
        .navigationTitle(procedure.titel)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: beginwaarde)
    }

    private func rij(_ titel: String, _ waarde: String, bron: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(titel, value: waarde)
            if let bron { Text(bron).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func beginwaarde() {
        let vandaag = Dag(Date())
        switch procedure.id {
        case "aanvangshuur":
            if let s = woning.contractStart { anker = s }
        case "huurverlaging":
            // Eerste dag van de maand die ten minste twee maanden ver ligt.
            if let v = procedure.termijnen(anker: vandaag, vandaag: vandaag).vroegst {
                let eerste = v.dag == 1 ? v : Dag(v.jaar, v.maand, 1).plusMaanden(1)
                anker = eerste.datum()
            }
        case "bezwaarHuurverhoging":
            anker = (Dag(vandaag.jaar, 7, 1) > vandaag ? Dag(vandaag.jaar, 7, 1) : Dag(vandaag.jaar + 1, 7, 1)).datum()
        case "servicekosten":
            anker = Dag(vandaag.jaar - 1, 12, 31).datum()
        default:
            break
        }
    }
}
