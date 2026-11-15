import Foundation

/// De rekenregels van één jaar, ingelezen uit `rules/wws-zelfstandig-<jaar>.json`.
/// Alle puntenwaarden staan in het bestand; deze code bevat er geen.
public struct Regelset: Codable, Sendable {
    public let schemaVersie: Int
    public let regelsetJaar: Int
    public let geldigVan: Dag
    public let geldigTotEnMet: Dag
    public let bronnen: [String: Bron]
    public let afronding: AfrondingRegels
    public let rubrieken: Rubrieken
    public let meetregels: Meetregels
    public let prijsopslagen: Prijsopslagen
    public let segmenten: Segmenten
    public let termijnen: Termijnen
    public let maximaleHuurprijs: MaximaleHuurprijs

    public struct Bron: Codable, Sendable {
        public let titel: String
        public let url: String
        public let versie: String
        public let geraadpleegd: Dag
    }

    public struct AfrondingRegels: Codable, Sendable {
        public let rubriekStap: Double
        public let rubriekBron: String
        public let oppervlaktePerRuimteDecimalen: Int
        public let oppervlakteBron: String
        public let totaalBron: String
    }

    /// Meetregels voor de oppervlakte (toelichting rubriek 1 en 2). Gebruikt bij inmeten met de camera.
    public struct Meetregels: Codable, Sendable {
        /// Hoogte boven de vloer waarop van muur tot muur wordt gemeten.
        public let meethoogteM: Double
        /// Alleen het deel waarboven het plafond minstens zo hoog is, telt mee.
        public let minimaleVrijeHoogteM: Double
        public let oppervlakteDecimalen: Int
        public let bron: String

        /// Netto oppervlakte: gemeten vloeroppervlak min het deel met een plafond lager dan de minimale
        /// vrije hoogte en min schachten/koven (beide door de gebruiker opgegeven). Nooit negatief.
        public func nettoOppervlakte(vloer: Double, aftrek: Double) -> Double {
            max(0, vloer - max(0, aftrek))
        }
    }

    public struct Rubrieken: Codable, Sendable {
        public let r1: OppervlakteVertrekken
        public let r2: OppervlakteOverigeRuimten
        public let r3: Verwarming
        public let r4: Energieprestatie
        public let r5: Keuken
        public let r6: Sanitair
        public let r7: Gehandicapten
        public let r8: Buitenruimten
        public let r9: Gemeenschappelijk
        public let r10: Parkeren
        public let r11: Woz
        public let r12: Bijzonder

        enum CodingKeys: String, CodingKey {
            case r1 = "1", r2 = "2", r3 = "3", r4 = "4", r5 = "5", r6 = "6"
            case r7 = "7", r8 = "8", r9 = "9", r10 = "10", r11 = "11", r12 = "12"
        }
    }

    public struct OppervlakteVertrekken: Codable, Sendable {
        public let titel: String
        public let puntenPerM2: Double
        public let minimumOppervlakteM2: Double
        public let bron: String
    }

    public struct OppervlakteOverigeRuimten: Codable, Sendable {
        public let titel: String
        public let puntenPerM2: Double
        public let minimumOppervlakteM2: Double
        public let zolderZonderVasteTrapAftrek: Double
        public let bron: String
    }

    public struct Verwarming: Codable, Sendable {
        public let titel: String
        public let puntenPerVerwarmdVertrek: Double
        public let puntenPerVerwarmdeOverigeOfVerkeersruimte: Double
        public let maximumOverigeEnVerkeersruimten: Double
        public let puntenPerVertrekMetVerkoeling: Double
        public let maximumVerkoeling: Double
        public let bron: String
    }

    public struct Energieprestatie: Codable, Sendable {
        public let titel: String
        public let klassen: [Klasse]
        public let klassenBron: String
        public let monumentGeenMinpunten: Bool
        public let monumentBron: String
        public let energieprestatievergoeding: PerType
        public let energieprestatievergoedingBron: String
        public let labelGeldigheidJaren: Int
        public let labelGeldigheidBron: String

        public struct Klasse: Codable, Sendable {
            public let klasse: String
            public let eiKleinerDan: Double?
            public let eiGroterDan: Double?
            public let eiTotEnMet: Double?
            public let bouwjaarVanaf: Int?
            public let bouwjaarTotEnMet: Int?
            public let eengezins: Double
            public let meergezins: Double

            func punten(_ type: Woningtype) -> Double { type == .eengezins ? eengezins : meergezins }

            var heeftEI: Bool { eiKleinerDan != nil || eiGroterDan != nil || eiTotEnMet != nil }

            func bevat(ei: Double) -> Bool {
                guard heeftEI else { return false }
                if let g = eiKleinerDan, !(ei < g) { return false }
                if let g = eiGroterDan, !(ei > g) { return false }
                if let g = eiTotEnMet, !(ei <= g) { return false }
                return true
            }

