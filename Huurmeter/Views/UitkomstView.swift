import SwiftUI
import SwiftData
import WWSKit
import HuurmeterCore

/// Scherm 7: punten, segment, maximale huur, verschil per maand en per jaar, uitklapbaar per rubriek.
struct UitkomstView: View {
    @Environment(\.modelContext) private var context
    @Environment(Winkel.self) private var winkel
    @Bindable var woning: Woning
    @State private var resultaat: Rekenservice.Resultaat?
    @State private var getoondePunten = 0

    var body: some View {
        Group {
            switch resultaat {
            case .none:
                ProgressView()
            case .melding(let tekst):
                ContentUnavailableView("Nog niet te berekenen", systemImage: "list.bullet.clipboard",
                                       description: Text(tekst.vertaald))
            case .uitkomst(let u):
                inhoud(u)
            }
        }
        .huisstijlAchtergrond()
        .navigationTitle("Uitkomst")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: bereken)
        .onChange(of: winkel.ontgrendeld) { bereken() }
        .task { if woning.herinneringenAan { await Meldingen.plan(voor: woning) } }
    }

    private func bereken() {
        let r = Rekenservice().bereken(woning.concept, peildatum: Dag(Date()))
        resultaat = r
        if case .uitkomst(let u) = r {
            if !(woning.laatsteBerekening?.zelfdeAls(u) ?? false) {
                woning.berekeningen.append(Berekening(uitkomst: u))
            }
        }
    }

    @ViewBuilder
    private func inhoud(_ u: Uitkomst) -> some View {
        let s = winkel.ontgrendeld ? Weergave.samenvatting(u, kaleHuur: woning.kaleHuur)
                                   : Weergave.vergrendeldeSamenvatting(u, kaleHuur: woning.kaleHuur)
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    if s.teVeel {
                        Pil(tekst: s.kop, voorgrond: Huisstijl.signaal, achtergrond: Huisstijl.signaalVlak)
                    } else {
                        Text(s.kop).font(.headline).foregroundStyle(Huisstijl.gedempt)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "\(getoondePunten)")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                            .foregroundStyle(Huisstijl.bosgroen)
                            .contentTransition(.numericText(value: Double(getoondePunten)))
                            .onAppear {
                                withAnimation(.huurmeter.delay(0.15)) { getoondePunten = u.totaal }
                            }
                            .onChange(of: u.totaal) { withAnimation(.huurmeter) { getoondePunten = u.totaal } }
                            .accessibilityLabel(Text(verbatim: "\(u.totaal)"))
                        Text("punten").font(.title3).foregroundStyle(Huisstijl.gedempt)
                        Spacer(minLength: 8)
                        Pil(tekst: Weergave.segment(u.segment))
                    }
                    .accessibilityElement(children: .combine)
                    ForEach(s.regels, id: \.self) { Text($0) }
                }
                .padding(.vertical, 8)
                .listRowBackground(Huisstijl.kaart)
                // Verbetering 1: bij een te hoge huur staat de betaalkaart direct onder de samenvatting.
                if !winkel.ontgrendeld && s.teVeel {
                    OntgrendelKaart(kop: "Zie hoeveel u te veel betaalt")
                }
            } footer: {
                Text(Uitkomst.disclaimer).font(.footnote.weight(.semibold))
            }

            if !winkel.ontgrendeld && u.maximaleHuur != nil && !s.teVeel {
                Section { OntgrendelKaart() }
            }

            Section {
                NavigationLink {
                    ActieView(woning: woning, uitkomst: u)
                } label: {
                    Label("Dossier en brief", systemImage: "doc.richtext")
                }
            } footer: {
                Text("Een PDF-dossier om mee te nemen naar uw verhuurder of de Huurcommissie, en een conceptbrief.")
            }

            if let t = u.termijnAanvangshuur {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        VStack {
                            Text("\(t.resterendeDagen)").font(.largeTitle.bold()).monospacedDigit()
                            Text(t.resterendeDagen == 1 ? "dag" : "dagen" as LocalizedStringKey).font(.caption)
                        }
                        .frame(minWidth: 64)
                        Text(Weergave.termijn(t)).font(.subheadline)
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
                            Text(verbatim: "\(r.nummer). \(r.titel.vertaald)")
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
