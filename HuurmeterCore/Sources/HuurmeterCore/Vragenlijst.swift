import Foundation
import WWSKit

/// Soort antwoord op een vraag van scherm 5.
public enum VraagType: Sendable, Equatable {
    case janee
    case aantal(maximum: Int)
    /// Lengte in meters.
    case lengte
    /// Oppervlakte in m².
    case oppervlakte
    case bedrag
    case keuze([KeuzeOptie])
    /// Opgeslagen als jjjjmmdd.
    case datum
}

public struct KeuzeOptie: Sendable, Equatable, Hashable {
    public let waarde: Double
    public let tekst: String
}

public struct Vraag: Sendable, Identifiable {
    public let sleutel: String
    /// Rubrieknummer uit Bijlage I onder A, of "opslag" voor prijsopslagen.
    public let rubriek: String
    public let tekst: String
    public let uitleg: String?
    public let type: VraagType
    /// Antwoord als de gebruiker niets invult.
    public let standaard: Double
    /// Mag de gebruiker een foto als bewijs toevoegen?
    public let fotoMogelijk: Bool
    /// Alleen tonen als de vraag punten kan opleveren.
    public let zichtbaar: @Sendable (WoningConcept) -> Bool

    public var id: String { sleutel }

    public init(_ sleutel: String, rubriek: String, _ tekst: String, uitleg: String? = nil, type: VraagType,
                standaard: Double = 0, foto: Bool = false,
                zichtbaar: @escaping @Sendable (WoningConcept) -> Bool = { _ in true }) {
        self.sleutel = sleutel; self.rubriek = rubriek; self.tekst = tekst; self.uitleg = uitleg
        self.type = type; self.standaard = Vragenlijst.standaarden[sleutel] ?? standaard
        self.fotoMogelijk = foto; self.zichtbaar = zichtbaar
    }
}

public struct VraagGroep: Sendable, Identifiable {
    public let id: String
    public let titel: String
    public let vragen: [Vraag]
}

/// De vragen van scherm 5. Teksten en zichtbaarheid staan hier; de puntenwaarden staan alleen in het regelbestand.
/// De voorzieningen voor keuken en badkamer worden uit de sleutels van de regelset gemaakt, zodat een nieuw
/// regelbestand automatisch tot nieuwe vragen leidt.
public enum Vragenlijst {
    public static let maximumBadkamers = 2

    /// Standaardantwoorden voor vragen die de gebruiker overslaat. Alle andere vragen staan standaard op 0 / nee.
    public static let standaarden: [String: Double] = {
        var d: [String: Double] = [
            "keuken.basisniveau": 1, "badkamers": 1, "gemBuiten.adressen": 1, "gemVertrek.adressen": 1,
            "gemOverig.adressen": 1, "parkeren.adressen": 1, "nieuwbouw.bouwVoor2028": 1,
        ]
        for i in 1...maximumBadkamers { d["badkamer\(i).voldoetEisen"] = 1 }
        return d
    }()

    /// Omschrijvingen voor de sleutels in rubriek 5 en 6 van het regelbestand.
    public static let omschrijvingen: [String: String] = [
        // Keuken (5.2)
        "afzuiginstallatie": "Ingebouwde afzuigkap",
        "kookplaatInductie": "Ingebouwde inductiekookplaat",
        "kookplaatKeramisch": "Ingebouwde keramische kookplaat",
        "kookplaatGas": "Ingebouwde gaskookplaat",
        "koelkast": "Ingebouwde koelkast",
        "vrieskast": "Ingebouwde vriezer",
        "ovenElektrisch": "Ingebouwde elektrische oven",
        "ovenGas": "Ingebouwde gasoven",
        "magnetron": "Ingebouwde magnetron",
        "vaatwasmachine": "Ingebouwde vaatwasser",
        "extraKastruimtePer60cm": "Extra keukenkasten (aantal stuks van 60 cm breed, minstens 60 cm hoog)",
        "eenhandsmengkraan": "Eenhendelmengkraan",
        "thermostatischeMengkraan": "Thermostaatkraan",
        "kokendwaterfunctie": "Kokendwaterkraan",
        // Badkamer (6.2)
        "bubbelfunctieBad": "Bubbelbad",
        "volledigeDoucheafscheiding": "Vaste douchewand of -cabine (geen gordijn)",
        "handdoekenradiator": "Handdoekradiator",
        "kastjeMetWastafel": "Wastafel in een ingebouwd kastje",
        "kastruimte": "Kast in de badkamer (minstens 40 × 40 cm)",
        "stopcontact": "Stopcontacten bij de wastafel",
    ]

