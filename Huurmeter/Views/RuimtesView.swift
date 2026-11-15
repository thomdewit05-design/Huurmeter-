import SwiftUI
import SwiftData
import WWSKit
import HuurmeterCore

/// Scherm 4: vertrekken, overige ruimten en buitenruimten. In fase 2 alleen handmatige invoer;
/// de knop "Scannen" (RoomPlan) volgt in fase 3.
struct RuimtesView: View {
    @Environment(\.modelContext) private var context
    @Bindable var woning: Woning
    @State private var bewerk: Ruimte?
    @State private var woningScan = false

    var body: some View {
        List {
            ForEach(RuimteSoort.weergaveVolgorde, id: \.self) { soort in
                let lijst = woning.gesorteerdeRuimten.filter { $0.soort == soort }
                if !lijst.isEmpty {
                    Section(soort.meervoud) {
                        ForEach(lijst) { r in
                            Button { bewerk = r } label: { RuimteRij(ruimte: r) }
                                .foregroundStyle(.primary)
                        }
                        .onDelete { idx in verwijder(idx.map { lijst[$0] }) }
                    }
                }
            }
            if Scanner.beschikbaar {
                Section {
                    Button {
                        woningScan = true
                    } label: {
                        Label("Hele woning scannen", systemImage: "camera.metering.matrix")
                    }
                } footer: {
                    Text("Loop met de camera kamer voor kamer door de woning. Daarna controleert u de lijst.")
                }
            }
            Section {
                Menu {
                    ForEach(RuimteSjabloon.alle) { s in
                        Button(s.naam.vertaald) { voegToe(s) }
                    }
                } label: {
                    Label("Ruimte toevoegen", systemImage: "plus.circle.fill")
                }
            } footer: {
                Text("Meet van muur tot muur op 1,50 m hoogte. Bij een schuin dak telt alleen het deel waar het plafond minstens 1,50 m hoog is. Vaste kasten tellen mee.")
            }
        }
        .overlay {
            if woning.ruimten.isEmpty {
                ContentUnavailableView("Nog geen ruimtes", systemImage: "square.split.2x2",
                                       description: Text("Voeg de kamers, de berging en de tuin of het balkon toe."))
            }
        }
        .huisstijlAchtergrond()
        .toetsenbordKlaar()
        .navigationTitle("Ruimtes")
        .fullScreenCover(isPresented: $woningScan) { WoningScanView(woning: woning) }
        .sheet(item: $bewerk) { r in
            NavigationStack { RuimteEditView(ruimte: r) }
        }
    }

    private func voegToe(_ s: RuimteSjabloon) {
        let volgende = (woning.ruimten.map(\.volgorde).max() ?? 0) + 1
        let aantal = woning.ruimten.filter { $0.functie == s.functie && $0.soort == s.soort }.count
        let r = Ruimte(naam: aantal == 0 ? s.naam : "\(s.naam) \(aantal + 1)", functie: s.functie, volgorde: volgende)
        r.soort = s.soort
        if s.soort == .buitenruimte { r.verwarmd = false }
        woning.ruimten.append(r)
        woning.geraakt()
        bewerk = r
    }

    private func verwijder(_ ruimten: [Ruimte]) {
        for r in ruimten { context.delete(r) }
        woning.geraakt()
    }
}

