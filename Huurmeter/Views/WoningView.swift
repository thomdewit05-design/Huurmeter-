import SwiftUI
import SwiftData
import HuurmeterCore
import WWSKit

/// Overzicht van één woning: de invoerstappen (scherm 2 t/m 6) en de uitkomst (scherm 7).
struct WoningView: View {
    @Bindable var woning: Woning

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
