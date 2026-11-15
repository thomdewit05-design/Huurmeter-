import Foundation
import WWSKit

/// Eén ruimte zoals de gebruiker hem invoert (scherm 4).
public struct RuimteConcept: Hashable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var naam: String
    public var soort: RuimteSoort
    public var functie: RuimteFunctie?
    /// m², met één decimaal getoond; intern ongerond bewaard.
    public var oppervlakte: Double
    public var verwarmd: Bool
    public var verkoeling: Bool
    public var zolderZonderVasteTrap: Bool
    public var bron: MeetBron

    public init(id: UUID = UUID(), naam: String, soort: RuimteSoort, functie: RuimteFunctie? = nil,
                oppervlakte: Double, verwarmd: Bool = false, verkoeling: Bool = false,
                zolderZonderVasteTrap: Bool = false, bron: MeetBron = .handmatig) {
        self.id = id; self.naam = naam; self.soort = soort; self.functie = functie
        self.oppervlakte = oppervlakte; self.verwarmd = verwarmd; self.verkoeling = verkoeling
        self.zolderZonderVasteTrap = zolderZonderVasteTrap; self.bron = bron
    }

    /// Standaardsoort bij een gekozen functie (de gebruiker kan dit aanpassen).
    public static func standaardSoort(voor f: RuimteFunctie) -> RuimteSoort {
        switch f {
        case .woonkamer, .slaapkamer, .keuken, .badkamer: return .vertrek
        case .toilet, .berging, .zolder, .garage, .overig: return .overigeRuimte
        case .gang: return .verkeersruimte
        }
    }
}

/// Alles wat de gebruiker over één woning invult, los van de opslag (SwiftData) en de UI.
public struct WoningConcept: Hashable, Codable, Sendable {
    public var adres: AdresGegevens
    public var bouwjaar: Int?
    public var woningtype: Woningtype?
    public var kaleHuur: Double?
    public var contractStart: Dag?
    public var ruimten: [RuimteConcept]
    /// Antwoorden op de vragen van scherm 5, per sleutel uit `Vragenlijst`. Ja/nee = 1/0, datum = jjjjmmdd.
    public var antwoorden: [String: Double]
    public var energielabel: Energielabel?
    public var energieIndex: Double?
    public var labelOpnamedatum: Dag?
    public var energieprestatievergoeding: Bool
    public var koelingInLabel: Bool
    public var wozWaarde: Double?
    public var wozPeildatum: Dag?

    public init(adres: AdresGegevens = AdresGegevens(postcode: "", huisnummer: ""), bouwjaar: Int? = nil,
                woningtype: Woningtype? = nil, kaleHuur: Double? = nil, contractStart: Dag? = nil,
                ruimten: [RuimteConcept] = [], antwoorden: [String: Double] = [:],
                energielabel: Energielabel? = nil, energieIndex: Double? = nil, labelOpnamedatum: Dag? = nil,
                energieprestatievergoeding: Bool = false, koelingInLabel: Bool = false,
                wozWaarde: Double? = nil, wozPeildatum: Dag? = nil) {
        self.adres = adres; self.bouwjaar = bouwjaar; self.woningtype = woningtype; self.kaleHuur = kaleHuur
        self.contractStart = contractStart; self.ruimten = ruimten; self.antwoorden = antwoorden
        self.energielabel = energielabel; self.energieIndex = energieIndex; self.labelOpnamedatum = labelOpnamedatum
        self.energieprestatievergoeding = energieprestatievergoeding; self.koelingInLabel = koelingInLabel
        self.wozWaarde = wozWaarde; self.wozPeildatum = wozPeildatum
    }

    /// Antwoord, of de standaardwaarde uit de vragenlijst als de gebruiker niets heeft ingevuld.
    public func antwoord(_ sleutel: String) -> Double { antwoorden[sleutel] ?? Vragenlijst.standaarden[sleutel] ?? 0 }
    public func ja(_ sleutel: String) -> Bool { antwoord(sleutel) >= 0.5 }
    public func aantal(_ sleutel: String) -> Int { max(0, Int(antwoord(sleutel).rounded())) }

    /// Som van de oppervlakten van vertrekken en overige ruimten (voor de vraag over kleine woningen).
    public var binnenOppervlakte: Double {
        ruimten.filter { $0.soort == .vertrek || $0.soort == .overigeRuimte }.map(\.oppervlakte).reduce(0, +)
    }
}

// MARK: - Datum als getal (antwoorden zijn Doubles)

public extension Dag {
    /// jjjjmmdd, bijv. 20250301.
    var alsGetal: Double { Double(jaar * 10_000 + maand * 100 + dag) }

    init?(getal: Double) {
        let n = Int(getal)
        guard n > 0 else { return nil }
        self.init(iso: String(format: "%04d-%02d-%02d", n / 10_000, (n / 100) % 100, n % 100))
    }

    /// Kalenderdag van een `Date` in de gegeven kalender (standaard: Gregoriaans, tijdzone van het toestel).
    init(_ datum: Date, kalender: Calendar = Dag.kalender) {
        let c = kalender.dateComponents([.year, .month, .day], from: datum)
        self.init(c.year!, c.month!, c.day!)
    }

    /// Middernacht van deze dag in de gegeven kalender.
    func datum(kalender: Calendar = Dag.kalender) -> Date {
        kalender.date(from: DateComponents(year: jaar, month: maand, day: dag))!
    }

    static var kalender: Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = .current
        return k
    }
}
