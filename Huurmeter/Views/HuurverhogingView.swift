import SwiftUI
import WWSKit
import HuurmeterCore

/// Check op de jaarlijkse huurverhoging: "Mag mijn huur zoveel omhoog?"
struct HuurverhogingView: View {
    let woning: Woning

    @State private var segment: HuurSegmentContract = .sociaal
    @State private var huidigeHuur: Double?
    @State private var nieuweHuur: Double?
    @State private var ingang = HuurverhogingView.volgende1Juli()
    @State private var heeftOntvangstdatum = false
    @State private var ontvangen = Date()
    @State private var heeftVorige = false
    @State private var vorige = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var huishouden: Huishouden = .eenpersoons
    @State private var inkomen: Inkomensgroep = .onbekend

    private let regels = try? HuurverhogingRegels.laad(jaar: 2026)

    var body: some View {
        Form {
            Section {
                Picker("Soort huurwoning", selection: $segment) {
                    Text("Sociale huur").tag(HuurSegmentContract.sociaal)
                    Text("Middenhuur").tag(HuurSegmentContract.midden)
                    Text("Vrije sector").tag(HuurSegmentContract.vrij)
                }
            } footer: {
                Text("Staat meestal in uw huurcontract of in de brief van de verhuurder. De app stelt het segment voor op basis van uw puntentelling.")
            }

            Section("Het voorstel") {
                bedragVeld("Huidige kale huur", waarde: $huidigeHuur)
                bedragVeld("Voorgestelde nieuwe huur", waarde: $nieuweHuur)
                DatePicker("Ingangsdatum", selection: $ingang, displayedComponents: .date)
                Toggle("Ik weet wanneer ik het voorstel kreeg", isOn: $heeftOntvangstdatum)
                if heeftOntvangstdatum {
                    DatePicker("Ontvangen op", selection: $ontvangen, displayedComponents: .date)
                }
                Toggle("Ik weet wanneer de vorige verhoging inging", isOn: $heeftVorige)
                if heeftVorige {
                    DatePicker("Vorige verhoging", selection: $vorige, displayedComponents: .date)
                }
            }

            if segment == .sociaal, let s = regels?.sociaal {
                Section {
                    Picker("Huishouden", selection: $huishouden) {
                        Text("1 persoon").tag(Huishouden.eenpersoons)
                        Text("2 of meer personen").tag(Huishouden.meerpersoons)
                    }
                    Picker("Gezamenlijk inkomen", selection: $inkomen) {
                        let g = huishouden == .eenpersoons ? s.inkomensgrenzen.eenpersoons : s.inkomensgrenzen.meerpersoons
                        Text("Weet ik niet / zeg ik liever niet").tag(Inkomensgroep.onbekend)
                        Text("Tot \(Opmaak.euro(g.laagTotEnMet))").tag(Inkomensgroep.laag)
                        Text("\(Opmaak.euro(g.laagTotEnMet)) – \(Opmaak.euro(g.middenTotEnMet))").tag(Inkomensgroep.midden)
                        Text("Boven \(Opmaak.euro(g.middenTotEnMet))").tag(Inkomensgroep.hoog)
                    }
                } header: {
                    Text("Inkomen")
                } footer: {
                    Text("Bij sociale huur mag de verhuurder bij een hoger inkomen meer verhogen. Het gaat om het inkomen van twee jaar geleden; de verhuurder moet dat met een verklaring van de Belastingdienst aantonen.")
                }
            }

            if let regels, let invoer {
                uitkomst(Huurverhoging.beoordeel(invoer, regels: regels))
            }
        }
        .huisstijlAchtergrond()
        .navigationTitle("Huurverhoging")
        .onAppear(perform: vulVoor)
    }

    private var invoer: HuurverhogingInvoer? {
        guard let h = huidigeHuur, let n = nieuweHuur, h > 0, n > 0 else { return nil }
        return HuurverhogingInvoer(
            segment: segment, huidigeHuur: h, voorgesteldeHuur: n, ingangsdatum: Dag(ingang),
            voorstelOntvangen: heeftOntvangstdatum ? Dag(ontvangen) : nil,
            vorigeVerhoging: heeftVorige ? Dag(vorige) : nil,
            huishouden: huishouden, inkomen: inkomen,
            maximaleHuur: woning.laatsteBerekening?.maxHuur)
    }

    @ViewBuilder
    private func uitkomst(_ u: HuurverhogingUitkomst) -> some View {
        Section {
            switch u.oordeel {
            case .toegestaan:
                Label("Deze verhoging mag", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(Huisstijl.bosgroen)
            case .teHoog(let teveel):
                Pil(tekst: "\(Opmaak.euro(teveel)) per maand te hoog", voorgrond: Huisstijl.signaal, achtergrond: Huisstijl.signaalVlak)
                Text("U hoeft niet akkoord te gaan. Laat de verhuurder vóór de ingangsdatum schriftelijk weten dat u bezwaar maakt.")
                    .font(.subheadline)
            case .nietTeBepalen:
                Label("Het maximum is hier niet vast te stellen", systemImage: "questionmark.circle")
                    .font(.headline).foregroundStyle(Huisstijl.gedempt)
            }
            ForEach(u.stappen, id: \.self) { Text($0).font(.subheadline) }
        } header: {
            Text("Uitkomst")
        } footer: {
            Text(Uitkomst.disclaimer)
        }
        if !u.aandachtspunten.isEmpty {
            Section("Let op") {
                ForEach(u.aandachtspunten, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.subheadline) }
            }
        }
    }

    private func bedragVeld(_ titel: LocalizedStringKey, waarde: Binding<Double?>) -> some View {
        HStack {
            Text(titel)
            TextField("€ 0", value: waarde, format: .currency(code: "EUR"))
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
    }

    private func vulVoor() {
        if huidigeHuur == nil { huidigeHuur = woning.kaleHuur }
        if let totaal = woning.laatsteBerekening?.totaal {
            segment = totaal <= 143 ? .sociaal : (totaal <= 186 ? .midden : .vrij)
        }
    }

    static func volgende1Juli() -> Date {
        let k = Calendar.current
        let nu = Date()
        let jaar = k.component(.year, from: nu)
        let ditJaar = k.date(from: DateComponents(year: jaar, month: 7, day: 1))!
        return ditJaar >= k.startOfDay(for: nu) ? ditJaar : k.date(from: DateComponents(year: jaar + 1, month: 7, day: 1))!
    }
}