    static let ruimteOmschrijvingBad: [String: String] = [
        "eenhandsmengkraan": "Eenhendelmengkranen",
        "thermostatischeMengkraan": "Thermostaatkranen",
    ]

    /// Ja/nee in plaats van een aantal voor deze voorzieningen.
    static let alleenJaNee: Set<String> = ["afzuiginstallatie", "kookplaatInductie", "kookplaatKeramisch", "kookplaatGas",
                                           "kokendwaterfunctie", "bubbelfunctieBad", "volledigeDoucheafscheiding", "kastruimte"]

    public static func groepen(regels: Regelset) -> [VraagGroep] {
        [verwarming(), keuken(regels), sanitair(regels), buitenruimte(), gemeenschappelijk(),
         parkeren(), bijzonder(), woningstatus()]
    }

    public static func alleVragen(regels: Regelset) -> [Vraag] { groepen(regels: regels).flatMap(\.vragen) }

    /// Zichtbare vragen per groep; lege groepen vallen weg.
    public static func zichtbareGroepen(regels: Regelset, concept: WoningConcept) -> [VraagGroep] {
        groepen(regels: regels).compactMap { g in
            let v = g.vragen.filter { $0.zichtbaar(concept) }
            return v.isEmpty ? nil : VraagGroep(id: g.id, titel: g.titel, vragen: v)
        }
    }

    // MARK: Groepen

    static func verwarming() -> VraagGroep {
        VraagGroep(id: "verwarming", titel: "Verwarming", vragen: [
            Vraag("verwarming.openKeuken", rubriek: "3", "Is er een open keuken met verwarming?",
                  uitleg: "Een open keuken telt voor verwarming als apart vertrek. Verwarming per kamer vult u in bij Ruimtes.",
                  type: .janee, foto: true),
        ])
    }

    static func keuken(_ regels: Regelset) -> VraagGroep {
        let basis: @Sendable (WoningConcept) -> Bool = { $0.ja("keuken.basisniveau") }
        let punten: @Sendable (WoningConcept) -> Bool = { $0.ja("keuken.basisniveau") && $0.antwoord("keuken.aanrecht") >= 1 }
        var vragen = [
            Vraag("keuken.basisniveau", rubriek: "5", "Voldoet de keuken aan het basisniveau?",
                  uitleg: "Water aan- en afvoer, een aansluiting voor koken, een aanrecht van minstens 1 meter, twee kastjes van minstens 50 cm breed en tegels of ander waterdicht materiaal tot 1,50 m hoog.",
                  type: .janee, standaard: 1),
            Vraag("keuken.aanrecht", rubriek: "5", "Lengte van het aanrecht",
                  uitleg: "Meet over het midden van het blad, inclusief spoelbak en kookplaat. Bij een hoekaanrecht telt u de lange zijden van beide delen op.",
                  type: .lengte, foto: true, zichtbaar: basis),
        ]
        for sleutel in regels.rubrieken.r5.voorzieningen.keys.sorted(by: volgorde) {
            vragen.append(Vraag("keuken.\(sleutel)", rubriek: "5", omschrijvingen[sleutel] ?? sleutel,
                                type: alleenJaNee.contains(sleutel) ? .janee : .aantal(maximum: 10),
                                foto: true, zichtbaar: punten))
        }
        return VraagGroep(id: "keuken", titel: "Keuken", vragen: vragen)
    }

