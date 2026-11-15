import Foundation

public enum Gebrekcategorie: String, Codable, CaseIterable, Sendable {
    case A, B, C
}

/// Gebrekencategorieën uit het Besluit huurprijzen woonruimte, ingelezen uit `rules/gebreken.json`.
public struct GebrekenRegels: Codable, Sendable {
    public let bronnen: [String: Regelset.Bron]
    public let geenHuurverhoging: Tekst
    public let categorieen: [Categorie]

    public struct Tekst: Codable, Sendable {
        public let tekst: String
        public let bron: String
    }

    public struct Categorie: Codable, Sendable, Identifiable {
        public let code: Gebrekcategorie
        public let titel: String
        /// De Huurcommissie stelt de huur ten laagste vast op dit deel van de overeengekomen huur (BHW art. 6 lid 1).
        public let laagsteHuurPercentage: Double
        public let bron: String
        public let voorbeelden: [String]
        public var id: Gebrekcategorie { code }
    }

    public func categorie(_ c: Gebrekcategorie) -> Categorie? { categorieen.first { $0.code == c } }

    /// De laagste huur die de Huurcommissie bij deze gebreken kan vaststellen.
    /// Bij meerdere gebreken telt het gebrek met het laagste percentage (BHW art. 6 lid 5).
    /// Dit is een ondergrens: de werkelijke verlaging volgt uit het gebrekenboek van de Huurcommissie.
    public func laagsteHuur(huur: Double, categorieen gekozen: Set<Gebrekcategorie>) -> (huur: Double, percentage: Double, bron: String)? {
        let kandidaten = gekozen.compactMap { categorie($0) }
        guard let laagste = kandidaten.min(by: { $0.laagsteHuurPercentage < $1.laagsteHuurPercentage }) else { return nil }
        return (Afronding.centen(huur * laagste.laagsteHuurPercentage), laagste.laagsteHuurPercentage, laagste.bron)
    }

    public static func laad() throws -> GebrekenRegels {
        guard let url = Bundle.module.url(forResource: "gebreken", withExtension: "json", subdirectory: "rules") else {
            throw WWSFout.geenRegelset("geen gebrekenregels")
        }
        return try JSONDecoder().decode(GebrekenRegels.self, from: Data(contentsOf: url))
    }
}
