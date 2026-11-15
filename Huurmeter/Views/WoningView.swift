import SwiftUI
import SwiftData
import HuurmeterCore
import WWSKit

/// Overzicht van één woning: de invoerstappen (scherm 2 t/m 6) en de uitkomst (scherm 7).
struct WoningView: View {
    @Bindable var woning: Woning
    @State private var meldingTekst: String?

    private var herinneringen: Binding<Bool> {
        Binding(get: { woning.herinneringenAan }, set: { aan in
            Task { @MainActor in
                if aan && !(await Meldingen.vraagToestemming()) {
                    meldingTekst = "Meldingen staan uit voor Huurmeter. Zet ze aan in Instellingen › Huurmeter › Meldingen."
                    woning.herinneringenAan = false
                    return
                }
                meldingTekst = nil
                woning.herinneringenAan = aan
                await Meldingen.plan(voor: woning)
            }
        })
    }

    var body: some View {
        let concept = woning.concept
        List {
            Section {
                ForEach(Stap.allCases) { stap in
                    NavigationLink {
                        bestemming(stap)
                    } label: {
                        StapRij(stap: stap, status: stap.status(concept))
                    }
                }
            } footer: {
                Text("Vul de stappen in willekeurige volgorde in. U kunt alles later aanpassen.")
            }

            Section {
                NavigationLink {
                    UitkomstView(woning: woning)
                } label: {
                    Label("Uitkomst", systemImage: "chart.bar.doc.horizontal")
                        .font(.headline)
                }
            } footer: {
                Text(Uitkomst.disclaimer)
            }

            Section("Meer controleren") {
                NavigationLink {
                    HuurverhogingView(woning: woning)
                } label: {
                    Label("Huurverhoging", systemImage: "arrow.up.right.circle")
                }
            }

            Section {
                Toggle(isOn: herinneringen) {
                    Label("Herinneringen", systemImage: "bell")
                }
            } footer: {
                Text(meldingTekst ?? "Een melding twee weken en drie dagen voor het einde van de termijn voor de aanvangshuur, en elk jaar op 1 mei als de huurverhoging eraan komt.")
            }
        }
        .huisstijlAchtergrond()
        .navigationTitle(woning.titel)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func bestemming(_ stap: Stap) -> some View {
        switch stap {
        case .adres: AdresView(woning: woning)
        case .huur: HuurView(woning: woning)
        case .ruimtes: RuimtesView(woning: woning)
        case .voorzieningen: VoorzieningenView(woning: woning)
        case .energieWoz: EnergieWozView(woning: woning)
        }
    }
}

private struct StapRij: View {
    let stap: Stap
    let status: Stap.Status

    var body: some View {
        HStack {
            Label(stap.titel, systemImage: stap.systeemIcoon)
            Spacer()
            switch status {
            case .klaar:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    .accessibilityLabel("Ingevuld")
            case .deels(let reden):
                Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    .accessibilityLabel(reden)
            case .leeg:
                Text("Nog invullen").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
