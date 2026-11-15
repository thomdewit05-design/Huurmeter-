import SwiftUI
import SwiftData
import HuurmeterCore

/// Scherm 2: postcode en huisnummer, aanvullen via PDOK (Locatieserver en BAG), alles handmatig aan te passen.
struct AdresView: View {
    @Bindable var woning: Woning
    @State private var bezig = false
    @State private var melding: String?
    @State private var gevonden: String?

    private let pdok = PDOKClient()
    private let epOnline = EPOnlineClient(sleutel: Bundle.main.object(forInfoDictionaryKey: "EPOnlineAPIKey") as? String)

    var body: some View {
        Form {
            if ContractScanner.beschikbaar && woning.straat.isEmpty {
                Section {
                    ContractScanKnop(woning: woning) { Task { await zoek() } }
                } footer: {
                    Text("Sneller: scan uw huurcontract. De app neemt het adres, de huur, de ingangsdatum en de servicekosten over.")
                }
            }
            Section {
                TextField("Postcode", text: $woning.postcode)
                    .textContentType(.postalCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Huisnummer en toevoeging", text: $woning.huisnummer)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await zoek() } }
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
                } else if let gevonden {
                    Label(gevonden, systemImage: "checkmark.circle.fill").foregroundStyle(Huisstijl.bosgroen)
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
        .huisstijlAchtergrond()
        .toetsenbordKlaar()
        .navigationTitle("Adres")
        .onChange(of: woning.postcode) { woning.geraakt() }
        .onChange(of: woning.huisnummer) { woning.geraakt() }
        .onChange(of: woning.bouwjaar) { woning.geraakt() }
    }

    private func zoek() async {
        guard !bezig, Postcode(woning.postcode) != nil, Huisnummer(woning.huisnummer) != nil else { return }
        bezig = true
        melding = nil
        gevonden = nil
        defer { bezig = false }
        do {
            let a = try await pdok.vulAan(postcode: woning.postcode, huisnummer: woning.huisnummer)
            woning.neemAdresOver(a)
            var opgehaald = [String(localized: "adres")]
            if a.bouwjaar != nil { opgehaald.append(String(localized: "bouwjaar")) }
            // Snelstart: meteen ook het energielabel, als dat er nog niet is en EP-Online beschikbaar is.
            if epOnline.beschikbaar && woning.energielabel == nil && woning.energieIndex == nil,
               let l = try? await epOnline.haalLabel(postcode: woning.postcode, huisnummer: woning.huisnummer) {
                woning.neemLabelOver(l)
                opgehaald.append(String(localized: "energielabel"))
            }
            gevonden = String(localized: "Opgehaald: \(opgehaald.joined(separator: ", ")). Tik op Volgende.")
            if a.bouwjaar == nil { melding = String(localized: "Adres gevonden, maar het bouwjaar niet. Vul het zelf in.") }
        } catch let fout as PDOKFout {
            melding = fout.description
        } catch {
            melding = PDOKFout.serverfout(0).description
        }
    }
}
