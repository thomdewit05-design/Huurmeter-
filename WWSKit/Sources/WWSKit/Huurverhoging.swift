import Foundation

/// Regels voor de maximale jaarlijkse huurverhoging, ingelezen uit `rules/huurverhoging-<jaar>.json`.
public struct HuurverhogingRegels: Codable, Sendable {
    public let jaar: Int
    public let bronnen: [String: Regelset.Bron]
    public let sociaal: Sociaal
    public let midden: Percentage
    public let vrij: Percentage
    public let procedure: Procedure

    public struct Sociaal: Codable, Sendable {
        public let geldigVan: Dag
        public let geldigTotEnMet: Dag
        public let inkomensgrenzen: Inkomensgrenzen
        public let laagInkomen: LaagInkomen
        public let middenInkomenMaxBedrag: Double
        public let hoogInkomenMaxBedrag: Double
        public let onzelfstandigPercentage: Double
        public let nietBovenMaximaleHuur: Bool
        public let bron: String

        public struct Inkomensgrenzen: Codable, Sendable {
            public let eenpersoons: Grenzen
            public let meerpersoons: Grenzen
        }
        public struct Grenzen: Codable, Sendable {
            public let laagTotEnMet: Double
            public let middenTotEnMet: Double
        }
        public struct LaagInkomen: Codable, Sendable {
            public let percentage: Double
            public let huurOnder: Double
            public let bedragBijLageHuur: Double
        }
    }

    public struct Percentage: Codable, Sendable {
        public let geldigVan: Dag?
        public let geldigTotEnMet: Dag?
        public let percentage: Double?
        public let geverifieerd: Bool
        public let bron: String
    }

    public struct Procedure: Codable, Sendable {
        public let voorstelMinimaalMaandenVooraf: Int
        public let maximaalEenmaalPerMaanden: Int
        public let bron: String
    }

    public static func laad(jaar: Int) throws -> HuurverhogingRegels {
        guard let url = Bundle.module.url(forResource: "huurverhoging-\(jaar)", withExtension: "json", subdirectory: "rules") else {
            throw WWSFout.geenRegelset("geen regels voor huurverhoging in \(jaar)")
        }
        return try JSONDecoder().decode(HuurverhogingRegels.self, from: Data(contentsOf: url))
    }
}

public enum HuurSegmentContract: String, Codable, CaseIterable, Sendable {
    case sociaal, midden, vrij
}

public enum Huishouden: String, Codable, CaseIterable, Sendable {
    case eenpersoons, meerpersoons
}

/// Inkomensgroep zoals de huurder die opgeeft (gezamenlijk huishoudinkomen, peiljaar van de verhuurder).
public enum Inkomensgroep: String, Codable, CaseIterable, Sendable {
    case laag, midden, hoog, onbekend
}

public struct HuurverhogingInvoer: Codable, Sendable {
    public var segment: HuurSegmentContract
    public var zelfstandig: Bool
    public var huidigeHuur: Double
    public var voorgesteldeHuur: Double
    public var ingangsdatum: Dag
    /// Datum waarop de huurder het voorstel ontving (schriftelijk).
    public var voorstelOntvangen: Dag?
    /// Ingangsdatum van de vorige huurverhoging (of van het contract als er nog geen was).
    public var vorigeVerhoging: Dag?
    public var huishouden: Huishouden
    public var inkomen: Inkomensgroep
    /// Maximale kale huur volgens het WWS (uit de puntentelling), voor sociale huur.
    public var maximaleHuur: Double?

    public init(segment: HuurSegmentContract, zelfstandig: Bool = true, huidigeHuur: Double, voorgesteldeHuur: Double,
                ingangsdatum: Dag, voorstelOntvangen: Dag? = nil, vorigeVerhoging: Dag? = nil,
                huishouden: Huishouden = .eenpersoons, inkomen: Inkomensgroep = .onbekend, maximaleHuur: Double? = nil) {
        self.segment = segment; self.zelfstandig = zelfstandig; self.huidigeHuur = huidigeHuur
        self.voorgesteldeHuur = voorgesteldeHuur; self.ingangsdatum = ingangsdatum
        self.voorstelOntvangen = voorstelOntvangen; self.vorigeVerhoging = vorigeVerhoging
        self.huishouden = huishouden; self.inkomen = inkomen; self.maximaleHuur = maximaleHuur
    }
}

public struct HuurverhogingUitkomst: Sendable, Equatable {
    public enum Oordeel: Sendable, Equatable {
        /// Binnen het wettelijke maximum.
        case toegestaan
        /// Hoger dan toegestaan; `teveel` = euro per maand boven de hoogst toegestane huur.
        case teHoog(teveel: Double)
        /// Het maximum is niet vast te stellen (reden in `stappen`).
        case nietTeBepalen
    }

    public let oordeel: Oordeel
    /// Hoogst toegestane nieuwe huur per maand (nil als niet te bepalen).
    public let hoogsteHuur: Double?
    public let verhogingBedrag: Double
    public let verhogingPercentage: Double
    public let stappen: [String]
    /// Vormfouten in het voorstel of de timing (los van de hoogte).
    public let aandachtspunten: [String]
}

