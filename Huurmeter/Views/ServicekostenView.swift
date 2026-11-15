import SwiftUI
import WWSKit
import HuurmeterCore

/// Functie 10: servicekosten-check. Vergelijk het jaaroverzicht met uw voorschotten.
struct ServicekostenView: View {
    let woning: Woning
    private let regels = try? ServicekostenRegels.laad()
    private let procedure = (try? Stappenplannen.laad())?.procedure("servicekosten")

    @State private var jaar = Dag(Date()).jaar - 1
    @State private var ontvangen = true
    @State private var ontvangstdatum = Date()
    @State private var posten: [ServicekostenPost] = [ServicekostenPost(naam: "", voorschot: 0, kosten: nil)]

    private var uitkomst: ServicekostenUitkomst? {
        guard let procedure else { return nil }
        return Servicekosten.beoordeel(posten: posten, jaar: jaar, overzichtOntvangen: ontvangen ? Dag(ontvangstdatum) : nil,
                                       vandaag: Dag(Date()), procedure: procedure)
    }

    var body: some View {
        Form {
            Section {
                Picker("Kalenderjaar", selection: $jaar) {
                    ForEach((Dag(Date()).jaar - 3)...Dag(Date()).jaar, id: \.self) { Text(String($0)).tag($0) }
                }
                Toggle("Jaaroverzicht ontvangen", isOn: $ontvangen)
                if ontvangen {
                    DatePicker("Ontvangen op", selection: $ontvangstdatum, in: ...Date(), displayedComponents: .date)
                }
            } header: {
                Text("Jaaroverzicht")
            } footer: {
                if let u = uitkomst {
                    Text("De verhuurder moet het overzicht per kostensoort uiterlijk \(u.overzichtUiterlijk.description) geven (BW 7:259 lid 2).")
                }
            }

            Section {
                ForEach($posten) { $post in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Kostensoort, bijv. schoonmaak", text: $post.naam)
                        HStack {
                            Text("Voorschot").foregroundStyle(.secondary)
                            Spacer()
                            TextField("€ 0", value: $post.voorschot, format: .currency(code: "EUR"))
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Kosten volgens overzicht").foregroundStyle(.secondary)
                            Spacer()
                            TextField("€ 0", value: $post.kosten, format: .currency(code: "EUR"))
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        if let s = post.saldo, s != 0 {
                            Text(s > 0 ? String(localized: "U krijgt \(Opmaak.euro(s)) terug") : String(localized: "U betaalt \(Opmaak.euro(-s)) bij"))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(s > 0 ? Huisstijl.bosgroen : Huisstijl.signaal)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { posten.remove(atOffsets: $0) }
                Button {
                    posten.append(ServicekostenPost(naam: "", voorschot: 0, kosten: nil))
                } label: {
                    Label("Kostensoort toevoegen", systemImage: "plus")
                }
            } header: {
                Text("Posten (per jaar)")
            } footer: {
                Text("Vul per post het voorschot over het hele jaar in en de kosten uit het overzicht.")
            }

            if let u = uitkomst, let regels {
                Section("Uitkomst") {
                    LabeledContent("Totaal voorschot", value: Opmaak.euro(u.totaalVoorschot))
                    LabeledContent("Totaal kosten", value: Opmaak.euro(u.totaalKosten))
                    LabeledContent(u.saldo >= 0 ? "Terug te krijgen" : "Bij te betalen" as LocalizedStringKey, value: Opmaak.euro(abs(u.saldo)))
                        .font(.headline)
                    if u.overzichtTeLaat {
                        Label(ontvangen ? "Het overzicht kwam te laat." : "U had het overzicht al moeten krijgen." as LocalizedStringKey,
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Huisstijl.signaal)
                    }
                }

                Section {
                    Text(verbatim: regels.inzage.tekst.vertaald + " (\(regels.inzage.bron))")
                    Text(verbatim: regels.zonderFormulier.tekst.vertaald + " (\(regels.zonderFormulier.bron))")
                    Text("Normbedrag overige servicekosten: \(Opmaak.euro(regels.normbedragen.zelfstandig.overigPerJaar)) per jaar. Gas, water en elektriciteit: \(regels.normbedragen.zelfstandig.gas), \(regels.normbedragen.zelfstandig.water) en \(regels.normbedragen.zelfstandig.elektriciteit) (\(regels.normbedragen.bron)).")
                    Text(verbatim: regels.voorschotTeHoog.tekst.vertaald + " (\(regels.voorschotTeHoog.bron))")
                } header: {
                    Text("Goed om te weten")
                }

                Section {
                    if u.verzoekVerlopen {
                        Label("De termijn voor de Huurcommissie over \(String(jaar)) is verstreken (\(u.verzoekUiterlijk.description)).",
                              systemImage: "clock.badge.exclamationmark")
                    } else {
                        LabeledContent("Huurcommissie uiterlijk", value: u.verzoekUiterlijk.description)
                        if !Servicekosten.ontvankelijk(geschil: u.saldo, regels: regels) && u.totaalKosten > 0 {
                            Text("Het verschil is kleiner dan \(Opmaak.euro(regels.minimumGeschil.bedrag)); dan neemt de Huurcommissie het verzoek niet in behandeling (\(regels.minimumGeschil.bron)). Gaat het om bepaalde posten waar u het niet mee eens bent, tel dan het betwiste bedrag.")
                                .font(.footnote)
                        }
                    }
                    NavigationLink {
                        StappenplanView(woning: woning)
                    } label: {
                        Label("Stappenplan Huurcommissie", systemImage: "list.number")
                    }
                } header: {
                    Text("Niet eens met de kosten?")
                } footer: {
                    Text("Bron: BW 7:260 lid 2 (tot 24 maanden na de uiterste datum voor het overzicht).")
                }
            }
        }
        .huisstijlAchtergrond()
        .toetsenbordKlaar()
        .navigationTitle("Servicekosten")
        .onAppear {
            // Voorschot uit het gescande contract als eerste post (per jaar).
            if let s = woning.servicekostenPerMaand, posten.count == 1, posten[0].naam.isEmpty, posten[0].voorschot == 0 {
                posten = [ServicekostenPost(naam: String(localized: "Servicekosten volgens contract"), voorschot: Afronding.centen(s * 12), kosten: nil)]
            }
        }
    }
}
