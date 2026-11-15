import SwiftUI

/// Betaalmuur voor de berekende maximale huur (en het dossier en de brief). Eén eenmalige aankoop
/// voor onbeperkt veel woningen en kamers; de prijs staat in App Store Connect, niet in de code.
struct OntgrendelKaart: View {
    @Environment(Winkel.self) private var winkel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bekijk uw maximale huur", systemImage: "lock.open")
                .font(.headline).foregroundStyle(Huisstijl.bosgroen)
            VStack(alignment: .leading, spacing: 6) {
                Label("De maximale kale huur en hoeveel u per maand en per jaar te veel betaalt", systemImage: "eurosign.circle")
                Label("PDF-dossier en conceptbrief aan uw verhuurder", systemImage: "doc.richtext")
                Label("Voor onbeperkt veel woningen en kamers", systemImage: "house.and.flag")
            }
            .font(.subheadline)
            Button {
                Task { await winkel.koop() }
            } label: {
                HStack {
                    Spacer()
                    Text(winkel.product.map { String(localized: "Ontgrendel voor \($0.displayPrice)") } ?? String(localized: "Laden…"))
                        .fontWeight(.semibold)
                    if winkel.bezig { ProgressView().padding(.leading, 4) }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(winkel.product == nil || winkel.bezig)
            Button("Eerdere aankoop herstellen") { Task { await winkel.herstel() } }
                .font(.footnote)
                .buttonStyle(.borderless)
            Text("Eenmalige aankoop. Geen abonnement en geen advertenties. Uw gegevens blijven op uw telefoon.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .alert("Melding", isPresented: Binding(get: { winkel.melding != nil }, set: { if !$0 { winkel.melding = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(winkel.melding ?? "")
        }
    }
}
