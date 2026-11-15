import SwiftUI
import RoomPlan
import HuurmeterCore

/// Keuken, badkamer of toilet scannen: RoomPlan herkent apparaten en sanitair, de app stelt de antwoorden
/// voor en de gebruiker bevestigt ze. Er wordt niets bewaard behalve de bevestigde antwoorden.
struct VoorzieningScanView: View {
    @Environment(\.dismiss) private var dismiss
    let woning: Woning
    let ruimte: ScanRuimte

    @State private var stoppen = false
    @State private var voorstellen: [Voorstel]?
    @State private var mislukt = false

    private var titel: LocalizedStringKey {
        switch ruimte {
        case .keuken: return "Keuken scannen"
        case .badkamer: return "Badkamer scannen"
        case .toilet: return "Toilet scannen"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let voorstellen {
                    controle(voorstellen)
                } else {
                    scanner
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                if voorstellen == nil && !mislukt {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Klaar") { stoppen = true }.disabled(stoppen)
                    }
                }
            }
        }
    }

    private var scanner: some View {
        ZStack(alignment: .bottom) {
            RoomPlanScanner(stoppen: stoppen) { kamer in
                guard let kamer else { mislukt = true; return }
                voorstellen = Objectherkenning.voorstellen(kamer.objects.map(Self.object), ruimte: ruimte)
            }
            .ignoresSafeArea()

            Text(mislukt ? "De scan is niet gelukt. Probeer het opnieuw of vul de vragen zelf in."
                         : "Loop langzaam door de ruimte en richt de camera op de apparaten en het sanitair. Tik op Klaar als alles is gezien." as LocalizedStringKey)
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding()
        }
    }

    @ViewBuilder
    private func controle(_ lijst: [Voorstel]) -> some View {
        Form {
            if lijst.isEmpty {
                Section {
                    Text("Er is niets herkend dat punten oplevert. Vul de vragen zelf in.")
                }
            } else {
                Section {
                    Text("Dit heeft de camera gezien. Controleer elk punt en zet uit wat niet klopt.")
                        .font(.subheadline)
                }
                ForEach(Array(lijst.indices), id: \.self) { i in
                    VoorstelSectie(voorstel: Binding(get: { voorstellen?[i] ?? lijst[i] }, set: { voorstellen?[i] = $0 }))
                }
            }
            if case .badkamer = ruimte {
                Section {
                    Label("Een douche herkent de camera niet. Vul die zelf in.", systemImage: "shower")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button {
                    neemOver()
                } label: {
                    Text(lijst.contains { $0.overnemen } ? "Overnemen" : "Sluiten").frame(maxWidth: .infinity).fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
        .huisstijlAchtergrond()
        .toetsenbordKlaar()
    }

    private func neemOver() {
        for v in voorstellen ?? [] where v.overnemen {
            woning.zetAntwoord(v.sleutel, v.waarde, rubriek: v.rubriek)
        }
        // Een badkamer die is gescand, bestaat in elk geval.
        if case .badkamer(let n) = ruimte, woning.antwoord("badkamers") < Double(n) {
            woning.zetAntwoord("badkamers", Double(n), rubriek: "6")
        }
        woning.geraakt()
        dismiss()
    }

    /// Van een RoomPlan-object naar een herkend object met afmetingen (meters).
    static func object(_ o: CapturedRoom.Object) -> GevondenObject {
        let soort: GevondenObject.Soort
        switch o.category {
        case .stove: soort = .kookplaat
        case .oven: soort = .oven
        case .dishwasher: soort = .vaatwasser
        case .refrigerator: soort = .koelkast
        case .sink: soort = .wastafelOfSpoelbak
        case .storage: soort = .kast
        case .toilet: soort = .toilet
        case .bathtub: soort = .bad
        case .washerDryer: soort = .wasmachine
        default: soort = .overig
        }
        return GevondenObject(soort, breedte: Double(o.dimensions.x), hoogte: Double(o.dimensions.y), diepte: Double(o.dimensions.z))
    }
}

/// Eén voorgesteld antwoord ter controle: aan/uit, soort kiezen, aantal of lengte aanpassen.
struct VoorstelSectie: View {
    @Binding var voorstel: Voorstel

    var body: some View {
        Section {
            Toggle(isOn: $voorstel.overnemen) {
                Text(voorstel.titel.vertaald).font(.headline)
            }
            if voorstel.overnemen {
                if voorstel.opties.count > 1 {
                    Picker(voorstel.titel.vertaald, selection: $voorstel.gekozen) {
                        ForEach(Array(voorstel.opties.enumerated()), id: \.offset) { n, o in
                            Text(o.tekst.vertaald).tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                if voorstel.isLengte {
                    LabeledContent("Lengte") {
                        HStack(spacing: 6) {
                            TextField("0", value: $voorstel.waarde, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                            Text("m").foregroundStyle(.secondary)
                        }
                    }
                } else if voorstel.isAantal {
                    Stepper(value: Binding(get: { Int(voorstel.waarde) }, set: { voorstel.waarde = Double($0) }), in: 1...6) {
                        LabeledContent("Aantal") { Text(verbatim: "\(Int(voorstel.waarde))").monospacedDigit() }
                    }
                }
            }
        } footer: {
            if let u = voorstel.uitleg { Text(u.vertaald) }
        }
    }
}