            func bevat(bouwjaar: Int) -> Bool {
                guard bouwjaarVanaf != nil || bouwjaarTotEnMet != nil else { return false }
                if let v = bouwjaarVanaf, bouwjaar < v { return false }
                if let t = bouwjaarTotEnMet, bouwjaar > t { return false }
                return true
            }
        }

        public struct PerType: Codable, Sendable {
            public let eengezins: Double
            public let meergezins: Double
            func punten(_ type: Woningtype) -> Double { type == .eengezins ? eengezins : meergezins }
        }
    }

    public struct Keuken: Codable, Sendable {
        public let titel: String
        public let aanrechtLengte: [Trede]
        public let voorzieningen: [String: Double]
        public let maximumVoorzieningenIsAanrechtPunten: Bool
        public let bron: String

        public struct Trede: Codable, Sendable {
            public let vanafMeter: Double
            public let punten: Double
        }
    }

    public struct Sanitair: Codable, Sendable {
        public let titel: String
        public let toilet: Toilet
        public let wastafel: Double
        public let wastafelMaximumPerRuimteBuitenBadkamer: Double
        public let meerpersoonswastafel: Double
        public let meerpersoonswastafelMaximumPerRuimteBuitenBadkamer: Double
        public let douche: Double
        public let bad: Double
        public let badEnDouche: Double
        public let voorzieningenBadruimte: [String: Double]
        public let kastruimteMaximumPerRuimte: Double
        public let stopcontactMaximumPerWastafel: Double
        public let maximumVoorzieningenIsDoucheBadPunten: Bool
        public let bron: String

        public struct Toilet: Codable, Sendable {
            public let aparteToiletruimte: Double
            public let inBadkamer: Double
            public let hangendAparteToiletruimte: Double
            public let hangendInBadkamer: Double
        }
    }

    public struct Gehandicapten: Codable, Sendable {
        public let titel: String
        public let kostenPerPunt: Double
        public let bron: String
    }

    public struct Buitenruimten: Codable, Sendable {
        public let titel: String
        public let priveBasisPunten: Double
        public let privePuntenPerM2: Double
        public let gemeenschappelijkPuntenPerM2: Double
        public let maximum: Double
        public let aftrekGeenBuitenruimte: Double
        public let bron: String
    }

    public struct Gemeenschappelijk: Codable, Sendable {
        public let titel: String
        public let vertrekPuntenPerM2: Double
        public let overigeRuimtePuntenPerM2: Double
        public let bron: String
    }

    public struct Parkeren: Codable, Sendable {
        public let titel: String
        public let typeI: Double
        public let typeII: Double
        public let typeIII: Double
        public let bron: String
    }

    public struct Woz: Codable, Sendable {
        public let titel: String
        public let minimumwaarde: Double
        public let taxatieFactor: Double
        public let cohorten: [Cohort]
        public let kleineWoning: KleineWoning
        public let uitzondering: Uitzondering
        public let cap: Cap
        public let waardePerM2AfrondenOpCenten: Bool
        public let bron: String

        public struct Cohort: Codable, Sendable {
            public let waardepeildatum: Dag
            public let bedragPerPunt: Double
            public let delerPerM2: Double
            public let delerPerM2KleineWoning: Double
            public let ookVoorTaxatieEnMinimum: Bool
        }

        public struct KleineWoning: Codable, Sendable {
            public let oppervlakteKleinerDanM2: Double
            public let bouwjaren: [Int]
            public let coropGebieden: [String]
        }

        public struct Uitzondering: Codable, Sendable {
            public let bouwjaren: [Int]
            public let drempelTotaal: Double
            public let minimumWozPunten: Double
        }

        public struct Cap: Codable, Sendable {
            public let maximumAandeel: Double
            public let geldtVanafTotaal: Double
            public let vangnetTotaal: Double
        }
    }

    public struct Bijzonder: Codable, Sendable {
        public let titel: String
        public let zorgwoningOpslag: Double
        public let videoAanbelfunctie: Double
        public let laadpaalPunten: Double
        public let bron: String
    }

    public struct Prijsopslagen: Codable, Sendable {
        public let rijksmonumentContractNaWbh: Double
        public let rijksmonumentContractVoorWbhExtraPunten: Double
        public let gemeentelijkOfProvinciaalMonument: Double
        public let nieuwbouwMiddenhuur: Nieuwbouw
        public let beschermdStadsOfDorpsgezicht: BeschermdGezicht
        public let opslagenWordenOpgeteld: Bool
        public let bron: String
        public let inwerkingtredingWetBetaalbareHuur: Dag
        public let inwerkingtredingWetBetaalbareHuurGeverifieerd: Bool
        public let inwerkingtredingWetBetaalbareHuurBron: String

