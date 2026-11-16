import SwiftUI
import WWSKit
import HuurmeterCore

/// De stappen van de kamerberekening.
enum KamerStap: Int, CaseIterable, Identifiable {
    case kamer, gedeeld, keuken, sanitair, energie, buiten, woz, overig, uitkomst

    var id: Int { rawValue }

    var titel: LocalizedStringKey {
        switch self {
        case .kamer: return "Uw kamer"
        case .gedeeld: return "Gedeelde ruimten"
        case .keuken: return "Keuken"
        case .sanitair: return "Sanitair"
        case .energie: return "Energie"
        case .buiten: return "Buitenruimte"
        case .woz: return "WOZ-waarde"
        case .overig: return "Overig"
        case .uitkomst: return "Uitkomst"
        }
    }

    var icoon: String {
        switch self {
        case .kamer: return "bed.double"
        case .gedeeld: return "sofa"
        case .keuken: return "fork.knife"
        case .sanitair: return "shower"
        case .energie: return "bolt"
        case .buiten: return "sun.max"
        case .woz: return "building.columns"
        case .overig: return "ellipsis.circle"
        case .uitkomst: return "checkmark.seal"
        }
    }
}

/// Functie 11: puntentelling voor een kamer (onzelfstandige woonruimte), als stappenplan.
/// De invoer blijft op het toestel bewaard (één kamer).
struct KamerView: View {
    @Environment(Winkel.self) private var winkel
    @AppStorage("kamerFormulier") private var opgeslagen: Data = Data()
    @AppStorage("kamerStap") private var stapNummer = 0
    @State private var f = KamerFormulier()
    @State private var geladen = false
    @State private var vooruit = true
    private let regels = try? KamerRegels.laad()

    private var stap: KamerStap { KamerStap(rawValue: stapNummer) ?? .kamer }

    private var uitkomst: Result<KamerUitkomst, Error>? {
        guard let regels else { return nil }
        return Result { try Kamerberekening.bereken(f.invoer, regels: regels, peildatum: Dag(Date())) }
    }

    var body: some View {
        Form {
            inhoud(stap)
        }
        .id(stap)
        .transition(.stap(vooruit: vooruit))
        .huisstijlAchtergrond()
        .safeAreaInset(edge: .top, spacing: 0) { kop }
        .onderbalk { navigatie }
        .sensoryFeedback(.selection, trigger: stapNummer)
        .navigationTitle("Kamer")
        .navigationBarTitleDisplayMode(.inline)
        .toetsenbordKlaar()
        .onAppear {
            guard !geladen else { return }
            geladen = true
            if let f2 = try? JSONDecoder().decode(KamerFormulier.self, from: opgeslagen) { f = f2 }
        }
        .onChange(of: f) { opgeslagen = (try? JSONEncoder().encode(f)) ?? Data() }
    }

    private func ga(naar nieuw: KamerStap) {
        vooruit = nieuw.rawValue >= stapNummer
        withAnimation(.huurmeter) { stapNummer = nieuw.rawValue }
    }

    // MARK: Kop en navigatie

