import SwiftUI
import WWSKit
import HuurmeterCore

/// Functie 11: puntentelling voor een kamer (onzelfstandige woonruimte).
/// De invoer blijft op het toestel bewaard (één kamer).
struct KamerView: View {
    @Environment(Winkel.self) private var winkel
    @AppStorage("kamerFormulier") private var opgeslagen: Data = Data()
    @State private var f = KamerFormulier()
    @State private var geladen = false
    private let regels = try? KamerRegels.laad()

    private var uitkomst: Result<KamerUitkomst, Error>? {
        guard let regels else { return nil }
        return Result { try Kamerberekening.bereken(f.invoer, regels: regels, peildatum: Dag(Date())) }
    }

    var body: some View {
        Form {
            uitlegSectie
            kamerSectie
            gedeeldSectie
            keukenSectie
            sanitairSectie
            energieSectie
            buitenSectie
            wozSectie
            overigSectie
            uitkomstSectie
        }
        .huisstijlAchtergrond()
        .navigationTitle("Kamer")
        .onAppear {
            guard !geladen else { return }
            geladen = true
            if let f2 = try? JSONDecoder().decode(KamerFormulier.self, from: opgeslagen) { f = f2 }
        }
        .onChange(of: f) { opgeslagen = (try? JSONEncoder().encode(f)) ?? Data() }
    }

    // MARK: Secties

    private var uitlegSectie: some View {
        Section {
            Text("Voor een kamer zonder eigen voordeur, keuken of toilet geldt een eigen puntentelling. Gedeelde ruimten tellen naar rato: hun punten worden gedeeld door het aantal kamers dat ze mag gebruiken.")
                .font(.subheadline)
            TextField("Uw kale huur per maand", value: $f.kaleHuur, format: .currency(code: "EUR"))
                .keyboardType(.decimalPad)
        }
    }

    private var kamerSectie: some View {
        Section {
            m2Veld("Kamer(s) die alleen u gebruikt", $f.priveVertrekken)
            m2Veld("Eigen berging, zolder e.d.", $f.priveOverigeRuimten)
            Stepper("Verwarmde eigen kamers: \(f.verwarmdePriveVertrekken)", value: $f.verwarmdePriveVertrekken, in: 0...6)
            Stepper("Verwarmde eigen overige ruimten: \(f.verwarmdePriveOverigeRuimten)", value: $f.verwarmdePriveOverigeRuimten, in: 0...6)
            Stepper("Eigen kamers met koeling: \(f.gekoeldePriveVertrekken)", value: $f.gekoeldePriveVertrekken, in: 0...6)
        } header: {
            Text("Uw eigen ruimte")
        } footer: {
            Text("Meet van muur tot muur, op 1,5 m hoogte. U kunt de oppervlakte ook met de LiDAR-scan van een woning meten en hier overnemen.")
        }
    }

