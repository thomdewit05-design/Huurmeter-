import Foundation

public enum Woningtype: String, Codable, Sendable {
    /// Geen andere woningen boven of onder de woning (vrijstaand, twee-onder-een-kap, rijtjeshuis).
    case eengezins
    /// Alle andere woningen (meergezins- of duplexwoning).
    case meergezins
}

public enum RuimteSoort: String, Codable, Sendable {
    case vertrek
    case overigeRuimte
    case verkeersruimte
    /// Privé-buitenruimte (tuin, balkon, dakterras, loggia).
    case buitenruimte
}

public enum RuimteFunctie: String, Codable, Sendable {
    case woonkamer, slaapkamer, keuken, badkamer, toilet, berging, zolder, garage, gang, overig
}

public enum MeetBron: String, Codable, Sendable {
    case scan, handmatig
}

public enum MonumentStatus: String, Codable, Sendable {
    case geen
    case rijksmonument
    case gemeentelijkOfProvinciaal
}

public struct RuimteInvoer: Codable, Sendable {
    public var naam: String
    public var soort: RuimteSoort
    public var functie: RuimteFunctie?
    /// Oppervlakte in m², gemeten van muur tot muur op 1,50 m hoogte; alleen het deel waarboven
    /// het plafond minstens 1,50 m hoog is. De app laat de gebruiker dit corrigeren (schuin dak).
    public var oppervlakte: Double
    public var verwarmd: Bool
    /// Vaste verkoelingsvoorziening die ook kan verwarmen (alleen vertrekken).
    public var verkoeling: Bool
    /// Alleen voor zolders (overige ruimte): geen vaste trap aanwezig.
    public var zolderZonderVasteTrap: Bool
    public var bron: MeetBron

    public init(naam: String, soort: RuimteSoort, functie: RuimteFunctie? = nil, oppervlakte: Double,
                verwarmd: Bool = false, verkoeling: Bool = false, zolderZonderVasteTrap: Bool = false,
                bron: MeetBron = .handmatig) {
        self.naam = naam; self.soort = soort; self.functie = functie; self.oppervlakte = oppervlakte
        self.verwarmd = verwarmd; self.verkoeling = verkoeling
        self.zolderZonderVasteTrap = zolderZonderVasteTrap; self.bron = bron
    }

    enum CodingKeys: String, CodingKey {
        case naam, soort, functie, oppervlakte, verwarmd, verkoeling, zolderZonderVasteTrap, bron
    }

    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        naam = try c.decode(String.self, forKey: .naam)
        soort = try c.decode(RuimteSoort.self, forKey: .soort)
        functie = try c.decodeIfPresent(RuimteFunctie.self, forKey: .functie)
        oppervlakte = try c.decode(Double.self, forKey: .oppervlakte)
        verwarmd = try c.decodeIfPresent(Bool.self, forKey: .verwarmd) ?? false
        verkoeling = try c.decodeIfPresent(Bool.self, forKey: .verkoeling) ?? false
        zolderZonderVasteTrap = try c.decodeIfPresent(Bool.self, forKey: .zolderZonderVasteTrap) ?? false
        bron = try c.decodeIfPresent(MeetBron.self, forKey: .bron) ?? .handmatig
    }
}

public struct KeukenInvoer: Codable, Sendable {
    /// Aan- en afvoer water, aansluitpunt koken, aanrecht ≥ 1 m, twee inbouwkasten ≥ 50 cm,
    /// waterdichte afwerking tot 1,50 m. Zo niet: geen punten.
    public var voldoetAanBasisniveau: Bool
    /// Aanrechtlengte in meters, gemeten over het midden van het blad (hoekaanrecht: beide lange zijden).
    public var aanrechtLengte: Double
    /// Aantal per voorziening; sleutels zoals in het regelbestand (rubriek 5, "voorzieningen").
    public var voorzieningen: [String: Int]

    public init(voldoetAanBasisniveau: Bool = true, aanrechtLengte: Double, voorzieningen: [String: Int] = [:]) {
        self.voldoetAanBasisniveau = voldoetAanBasisniveau
        self.aanrechtLengte = aanrechtLengte
        self.voorzieningen = voorzieningen
    }

