import Foundation

/// De invoerschermen 2 t/m 6 en wanneer ze als "ingevuld" gelden.
public enum Stap: String, CaseIterable, Identifiable, Sendable {
    case adres, huur, ruimtes, voorzieningen, energieWoz

    public var id: String { rawValue }

    public var titel: String {
        switch self {
        case .adres: return "Adres"
        case .huur: return "Huur"
        case .ruimtes: return "Ruimtes"
        case .voorzieningen: return "Voorzieningen"
        case .energieWoz: return "Energie en WOZ"
        }
    }

    public var systeemIcoon: String {
        switch self {
        case .adres: return "house"
        case .huur: return "eurosign.circle"
        case .ruimtes: return "square.split.2x2"
        case .voorzieningen: return "checklist"
        case .energieWoz: return "bolt"
        }
    }

    public enum Status: Equatable, Sendable {
        case leeg
        case deels(String)
        case klaar
    }

    public func status(_ c: WoningConcept) -> Status {
        switch self {
        case .adres:
            if Postcode(c.adres.postcode) == nil || c.adres.huisnummer.isEmpty { return .leeg }
            return c.bouwjaar == nil ? .deels("Bouwjaar ontbreekt") : .klaar
        case .huur:
            if c.kaleHuur == nil && c.contractStart == nil && c.woningtype == nil { return .leeg }
            if c.woningtype == nil { return .deels("Type woning ontbreekt") }
            if c.kaleHuur == nil { return .deels("Kale huur ontbreekt") }
            return .klaar
        case .ruimtes:
            if c.ruimten.isEmpty { return .leeg }
            let kamers = c.ruimten.filter { $0.soort == .vertrek }.count
            return kamers == 0 ? .deels("Nog geen kamer toegevoegd") : .klaar
        case .voorzieningen:
            return c.antwoorden.isEmpty ? .leeg : .klaar
        case .energieWoz:
            if c.wozWaarde == nil && c.energielabel == nil && c.energieIndex == nil { return .leeg }
            if c.wozWaarde == nil { return .deels("Zonder WOZ-waarde rekent de app met de minimumwaarde") }
            if c.energielabel != nil && c.labelOpnamedatum == nil { return .deels("Opnamedatum van het label ontbreekt") }
            return .klaar
        }
    }
}