    private var gedeeldSectie: some View {
        Section {
            ForEach($f.gedeeldeRuimten) { $r in
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Soort", selection: $r.soort) {
                        Text("Woonkamer of ander vertrek").tag(GedeeldeRuimte.Soort.vertrek)
                        Text("Berging, zolder, gang").tag(GedeeldeRuimte.Soort.overig)
                    }
                    m2Veld("Oppervlakte", $r.m2)
                    deelVelden(kamers: $r.kamers, adressen: $r.adressen)
                    Toggle("Verwarmd", isOn: $r.verwarmd)
                    if r.soort == .vertrek { Toggle("Koeling", isOn: $r.gekoeld) }
                }
            }
            .onDelete { f.gedeeldeRuimten.remove(atOffsets: $0) }
            Button { f.gedeeldeRuimten.append(GedeeldeRuimte()) } label: { Label("Gedeelde ruimte toevoegen", systemImage: "plus") }
        } header: {
            Text("Gedeelde ruimten")
        } footer: {
            Text("Gangen en trappenhuizen tellen alleen mee voor verwarming (1 punt), niet voor de oppervlakte. Vul dan 0 m² in.")
        }
    }

    private var keukenSectie: some View {
        Section {
            ForEach($f.keukens) { $k in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Aanrecht")
                        Spacer()
                        TextField("m", value: $k.aanrechtLengte, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                        Text("m").foregroundStyle(.secondary)
                    }
                    deelVelden(kamers: $k.kamers, adressen: $k.adressen)
                    DisclosureGroup("Inbouwapparatuur en extra's (\(k.voorzieningen.count))") {
                        ForEach(Self.keukenVoorzieningen, id: \.sleutel) { o in
                            let sleutel = o.sleutel, naam = o.naam
                            Toggle(naam.vertaald, isOn: Binding(get: { k.voorzieningen.contains(sleutel) },
                                                       set: { if $0 { k.voorzieningen.insert(sleutel) } else { k.voorzieningen.remove(sleutel) } }))
                        }
                    }
                }
            }
            .onDelete { f.keukens.remove(atOffsets: $0) }
            Button { f.keukens.append(KeukenRij()) } label: { Label("Keuken toevoegen", systemImage: "plus") }
        } header: {
            Text("Keuken")
        }
    }

    private var sanitairSectie: some View {
        Section {
            ForEach($f.sanitair) { $s in
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Toilet", selection: $s.toilet) {
                        Text("Geen").tag(KamerSanitair.Toilet.geen)
                        Text("Staand").tag(KamerSanitair.Toilet.staand)
                        Text("Hangend").tag(KamerSanitair.Toilet.zwevend)
                    }
                    Stepper("Wastafels: \(s.wastafels)", value: $s.wastafels, in: 0...6)
                    Stepper("Meerpersoonswastafels: \(s.meerpersoonswastafels)", value: $s.meerpersoonswastafels, in: 0...3)
                    Stepper("Douches: \(s.douches)", value: $s.douches, in: 0...3)
                    Stepper("Baden: \(s.baden)", value: $s.baden, in: 0...2)
                    Stepper("Bad met douche: \(s.badDouches)", value: $s.badDouches, in: 0...2)
                    deelVelden(kamers: $s.kamers, adressen: $s.adressen)
                    if s.douches + s.baden + s.badDouches > 0 {
                        DisclosureGroup("Extra's in de badkamer (\(s.extra.count))") {
                            ForEach(Self.badkamerExtras, id: \.sleutel) { o in
                                let sleutel = o.sleutel, naam = o.naam
                                Toggle(naam.vertaald, isOn: Binding(get: { s.extra.contains(sleutel) },
                                                           set: { if $0 { s.extra.insert(sleutel) } else { s.extra.remove(sleutel) } }))
                            }
                        }
                    }
                }
            }
            .onDelete { f.sanitair.remove(atOffsets: $0) }
            Button { f.sanitair.append(SanitairRij()) } label: { Label("Badkamer of toilet toevoegen", systemImage: "plus") }
        } header: {
            Text("Sanitair")
        } footer: {
            Text("Voeg elke badkamer en elk apart toilet apart toe, ook als u het alleen gebruikt (dan 1 kamer).")
        }
    }

    private var energieSectie: some View {
        Section {
            Picker("Energielabel van de woning", selection: $f.label) {
                Text("Geen of onbekend").tag(Energielabel?.none)
                ForEach(Energielabel.allCases, id: \.self) { Text($0.rawValue).tag(Energielabel?.some($0)) }
            }
            if f.label != nil {
                DatePicker("Opnamedatum", selection: $f.labelOpnamedatum, in: ...Date(), displayedComponents: .date)
            }
            TextField("Bouwjaar", value: $f.bouwjaar, format: .number.grouping(.never)).keyboardType(.numberPad)
        } header: {
            Text("Energie")
        } footer: {
            Text("Het label van de hele woning telt, maal uw deel van de oppervlakte. Zonder geldig label telt het bouwjaar.")
        }
    }

    private var buitenSectie: some View {
        Section {
            m2Veld("Eigen balkon of tuin", $f.priveBuitenruimte)
            ForEach($f.gedeeldeBuitenruimten) { $b in
                VStack(alignment: .leading, spacing: 6) {
                    m2Veld("Gedeelde buitenruimte", $b.m2)
                    deelVelden(kamers: $b.kamers, adressen: $b.adressen)
                }
            }
            .onDelete { f.gedeeldeBuitenruimten.remove(atOffsets: $0) }
            Button { f.gedeeldeBuitenruimten.append(GedeeldeBuitenruimte()) } label: { Label("Gedeelde buitenruimte toevoegen", systemImage: "plus") }
        } header: {
            Text("Buitenruimte")
        }
    }

    private var wozSectie: some View {
        Section {
            TextField("WOZ-waarde van het hele adres", value: $f.wozWaarde, format: .currency(code: "EUR").precision(.fractionLength(0)))
                .keyboardType(.numberPad)
            m2Veld("Gebruiksoppervlakte van het adres", $f.gebruiksoppervlakteAdres)
            if let regels {
                Picker("Waardepeildatum", selection: $f.wozPeildatum) {
                    ForEach(regels.corop.perPeildatum.keys.sorted().reversed(), id: \.self) { iso in
                        Text(Dag(iso: iso)?.description ?? iso).tag(iso)
                    }
                }
                Picker("COROP-gebied", selection: $f.coropGebied) {
                    Text("Kies").tag(String?.none)
                    ForEach(regels.corop.gebieden, id: \.self) { Text($0).tag(String?.some($0)) }
                }
            }
            Link(destination: URL(string: "https://www.wozwaardeloket.nl")!) {
                Label("WOZ en oppervlakte opzoeken op wozwaardeloket.nl", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text("WOZ-waarde")
        } footer: {
            Text("Het COROP-gebied is de regio van uw gemeente (bijvoorbeeld Groot-Amsterdam of Utrecht). De WOZ-waarde per m² wordt vergeleken met het gemiddelde van die regio: 10, 12 of 14 punten.")
        }
    }

    private var overigSectie: some View {
        Section {
            Toggle("Alleen bereikbaar via een kamer van de verhuurder, die zelf in de woning woont", isOn: $f.alleenViaVertrekVerhuurder)
            Toggle("Raam in de woonkamer kleiner dan 0,75 m²", isOn: $f.ruitKleinerDan075)
            Toggle("Onderkant raam woonkamer hoger dan 1,60 m", isOn: $f.kozijnHogerDan160)
            Toggle("Video-intercom met deuropener", isOn: $f.videoIntercom)
            Picker("Monument", selection: $f.monument) {
                Text("Geen").tag(KamerMonument.geen)
                Text("Rijksmonument, contract vóór 1-7-2024").tag(KamerMonument.rijksmonumentContractVoorWbh)
                Text("Rijksmonument, contract vanaf 1-7-2024").tag(KamerMonument.rijksmonumentContractNaWbh)
                Text("Gemeentelijk of provinciaal monument").tag(KamerMonument.gemeentelijkOfProvinciaal)
            }
        } header: {
            Text("Overig")
        }
    }

    @ViewBuilder
    private var uitkomstSectie: some View {
        switch uitkomst {
        case .success(let u):
            Section {
                LabeledContent("Punten", value: String(u.totaal)).font(.headline)
                if let max = u.maximaleHuur {
                    if winkel.ontgrendeld {
                        LabeledContent("Maximale kale huur", value: Opmaak.euro(max)).font(.headline)
                    }
                    if let huur = f.kaleHuur, huur > 0 {
                        if huur > max + 0.005 {
                            Label(winkel.ontgrendeld ? String(localized: "U betaalt mogelijk \(Opmaak.euro(huur - max)) per maand te veel.")
                                                     : Bandbreedte.voor(teVeelPerMaand: huur - max).map(Weergave.bandTekst)
                                                       ?? String(localized: "Uw huur is waarschijnlijk te hoog"),
                                  systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Huisstijl.signaal)
                        } else {
                            Label("Uw huur is niet hoger dan het maximum.", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Huisstijl.bosgroen)
                        }
                    }
                }
                ForEach(u.waarschuwingen, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
            } header: {
                Text("Uitkomst")
            } footer: {
                Text("Voor kamers geldt altijd huurbescherming, ook bij veel punten (BW 7:247). \(Uitkomst.disclaimer.vertaald)")
            }
            if !winkel.ontgrendeld && u.maximaleHuur != nil {
                Section { OntgrendelKaart() }
            }
            Section("Punten per rubriek") {
                ForEach(u.rubrieken, id: \.nummer) { r in
                    DisclosureGroup {
                        ForEach(r.stappen, id: \.self) { Text($0).font(.footnote) }
                        Text(r.bron).font(.caption).foregroundStyle(.secondary)
                    } label: {
                        LabeledContent(String("\(r.nummer). \(r.titel.vertaald)"), value: Opmaak.getal(r.punten, decimalen: 2))
                    }
                }
            }
        case .failure(let fout):
            Section("Uitkomst") {
                Text(verbatim: (fout as? WWSFout)?.description ?? fout.localizedDescription).foregroundStyle(Huisstijl.signaal)
            }
        case nil:
            Section { Text("De regels voor kamers konden niet worden geladen.") }
        }
    }

    // MARK: Hulp

    private func m2Veld(_ titel: LocalizedStringKey, _ waarde: Binding<Double>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField("0", value: waarde, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
            Text("m²").foregroundStyle(.secondary)
        }
    }

    private func deelVelden(kamers: Binding<Int>, adressen: Binding<Int>) -> some View {
        Group {
            Stepper(value: kamers, in: 1...30) {
                Text("Aantal kamers dat dit deelt: \(kamers.wrappedValue)")
            }
            Stepper(value: adressen, in: 1...50) {
                if adressen.wrappedValue == 1 { Text("Alleen dit adres") } else { Text("Aantal adressen dat dit deelt: \(adressen.wrappedValue)") }
            }
        }
    }

    struct Optie { let sleutel: String; let naam: String }

    static let keukenVoorzieningen: [Optie] = [
        Optie(sleutel: "afzuiginstallatie", naam: "Afzuigkap (inbouw)"), Optie(sleutel: "kookplaatInductie", naam: "Inductiekookplaat"),
        Optie(sleutel: "kookplaatKeramisch", naam: "Keramische kookplaat"), Optie(sleutel: "kookplaatGas", naam: "Gaskookplaat"),
        Optie(sleutel: "koelkast", naam: "Koelkast (inbouw)"), Optie(sleutel: "vrieskast", naam: "Vriezer (inbouw)"),
        Optie(sleutel: "ovenElektrisch", naam: "Elektrische oven (inbouw)"), Optie(sleutel: "ovenGas", naam: "Gasoven (inbouw)"),
        Optie(sleutel: "magnetron", naam: "Magnetron (inbouw)"), Optie(sleutel: "vaatwasmachine", naam: "Vaatwasser (inbouw)"),
        Optie(sleutel: "eenhandsmengkraan", naam: "Eenhendelmengkraan"), Optie(sleutel: "thermostatischeMengkraan", naam: "Thermostaatkraan"),
        Optie(sleutel: "kokendWater", naam: "Kokendwaterkraan"),
    ]

    static let badkamerExtras: [Optie] = [
        Optie(sleutel: "bubbelbad", naam: "Bubbelbad"), Optie(sleutel: "doucheafscheiding", naam: "Vaste douchewand of -cabine"),
        Optie(sleutel: "handdoekradiator", naam: "Handdoekradiator"), Optie(sleutel: "ingebouwdKastjeWastafel", naam: "Wastafelmeubel"),
        Optie(sleutel: "kastruimte", naam: "Kastruimte (min. 40 × 40 cm)"), Optie(sleutel: "stopcontact", naam: "Stopcontact bij wastafel"),
        Optie(sleutel: "eenhandsmengkraan", naam: "Eenhendelmengkraan"), Optie(sleutel: "thermostatischeMengkraan", naam: "Thermostaatkraan"),
    ]
}

// MARK: - Formuliermodel (bewaard als JSON)

struct GedeeldeRuimte: Codable, Hashable, Identifiable {
    enum Soort: String, Codable { case vertrek, overig }
    var id = UUID()
    var soort: Soort = .vertrek
    var m2: Double = 0
    var kamers = 2
    var adressen = 1
    var verwarmd = true
    var gekoeld = false
}

struct KeukenRij: Codable, Hashable, Identifiable {
    var id = UUID()
    var aanrechtLengte: Double = 0
    var voorzieningen: Set<String> = []
    var kamers = 2
    var adressen = 1
}

struct SanitairRij: Codable, Hashable, Identifiable {
    var id = UUID()
    var toilet: KamerSanitair.Toilet = .geen
    var wastafels = 0
    var meerpersoonswastafels = 0
    var douches = 0
    var baden = 0
    var badDouches = 0
    var extra: Set<String> = []
    var kamers = 2
    var adressen = 1
}

struct GedeeldeBuitenruimte: Codable, Hashable, Identifiable {
    var id = UUID()
    var m2: Double = 0
    var kamers = 2
    var adressen = 1
}

struct KamerFormulier: Codable, Hashable {
    var kaleHuur: Double?
    var priveVertrekken: Double = 0
    var priveOverigeRuimten: Double = 0
    var verwarmdePriveVertrekken = 1
    var verwarmdePriveOverigeRuimten = 0
    var gekoeldePriveVertrekken = 0
    var gedeeldeRuimten: [GedeeldeRuimte] = []
    var keukens: [KeukenRij] = []
    var sanitair: [SanitairRij] = []
    var label: Energielabel?
    var labelOpnamedatum = Date()
    var bouwjaar = 1970
    var priveBuitenruimte: Double = 0
    var gedeeldeBuitenruimten: [GedeeldeBuitenruimte] = []
    var wozWaarde: Double?
    var gebruiksoppervlakteAdres: Double = 0
    var wozPeildatum = "2025-01-01"
    var coropGebied: String?
    var alleenViaVertrekVerhuurder = false
    var ruitKleinerDan075 = false
    var kozijnHogerDan160 = false
    var videoIntercom = false
    var monument: KamerMonument = .geen

    var invoer: KamerInvoer {
        var k = KamerInvoer()
        k.priveVertrekken = priveVertrekken
        k.priveOverigeRuimten = priveOverigeRuimten
        k.verwarmdePriveVertrekken = verwarmdePriveVertrekken
        k.verwarmdePriveOverigeRuimten = verwarmdePriveOverigeRuimten
        k.gekoeldePriveVertrekken = gekoeldePriveVertrekken
        for r in gedeeldeRuimten {
            let g = Gedeeld(r.m2, kamers: r.kamers, adressen: r.adressen)
            let een = Gedeeld(1, kamers: r.kamers, adressen: r.adressen)
            switch (r.soort, r.adressen > 1) {
            case (.vertrek, false): k.gemeenschappelijkeVertrekken.append(g)
            case (.vertrek, true): k.binnenruimtenMeerdereAdressen.append(g)
            case (.overig, false): k.gemeenschappelijkeOverigeRuimten.append(g)
            case (.overig, true): k.overigeRuimtenMeerdereAdressen.append(g)
            }
            if r.verwarmd {
                if r.soort == .vertrek { k.verwarmdeGemeenschappelijkeVertrekken.append(een) }
                else { k.verwarmdeGemeenschappelijkeOverigeRuimten.append(een) }
            }
            if r.gekoeld && r.verwarmd && r.soort == .vertrek && r.adressen <= 1 { k.gekoeldeGemeenschappelijkeVertrekken.append(een) }
        }
        k.keukens = keukens.map {
            KamerKeuken(aanrechtLengte: $0.aanrechtLengte, voorzieningen: Dictionary(uniqueKeysWithValues: $0.voorzieningen.map { ($0, 1) }),
                        kamers: $0.kamers, adressen: $0.adressen)
        }
        k.sanitair = sanitair.map {
            KamerSanitair(toilet: $0.toilet, wastafels: $0.wastafels, meerpersoonswastafels: $0.meerpersoonswastafels,
                          douches: $0.douches, baden: $0.baden, badDouches: $0.badDouches,
                          extra: Dictionary(uniqueKeysWithValues: $0.extra.map { ($0, 1) }), kamers: $0.kamers, adressen: $0.adressen)
        }
        k.label = label
        k.labelOpnamedatum = label == nil ? nil : Dag(labelOpnamedatum)
        k.bouwjaar = bouwjaar
        k.priveBuitenruimte = priveBuitenruimte
        k.gemeenschappelijkeBuitenruimten = gedeeldeBuitenruimten.map { Gedeeld($0.m2, kamers: $0.kamers, adressen: $0.adressen) }
        k.wozWaarde = wozWaarde
        k.gebruiksoppervlakteAdres = gebruiksoppervlakteAdres > 0 ? gebruiksoppervlakteAdres : nil
        k.wozPeildatum = Dag(iso: wozPeildatum)
        k.coropGebied = coropGebied
        k.videoIntercom = videoIntercom
        k.alleenViaVertrekVerhuurder = alleenViaVertrekVerhuurder
        k.ruitKleinerDan075 = ruitKleinerDan075
        k.kozijnHogerDan160 = kozijnHogerDan160
        k.monument = monument
        return k
    }
}
