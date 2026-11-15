import SwiftUI
import RoomPlan
import HuurmeterCore

/// Scherm voor het scannen van één ruimte. Na de scan ziet de gebruiker de gemeten vloer en kiest
/// of de meting wordt gebruikt; corrigeren kan daarna in het ruimtescherm.
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    let naam: String
    let gebruik: (ScanResultaat, Data?) -> Void

    @State private var stoppen = false
    @State private var resultaat: ScanResultaat?
    @State private var mislukt = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                RoomPlanScanner(stoppen: stoppen) { kamer in
                    if let kamer, let s = ScanResultaat(kamer) {
                        resultaat = s
                    } else {
                        mislukt = true
                    }
                }
                .ignoresSafeArea()

                if let resultaat {
                    uitkomstKaart(resultaat)
                } else if mislukt {
                    melding("Er is geen vloer herkend. Probeer het opnieuw of vul de oppervlakte zelf in.")
                } else if !stoppen {
                    melding("Scan alleen deze ruimte. Richt de camera op de muren en loop langzaam rond. Tik op Klaar als alle muren zijn gezien.")
                }
            }
            .navigationTitle(naam)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if resultaat == nil && !mislukt {
                        Button("Klaar") { stoppen = true }.disabled(stoppen)
                    }
                }
            }
        }
    }

    private func melding(_ tekst: String) -> some View {
        Text(tekst)
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding()
    }

    private func uitkomstKaart(_ s: ScanResultaat) -> some View {
        VStack(spacing: 12) {
            Text("Gemeten vloer: \(Inmeting.weergave(s.vloeroppervlakte))")
                .font(.title3.bold())
            Text("U kunt de waarde hierna nog aanpassen, bijvoorbeeld voor een schuin dak.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button {
                gebruik(s, Plattegrond.png(s, naam: naam))
                dismiss()
            } label: {
                Text("Gebruik deze meting").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding()
    }
}