        public struct Nieuwbouw: Codable, Sendable {
            public let opslag: Double
            public let ingebruiknameNa: Dag
            public let bouwGestartVoor: Dag
            public let duurJaren: Int
        }

        public struct BeschermdGezicht: Codable, Sendable {
            public let opslag: Double
            public let gebouwdVoor: Int
        }
    }

    public struct Segmenten: Codable, Sendable {
        public let sociaalTotEnMetPunten: Int
        public let middenTotEnMetPunten: Int
        public let bron: String
        public let geverifieerd: Bool
    }

    public struct Termijnen: Codable, Sendable {
        public let toetsingAanvangshuurMaanden: Int
        public let bron: String
    }

    public struct MaximaleHuurprijs: Codable, Sendable {
        public let minimumPunten: Int
        public let bron: String
        public let tabel: [String: Double]

        public func bedrag(bijPunten p: Int) -> Double? {
            tabel[String(max(p, minimumPunten))]
        }
    }
}

// MARK: - Laden en kiezen op peildatum

public enum RegelsetBibliotheek {
    /// Alle regelsets die met de package zijn meegeleverd.
    public static func alle() throws -> [Regelset] {
        guard let map = Bundle.module.url(forResource: "rules", withExtension: nil) else {
            throw WWSFout.geenRegelset("map 'rules' ontbreekt in de bundel")
        }
        let bestanden = try FileManager.default.contentsOfDirectory(at: map, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("wws-zelfstandig-") && $0.pathExtension == "json" }
        return try bestanden.map { try laad(url: $0) }.sorted { $0.geldigVan < $1.geldigVan }
    }

    public static func laad(url: URL) throws -> Regelset {
        try laad(data: Data(contentsOf: url))
    }

    public static func laad(data: Data) throws -> Regelset {
        let r = try JSONDecoder().decode(Regelset.self, from: data)
        try valideer(r)
        return r
    }

    /// Kies de regelset die geldt op de peildatum.
    public static func regelset(op peildatum: Dag) throws -> Regelset {
        let kandidaten = try alle().filter { $0.geldigVan <= peildatum && peildatum <= $0.geldigTotEnMet }
        guard let r = kandidaten.first else {
            throw WWSFout.geenRegelset("geen regelbestand voor peildatum \(peildatum)")
        }
        guard kandidaten.count == 1 else {
            throw WWSFout.geenRegelset("meerdere regelbestanden voor peildatum \(peildatum)")
        }
        return r
    }

    /// Controleert dat het bestand intern consistent is (geen gaten in de huurtabel, bronnen aanwezig).
    static func valideer(_ r: Regelset) throws {
        let t = r.maximaleHuurprijs.tabel
        let punten = t.keys.compactMap(Int.init).sorted()
        guard let eerste = punten.first, let laatste = punten.last, eerste == r.maximaleHuurprijs.minimumPunten,
              punten.count == laatste - eerste + 1 else {
            throw WWSFout.ongeldigRegelbestand("huurprijstabel is niet aaneengesloten vanaf \(r.maximaleHuurprijs.minimumPunten) punten")
        }
        for (a, b) in zip(punten, punten.dropFirst()) where t[String(a)]! >= t[String(b)]! {
            throw WWSFout.ongeldigRegelbestand("huurprijstabel stijgt niet bij \(a) -> \(b) punten")
        }
        guard r.maximaleHuurprijs.bedrag(bijPunten: r.segmenten.middenTotEnMetPunten) != nil else {
            throw WWSFout.ongeldigRegelbestand("huurprijstabel bevat de middenhuurgrens niet")
        }
        guard r.rubrieken.r11.cohorten.filter(\.ookVoorTaxatieEnMinimum).count == 1 else {
            throw WWSFout.ongeldigRegelbestand("precies één WOZ-cohort moet gelden voor taxatie- en minimumwaarden")
        }
        guard !r.bronnen.isEmpty else { throw WWSFout.ongeldigRegelbestand("geen bronnen") }
    }
}

public enum WWSFout: Error, Equatable, CustomStringConvertible {
    case geenRegelset(String)
    case ongeldigRegelbestand(String)
    case ongeldigeInvoer(String)
    /// De bron geeft voor deze invoer geen eenduidige uitkomst; de app moet dit voorleggen in plaats van te gokken.
    case nietEenduidig(String)

    public var description: String {
        switch self {
        case .geenRegelset(let s): return "Geen regelset: \(s)"
        case .ongeldigRegelbestand(let s): return "Ongeldig regelbestand: \(s)"
        case .ongeldigeInvoer(let s): return "Ongeldige invoer: \(s)"
        case .nietEenduidig(let s): return "Niet eenduidig volgens de bron: \(s)"
        }
    }
}
