import SwiftUI
import SwiftData
import PhotosUI
import WWSKit
import HuurmeterCore

/// Scherm 5: korte vragen per rubriek. Alleen vragen die punten kunnen opleveren worden getoond.
struct VoorzieningenView: View {
    @Bindable var woning: Woning

    var body: some View {
        Group {
            if let regels = HuidigeRegels.regels {
                let concept = woning.concept
                Form {
                    ForEach(Vragenlijst.zichtbareGroepen(regels: regels, concept: concept)) { groep in
                        Section(groep.titel) {
                            ForEach(groep.vragen) { vraag in
                                VraagRij(woning: woning, vraag: vraag)
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
        .navigationTitle("Voorzieningen")
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
                Text(uitleg).font(.footnote).foregroundStyle(.secondary)
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
            Toggle(vraag.tekst, isOn: Binding(get: { waarde.wrappedValue >= 0.5 }, set: { waarde.wrappedValue = $0 ? 1 : 0 }))
        case .aantal(let maximum):
            Stepper(value: Binding(get: { Int(waarde.wrappedValue.rounded()) }, set: { waarde.wrappedValue = Double($0) }),
                    in: 0...maximum) {
                HStack {
                    Text(vraag.tekst)
                    Spacer()
                    Text("\(Int(waarde.wrappedValue.rounded()))").monospacedDigit().foregroundStyle(.secondary)
                }
            }
        case .lengte:
            eenheidVeld(eenheid: "m")
        case .oppervlakte:
            eenheidVeld(eenheid: "m²")
        case .bedrag:
            VStack(alignment: .leading) {
                Text(vraag.tekst)
                TextField("€ 0", value: optioneel, format: .currency(code: "EUR"))
                    .keyboardType(.decimalPad)
            }
        case .keuze(let opties):
            Picker(vraag.tekst, selection: waarde) {
                ForEach(opties, id: \.self) { Text($0.tekst).tag($0.waarde) }
            }
        case .datum:
            DatumVraag(tekst: vraag.tekst, waarde: waarde)
        }
    }

    private func eenheidVeld(eenheid: String) -> some View {
        VStack(alignment: .leading) {
            Text(vraag.tekst)
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
                Label(foto == nil ? "Foto als bewijs" : "Andere foto", systemImage: "camera")
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