    enum CodingKeys: String, CodingKey { case voldoetAanBasisniveau, aanrechtLengte, voorzieningen }

    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        voldoetAanBasisniveau = try c.decodeIfPresent(Bool.self, forKey: .voldoetAanBasisniveau) ?? true
        aanrechtLengte = try c.decode(Double.self, forKey: .aanrechtLengte)
        voorzieningen = try c.decodeIfPresent([String: Int].self, forKey: .voorzieningen) ?? [:]
    }
}

public enum SanitaireRuimteSoort: String, Codable, Sendable {
    /// Bad- of doucheruimte.
    case badkamer
    /// Aparte toiletruimte.
    case toiletruimte
    /// Een ander vertrek of overige ruimte (bijv. wastafel op de slaapkamer).
    case anders
}

public struct SanitaireRuimteInvoer: Codable, Sendable {
    public var naam: String
    public var soort: SanitaireRuimteSoort
    public var staandeToiletten: Int
    public var hangendeToiletten: Int
    public var wastafels: Int
    public var meerpersoonswastafels: Int
    public var douches: Int
    public var baden: Int
    /// Voldoet de bad-/doucheruimte aan de eisen uit toelichting 6.2 (waterdichte vloer, vrije hoogte,
    /// betegeling, wastafel met mengkraan en spiegel, douche/bad met warm en koud water)?
    public var voldoetAanEisenBadruimte: Bool
    /// Aantal per voorziening; sleutels zoals in het regelbestand (rubriek 6, "voorzieningenBadruimte").
    public var voorzieningen: [String: Int]

    public init(naam: String, soort: SanitaireRuimteSoort, staandeToiletten: Int = 0, hangendeToiletten: Int = 0,
                wastafels: Int = 0, meerpersoonswastafels: Int = 0, douches: Int = 0, baden: Int = 0,
                voldoetAanEisenBadruimte: Bool = false, voorzieningen: [String: Int] = [:]) {
        self.naam = naam; self.soort = soort
        self.staandeToiletten = staandeToiletten; self.hangendeToiletten = hangendeToiletten
        self.wastafels = wastafels; self.meerpersoonswastafels = meerpersoonswastafels
        self.douches = douches; self.baden = baden
        self.voldoetAanEisenBadruimte = voldoetAanEisenBadruimte; self.voorzieningen = voorzieningen
    }

    enum CodingKeys: String, CodingKey {
        case naam, soort, staandeToiletten, hangendeToiletten, wastafels, meerpersoonswastafels
        case douches, baden, voldoetAanEisenBadruimte, voorzieningen
    }

    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        naam = try c.decode(String.self, forKey: .naam)
        soort = try c.decode(SanitaireRuimteSoort.self, forKey: .soort)
        staandeToiletten = try c.decodeIfPresent(Int.self, forKey: .staandeToiletten) ?? 0
        hangendeToiletten = try c.decodeIfPresent(Int.self, forKey: .hangendeToiletten) ?? 0
        wastafels = try c.decodeIfPresent(Int.self, forKey: .wastafels) ?? 0
        meerpersoonswastafels = try c.decodeIfPresent(Int.self, forKey: .meerpersoonswastafels) ?? 0
        douches = try c.decodeIfPresent(Int.self, forKey: .douches) ?? 0
        baden = try c.decodeIfPresent(Int.self, forKey: .baden) ?? 0
        voldoetAanEisenBadruimte = try c.decodeIfPresent(Bool.self, forKey: .voldoetAanEisenBadruimte) ?? false
        voorzieningen = try c.decodeIfPresent([String: Int].self, forKey: .voorzieningen) ?? [:]
    }
}

public enum Energielabel: String, Codable, CaseIterable, Sendable {
    case aPlus4 = "A++++", aPlus3 = "A+++", aPlus2 = "A++", aPlus1 = "A+"
    case a = "A", b = "B", c = "C", d = "D", e = "E", f = "F", g = "G"
}

public struct EnergieInvoer: Codable, Sendable {
    /// Energielabel (NTA 8800 of NEN 7120).
    public var label: Energielabel?
    /// Energie-Index (oud systeem), alleen als er geen label is.
    public var energieIndex: Double?
    /// Datum van opname van de gegevens (bepaalt de geldigheid van tien jaar).
    public var opnamedatum: Dag?
    /// Is er een energieprestatievergoeding (art. 7:237 BW) overeengekomen?
    public var energieprestatievergoeding: Bool
    /// Is de koelfunctie meegenomen in een geldig NTA 8800-label? Voorwaarde voor punten voor verkoeling.
    public var koelingInLabel: Bool

