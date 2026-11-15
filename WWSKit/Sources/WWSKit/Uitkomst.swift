import Foundation

public struct RubriekUitkomst: Codable, Sendable, Identifiable {
    /// Rubrieknummer zoals in Bijlage I onder A ("1" t/m "12").
    public let nummer: String
    public let titel: String
    /// Punten na afronding op 0,25.
    public let punten: Double
    /// Tussenstappen in gewone taal.
    public let stappen: [String]
    /// Bronverwijzing uit het regelbestand.
    public let bron: String

    public var id: String { nummer }
}

public enum Segment: String, Codable, Sendable {
    case sociaal
    case midden
    case vrij

    public var omschrijving: String {
        switch self {
        case .sociaal: return "sociale huur"
        case .midden: return "middenhuur"
        case .vrij: return "vrije sector"
        }
    }
}

public struct Termijn: Codable, Sendable {
    /// Laatste dag waarop de huurder de Huurcommissie kan vragen de aanvangshuur te toetsen.
    public let einddatum: Dag
    /// Resterende dagen vanaf de peildatum (0 of meer).
    public let resterendeDagen: Int

    public init(einddatum: Dag, resterendeDagen: Int) {
        self.einddatum = einddatum
        self.resterendeDagen = resterendeDagen
    }
}

public struct Uitkomst: Codable, Sendable {
    public let regelsetJaar: Int
    public let peildatum: Dag
    public let rubrieken: [RubriekUitkomst]
    /// Som van de rubrieken vóór afronding op hele punten.
    public let somRubrieken: Double
    /// Puntentotaal, afgerond op hele punten, inclusief eventuele extra punten rijksmonument (art. 8a lid 2).
    public let totaal: Int
    public let segment: Segment
    /// Maximale huurprijsgrens uit de tabel, zonder prijsopslag. Nil in de vrije sector.
    public let maximaleHuurZonderOpslag: Double?
    /// Opgetelde prijsopslag als fractie (0,15 = 15%).
    public let prijsopslag: Double
    public let prijsopslagStappen: [String]
    /// Maximale huurprijsgrens inclusief prijsopslag. Nil in de vrije sector.
    public let maximaleHuur: Double?
    /// Huidige kale huur min maximale huur (positief = te veel). Nil als niet te bepalen.
    public let verschilPerMaand: Double?
    public let verschilPerJaar: Double?
    public let termijnAanvangshuur: Termijn?
    /// Signalen die de gebruiker moet zien (bijv. verlopen label, aannames).
    public let waarschuwingen: [String]

    public static let disclaimer = "Indicatie op basis van uw invoer. Alleen de Huurcommissie of de rechter stelt de huurprijs bindend vast."

    public func rubriek(_ nummer: String) -> RubriekUitkomst? { rubrieken.first { $0.nummer == nummer } }
}
