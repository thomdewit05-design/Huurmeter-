import SwiftUI
import SwiftData
import WWSKit
import HuurmeterCore

/// Scherm 6: energielabel en WOZ-waarde, met links om ze op te zoeken.
struct EnergieWozView: View {
    @Bindable var woning: Woning

    private var label: Binding<Energielabel?> {
        Binding(get: { woning.energielabel },
                set: { woning.energielabel = $0; if $0 != nil { woning.energieIndex = nil } })
    }

    private var labelDatum: Binding<Date> {
        Binding(get: { woning.labelDatum ?? Date() }, set: { woning.labelDatum = $0; woning.geraakt() })
    }

    private var peildata: [Dag] { Rekenservice.wozPeildata(op: Dag(Date())) }

    private var wozPeildatum: Binding<Dag?> {
        Binding(get: { woning.wozPeildatum.map { Dag($0) } ?? peildata.first },
                set: { woning.wozPeildatum = $0?.datum(); woning.geraakt() })
    }

    private var heeftKoeling: Bool { woning.ruimten.contains { $0.verkoeling } }

    var body: some View {
        Form {
            Section {
                Picker("Energielabel", selection: label) {
                    Text("Geen of onbekend").tag(Energielabel?.none)
                    ForEach(Energielabel.allCases, id: \.self) { Text($0.rawValue).tag(Energielabel?.some($0)) }
                }
                if woning.energielabel != nil {
                    DatePicker("Opnamedatum", selection: labelDatum, in: ...Date(), displayedComponents: .date)
                } else {
                    TextField("Energie-Index (alleen oud label)", value: $woning.energieIndex,
                              format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                }
                Link(destination: URL(string: "https://www.ep-online.nl")!) {
                    Label("Label opzoeken op ep-online.nl", systemImage: "arrow.up.right.square")
                }
            } header: {
                Text("Energielabel")
            } footer: {
                Text("Een label is tien jaar geldig vanaf de datum van opname. Is het verlopen of is er geen label, dan telt het bouwjaar.")
            }

            Section {
                Toggle("Energieprestatievergoeding afgesproken", isOn: $woning.energieprestatievergoeding)
                if heeftKoeling {
                    Toggle("Koeling staat in het energielabel", isOn: $woning.koelingInLabel)
                }
            } footer: {
                Text("Een energieprestatievergoeding is een aparte vergoeding voor bijvoorbeeld zonnepanelen bij een zeer zuinige woning. Staat dat niet in uw contract, laat dit dan uit.")
            }

            Section {
                TextField("WOZ-waarde", value: $woning.wozWaarde, format: .currency(code: "EUR").precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
                if woning.wozWaarde != nil {
                    Picker("Waardepeildatum", selection: wozPeildatum) {
                        ForEach(peildata, id: \.self) { Text($0.description).tag(Dag?.some($0)) }
                    }
                }
                Link(destination: URL(string: "https://www.wozwaardeloket.nl")!) {
                    Label("WOZ-waarde opzoeken op wozwaardeloket.nl", systemImage: "arrow.up.right.square")
                }
            } header: {
                Text("WOZ-waarde")
            } footer: {
                if woning.wozWaarde == nil {
                    Text("Zonder WOZ-waarde rekent de app met de wettelijke minimumwaarde. Dat geeft meestal te weinig punten.")
                } else {
                    Text("De waardepeildatum staat op de WOZ-beschikking van de gemeente, bijvoorbeeld 01-01-2025.")
                }
            }
        }
        .navigationTitle("Energie en WOZ")
        .onChange(of: woning.wozWaarde) {
            if woning.wozWaarde != nil && woning.wozPeildatum == nil { woning.wozPeildatum = peildata.first?.datum() }
            woning.geraakt()
        }
        .onChange(of: woning.energieIndex) { woning.geraakt() }
        .onChange(of: woning.energieprestatievergoeding) { woning.geraakt() }
        .onChange(of: woning.koelingInLabel) { woning.geraakt() }
    }
}
