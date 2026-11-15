import SwiftUI
import WWSKit

/// Scherm 9: uitleg, bronnen, disclaimer en privacy.
struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Wat doet Huurmeter?") {
                Text("Huurmeter rekent uit hoeveel punten uw huurwoning heeft volgens het woningwaarderingsstelsel (WWS), wat de maximale kale huur is en of u mogelijk te veel betaalt.")
            }
            Section("Belangrijk") {
                Text(Uitkomst.disclaimer)
                Text("Huurmeter is niet van of namens de overheid of de Huurcommissie.")
            }
            Section("Privacy") {
                Text("Alles wat u invult blijft op uw telefoon. Er is geen account en de app verzamelt geen gegevens. Alleen bij 'Adres opzoeken' worden postcode en huisnummer naar de openbare dienst PDOK van het Kadaster gestuurd.")
            }
            if let regels = HuidigeRegels.regels {
                Section("Bronnen (regels \(String(regels.regelsetJaar)))") {
                    ForEach(regels.bronnen.keys.sorted(), id: \.self) { sleutel in
                        if let b = regels.bronnen[sleutel], let url = URL(string: b.url) {
                            Link(destination: url) {
                                VStack(alignment: .leading) {
                                    Text(b.titel)
                                    Text(b.versie).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Info")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Sluit") { dismiss() } }
        }
    }
}
