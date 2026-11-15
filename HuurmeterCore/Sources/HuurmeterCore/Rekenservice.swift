import Foundation
import WWSKit

/// Rekent een concept door en geeft een uitkomst of een melding in gewone taal.
public struct Rekenservice: Sendable {
    public init() {}

    public enum Resultaat: Sendable {
        case uitkomst(Uitkomst)
        case melding(String)
    }

    public func bereken(_ c: WoningConcept, peildatum: Dag) -> Resultaat {
        do {
            let regels = try RegelsetBibliotheek.regelset(op: peildatum)
            let invoer = try Invoerbouwer.invoer(c, regels: regels)
            return .uitkomst(try Rekenmachine(regels: regels).bereken(invoer, peildatum: peildatum))
        } catch let fout as Invoerbouwer.Ontbreekt {
            return .melding(fout.description)
        } catch let fout as WWSFout {
            return .melding(Self.tekst(fout))
        } catch {
            return .melding("De berekening is niet gelukt: \(error.localizedDescription)")
        }
    }

    static func tekst(_ fout: WWSFout) -> String {
        switch fout {
        case .geenRegelset:
            return "Voor deze datum zijn nog geen rekenregels beschikbaar. Werk de app bij."
        case .ongeldigRegelbestand:
            return "De rekenregels in de app zijn beschadigd. Installeer de app opnieuw."
        case .ongeldigeInvoer(let s):
            return "Controleer uw invoer: \(s)."
        case .nietEenduidig(let s):
            return "De officiële regels geven hier geen eenduidig antwoord (\(s)). Controleer uw invoer of laat de Huurcommissie dit beoordelen."
        }
    }

    /// Rekencijfers die het scherm Energie en WOZ nodig heeft om de juiste waardepeildata aan te bieden.
    public static func wozPeildata(op peildatum: Dag) -> [Dag] {
        ((try? RegelsetBibliotheek.regelset(op: peildatum))?.rubrieken.r11.cohorten.map(\.waardepeildatum) ?? [])
            .sorted(by: >)
    }
}

/// Teksten en getallen voor het uitkomstscherm (scherm 7).
public enum Opmaak {
    public static func euro(_ x: Double) -> String {
        "€ " + getal(x, decimalen: 2)
    }

    public static func getal(_ x: Double, decimalen: Int) -> String {
        Getalnotatie.nl(x, decimalen: decimalen)
    }

    /// "12,5 m²" (spec: altijd één decimaal).
    public static func oppervlakte(_ m2: Double) -> String { getal(m2, decimalen: 1) + " m²" }

    public static func punten(_ p: Double) -> String {
        let heel = p.truncatingRemainder(dividingBy: 1) == 0
        let s = getal(p, decimalen: heel ? 0 : 2)
        return abs(p) == 1 ? "\(s) punt" : "\(s) punten"
    }

    public static func segment(_ s: Segment) -> String {
        switch s {
        case .sociaal: return "Sociale huur"
        case .midden: return "Middenhuur"
        case .vrij: return "Vrije sector"
        }
    }

    public struct Samenvatting: Equatable, Sendable {
        public let kop: String
        public let regels: [String]
        /// true = huurder betaalt meer dan het maximum.
        public let teVeel: Bool
    }

    public static func samenvatting(_ u: Uitkomst, kaleHuur: Double?) -> Samenvatting {
        guard let max = u.maximaleHuur else {
            return Samenvatting(kop: "Vrije sector: geen maximale huur",
                                regels: ["Met \(u.totaal) punten valt de woning in de vrije sector. Daar geldt geen wettelijke maximale huurprijs."],
                                teVeel: false)
        }
        var regels = ["Maximale kale huur: \(euro(max)) per maand."]
        if u.prijsopslag > 0 {
            regels.append("Inclusief \(getal(u.prijsopslag * 100, decimalen: 0))% opslag (\(euro(u.maximaleHuurZonderOpslag ?? max)) zonder opslag).")
        }
        guard let huur = kaleHuur, let verschil = u.verschilPerMaand, let perJaar = u.verschilPerJaar else {
            regels.append("Vul uw kale huur in om het verschil te zien.")
            return Samenvatting(kop: "\(u.totaal) punten · \(segment(u.segment))", regels: regels, teVeel: false)
        }
        if verschil > 0 {
            regels.append("U betaalt \(euro(huur)): \(euro(verschil)) per maand te veel, \(euro(perJaar)) per jaar.")
            return Samenvatting(kop: "Mogelijk \(euro(verschil)) per maand te veel", regels: regels, teVeel: true)
        }
        regels.append("U betaalt \(euro(huur)), dat is niet meer dan het maximum.")
        return Samenvatting(kop: "\(u.totaal) punten · \(segment(u.segment))", regels: regels, teVeel: false)
    }

    public static func termijn(_ t: Termijn) -> String {
        let dagen = t.resterendeDagen == 1 ? "1 dag" : "\(t.resterendeDagen) dagen"
        return "Nog \(dagen) om de Huurcommissie te vragen uw aanvangshuur te toetsen (tot en met \(t.einddatum)). Dit geldt alleen als dit uw eerste huurcontract voor deze woning is."
    }
}