public enum Huurverhoging {
    public static func beoordeel(_ i: HuurverhogingInvoer, regels r: HuurverhogingRegels) -> HuurverhogingUitkomst {
        var stappen: [String] = []
        var aandacht: [String] = []
        let verhoging = Afronding.centen(i.voorgesteldeHuur - i.huidigeHuur)
        let pct = i.huidigeHuur > 0 ? verhoging / i.huidigeHuur : 0
        stappen.append("Voorgestelde verhoging: \(NL.euro(verhoging)) per maand (\(Getalnotatie.nl(pct * 100, decimalen: 1))%).")

        // Procedure (BW 7:252 lid 1 en 7:250)
        let p = r.procedure
        if let ontvangen = i.voorstelOntvangen, ontvangen > i.ingangsdatum.plusMaanden(-p.voorstelMinimaalMaandenVooraf) {
            aandacht.append("Het voorstel kwam later dan \(p.voorstelMinimaalMaandenVooraf) maanden vóór de ingangsdatum (\(i.ingangsdatum.plusMaanden(-p.voorstelMinimaalMaandenVooraf))). Dat mag niet (art. 7:252 lid 1 BW).")
        }
        if let vorige = i.vorigeVerhoging, i.ingangsdatum < vorige.plusMaanden(p.maximaalEenmaalPerMaanden) {
            aandacht.append("De vorige verhoging ging in op \(vorige). Een nieuwe verhoging mag pas \(p.maximaalEenmaalPerMaanden) maanden later, op of na \(vorige.plusMaanden(p.maximaalEenmaalPerMaanden)) (art. 7:250 BW).")
        }

        var hoogste: Double?
        switch i.segment {
        case .sociaal:
            let s = r.sociaal
            if i.ingangsdatum < s.geldigVan || i.ingangsdatum > s.geldigTotEnMet {
                stappen.append("Het schema in de app geldt voor verhogingen van \(s.geldigVan) t/m \(s.geldigTotEnMet).")
                break
            }
            if !i.zelfstandig {
                hoogste = Afronding.centen(i.huidigeHuur * (1 + s.onzelfstandigPercentage))
                stappen.append("Kamer (onzelfstandig): maximaal \(Getalnotatie.nl(s.onzelfstandigPercentage * 100, decimalen: 1))%.")
            } else {
                let g = i.huishouden == .eenpersoons ? s.inkomensgrenzen.eenpersoons : s.inkomensgrenzen.meerpersoons
                let laag = i.huidigeHuur < s.laagInkomen.huurOnder
                    ? i.huidigeHuur + s.laagInkomen.bedragBijLageHuur
                    : Afronding.centen(i.huidigeHuur * (1 + s.laagInkomen.percentage))
                let laagTekst = i.huidigeHuur < s.laagInkomen.huurOnder
                    ? "huur onder \(NL.euro(s.laagInkomen.huurOnder)): maximaal \(NL.euro(s.laagInkomen.bedragBijLageHuur))"
                    : "maximaal \(Getalnotatie.nl(s.laagInkomen.percentage * 100, decimalen: 1))%"
                switch i.inkomen {
                case .laag:
                    hoogste = laag
                    stappen.append("Inkomen tot \(NL.euro(g.laagTotEnMet)): \(laagTekst).")
                case .midden:
                    hoogste = i.huidigeHuur + s.middenInkomenMaxBedrag
                    stappen.append("Inkomen \(NL.euro(g.laagTotEnMet)) tot \(NL.euro(g.middenTotEnMet)): maximaal \(NL.euro(s.middenInkomenMaxBedrag)) per maand.")
                case .hoog:
                    hoogste = i.huidigeHuur + s.hoogInkomenMaxBedrag
                    stappen.append("Inkomen boven \(NL.euro(g.middenTotEnMet)): maximaal \(NL.euro(s.hoogInkomenMaxBedrag)) per maand.")
                case .onbekend:
                    // Zonder inkomensverklaring geldt de inkomensonafhankelijke verhoging.
                    hoogste = laag
                    stappen.append("Inkomen niet opgegeven: de verhoging die voor iedereen geldt, \(laagTekst). Een hogere verhoging mag alleen met een inkomensverklaring van de Belastingdienst.")
                }
            }
            if s.nietBovenMaximaleHuur, let maxHuur = i.maximaleHuur, let h = hoogste, h > maxHuur {
                hoogste = Swift.max(i.huidigeHuur, maxHuur)
                stappen.append("Niet hoger dan de maximale huur volgens de puntentelling: \(NL.euro(maxHuur)).")
            }
        case .midden, .vrij:
            let regel = i.segment == .midden ? r.midden : r.vrij
            let naam = i.segment == .midden ? "middenhuur" : "vrije sector"
            if let pctMax = regel.percentage, regel.geverifieerd {
                if let van = regel.geldigVan, let tot = regel.geldigTotEnMet, i.ingangsdatum < van || i.ingangsdatum > tot {
                    stappen.append("Het percentage in de app geldt voor verhogingen van \(van) t/m \(tot).")
                } else {
                    hoogste = Afronding.centen(i.huidigeHuur * (1 + pctMax))
                    stappen.append("\(naam.prefix(1).uppercased() + naam.dropFirst()): maximaal \(Getalnotatie.nl(pctMax * 100, decimalen: 1))%.")
                }
            } else {
                stappen.append("Voor \(naam) is het maximale percentage van \(r.jaar) nog niet in de app opgenomen.")
            }
        }

        let oordeel: HuurverhogingUitkomst.Oordeel
        if let h = hoogste {
            let teveel = Afronding.centen(i.voorgesteldeHuur - h)
            oordeel = teveel > 0 ? .teHoog(teveel: teveel) : .toegestaan
            stappen.append("Hoogst toegestane nieuwe huur: \(NL.euro(h)) per maand.")
        } else {
            oordeel = .nietTeBepalen
        }
        return HuurverhogingUitkomst(oordeel: oordeel, hoogsteHuur: hoogste, verhogingBedrag: verhoging,
                                     verhogingPercentage: pct, stappen: stappen, aandachtspunten: aandacht)
    }
}
