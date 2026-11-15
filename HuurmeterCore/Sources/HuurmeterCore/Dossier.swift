import Foundation
import WWSKit

/// Inhoud van het PDF-dossier (spec §5, scherm 8), los van de opmaak zodat hij te testen is.
public struct DossierInhoud: Sendable, Equatable {
    public struct Ruimte: Sendable, Equatable {
        public let naam: String
        public let soort: String
        public let oppervlakte: String
        /// "gescand" of "handmatig" (spec §6: komt in het dossier).
        public let bron: String
        public let opmerking: String?
    }

    public struct Rubriek: Sendable, Equatable {
        public let kop: String
        public let punten: String
        public let stappen: [String]
        public let bron: String
    }

    public let titel: String
    public let adres: String
    public let datum: String
    public let samenvatting: [String]
    public let kerncijfers: [(String, String)]
    public let ruimten: [Ruimte]
    public let rubrieken: [Rubriek]
    public let prijsopslag: [String]
    public let waarschuwingen: [String]
    public let bronnen: [String]
    public let voetnoten: [String]

    public static func == (a: DossierInhoud, b: DossierInhoud) -> Bool {
        a.titel == b.titel && a.adres == b.adres && a.datum == b.datum && a.samenvatting == b.samenvatting
            && a.kerncijfers.map { "\($0.0)=\($0.1)" } == b.kerncijfers.map { "\($0.0)=\($0.1)" }
            && a.ruimten == b.ruimten && a.rubrieken == b.rubrieken && a.prijsopslag == b.prijsopslag
            && a.waarschuwingen == b.waarschuwingen && a.bronnen == b.bronnen && a.voetnoten == b.voetnoten
    }

    public static let nietVanDeOverheid = "Huurmeter is niet van of namens de overheid of de Huurcommissie."

    public init(concept c: WoningConcept, uitkomst u: Uitkomst, regels: Regelset) {
        titel = "Puntentelling huurwoning"
        adres = c.adres.weergave.isEmpty ? "Adres niet ingevuld" : c.adres.weergave
        datum = "Berekend op \(u.peildatum) met de regels van \(u.regelsetJaar)"
        samenvatting = Opmaak.samenvatting(u, kaleHuur: c.kaleHuur).regels

        var k: [(String, String)] = [("Puntentotaal", "\(u.totaal) punten"), ("Segment", Opmaak.segment(u.segment))]
        k.append(("Maximale kale huur", u.maximaleHuur.map { Opmaak.euro($0) + " per maand" } ?? "geen (vrije sector)"))
        if let h = c.kaleHuur { k.append(("Huidige kale huur", Opmaak.euro(h) + " per maand")) }
        if let v = u.verschilPerMaand, v > 0, let j = u.verschilPerJaar {
            k.append(("Te veel per maand", Opmaak.euro(v)))
            k.append(("Te veel per jaar", Opmaak.euro(j)))
        }
        if let b = c.bouwjaar { k.append(("Bouwjaar", String(b))) }
        if let s = c.contractStart { k.append(("Ingang huurcontract", s.description)) }
        if let t = u.termijnAanvangshuur {
            k.append(("Aanvangshuur laten toetsen", "uiterlijk \(t.einddatum) (nog \(t.resterendeDagen) dagen)"))
        }
        kerncijfers = k

        ruimten = c.ruimten.map { r in
            Ruimte(naam: r.naam, soort: Self.soortTekst(r.soort), oppervlakte: Opmaak.oppervlakte(r.oppervlakte),
                   bron: r.bron == .scan ? "gescand" : "handmatig",
                   opmerking: r.zolderZonderVasteTrap ? "geen vaste trap" : nil)
        }
        rubrieken = u.rubrieken.map {
            Rubriek(kop: "\($0.nummer). \($0.titel)", punten: Opmaak.punten($0.punten), stappen: $0.stappen, bron: $0.bron)
        }
        prijsopslag = u.prijsopslagStappen
        waarschuwingen = u.waarschuwingen
        bronnen = regels.bronnen.keys.sorted().compactMap { regels.bronnen[$0] }.map { "\($0.titel) (\($0.versie)). \($0.url)" }
        voetnoten = [Uitkomst.disclaimer, Self.nietVanDeOverheid]
    }

