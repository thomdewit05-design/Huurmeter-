import SwiftUI
import SwiftData
import WWSKit
import HuurmeterCore
import WidgetKit

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
        .huisstijlAchtergrond()
        .navigationTitle("Uitkomst")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: bereken)
        .task { if woning.herinneringenAan { await Meldingen.plan(voor: woning) } }
    }

    private func bereken() {
        let r = Rekenservice().bereken(woning.concept, peildatum: Dag(Date()))
        resultaat = r
        if case .uitkomst(let u) = r {
            if !(woning.laatsteBerekening?.zelfdeAls(u) ?? false) {
                woning.berekeningen.append(Berekening(uitkomst: u))
            }
            // Gegevens voor de widget (gedeelde App Group-opslag op het toestel).
            if let opslag = UserDefaults(suiteName: WidgetGegevens.appGroup) {
                WidgetGegevens(adres: woning.adres.weergave, uitkomst: u).bewaar(in: opslag)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    @ViewBuilder
    private func inhoud(_ u: Uitkomst) -> some View {
        let s = Opmaak.samenvatting(u, kaleHuur: woning.kaleHuur)
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    if s.teVeel {
                        Pil(tekst: s.kop, voorgrond: Huisstijl.signaal, achtergrond: Huisstijl.signaalVlak)
                    } else {
                        Text(s.kop).font(.headline).foregroundStyle(Huisstijl.gedempt)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(u.totaal)")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                            .foregroundStyle(Huisstijl.bosgroen)
                        Text("punten").font(.title3).foregroundStyle(Huisstijl.gedempt)
                        Spacer(minLength: 8)
                        Pil(tekst: Opmaak.segment(u.segment))
                    }
                    .accessibilityElement(children: .combine)
                    ForEach(s.regels, id: \.self) { Text($0) }
                }
                .padding(.vertical, 8)
                .listRowBackground(Huisstijl.kaart)
            } footer: {
                Text(Uitkomst.disclaimer).font(.footnote.weight(.semibold))
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