    public init(label: Energielabel? = nil, energieIndex: Double? = nil, opnamedatum: Dag? = nil,
                energieprestatievergoeding: Bool = false, koelingInLabel: Bool = false) {
        self.label = label; self.energieIndex = energieIndex; self.opnamedatum = opnamedatum
        self.energieprestatievergoeding = energieprestatievergoeding; self.koelingInLabel = koelingInLabel
    }

    enum CodingKeys: String, CodingKey { case label, energieIndex, opnamedatum, energieprestatievergoeding, koelingInLabel }

    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        label = try c.decodeIfPresent(Energielabel.self, forKey: .label)
        energieIndex = try c.decodeIfPresent(Double.self, forKey: .energieIndex)
        opnamedatum = try c.decodeIfPresent(Dag.self, forKey: .opnamedatum)
        energieprestatievergoeding = try c.decodeIfPresent(Bool.self, forKey: .energieprestatievergoeding) ?? false
        koelingInLabel = try c.decodeIfPresent(Bool.self, forKey: .koelingInLabel) ?? false
    }
}

public struct GemeenschappelijkeBuitenruimteInvoer: Codable, Sendable {
    public var naam: String
    public var oppervlakte: Double
    /// Aantal adressen met toegang en gebruiksrecht.
    public var adressen: Int
    public init(naam: String, oppervlakte: Double, adressen: Int) {
        self.naam = naam; self.oppervlakte = oppervlakte; self.adressen = adressen
    }
}

public struct GemeenschappelijkeRuimteInvoer: Codable, Sendable {
    public var naam: String
    /// `.vertrek` of `.overigeRuimte`.
    public var soort: RuimteSoort
    public var oppervlakte: Double
    public var verwarmd: Bool
    public var keuken: KeukenInvoer?
    public var sanitair: SanitaireRuimteInvoer?
    public var adressen: Int

    public init(naam: String, soort: RuimteSoort, oppervlakte: Double, verwarmd: Bool = false,
                keuken: KeukenInvoer? = nil, sanitair: SanitaireRuimteInvoer? = nil, adressen: Int) {
        self.naam = naam; self.soort = soort; self.oppervlakte = oppervlakte; self.verwarmd = verwarmd
        self.keuken = keuken; self.sanitair = sanitair; self.adressen = adressen
    }
}

public struct ParkeerruimteInvoer: Codable, Sendable {
    public var naam: String
    public var plekkenTypeI: Int
    public var plekkenTypeII: Int
    public var plekkenTypeIII: Int
    /// Totale oppervlakte van de type I-plekken (telt mee in de WOZ-oppervlakte, rubriek 11).
    public var oppervlakteTypeI: Double
    /// Aantal plekken met een laadpaal voor exclusief gebruik door de bewoners (rubriek 12).
    public var plekkenMetLaadpaal: Int
    /// Aantal adressen dat gebruik kan maken van deze plekken (privé-plek: 1).
    public var adressen: Int

    public init(naam: String, plekkenTypeI: Int = 0, plekkenTypeII: Int = 0, plekkenTypeIII: Int = 0,
                oppervlakteTypeI: Double = 0, plekkenMetLaadpaal: Int = 0, adressen: Int) {
        self.naam = naam; self.plekkenTypeI = plekkenTypeI; self.plekkenTypeII = plekkenTypeII
        self.plekkenTypeIII = plekkenTypeIII; self.oppervlakteTypeI = oppervlakteTypeI
        self.plekkenMetLaadpaal = plekkenMetLaadpaal; self.adressen = adressen
    }

    enum CodingKeys: String, CodingKey { case naam, plekkenTypeI, plekkenTypeII, plekkenTypeIII, oppervlakteTypeI, plekkenMetLaadpaal, adressen }

    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        naam = try c.decode(String.self, forKey: .naam)
        plekkenTypeI = try c.decodeIfPresent(Int.self, forKey: .plekkenTypeI) ?? 0
        plekkenTypeII = try c.decodeIfPresent(Int.self, forKey: .plekkenTypeII) ?? 0
        plekkenTypeIII = try c.decodeIfPresent(Int.self, forKey: .plekkenTypeIII) ?? 0
        oppervlakteTypeI = try c.decodeIfPresent(Double.self, forKey: .oppervlakteTypeI) ?? 0
        plekkenMetLaadpaal = try c.decodeIfPresent(Int.self, forKey: .plekkenMetLaadpaal) ?? 0
        adressen = try c.decode(Int.self, forKey: .adressen)
    }
}

