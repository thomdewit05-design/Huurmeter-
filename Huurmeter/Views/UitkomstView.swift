import SwiftUI
import SwiftData
import WWSKit
import HuurmeterCore

/// Scherm 7: punten, segment, maximale huur, verschil per maand en per jaar, uitklapbaar per rubriek.
struct UitkomstView: View {
    @Environment(\.modelContext) private var context
    @Bindable var woning: Woning
    @State private var resultaat: Rekenservice.Resultaat?

    var body: some View {
        Group {
            switch resultaat {
            case .none:
                ProgressView()
            case .melding(let tekst):
                ContentUnavailableView("Nog niet te berekenen", systemImage: "list.bullet.clipboard",
                                       description: Text(tekst))
            case .uitkomst(let u):
                inhoud(u)
            }
        }
        .navigationTitle("Uitkomst")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: bereken)
    }

    private func bereken() {
        let r = Rekenservice().bereken(woning.concept, peildatum: Dag(Date()))
        resultaat = r
        if case .uitkomst(let u) = r, !(woning.laatsteBerekening?.zelfdeAls(u) ?? false) {
            woning.berekeningen.append(Berekening(uitkomst: u))
        }
    }

    @ViewBuilder
    private func inhoud(_ u: Uitkomst) -> some View {
        let s = Opmaak.samenvatting(u, kaleHuur: woning.kaleHuur)
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(s.kop)
                        .font(.title2.bold())
                        .foregroundStyle(s.teVeel ? Color.red : Color.primary)
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(u.totaal)").font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("punten").font(.title3)
                        Spacer()
                        Text(Opmaak.segment(u.segment))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .accessibilityElement(children: .combine)
                    ForEach(s.regels, id: \.self) { Text($0) }
                }
                .padding(.vertical, 4)
            } footer: {
                Text(Uitkomst.disclaimer).font(.footnote.weight(.semibold))
            }

            if let t = u.termijnAanvangshuur {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        VStack {
                            Text("\(t.resterendeDagen)").font(.largeTitle.bold()).monospacedDigit()
                            Text(t.resterendeDagen == 1 ? "dag" : "dagen").font(.caption)
                        }
                        .frame(minWidth: 64)
                        Text(Opmaak.termijn(t)).font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                } header: {
                    Text("Aanvangshuur laten toetsen")
                }
            }

            if !u.waarschuwingen.isEmpty {
                Section("Let op") {
                    ForEach(u.waarschuwingen, id: \.self) { w in
                        Label(w, systemImage: "exclamationmark.triangle").font(.subheadline)
                    }
                }
            }

            Section {
                ForEach(u.rubrieken) { r in
                    DisclosureGroup {
                        ForEach(Array(r.stappen.enumerated()), id: \.offset) { _, stap in
                            Text(stap).font(.footnote)
                        }
                        Text("Bron: \(r.bron)").font(.caption2).foregroundStyle(.secondary)
                    } label: {
                        HStack {
                            Text("\(r.nummer). \(r.titel)")
                            Spacer()
                            Text(Opmaak.punten(r.punten)).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                if !u.prijsopslagStappen.isEmpty {
                    DisclosureGroup("Prijsopslag") {
                        ForEach(u.prijsopslagStappen, id: \.self) { Text($0).font(.footnote) }
                    }
                }
            } header: {
                Text("Punten per rubriek")
            } footer: {
                Text("Berekend met de regels van \(String(u.regelsetJaar)), peildatum \(u.peildatum.description).")
            }
        }
    }
}