private struct RuimteRij: View {
    let ruimte: Ruimte

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(ruimte.naam.isEmpty ? String(localized: "Naamloos") : ruimte.naam)
                Text(ruimte.bron == .scan ? "Gescand" : "Handmatig" as LocalizedStringKey).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(ruimte.oppervlakte > 0 ? Opmaak.oppervlakte(ruimte.oppervlakte) : "– m²")
                .monospacedDigit()
                .foregroundStyle(ruimte.oppervlakte > 0 ? .primary : .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Bewerken van één ruimte.
struct RuimteEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var ruimte: Ruimte
    @State private var toonScan = false
    @State private var toonHoeken = false

    private var aftrek: Binding<Double?> {
        Binding(get: { ruimte.aftrek > 0 ? ruimte.aftrek : nil },
                set: { ruimte.aftrek = max(0, $0 ?? 0); if ruimte.bron == .scan { ruimte.herberekenUitScan() } })
    }

    private var schuinDak: Binding<Bool> {
        Binding(get: { ruimte.schuinDak },
                set: { ruimte.schuinDak = $0
                       if !$0 { ruimte.aftrek = 0 }
                       if ruimte.bron == .scan { ruimte.herberekenUitScan() } else { ruimte.woning?.geraakt() } })
    }

    private var functie: Binding<RuimteFunctie> {
        Binding(get: { ruimte.functie ?? .overig },
                set: { f in
                    ruimte.functie = f
                    if ruimte.soort != .buitenruimte { ruimte.soort = RuimteConcept.standaardSoort(voor: f) }
                    ruimte.woning?.geraakt()
                })
    }

    private var soort: Binding<RuimteSoort> {
        Binding(get: { ruimte.soort }, set: { ruimte.soort = $0; ruimte.woning?.geraakt() })
    }

    private var oppervlakte: Binding<Double?> {
        Binding(get: { ruimte.oppervlakte > 0 ? ruimte.oppervlakte : nil },
                set: { ruimte.oppervlakte = max(0, $0 ?? 0); ruimte.bron = .handmatig; ruimte.woning?.geraakt() })
    }

    var body: some View {
        Form {
            Section {
                TextField("Naam", text: $ruimte.naam)
                if ruimte.soort != .buitenruimte {
                    Picker("Functie", selection: functie) {
                        ForEach(RuimteFunctie.allCases, id: \.self) { Text($0.naam.vertaald).tag($0) }
                    }
                }
                Picker("Soort", selection: soort) {
                    ForEach(RuimteSoort.weergaveVolgorde, id: \.self) { Text($0.enkelvoud).tag($0) }
                }
            } footer: {
                Text(ruimte.soort.uitleg.vertaald)
            }

            if ruimte.soort != .buitenruimte {
                inmetenSectie
            }

            Section {
                TextField("Oppervlakte in m²", value: oppervlakte, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                if OppervlakteMeterView.beschikbaar {
                    Button {
                        toonHoeken = true
                    } label: {
                        Label("Meten door de hoeken aan te tikken", systemImage: "camera.metering.spot")
                    }
                }
            } header: {
                Text("Oppervlakte")
            } footer: {
                if ruimte.soort == .buitenruimte {
                    Text("De hele onbebouwde oppervlakte. Bij een balkon meet u vanaf de binnenkant van het hek.")
                } else {
                    Text("Van muur tot muur op 1,50 m hoogte, alleen het deel waar het plafond minstens 1,50 m hoog is.")
                }
            }

            if ruimte.soort != .buitenruimte {
                Section {
                    Toggle("Verwarmd", isOn: $ruimte.verwarmd)
                    if ruimte.soort == .vertrek {
                        Toggle("Vaste koeling die ook verwarmt", isOn: $ruimte.verkoeling)
                    }
                    if ruimte.soort == .overigeRuimte && ruimte.functie == .zolder {
                        Toggle("Geen vaste trap (vlizotrap of luik)", isOn: $ruimte.zolderZonderVasteTrap)
                    }
                } footer: {
                    if ruimte.soort == .vertrek {
                        Text("Koeling telt alleen bij een vaste installatie, zoals een warmtepomp of vaste airco. Een mobiele airco telt niet.")
                    }
                }
            }
        }
        .huisstijlAchtergrond()
        .toetsenbordKlaar()
        .navigationTitle(ruimte.naam.isEmpty ? "Ruimte" : ruimte.naam)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Klaar") { dismiss() } }
        }
        .onChange(of: ruimte.verwarmd) { ruimte.woning?.geraakt() }
        .onChange(of: ruimte.verkoeling) { ruimte.woning?.geraakt() }
        .onChange(of: ruimte.zolderZonderVasteTrap) { ruimte.woning?.geraakt() }
        .onChange(of: ruimte.naam) { ruimte.woning?.geraakt() }
        .fullScreenCover(isPresented: $toonHoeken) {
            OppervlakteMeterView(titel: ruimte.naam.isEmpty ? String(localized: "Ruimte") : ruimte.naam) { m2 in
                ruimte.oppervlakte = m2
                ruimte.bron = .scan
                ruimte.woning?.geraakt()
            }
        }
        .fullScreenCover(isPresented: $toonScan) {
            ScanView(naam: ruimte.naam.isEmpty ? "Ruimte" : ruimte.naam) { scan, plattegrond in
                ruimte.neemScanOver(scan, plattegrond: plattegrond)
            }
        }
    }

    /// Fase 3: scannen met RoomPlan en de WWS-correcties die RoomPlan niet zelf kan zien.
    @ViewBuilder
    private var inmetenSectie: some View {
        Section {
            if Scanner.beschikbaar {
                Button {
                    toonScan = true
                } label: {
                    Label(ruimte.gescandeOppervlakte == nil ? "Scannen met de camera" : "Opnieuw scannen" as LocalizedStringKey,
                          systemImage: "camera.viewfinder")
                }
            }
            if let gescand = ruimte.gescandeOppervlakte {
                LabeledContent("Gemeten vloer", value: Inmeting.weergave(gescand))
                if let data = ruimte.plattegrond, let beeld = UIImage(data: data) {
                    Image(uiImage: beeld)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 220)
                        .accessibilityLabel("Plattegrond van \(ruimte.naam)")
                }
            }
            Toggle("Schuin dak of verlaagd plafond", isOn: schuinDak)
            if ruimte.schuinDak || ruimte.aftrek > 0 {
                HStack {
                    Text("Aftrekken")
                    TextField("0", value: aftrek, format: .number.precision(.fractionLength(0...2)))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                    Text("m²").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Inmeten")
        } footer: {
            if ruimte.schuinDak {
                Text("Trek het deel af waar het plafond lager is dan 1,50 m, plus schachten en leidingkokers. Vaste kasten tellen wél mee. De camera herkent een schuin dak niet goed, dus dit vult u zelf in.")
            } else if Scanner.beschikbaar {
                Text("De scan meet de vloer van muur tot muur. Controleer de uitkomst en pas hem zo nodig aan.")
            } else {
                Text("Meet de kamer met een rolmaat en vul de oppervlakte hieronder in.")
            }
        }
    }
}

// MARK: - Teksten

struct RuimteSjabloon: Identifiable {
    let naam: String
    let functie: RuimteFunctie
    let soort: RuimteSoort
    var id: String { naam }

    static let alle: [RuimteSjabloon] = [
        .init(naam: "Woonkamer", functie: .woonkamer, soort: .vertrek),
        .init(naam: "Slaapkamer", functie: .slaapkamer, soort: .vertrek),
        .init(naam: "Keuken", functie: .keuken, soort: .vertrek),
        .init(naam: "Badkamer", functie: .badkamer, soort: .vertrek),
        .init(naam: "Toilet", functie: .toilet, soort: .overigeRuimte),
        .init(naam: "Hal of gang", functie: .gang, soort: .verkeersruimte),
        .init(naam: "Berging", functie: .berging, soort: .overigeRuimte),
        .init(naam: "Zolder", functie: .zolder, soort: .overigeRuimte),
        .init(naam: "Garage", functie: .garage, soort: .overigeRuimte),
        .init(naam: "Tuin", functie: .overig, soort: .buitenruimte),
        .init(naam: "Balkon", functie: .overig, soort: .buitenruimte),
        .init(naam: "Andere ruimte", functie: .overig, soort: .vertrek),
    ]
}

extension RuimteSoort {
    static let weergaveVolgorde: [RuimteSoort] = [.vertrek, .overigeRuimte, .verkeersruimte, .buitenruimte]

    var enkelvoud: String {
        switch self {
        case .vertrek: return "Kamer (vertrek)"
        case .overigeRuimte: return "Overige ruimte"
        case .verkeersruimte: return "Gang, hal of overloop"
        case .buitenruimte: return "Eigen buitenruimte"
        }
    }

    var meervoud: String {
        switch self {
        case .vertrek: return "Kamers"
        case .overigeRuimte: return "Overige ruimtes"
        case .verkeersruimte: return "Gangen en hal"
        case .buitenruimte: return "Buitenruimte"
        }
    }

    var uitleg: String {
        switch self {
        case .vertrek:
            return "Een kamer om in te verblijven, met een raam, minstens 4 m² en grotendeels 2,10 m hoog. Keuken en badkamer tellen altijd als kamer."
        case .overigeRuimte:
            return "Een ruimte van minstens 2 m² die geen kamer is, zoals een berging, zolder, bijkeuken of eigen garage."
        case .verkeersruimte:
            return "Gangen, hal en overloop. Deze tellen alleen mee voor verwarming."
        case .buitenruimte:
            return "Tuin, balkon, dakterras of loggia die alleen bij uw woning hoort. Een Frans balkon telt niet."
        }
    }
}

extension RuimteFunctie {
    var naam: String {
        switch self {
        case .woonkamer: return "Woonkamer"
        case .slaapkamer: return "Slaapkamer"
        case .keuken: return "Keuken"
        case .badkamer: return "Badkamer of doucheruimte"
        case .toilet: return "Toilet"
        case .berging: return "Berging of bijkeuken"
        case .zolder: return "Zolder"
        case .garage: return "Garage"
        case .gang: return "Gang of hal"
        case .overig: return "Anders"
        }
    }
}