public struct WozInvoer: Codable, Sendable {
    /// Laatst vastgestelde WOZ-waarde.
    public var waarde: Double?
    /// Waardepeildatum van de WOZ-beschikking (bv. 2025-01-01).
    public var waardepeildatum: Dag?
    /// Taxatiewaarde (register-taxateur), alleen als er nog geen WOZ-waarde is.
    public var taxatiewaarde: Double?

    public init(waarde: Double? = nil, waardepeildatum: Dag? = nil, taxatiewaarde: Double? = nil) {
        self.waarde = waarde; self.waardepeildatum = waardepeildatum; self.taxatiewaarde = taxatiewaarde
    }
}

public struct WoningInvoer: Codable, Sendable {
    public var bouwjaar: Int
    public var woningtype: Woningtype
    public var ruimten: [RuimteInvoer]
    /// Open keuken: telt voor rubriek 3 als afzonderlijk verwarmd vertrek, maar niet voor de oppervlakte.
    public var verwarmdeOpenKeukens: Int
    public var keukens: [KeukenInvoer]
    public var sanitaireRuimten: [SanitaireRuimteInvoer]
    public var energie: EnergieInvoer
    /// Door de verhuurder bestede kosten aan woonvoorzieningen voor gehandicapten (rubriek 7).
    public var kostenGehandicaptenvoorzieningen: Double
    public var gemeenschappelijkeBuitenruimten: [GemeenschappelijkeBuitenruimteInvoer]
    public var gemeenschappelijkeRuimten: [GemeenschappelijkeRuimteInvoer]
    public var parkeerruimten: [ParkeerruimteInvoer]
    public var woz: WozInvoer
    /// Ligt de woning in een gemeente in het COROP-gebied Amsterdam of Utrecht? (11.1 onder a)
    public var coropAmsterdamOfUtrecht: Bool
    public var zorgwoning: Bool
    public var videoAanbelfunctie: Bool
    public var monument: MonumentStatus
    public var beschermdStadsOfDorpsgezicht: Bool
    /// Datum van eerste ingebruikname als woonruimte (voor de nieuwbouwopslag).
    public var ingebruiknameDatum: Dag?
    /// Is de bouw of verbouw tot woning gestart vóór 1 januari 2028?
    public var bouwGestartVoor2028: Bool
    /// Ingangsdatum van de (eerste) huurovereenkomst.
    public var contractStart: Dag?
    /// Huidige kale huur per maand.
    public var kaleHuur: Double?

    public init(bouwjaar: Int, woningtype: Woningtype, ruimten: [RuimteInvoer] = [], verwarmdeOpenKeukens: Int = 0,
                keukens: [KeukenInvoer] = [], sanitaireRuimten: [SanitaireRuimteInvoer] = [],
                energie: EnergieInvoer = EnergieInvoer(), kostenGehandicaptenvoorzieningen: Double = 0,
                gemeenschappelijkeBuitenruimten: [GemeenschappelijkeBuitenruimteInvoer] = [],
                gemeenschappelijkeRuimten: [GemeenschappelijkeRuimteInvoer] = [],
                parkeerruimten: [ParkeerruimteInvoer] = [], woz: WozInvoer = WozInvoer(),
                coropAmsterdamOfUtrecht: Bool = false, zorgwoning: Bool = false, videoAanbelfunctie: Bool = false,
                monument: MonumentStatus = .geen, beschermdStadsOfDorpsgezicht: Bool = false,
                ingebruiknameDatum: Dag? = nil, bouwGestartVoor2028: Bool = false,
                contractStart: Dag? = nil, kaleHuur: Double? = nil) {
        self.bouwjaar = bouwjaar; self.woningtype = woningtype; self.ruimten = ruimten
        self.verwarmdeOpenKeukens = verwarmdeOpenKeukens; self.keukens = keukens
        self.sanitaireRuimten = sanitaireRuimten; self.energie = energie
        self.kostenGehandicaptenvoorzieningen = kostenGehandicaptenvoorzieningen
        self.gemeenschappelijkeBuitenruimten = gemeenschappelijkeBuitenruimten
        self.gemeenschappelijkeRuimten = gemeenschappelijkeRuimten; self.parkeerruimten = parkeerruimten
        self.woz = woz; self.coropAmsterdamOfUtrecht = coropAmsterdamOfUtrecht; self.zorgwoning = zorgwoning
        self.videoAanbelfunctie = videoAanbelfunctie; self.monument = monument
        self.beschermdStadsOfDorpsgezicht = beschermdStadsOfDorpsgezicht
        self.ingebruiknameDatum = ingebruiknameDatum; self.bouwGestartVoor2028 = bouwGestartVoor2028
        self.contractStart = contractStart; self.kaleHuur = kaleHuur
    }