    static func sanitair(_ regels: Regelset) -> VraagGroep {
        var vragen = [
            Vraag("toilet.staand", rubriek: "6", "Aantal aparte toiletruimtes met een staand toilet", type: .aantal(maximum: 5), foto: true),
            Vraag("toilet.hangend", rubriek: "6", "Aantal aparte toiletruimtes met een hangend toilet", type: .aantal(maximum: 5), foto: true),
            Vraag("toilet.wastafel", rubriek: "6", "Zit er een wastafel in een aparte toiletruimte?", type: .janee,
                  zichtbaar: { $0.aantal("toilet.staand") + $0.aantal("toilet.hangend") > 0 }),
            Vraag("badkamers", rubriek: "6", "Aantal bad- of doucheruimtes", type: .aantal(maximum: maximumBadkamers), standaard: 1),
        ]
        for i in 1...maximumBadkamers {
            let p = "badkamer\(i)"
            let bestaat: @Sendable (WoningConcept) -> Bool = { $0.aantal("badkamers") >= i }
            let extra: @Sendable (WoningConcept) -> Bool = {
                $0.aantal("badkamers") >= i && $0.ja("\(p).voldoetEisen") && $0.aantal("\(p).douches") + $0.aantal("\(p).baden") > 0
            }
            let n = maximumBadkamers > 1 ? " (badkamer \(i))" : ""
            vragen += [
                Vraag("\(p).douches", rubriek: "6", "Aantal douches\(n)", type: .aantal(maximum: 3), foto: true, zichtbaar: bestaat),
                Vraag("\(p).baden", rubriek: "6", "Aantal baden\(n)", type: .aantal(maximum: 2), foto: true, zichtbaar: bestaat),
                Vraag("\(p).wastafels", rubriek: "6", "Aantal gewone wastafels\(n)", type: .aantal(maximum: 4), zichtbaar: bestaat),
                Vraag("\(p).meerpersoonswastafels", rubriek: "6", "Aantal dubbele wastafels\(n)",
                      uitleg: "Minstens 70 cm breed en met twee kranen.", type: .aantal(maximum: 2), zichtbaar: bestaat),
                Vraag("\(p).toiletStaand", rubriek: "6", "Staand toilet in deze badkamer\(n)?", type: .janee, zichtbaar: bestaat),
                Vraag("\(p).toiletHangend", rubriek: "6", "Hangend toilet in deze badkamer\(n)?", type: .janee, zichtbaar: bestaat),
                Vraag("\(p).voldoetEisen", rubriek: "6", "Voldoet de badkamer\(n) aan de basiseisen?",
                      uitleg: "Waterdichte vloer, over minstens de helft van de vloer 2 m vrije hoogte, tegels tot 1,50 m (bad) of 1,80 m (douche), wastafel met mengkraan en spiegel, warm en koud water bij douche of bad.",
                      type: .janee, standaard: 1, zichtbaar: bestaat),
            ]
            for sleutel in regels.rubrieken.r6.voorzieningenBadruimte.keys.sorted(by: volgorde) {
                let tekst = (ruimteOmschrijvingBad[sleutel] ?? omschrijvingen[sleutel] ?? sleutel) + n
                vragen.append(Vraag("\(p).\(sleutel)", rubriek: "6", tekst,
                                    type: alleenJaNee.contains(sleutel) ? .janee : .aantal(maximum: 6),
                                    foto: true, zichtbaar: extra))
            }
        }
        vragen.append(Vraag("wastafels.overig", rubriek: "6", "In hoeveel andere kamers zit een wastafel?",
                            uitleg: "Bijvoorbeeld op een slaapkamer. Per kamer telt één wastafel.", type: .aantal(maximum: 10)))
        return VraagGroep(id: "sanitair", titel: "Sanitair", vragen: vragen)
    }

