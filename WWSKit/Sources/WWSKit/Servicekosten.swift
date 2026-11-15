import Foundation

/// Regels voor de servicekosten-check, ingelezen uit `rules/servicekosten.json`.
public struct ServicekostenRegels: Codable, Sendable {
    public let bronnen: [String: Regelset.Bron]
    public let minimumGeschil: Bedrag
    public let zonderFormulier: Tekst
    public let normbedragen: Normbedragen
    public let voorschotTeHoog: Tekst
    public let inzage: Tekst

    public struct Bedrag: Codable, Sendable { public let bedrag: Double; public let bron: String }
    public struct Tekst: Codable, Sendable { public let tekst: String; public let bron: String }
    public struct Normbedragen: Codable, Sendable {
        public struct Set: Codable, Sendable {
            public let gas: String
            public let water: String
            public let elektriciteit: String
            public let overigPerJaar: Double
        }
        public let zelfstandig: Set
        public let onzelfstandig: Set
        public let bron: String
    }

    public static func laad() throws -> ServicekostenRegels {
        guard let url = Bundle.module.url(forResource: "servicekosten", withExtension: "json", subdirectory: "rules") else {
            throw WWSFout.geenRegelset("geen servicekostenregels")
        }
        return try JSONDecoder().decode(ServicekostenRegels.self, from: Data(contentsOf: url))
    }
}

/// Eén kostensoort uit het jaaroverzicht.
public struct ServicekostenPost: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var naam: String
    /// Wat de huurder dat jaar aan voorschot voor deze post betaalde.
    public var voorschot: Double
    /// Wat de verhuurder volgens het overzicht aan kosten rekent; nil als de post er niet in staat.
    public var kosten: Double?

    public init(id: UUID = UUID(), naam: String, voorschot: Double, kosten: Double?) {
        self.id = id; self.naam = naam; self.voorschot = voorschot; self.kosten = kosten
    }

    /// Positief: u krijgt terug. Negatief: u betaalt bij.
    public var saldo: Double? { kosten.map { Afronding.centen(voorschot - $0) } }
}

public struct ServicekostenUitkomst: Sendable, Equatable {
    public let totaalVoorschot: Double
    public let totaalKosten: Double
    /// Positief: terug te krijgen; negatief: bij te betalen.
    public let saldo: Double
    public let overzichtUiterlijk: Dag
    /// Overzicht niet (op tijd) ontvangen terwijl de termijn verstreken is.
    public let overzichtTeLaat: Bool
    public let verzoekUiterlijk: Dag
    public let verzoekVerlopen: Bool
}

public enum Servicekosten {
    /// - Parameters:
    ///   - jaar: het kalenderjaar waarover het overzicht gaat.
    ///   - overzichtOntvangen: datum waarop de huurder het jaaroverzicht kreeg (nil: niet ontvangen).
    public static func beoordeel(posten: [ServicekostenPost], jaar: Int, overzichtOntvangen: Dag?, vandaag: Dag,
                                 procedure: Stappenplannen.Procedure) -> ServicekostenUitkomst {
        let t = procedure.termijnen(anker: Dag(jaar, 12, 31), vandaag: vandaag)
        let overzichtUiterlijk = t.overzichtUiterlijk ?? Dag(jaar + 1, 6, 30)
        let teLaat: Bool
        if let o = overzichtOntvangen { teLaat = o > overzichtUiterlijk } else { teLaat = vandaag > overzichtUiterlijk }
        let voorschot = Afronding.centen(posten.reduce(0) { $0 + $1.voorschot })
        let kosten = Afronding.centen(posten.reduce(0) { $0 + ($1.kosten ?? 0) })
        return ServicekostenUitkomst(totaalVoorschot: voorschot, totaalKosten: kosten,
                                     saldo: Afronding.centen(voorschot - kosten),
                                     overzichtUiterlijk: overzichtUiterlijk, overzichtTeLaat: teLaat,
                                     verzoekUiterlijk: t.uiterlijk, verzoekVerlopen: t.verlopen)
    }

    /// Of een verschil groot genoeg is om de Huurcommissie te vragen (UW art. 9 lid 3).
    public static func ontvankelijk(geschil: Double, regels: ServicekostenRegels) -> Bool {
        abs(geschil) >= regels.minimumGeschil.bedrag
    }
}