    enum CodingKeys: String, CodingKey {
        case bouwjaar, woningtype, ruimten, verwarmdeOpenKeukens, keukens, sanitaireRuimten, energie
        case kostenGehandicaptenvoorzieningen, gemeenschappelijkeBuitenruimten, gemeenschappelijkeRuimten
        case parkeerruimten, woz, coropAmsterdamOfUtrecht, zorgwoning, videoAanbelfunctie, monument
        case beschermdStadsOfDorpsgezicht, ingebruiknameDatum, bouwGestartVoor2028, contractStart, kaleHuur
    }

    /// Ontbrekende velden krijgen een lege standaardwaarde, zodat fixtures kort kunnen blijven.
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        bouwjaar = try c.decode(Int.self, forKey: .bouwjaar)
        woningtype = try c.decode(Woningtype.self, forKey: .woningtype)
        ruimten = try c.decodeIfPresent([RuimteInvoer].self, forKey: .ruimten) ?? []
        verwarmdeOpenKeukens = try c.decodeIfPresent(Int.self, forKey: .verwarmdeOpenKeukens) ?? 0
        keukens = try c.decodeIfPresent([KeukenInvoer].self, forKey: .keukens) ?? []
        sanitaireRuimten = try c.decodeIfPresent([SanitaireRuimteInvoer].self, forKey: .sanitaireRuimten) ?? []
        energie = try c.decodeIfPresent(EnergieInvoer.self, forKey: .energie) ?? EnergieInvoer()
        kostenGehandicaptenvoorzieningen = try c.decodeIfPresent(Double.self, forKey: .kostenGehandicaptenvoorzieningen) ?? 0
        gemeenschappelijkeBuitenruimten = try c.decodeIfPresent([GemeenschappelijkeBuitenruimteInvoer].self, forKey: .gemeenschappelijkeBuitenruimten) ?? []
        gemeenschappelijkeRuimten = try c.decodeIfPresent([GemeenschappelijkeRuimteInvoer].self, forKey: .gemeenschappelijkeRuimten) ?? []
        parkeerruimten = try c.decodeIfPresent([ParkeerruimteInvoer].self, forKey: .parkeerruimten) ?? []
        woz = try c.decodeIfPresent(WozInvoer.self, forKey: .woz) ?? WozInvoer()
        coropAmsterdamOfUtrecht = try c.decodeIfPresent(Bool.self, forKey: .coropAmsterdamOfUtrecht) ?? false
        zorgwoning = try c.decodeIfPresent(Bool.self, forKey: .zorgwoning) ?? false
        videoAanbelfunctie = try c.decodeIfPresent(Bool.self, forKey: .videoAanbelfunctie) ?? false
        monument = try c.decodeIfPresent(MonumentStatus.self, forKey: .monument) ?? .geen
        beschermdStadsOfDorpsgezicht = try c.decodeIfPresent(Bool.self, forKey: .beschermdStadsOfDorpsgezicht) ?? false
        ingebruiknameDatum = try c.decodeIfPresent(Dag.self, forKey: .ingebruiknameDatum)
        bouwGestartVoor2028 = try c.decodeIfPresent(Bool.self, forKey: .bouwGestartVoor2028) ?? false
        contractStart = try c.decodeIfPresent(Dag.self, forKey: .contractStart)
        kaleHuur = try c.decodeIfPresent(Double.self, forKey: .kaleHuur)
    }
}