    static func buitenruimte() -> VraagGroep {
        VraagGroep(id: "buiten", titel: "Gedeelde buitenruimte", vragen: [
            Vraag("gemBuiten.oppervlakte", rubriek: "8", "Oppervlakte van een tuin of dakterras dat u deelt met andere adressen",
                  uitleg: "Uw eigen tuin of balkon voegt u toe bij Ruimtes.", type: .oppervlakte, foto: true),
            Vraag("gemBuiten.adressen", rubriek: "8", "Met hoeveel adressen (inclusief uzelf) deelt u deze buitenruimte?",
                  type: .aantal(maximum: 999), standaard: 1, zichtbaar: { $0.antwoord("gemBuiten.oppervlakte") > 0 }),
        ])
    }

    static func gemeenschappelijk() -> VraagGroep {
        VraagGroep(id: "gemeenschappelijk", titel: "Gedeelde binnenruimtes", vragen: [
            Vraag("gemVertrek.oppervlakte", rubriek: "9", "Oppervlakte van een gedeelde woon- of recreatieruimte",
                  uitleg: "Alleen ruimtes binnen het gebouw die u volgens het huurcontract mag gebruiken.", type: .oppervlakte),
            Vraag("gemVertrek.verwarmd", rubriek: "9", "Is die ruimte verwarmd?", type: .janee,
                  zichtbaar: { $0.antwoord("gemVertrek.oppervlakte") > 0 }),
            Vraag("gemVertrek.adressen", rubriek: "9", "Met hoeveel adressen deelt u die ruimte?", type: .aantal(maximum: 999),
                  standaard: 1, zichtbaar: { $0.antwoord("gemVertrek.oppervlakte") > 0 }),
            Vraag("gemOverig.oppervlakte", rubriek: "9", "Oppervlakte van een gedeelde berging, wasruimte of fietsenstalling",
                  type: .oppervlakte),
            Vraag("gemOverig.adressen", rubriek: "9", "Met hoeveel adressen deelt u die ruimte?", type: .aantal(maximum: 999),
                  standaard: 1, zichtbaar: { $0.antwoord("gemOverig.oppervlakte") > 0 }),
        ])
    }

    static func parkeren() -> VraagGroep {
        let iets: @Sendable (WoningConcept) -> Bool = {
            $0.aantal("parkeren.typeI") + $0.aantal("parkeren.typeII") + $0.aantal("parkeren.typeIII") > 0
        }
        return VraagGroep(id: "parkeren", titel: "Gedeeld parkeren", vragen: [
            Vraag("parkeren.typeI", rubriek: "10", "Parkeerplekken in een afgesloten parkeergarage bij het complex",
                  uitleg: "Alleen plekken die bij het complex horen en niet openbaar zijn. Een eigen garage voegt u toe bij Ruimtes.",
                  type: .aantal(maximum: 999)),
            Vraag("parkeren.typeII", rubriek: "10", "Parkeerplekken buiten met een dak", type: .aantal(maximum: 999)),
            Vraag("parkeren.typeIII", rubriek: "10", "Parkeerplekken buiten zonder dak", type: .aantal(maximum: 999)),
            Vraag("parkeren.adressen", rubriek: "10", "Hoeveel adressen kunnen deze plekken gebruiken?",
                  type: .aantal(maximum: 999), standaard: 1, zichtbaar: iets),
            Vraag("parkeren.oppervlakteTypeI", rubriek: "11", "Oppervlakte van uw plek in de parkeergarage",
                  uitleg: "Telt mee bij de WOZ-punten. Een parkeerplek is minstens 12 m².", type: .oppervlakte,
                  zichtbaar: { $0.aantal("parkeren.typeI") > 0 }),
            Vraag("parkeren.laadpalen", rubriek: "12", "Aantal van deze plekken met een laadpaal voor bewoners",
                  type: .aantal(maximum: 999), zichtbaar: iets),
        ])
    }

