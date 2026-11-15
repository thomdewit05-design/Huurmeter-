import SwiftUI
import SwiftData
import WWSKit

/// Scherm 3: kale huur, ingangsdatum contract, type woning.
struct HuurView: View {
    @Bindable var woning: Woning

    private var datumBekend: Binding<Bool> {
        Binding(get: { woning.contractStart != nil },
                set: { woning.contractStart = $0 ? (woning.contractStart ?? Date()) : nil; woning.geraakt() })
    }

    private var contractDatum: Binding<Date> {
        Binding(get: { woning.contractStart ?? Date() },
                set: { woning.contractStart = $0; woning.geraakt() })
    }

    private var type: Binding<Woningtype?> {
        Binding(get: { woning.woningtype }, set: { woning.woningtype = $0 })
    }

    var body: some View {
        Form {
            if ContractScanner.beschikbaar {
                Section {
                    ContractScanKnop(woning: woning)
                } footer: {
                    Text("De app leest de kale huur en de ingangsdatum uit uw contract. Dat gebeurt op uw telefoon; de foto's worden niet bewaard.")
                }
            }
            Section {
                TextField("Kale huur per maand", value: $woning.kaleHuur, format: .currency(code: "EUR"))
                    .keyboardType(.decimalPad)
            } header: {
                Text("Kale huur")
            } footer: {
                Text("De huur zonder servicekosten, gas, water en licht. Staat in uw huurcontract of op de jaarlijkse huurverhogingsbrief.")
            }

            Section {
                Toggle("Ik weet de ingangsdatum", isOn: datumBekend)
                if woning.contractStart != nil {
                    DatePicker("Ingangsdatum contract", selection: contractDatum, in: ...Date(), displayedComponents: .date)
                }
            } header: {
                Text("Huurcontract")
            } footer: {
                Text("Binnen zes maanden na de start van uw eerste huurcontract voor deze woning kunt u de Huurcommissie vragen de aanvangshuur te toetsen.")
            }

            Section {
                Picker("Type woning", selection: type) {
                    Text("Kies…").tag(Woningtype?.none)
                    Text("Eengezinswoning").tag(Woningtype?.some(.eengezins))
                    Text("Appartement of andere woning").tag(Woningtype?.some(.meergezins))
                }
            } footer: {
                Text("Een eengezinswoning heeft geen andere woningen boven of onder zich, zoals een rijtjeshuis of vrijstaand huis. Al het andere (flat, boven- of benedenwoning) is een appartement.")
            }
        }
        .huisstijlAchtergrond()
        .toetsenbordKlaar()
        .navigationTitle("Huur")
        .onChange(of: woning.kaleHuur) { woning.geraakt() }
    }
}
