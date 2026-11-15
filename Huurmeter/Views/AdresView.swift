import SwiftUI
import SwiftData
import HuurmeterCore

/// Scherm 2: postcode en huisnummer, aanvullen via PDOK (Locatieserver en BAG), alles handmatig aan te passen.
struct AdresView: View {
    @Bindable var woning: Woning
    @State private var bezig = false
    @State private var melding: String?

    private let pdok = PDOKClient()

    var body: some View {
        Form {
            Section {
                TextField("Postcode", text: $woning.postcode)
                    .textContentType(.postalCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Huisnummer en toevoeging", text: $woning.huisnummer)
                    .autocorrectionDisabled()
                Button {
                    Task { await zoek() }
                } label: {
                    HStack {
                        Text("Adres opzoeken")
                        if bezig { Spacer(); ProgressView() }
                    }
                }
                .disabled(bezig || Postcode(woning.postcode) == nil || Huisnummer(woning.huisnummer) == nil)
            } footer: {
                if let melding {
                    Text(melding).foregroundStyle(.orange)
                } else {
                    Text("Straat, plaats en bouwjaar worden opgehaald uit de openbare registers van het Kadaster (PDOK).")
                }
            }

            Section("Adres") {
                TextField("Straat", text: $woning.straat)
                TextField("Plaats", text: $woning.plaats)
            }

            Section {
                TextField("Bouwjaar", value: $woning.bouwjaar, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
            } header: {
                Text("Bouwjaar")
            } footer: {
                Text("Het bouwjaar telt mee als er geen geldig energielabel is. Bij verbouw kan een later jaar gelden.")
            }
        }
        .navigationTitle("Adres")
        .onChange(of: woning.postcode) { woning.geraakt() }
        .onChange(of: woning.huisnummer) { woning.geraakt() }
        .onChange(of: woning.bouwjaar) { woning.geraakt() }
    }

    private func zoek() async {
        bezig = true
        melding = nil
        defer { bezig = false }
        do {
            let a = try await pdok.vulAan(postcode: woning.postcode, huisnummer: woning.huisnummer)
            woning.neemAdresOver(a)
            if a.bouwjaar == nil { melding = "Adres gevonden, maar het bouwjaar niet. Vul het zelf in." }
        } catch let fout as PDOKFout {
            melding = fout.description
        } catch {
            melding = PDOKFout.serverfout(0).description
        }
    }
}