    static func bijzonder() -> VraagGroep {
        VraagGroep(id: "bijzonder", titel: "Overige voorzieningen", vragen: [
            Vraag("videoAanbel", rubriek: "12", "Videodeurbel waarmee u de voordeur van het gebouw opent?",
                  type: .janee, foto: true, zichtbaar: { $0.woningtype == .meergezins }),
            Vraag("zorgwoning", rubriek: "12", "Is het een zorgwoning?",
                  uitleg: "Een drempelloze woning in een complex met alarmering naar een meldkamer en gezamenlijke ruimtes voor maaltijden of recreatie.",
                  type: .janee),
            Vraag("gehandicapten.kosten", rubriek: "7", "Kosten die de verhuurder maakte voor aanpassingen voor een bewoner met een beperking",
                  uitleg: "Alleen aanpassingen sinds 1 april 1994 die deels gesubsidieerd zijn.", type: .bedrag),
        ])
    }

    static func woningstatus() -> VraagGroep {
        VraagGroep(id: "status", titel: "Monument en nieuwbouw", vragen: [
            Vraag("monument", rubriek: "opslag", "Is de woning een monument?",
                  type: .keuze([KeuzeOptie(waarde: 0, tekst: "Nee"), KeuzeOptie(waarde: 1, tekst: "Rijksmonument"),
                                KeuzeOptie(waarde: 2, tekst: "Gemeentelijk of provinciaal monument")])),
            Vraag("beschermdGezicht", rubriek: "opslag", "Ligt de woning in een rijksbeschermd stads- of dorpsgezicht?",
                  type: .janee, zichtbaar: { ($0.bouwjaar ?? 9999) < 1965 && $0.antwoord("monument") == 0 }),
            Vraag("nieuwbouw.ingebruikname", rubriek: "opslag", "Wanneer is de woning voor het eerst bewoond?",
                  type: .datum, zichtbaar: { ($0.bouwjaar ?? 0) >= 2024 }),
            Vraag("nieuwbouw.bouwVoor2028", rubriek: "opslag", "Is de bouw vóór 1 januari 2028 gestart?",
                  type: .janee, standaard: 1, zichtbaar: { ($0.bouwjaar ?? 0) >= 2024 }),
            Vraag("coropAmsterdamUtrecht", rubriek: "11", "Ligt de woning in de regio Amsterdam of Utrecht?",
                  uitleg: "Het gaat om de COROP-gebieden Groot-Amsterdam en Utrecht. Dit telt alleen voor kleine woningen uit 2018 t/m 2022.",
                  type: .janee,
                  zichtbaar: { (2018...2022).contains($0.bouwjaar ?? 0) && $0.binnenOppervlakte < 40.5 }),
        ])
    }

    /// Vaste volgorde: eerst kookplaat/apparatuur zoals in de bijlage, onbekende sleutels achteraan.
    static let vasteVolgorde = ["afzuiginstallatie", "kookplaatInductie", "kookplaatKeramisch", "kookplaatGas", "koelkast",
                                "vrieskast", "ovenElektrisch", "ovenGas", "magnetron", "vaatwasmachine",
                                "extraKastruimtePer60cm", "eenhandsmengkraan", "thermostatischeMengkraan",
                                "kokendwaterfunctie", "bubbelfunctieBad", "volledigeDoucheafscheiding",
                                "handdoekenradiator", "kastjeMetWastafel", "kastruimte", "stopcontact"]

    static func volgorde(_ a: String, _ b: String) -> Bool {
        (vasteVolgorde.firstIndex(of: a) ?? Int.max, a) < (vasteVolgorde.firstIndex(of: b) ?? Int.max, b)
    }
}