    private var kop: some View {
        let totaal = KamerStap.allCases.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: stap.icoon)
                    .font(.headline)
                    .foregroundStyle(Huisstijl.opLimoen)
                    .frame(width: 38, height: 38)
                    .background(Huisstijl.limoen, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Stap \(stap.rawValue + 1) van \(totaal)")
                        .font(.caption.weight(.semibold)).foregroundStyle(Huisstijl.gedempt)
                    Menu {
                        ForEach(KamerStap.allCases) { s in
                            Button { ga(naar: s) } label: { Label(s.titel, systemImage: s.icoon) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(stap.titel).font(.title3.weight(.bold)).foregroundStyle(Huisstijl.bosgroen)
                            Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Huisstijl.gedempt)
                        }
                    }
                    .accessibilityHint(Text("Kies een andere stap"))
                }
                Spacer(minLength: 8)
                if case .success(let u) = uitkomst {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(verbatim: "\(u.totaal)").font(.title2.weight(.heavy)).monospacedDigit().foregroundStyle(Huisstijl.bosgroen)
                            .contentTransition(.numericText(value: Double(u.totaal)))
                            .animation(.huurmeter, value: u.totaal)
                        Text("punten").font(.caption2.weight(.semibold)).foregroundStyle(Huisstijl.gedempt)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            ProgressView(value: Double(stap.rawValue + 1), total: Double(totaal))
                .animation(.huurmeter, value: stap)
                .tint(Huisstijl.bosgroen)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Huisstijl.kaart)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var navigatie: some View {
        HStack(spacing: 12) {
            if let vorige = KamerStap(rawValue: stap.rawValue - 1) {
                Button { ga(naar: vorige) } label: {
                    Label("Vorige", systemImage: "chevron.left").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            if let volgende = KamerStap(rawValue: stap.rawValue + 1) {
                Button { ga(naar: volgende) } label: {
                    HStack(spacing: 6) {
                        Text(volgende == .uitkomst ? "Bekijk uitkomst" : "Volgende")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button { ga(naar: .kamer) } label: {
                    Label("Terug naar het begin", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Huisstijl.kaart)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: Inhoud per stap

    @ViewBuilder
    private func inhoud(_ s: KamerStap) -> some View {
        switch s {
        case .kamer: kamerStap
        case .gedeeld: gedeeldStap
        case .keuken: keukenStap
        case .sanitair: sanitairStap
        case .energie: energieStap
        case .buiten: buitenStap
        case .woz: wozStap
        case .overig: overigStap
        case .uitkomst: uitkomstStap
        }
    }

    @ViewBuilder
    private var kamerStap: some View {
        Section {
            Text("Voor een kamer zonder eigen voordeur, keuken of toilet geldt een eigen puntentelling. Gedeelde ruimten tellen naar rato: hun punten worden gedeeld door het aantal kamers dat ze mag gebruiken.")
                .font(.subheadline)
        }
        Section("Huur") {
            bedragRij("Kale huur per maand", $f.kaleHuur)
        }
        Section {
            getalRij("Kamer(s) die alleen u gebruikt", $f.priveVertrekken, eenheid: "m²")
            getalRij("Eigen berging, zolder e.d.", $f.priveOverigeRuimten, eenheid: "m²")
        } header: {
            Text("Oppervlakte")
        } footer: {
            Text("Meet van muur tot muur, op 1,5 m hoogte.")
        }
        Section("Verwarming en koeling") {
            aantalRij("Verwarmde eigen kamers", $f.verwarmdePriveVertrekken, 0...6)
            aantalRij("Verwarmde eigen overige ruimten", $f.verwarmdePriveOverigeRuimten, 0...6)
            aantalRij("Eigen kamers met koeling", $f.gekoeldePriveVertrekken, 0...6)
        }
    }

    @ViewBuilder
    private var gedeeldStap: some View {
        Section {
            Text("Voeg de ruimten toe die u deelt met andere bewoners, zoals een woonkamer, gang of berging.")
                .font(.subheadline)
        } footer: {
            Text("Gangen en trappenhuizen tellen alleen mee voor verwarming (1 punt), niet voor de oppervlakte. Vul dan 0 m² in.")
        }
        ForEach($f.gedeeldeRuimten) { $item in
            Section {
                Picker("Soort", selection: $item.soort) {
                    Text("Woonkamer of ander vertrek").tag(GedeeldeRuimte.Soort.vertrek)
                    Text("Berging, zolder, gang").tag(GedeeldeRuimte.Soort.overig)
                }
                .pickerStyle(.menu)
                getalRij("Oppervlakte", $item.m2, eenheid: "m²")
                deelRijen(kamers: $item.kamers, adressen: $item.adressen)
                Toggle("Verwarmd", isOn: $item.verwarmd)
                if item.soort == .vertrek {
                    Toggle("Koeling", isOn: $item.gekoeld)
                }
            } header: {
                blokKop("Gedeelde ruimte \(nummer(item.id, in: f.gedeeldeRuimten))") { f.gedeeldeRuimten.removeAll { $0.id == item.id } }
            }
        }
        Section {
            toevoegKnop("Gedeelde ruimte toevoegen") { f.gedeeldeRuimten.append(GedeeldeRuimte()) }
        }
    }

    @ViewBuilder
    private var keukenStap: some View {
        if f.keukens.isEmpty {
            Section {
                Text("Voeg de keuken toe die u gebruikt, ook als u die deelt.").font(.subheadline)
            }
        }
        ForEach($f.keukens) { $item in
            Section {
                getalRij("Lengte aanrecht", $item.aanrechtLengte, eenheid: "m")
                deelRijen(kamers: $item.kamers, adressen: $item.adressen)
                DisclosureGroup {
                    ForEach(Self.keukenVoorzieningen, id: \.sleutel) { o in
                        Toggle(o.naam.vertaald, isOn: keuze(o.sleutel, in: $item.voorzieningen))
                    }
                } label: {
                    LabeledContent("Inbouwapparatuur en extra's") {
                        Text(verbatim: "\(item.voorzieningen.count)").monospacedDigit()
                    }
                }
            } header: {
                blokKop("Keuken \(nummer(item.id, in: f.keukens))") { f.keukens.removeAll { $0.id == item.id } }
            }
        }
        Section {
            toevoegKnop("Keuken toevoegen") { f.keukens.append(KeukenRij()) }
        }
    }

    @ViewBuilder
    private var sanitairStap: some View {
        Section {
            Text("Voeg elke badkamer en elk apart toilet apart toe, ook als u het alleen gebruikt (dan 1 kamer).")
                .font(.subheadline)
        }
        ForEach($f.sanitair) { $item in
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Toilet")
                    Picker("Toilet", selection: $item.toilet) {
                        Text("Geen").tag(KamerSanitair.Toilet.geen)
                        Text("Staand").tag(KamerSanitair.Toilet.staand)
                        Text("Hangend").tag(KamerSanitair.Toilet.zwevend)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                aantalRij("Wastafels", $item.wastafels, 0...6)
                aantalRij("Meerpersoonswastafels", $item.meerpersoonswastafels, 0...3)
                aantalRij("Douches", $item.douches, 0...3)
                aantalRij("Baden", $item.baden, 0...2)
                aantalRij("Bad met douche", $item.badDouches, 0...2)
                deelRijen(kamers: $item.kamers, adressen: $item.adressen)
                if item.douches + item.baden + item.badDouches > 0 {
                    DisclosureGroup {
                        ForEach(Self.badkamerExtras, id: \.sleutel) { o in
                            Toggle(o.naam.vertaald, isOn: keuze(o.sleutel, in: $item.extra))
                        }
                    } label: {
                        LabeledContent("Extra's in de badkamer") {
                            Text(verbatim: "\(item.extra.count)").monospacedDigit()
                        }
                    }
                }
            } header: {
                blokKop("Badkamer of toilet \(nummer(item.id, in: f.sanitair))") { f.sanitair.removeAll { $0.id == item.id } }
            }
        }
        Section {
            toevoegKnop("Badkamer of toilet toevoegen") { f.sanitair.append(SanitairRij()) }
        }
    }

    @ViewBuilder
    private var energieStap: some View {
        Section {
            Picker("Energielabel", selection: $f.label) {
                Text("Geen of onbekend").tag(Energielabel?.none)
                ForEach(Energielabel.allCases, id: \.self) { Text($0.rawValue).tag(Energielabel?.some($0)) }
            }
            .pickerStyle(.menu)
            if f.label != nil {
                DatePicker("Opnamedatum", selection: $f.labelOpnamedatum, in: ...Date(), displayedComponents: .date)
            }
            LabeledContent("Bouwjaar") {
                TextField("Bouwjaar", value: $f.bouwjaar, format: .number.grouping(.never))
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90)
            }
        } header: {
            Text("Energielabel van de woning")
        } footer: {
            Text("Het label van de hele woning telt, maal uw deel van de oppervlakte. Zonder geldig label telt het bouwjaar.")
        }
        Section {
            Link(destination: URL(string: "https://www.ep-online.nl")!) {
                Label("Label opzoeken op ep-online.nl", systemImage: "arrow.up.right.square")
            }
        }
    }

    @ViewBuilder
    private var buitenStap: some View {
        Section {
            getalRij("Eigen balkon of tuin", $f.priveBuitenruimte, eenheid: "m²")
        } header: {
            Text("Alleen voor u")
        } footer: {
            Text("De hele onbebouwde oppervlakte. Bij een balkon meet u vanaf de binnenkant van het hek.")
        }
        ForEach($f.gedeeldeBuitenruimten) { $item in
            Section {
                getalRij("Oppervlakte", $item.m2, eenheid: "m²")
                deelRijen(kamers: $item.kamers, adressen: $item.adressen)
            } header: {
                blokKop("Gedeelde buitenruimte \(nummer(item.id, in: f.gedeeldeBuitenruimten))") { f.gedeeldeBuitenruimten.removeAll { $0.id == item.id } }
            }
        }
        Section {
            toevoegKnop("Gedeelde buitenruimte toevoegen") { f.gedeeldeBuitenruimten.append(GedeeldeBuitenruimte()) }
        }
    }

    @ViewBuilder
    private var wozStap: some View {
        Section {
            bedragRij("WOZ-waarde", $f.wozWaarde, decimalen: 0)
            getalRij("Gebruiksoppervlakte", $f.gebruiksoppervlakteAdres, eenheid: "m²")
            if let regels {
                Picker("Waardepeildatum", selection: $f.wozPeildatum) {
                    ForEach(regels.corop.perPeildatum.keys.sorted().reversed(), id: \.self) { iso in
                        Text(Dag(iso: iso)?.description ?? iso).tag(iso)
                    }
                }
                .pickerStyle(.menu)
                Picker("COROP-gebied", selection: $f.coropGebied) {
                    Text("Kies").tag(String?.none)
                    ForEach(regels.corop.gebieden, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                .pickerStyle(.navigationLink)
            }
        } header: {
            Text("Van het hele adres")
        } footer: {
            Text("Het COROP-gebied is de regio van uw gemeente (bijvoorbeeld Groot-Amsterdam of Utrecht). De WOZ-waarde per m² wordt vergeleken met het gemiddelde van die regio: 10, 12 of 14 punten.")
        }
        Section {
            Link(destination: URL(string: "https://www.wozwaardeloket.nl")!) {
                Label("WOZ en oppervlakte opzoeken op wozwaardeloket.nl", systemImage: "arrow.up.right.square")
            }
        }
    }

    @ViewBuilder
    private var overigStap: some View {
        Section("Aftrekpunten") {
            Toggle("Alleen bereikbaar via een kamer van de verhuurder, die zelf in de woning woont", isOn: $f.alleenViaVertrekVerhuurder)
            Toggle("Raam in de woonkamer kleiner dan 0,75 m²", isOn: $f.ruitKleinerDan075)
            Toggle("Onderkant raam woonkamer hoger dan 1,60 m", isOn: $f.kozijnHogerDan160)
        }
        Section("Extra") {
            Toggle("Video-intercom met deuropener", isOn: $f.videoIntercom)
            Picker("Monument", selection: $f.monument) {
                Text("Geen").tag(KamerMonument.geen)
                Text("Rijksmonument, contract vóór 1-7-2024").tag(KamerMonument.rijksmonumentContractVoorWbh)
                Text("Rijksmonument, contract vanaf 1-7-2024").tag(KamerMonument.rijksmonumentContractNaWbh)
                Text("Gemeentelijk of provinciaal monument").tag(KamerMonument.gemeentelijkOfProvinciaal)
            }
            .pickerStyle(.navigationLink)
        }
    }

    @ViewBuilder
    private var uitkomstStap: some View {
        switch uitkomst {
        case .success(let u):
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(verbatim: "\(u.totaal)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(Huisstijl.bosgroen)
                        Text("punten").font(.title3).foregroundStyle(Huisstijl.gedempt)
                    }
                    if let max = u.maximaleHuur, winkel.ontgrendeld {
                        LabeledContent("Maximale kale huur", value: Opmaak.euro(max)).font(.headline)
                    }
                    if let max = u.maximaleHuur, let huur = f.kaleHuur, huur > 0 {
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
                .padding(.vertical, 6)
                ForEach(u.waarschuwingen, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                if !winkel.ontgrendeld && u.maximaleHuur != nil {
                    OntgrendelKaart()
                }
            } footer: {
                Text("Voor kamers geldt altijd huurbescherming, ook bij veel punten (BW 7:247). \(Uitkomst.disclaimer.vertaald)")
            }
            Section("Punten per rubriek") {
                ForEach(u.rubrieken, id: \.nummer) { r in
                    DisclosureGroup {
                        ForEach(r.stappen, id: \.self) { Text($0).font(.footnote) }
                        Text(r.bron).font(.caption).foregroundStyle(.secondary)
                    } label: {
                        LabeledContent {
                            Text(Opmaak.getal(r.punten, decimalen: 2)).monospacedDigit()
                        } label: {
                            Text(verbatim: "\(r.nummer). \(r.titel.vertaald)")
                        }
                    }
                }
            }
        case .failure(let fout):
            Section {
                Text(verbatim: (fout as? WWSFout)?.description ?? fout.localizedDescription).foregroundStyle(Huisstijl.signaal)
            }
        case nil:
            Section { Text("De regels voor kamers konden niet worden geladen.") }
        }
    }

    // MARK: Rijen (alle getallen rechts uitgelijnd, eenheid in een vaste kolom)

    private func getalRij(_ titel: LocalizedStringKey, _ waarde: Binding<Double>, eenheid: String) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField("0", value: waarde, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 80)
                Text(eenheid).foregroundStyle(.secondary).frame(width: 26, alignment: .leading)
                if eenheid == "m²" {
                    MeetOppervlakteKnop(titel: String(localized: "Oppervlakte meten")) { waarde.wrappedValue = $0 }
                }
            }
        } label: {
            Text(titel)
        }
    }

    private func bedragRij(_ titel: LocalizedStringKey, _ waarde: Binding<Double?>, decimalen: Int = 2) -> some View {
        LabeledContent {
            TextField("€ 0", value: waarde, format: .currency(code: "EUR").precision(.fractionLength(decimalen)))
                .keyboardType(decimalen == 0 ? .numberPad : .decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 140)
        } label: {
            Text(titel)
        }
    }

    private func aantalRij(_ titel: LocalizedStringKey, _ waarde: Binding<Int>, _ bereik: ClosedRange<Int>) -> some View {
        Stepper(value: waarde, in: bereik) {
            LabeledContent {
                Text(verbatim: "\(waarde.wrappedValue)").monospacedDigit().foregroundStyle(.primary)
            } label: {
                Text(titel)
            }
        }
    }

    @ViewBuilder
    private func deelRijen(kamers: Binding<Int>, adressen: Binding<Int>) -> some View {
        aantalRij("Kamers die dit delen", kamers, 1...30)
        aantalRij("Adressen die dit delen", adressen, 1...50)
    }

    private func blokKop(_ titel: LocalizedStringKey, verwijder: @escaping () -> Void) -> some View {
        HStack {
            Text(titel)
            Spacer()
            Button(role: .destructive, action: verwijder) {
                Label("Verwijder", systemImage: "trash").labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Verwijder"))
        }
    }

    private func toevoegKnop(_ titel: LocalizedStringKey, actie: @escaping () -> Void) -> some View {
        Button(action: actie) {
            Label(titel, systemImage: "plus.circle.fill").font(.headline)
        }
    }

    private func nummer<T: Identifiable>(_ id: T.ID, in lijst: [T]) -> Int {
        (lijst.firstIndex { $0.id == id } ?? 0) + 1
    }

    private func keuze(_ sleutel: String, in set: Binding<Set<String>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(sleutel) },
                set: { if $0 { set.wrappedValue.insert(sleutel) } else { set.wrappedValue.remove(sleutel) } })
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