    static func soortTekst(_ s: RuimteSoort) -> String {
        switch s {
        case .vertrek: return "vertrek"
        case .overigeRuimte: return "overige ruimte"
        case .verkeersruimte: return "verkeersruimte"
        case .buitenruimte: return "buitenruimte"
        }
    }
}

/// Conceptbrief aan de verhuurder (spec §5, scherm 8). De tekst moet nog worden nagelezen door iemand
/// met kennis van huurrecht (open punt in de spec); de app noemt hem daarom overal "concept".
public enum Brief {
    public enum Fout: Error, Equatable, CustomStringConvertible {
        case geenTeHogeHuur, vrijeSector, kaleHuurOntbreekt

        public var description: String {
            switch self {
            case .geenTeHogeHuur: return "Uw huur is niet hoger dan de maximale huur. Een brief om verlaging te vragen is dan niet nodig."
            case .vrijeSector: return "De woning valt in de vrije sector. Daar geldt geen maximale huur, dus de brief is niet van toepassing."
            case .kaleHuurOntbreekt: return "Vul eerst uw kale huur in (scherm Huur)."
            }
        }
    }

    public static func tekst(concept c: WoningConcept, uitkomst u: Uitkomst, vandaag: Dag) throws -> String {
        guard let max = u.maximaleHuur else { throw Fout.vrijeSector }
        guard let huur = c.kaleHuur else { throw Fout.kaleHuurOntbreekt }
        guard let verschil = u.verschilPerMaand, verschil > 0 else { throw Fout.geenTeHogeHuur }

        let adres = c.adres.weergave.isEmpty ? "[adres van de woning]" : c.adres.weergave
        let sinds = c.contractStart.map { " sinds \($0)" } ?? ""
        let opslag = u.prijsopslag > 0
            ? " Daarin is een opslag van \(Opmaak.getal(u.prijsopslag * 100, decimalen: 0))% meegenomen (artikel 8a Besluit huurprijzen woonruimte)."
            : ""

        var alinea: [String] = [
            "[Uw naam]\n[Uw adres]\n[Postcode en plaats]",
            "[Naam verhuurder]\n[Adres verhuurder]\n[Postcode en plaats verhuurder]",
            "[Plaats], \(vandaag)",
            "Betreft: kale huur van \(adres)",
            "Geachte [naam verhuurder],",
            "Ik huur\(sinds) de woning aan \(adres). De kale huur is \(Opmaak.euro(huur)) per maand.",
            "Ik heb de kwaliteit van de woning gewaardeerd volgens het woningwaarderingsstelsel uit bijlage I van het Besluit huurprijzen woonruimte. De woning komt uit op \(u.totaal) punten. Bij dat aantal punten hoort in \(u.regelsetJaar) een maximale kale huur van \(Opmaak.euro(max)) per maand.\(opslag)",
            "Mijn kale huur is daarmee \(Opmaak.euro(verschil)) per maand hoger dan de maximale huur. De puntentelling per onderdeel vindt u in de bijlage.",
            "Ik verzoek u de kale huur te verlagen naar \(Opmaak.euro(max)) per maand. Graag ontvang ik binnen zes weken uw schriftelijke reactie.",
        ]
        if let t = u.termijnAanvangshuur {
            alinea.append("Mijn huurovereenkomst is minder dan zes maanden geleden ingegaan. Als wij er niet samen uitkomen, vraag ik de Huurcommissie om de aanvangshuur te toetsen. Dat kan tot en met \(t.einddatum).")
        } else {
            alinea.append("Als wij er niet samen uitkomen, kan ik de Huurcommissie vragen een uitspraak te doen over de hoogte van de huur.")
        }
        alinea += ["Met vriendelijke groet,", "[Uw naam]", "Bijlage: puntentelling van de woning"]
        return alinea.joined(separator: "\n\n")
    }
}
