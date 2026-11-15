import SwiftUI
import SwiftData
import PhotosUI
import WWSKit
import HuurmeterCore

/// Scherm 5: korte vragen per rubriek. Alleen vragen die punten kunnen opleveren worden getoond.
struct VoorzieningenView: View {
    @Bindable var woning: Woning
    @State private var scan: ScanKeuze?

    var body: some View {
        Group {
            if let regels = HuidigeRegels.regels {
                let concept = woning.concept
                Form {
                    ForEach(Vragenlijst.zichtbareGroepen(regels: regels, concept: concept)) { groep in
                        Section(groep.titel.vertaald) {
                            if Scanner.beschikbaar { scanKnoppen(groep.id) }
                            let tegels = groep.vragen.filter(Tegels.isTegel)
                            ForEach(groep.vragen.filter { !Tegels.isTegel($0) }) { vraag in
                                VraagRij(woning: woning, vraag: vraag)
                            }
                            if !tegels.isEmpty {
                                TegelRaster(woning: woning, vragen: tegels)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Geen rekenregels", systemImage: "exclamationmark.triangle",
                                       description: Text("Voor vandaag zijn geen rekenregels beschikbaar. Werk de app bij."))
            }
        }
        .huisstijlAchtergrond()
        .toetsenbordKlaar()
        .navigationTitle("Voorzieningen")
        .fullScreenCover(item: $scan) { s in VoorzieningScanView(woning: woning, ruimte: s.ruimte) }
    }

    /// AR: keuken, badkamer of toilet scannen; de camera herkent apparaten en sanitair.
    @ViewBuilder
    private func scanKnoppen(_ groep: String) -> some View {
        switch groep {
        case "keuken":
            Button { scan = ScanKeuze(ruimte: .keuken) } label: {
                Label("Keuken scannen met de camera", systemImage: "camera.viewfinder")
            }
        case "sanitair":
            Button { scan = ScanKeuze(ruimte: .badkamer(1)) } label: {
                Label("Badkamer scannen met de camera", systemImage: "camera.viewfinder")
            }
            if woning.antwoord("badkamers") >= 2 {
                Button { scan = ScanKeuze(ruimte: .badkamer(2)) } label: {
                    Label("Tweede badkamer scannen", systemImage: "camera.viewfinder")
                }
            }
            Button { scan = ScanKeuze(ruimte: .toilet) } label: {
                Label("Apart toilet scannen", systemImage: "camera.viewfinder")
            }
        default:
            EmptyView()
        }
    }
}

private struct ScanKeuze: Identifiable {
    let ruimte: ScanRuimte
    var id: String {
        switch ruimte {
        case .keuken: return "keuken"
        case .badkamer(let n): return "badkamer\(n)"
        case .toilet: return "toilet"
        }
    }
}

private struct VraagRij: View {
    let woning: Woning
    let vraag: Vraag
    @State private var toonMeter = false

    private var waarde: Binding<Double> {
        Binding(get: { woning.antwoord(vraag.sleutel) },
                set: { woning.zetAntwoord(vraag.sleutel, $0, rubriek: vraag.rubriek) })
    }

    private var optioneel: Binding<Double?> {
        Binding(get: { let w = woning.antwoord(vraag.sleutel); return w > 0 ? w : nil },
                set: { woning.zetAntwoord(vraag.sleutel, max(0, $0 ?? 0), rubriek: vraag.rubriek) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            invoer
            if let uitleg = vraag.uitleg {
                Text(uitleg.vertaald).font(.footnote).foregroundStyle(.secondary)
            }
            if vraag.sleutel == "keuken.aanrecht" && AanrechtMeterView.beschikbaar {
                Button {
                    toonMeter = true
                } label: {
                    Label("Meet met de camera", systemImage: "ruler")
                        .font(.footnote)
                }
                .buttonStyle(.borderless)
            }
            if vraag.fotoMogelijk && woning.antwoord(vraag.sleutel) > 0 {
                FotoKnop(woning: woning, vraag: vraag)
            }
        }
        .padding(.vertical, 2)
        .fullScreenCover(isPresented: $toonMeter) {
            AanrechtMeterView { lengte in
                woning.zetAntwoord(vraag.sleutel, lengte, rubriek: vraag.rubriek)
            }
        }
    }

    @ViewBuilder
    private var invoer: some View {
        switch vraag.type {
        case .janee:
            Toggle(vraag.tekst.vertaald, isOn: Binding(get: { waarde.wrappedValue >= 0.5 }, set: { waarde.wrappedValue = $0 ? 1 : 0 }))
        case .aantal(let maximum):
            Stepper(value: Binding(get: { Int(waarde.wrappedValue.rounded()) }, set: { waarde.wrappedValue = Double($0) }),
                    in: 0...maximum) {
                HStack {
                    Text(vraag.tekst.vertaald)
                    Spacer()
                    Text(verbatim: "\(Int(waarde.wrappedValue.rounded()))").monospacedDigit().foregroundStyle(.secondary)
                }
            }
        case .lengte:
            eenheidVeld(eenheid: "m")
        case .oppervlakte:
            eenheidVeld(eenheid: "m²")
        case .bedrag:
            VStack(alignment: .leading) {
                Text(vraag.tekst.vertaald)
                TextField("€ 0", value: optioneel, format: .currency(code: "EUR"))
                    .keyboardType(.decimalPad)
            }
        case .keuze(let opties):
            Picker(vraag.tekst.vertaald, selection: waarde) {
                ForEach(opties, id: \.self) { Text($0.tekst.vertaald).tag($0.waarde) }
            }
        case .datum:
            DatumVraag(tekst: vraag.tekst.vertaald, waarde: waarde)
        }
    }

    private func eenheidVeld(eenheid: String) -> some View {
        VStack(alignment: .leading) {
            Text(vraag.tekst.vertaald)
            HStack {
                TextField("0", value: optioneel, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                Text(eenheid).foregroundStyle(.secondary)
            }
        }
    }
}

private struct DatumVraag: View {
    let tekst: String
    @Binding var waarde: Double

    var body: some View {
        let dag = Dag(getal: waarde)
        Toggle(tekst, isOn: Binding(get: { dag != nil },
                                    set: { waarde = $0 ? Dag(Date()).alsGetal : 0 }))
        if let dag {
            DatePicker("Datum", selection: Binding(get: { dag.datum() }, set: { waarde = Dag($0).alsGetal }),
                       displayedComponents: .date)
        }
    }
}

/// Optionele foto als bewijs bij een vraag (spec, scherm 5). Wordt alleen op het toestel bewaard.
private struct FotoKnop: View {
    let woning: Woning
    let vraag: Vraag
    @State private var keuze: PhotosPickerItem?

    var body: some View {
        let foto = woning.voorziening(vraag.sleutel)?.foto
        HStack(spacing: 12) {
            if let foto, let beeld = UIImage(data: foto) {
                Image(uiImage: beeld)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Bewijsfoto")
                Button("Verwijder foto", role: .destructive) {
                    woning.voorziening(vraag.sleutel)?.foto = nil
                }
                .font(.footnote)
            }
            PhotosPicker(selection: $keuze, matching: .images) {
                Label(foto == nil ? "Foto als bewijs" : "Andere foto" as LocalizedStringKey, systemImage: "camera")
                    .font(.footnote)
            }
        }
        .buttonStyle(.borderless)
        .onChange(of: keuze) {
            guard let item = keuze else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let beeld = UIImage(data: data),
                   let jpeg = beeld.verkleind(maximaleZijde: 1600).jpegData(compressionQuality: 0.7) {
                    if woning.voorziening(vraag.sleutel) == nil {
                        woning.zetAntwoord(vraag.sleutel, woning.antwoord(vraag.sleutel), rubriek: vraag.rubriek)
                    }
                    woning.voorziening(vraag.sleutel)?.foto = jpeg
                }
                keuze = nil
            }
        }
    }
}

extension UIImage {
    func verkleind(maximaleZijde: CGFloat) -> UIImage {
        let schaal = min(1, maximaleZijde / max(size.width, size.height))
        guard schaal < 1 else { return self }
        let nieuw = CGSize(width: size.width * schaal, height: size.height * schaal)
        return UIGraphicsImageRenderer(size: nieuw).image { _ in draw(in: CGRect(origin: .zero, size: nieuw)) }
    }
}

// MARK: - Tegels voor apparatuur en extra's (sneller dan een lijst schakelaars)

enum Tegels {
    /// Vragen die als tegel worden getoond: keukenapparatuur en extra's in de badkamer.
    static func isTegel(_ v: Vraag) -> Bool {
        let delen = v.sleutel.split(separator: ".")
        guard delen.count == 2 else { return false }
        let soort = String(delen[0]), naam = String(delen[1])
        switch v.type {
        case .janee, .aantal: break
        default: return false
        }
        if soort == "keuken" { return !["basisniveau", "aanrecht"].contains(naam) }
        if soort.hasPrefix("badkamer") {
            return !["douches", "baden", "wastafels", "meerpersoonswastafels", "toiletStaand", "toiletHangend", "voldoetEisen"].contains(naam)
        }
        return false
    }

    static func icoon(_ sleutel: String) -> String {
        let naam = sleutel.split(separator: ".").last.map(String.init) ?? sleutel
        switch naam {
        case "afzuiginstallatie": return "wind"
        case "kookplaatInductie", "kookplaatKeramisch": return "cooktop"
        case "kookplaatGas": return "flame"
        case "koelkast": return "refrigerator"
        case "vrieskast": return "snowflake"
        case "ovenElektrisch", "ovenGas": return "oven"
        case "magnetron": return "microwave"
        case "vaatwasmachine": return "dishwasher"
        case "extraKastruimtePer60cm", "kastruimte": return "cabinet"
        case "eenhandsmengkraan": return "drop"
        case "thermostatischeMengkraan": return "thermometer.medium"
        case "kokendwaterfunctie": return "drop.fill"
        case "bubbelfunctieBad": return "bathtub"
        case "volledigeDoucheafscheiding": return "shower"
        case "handdoekenradiator": return "heater.vertical"
        case "kastjeMetWastafel": return "sink"
        case "stopcontact": return "powerplug"
        default: return "square.grid.2x2"
        }
    }
}

/// Raster van tegels: tik = aan/uit (of één erbij bij een aantal), lang indrukken = minder of wissen.
private struct TegelRaster: View {
    let woning: Woning
    let vragen: [Vraag]
    private let kolommen = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tik aan wat er is. Lang indrukken om te verminderen.")
                .font(.footnote).foregroundStyle(.secondary)
            LazyVGrid(columns: kolommen, spacing: 10) {
                ForEach(vragen) { vraag in tegel(vraag) }
            }
            let gekozen = vragen.filter { $0.fotoMogelijk && woning.antwoord($0.sleutel) > 0 }
            if !gekozen.isEmpty {
                DisclosureGroup("Foto's als bewijs") {
                    ForEach(gekozen) { vraag in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vraag.tekst.vertaald).font(.footnote.weight(.semibold))
                            FotoKnop(woning: woning, vraag: vraag)
                        }
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private func maximum(_ v: Vraag) -> Int {
        if case .aantal(let m) = v.type { return m }
        return 1
    }

    private func tegel(_ vraag: Vraag) -> some View {
        let waarde = Int(woning.antwoord(vraag.sleutel).rounded())
        let aan = waarde > 0
        let isAantal = maximum(vraag) > 1
        return Button {
            let nieuw = isAantal ? min(waarde + 1, maximum(vraag)) : (aan ? 0 : 1)
            woning.zetAntwoord(vraag.sleutel, Double(nieuw), rubriek: vraag.rubriek)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: Tegels.icoon(vraag.sleutel))
                        .font(.title3)
                        .foregroundStyle(aan ? Huisstijl.opLimoen : Huisstijl.gedempt)
                    Spacer()
                    if aan {
                        Text(verbatim: isAantal ? "\(waarde)" : "✓")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Huisstijl.opLimoen)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Huisstijl.kaart.opacity(0.6), in: Capsule())
                    }
                }
                Text(vraag.tekst.vertaald)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(aan ? Huisstijl.opLimoen : .primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(aan ? Huisstijl.limoen : Huisstijl.salie, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(aan ? Huisstijl.bosgroen.opacity(0.3) : .clear))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isAantal && waarde > 0 {
                Button { woning.zetAntwoord(vraag.sleutel, Double(waarde - 1), rubriek: vraag.rubriek) } label: {
                    Label("Eén minder", systemImage: "minus.circle")
                }
            }
            if waarde > 0 {
                Button(role: .destructive) { woning.zetAntwoord(vraag.sleutel, 0, rubriek: vraag.rubriek) } label: {
                    Label("Wissen", systemImage: "xmark.circle")
                }
            }
        }
        .accessibilityLabel(Text(vraag.tekst.vertaald))
        .accessibilityValue(Text(isAantal ? "\(waarde)" : (aan ? String(localized: "aan") : String(localized: "uit"))))
        .accessibilityAddTraits(aan ? .isSelected : [])
    }
}
