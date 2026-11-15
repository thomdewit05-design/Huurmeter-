import Foundation

// Functie 11: puntentelling voor onzelfstandige woonruimte (kamers),
// Bijlage I onder B van het Besluit huurprijzen woonruimte.

/// Iets dat met andere kamers wordt gedeeld: punten worden gedeeld door het aantal kamers met toegang en gebruiksrecht.
public struct Gedeeld: Codable, Sendable, Hashable {
    public var waarde: Double
    /// Aantal onzelfstandige woonruimten met toegang en gebruiksrecht (minimaal 1).
    public var kamers: Int
    /// Aantal adressen dat de ruimte deelt (rubrieken 8, 9 en 10); 1 = alleen dit adres.
    public var adressen: Int

    public init(_ waarde: Double, kamers: Int, adressen: Int = 1) {
        self.waarde = waarde; self.kamers = kamers; self.adressen = adressen
    }

    var deler: Double { Double(max(1, kamers) * max(1, adressen)) }
}

public struct KamerKeuken: Codable, Sendable, Hashable {
    public var aanrechtLengte: Double
    /// Sleutels uit `r5.voorzieningen` met aantallen (meestal 1; kastruimte per 60 cm).
    public var voorzieningen: [String: Int]
    /// Aantal kamers met toegang en gebruiksrecht tot deze keuken (op dit adres).
    public var kamers: Int
    /// Meer dan 1: de keuken ligt in een binnenruimte die met andere adressen wordt gedeeld (telt in rubriek 9).
    public var adressen: Int
    public init(aanrechtLengte: Double, voorzieningen: [String: Int] = [:], kamers: Int, adressen: Int = 1) {
        self.aanrechtLengte = aanrechtLengte; self.voorzieningen = voorzieningen; self.kamers = kamers; self.adressen = adressen
    }
    var deler: Double { Double(max(1, kamers) * max(1, adressen)) }
}

/// Een sanitaire ruimte (badkamer of toilet) met haar voorzieningen.
public struct KamerSanitair: Codable, Sendable, Hashable {
    public enum Toilet: String, Codable, Sendable { case geen, staand, zwevend }
    public var toilet: Toilet
    public var wastafels: Int
    public var meerpersoonswastafels: Int
    public var douches: Int
    public var baden: Int
    public var badDouches: Int
    /// Sleutels uit `r6.extra` met aantallen.
    public var extra: [String: Int]
    public var kamers: Int
    /// Meer dan 1: gedeeld met andere adressen (telt in rubriek 9).
    public var adressen: Int

    public init(toilet: Toilet = .geen, wastafels: Int = 0, meerpersoonswastafels: Int = 0, douches: Int = 0,
                baden: Int = 0, badDouches: Int = 0, extra: [String: Int] = [:], kamers: Int, adressen: Int = 1) {
        self.toilet = toilet; self.wastafels = wastafels; self.meerpersoonswastafels = meerpersoonswastafels
        self.douches = douches; self.baden = baden; self.badDouches = badDouches; self.extra = extra
        self.kamers = kamers; self.adressen = adressen
    }
    var deler: Double { Double(max(1, kamers) * max(1, adressen)) }

    /// Een ruimte met douche of bad is een badkamer.
    public var isBadkamer: Bool { douches + baden + badDouches > 0 }
}

public enum KamerMonument: String, Codable, CaseIterable, Sendable {
    case geen, rijksmonumentContractVoorWbh, rijksmonumentContractNaWbh, gemeentelijkOfProvinciaal
}

public enum Parkeertype: String, Codable, CaseIterable, Sendable { case typeI, typeII, typeIII }

public struct KamerInvoer: Codable, Sendable {
    // Rubriek 1 en 2 (m²)
    public var priveVertrekken: Double = 0
    public var gemeenschappelijkeVertrekken: [Gedeeld] = []
    public var priveOverigeRuimten: Double = 0
    public var gemeenschappelijkeOverigeRuimten: [Gedeeld] = []
    // Rubriek 3 (aantallen verwarmde ruimten; waarde = aantal)
    public var verwarmdePriveVertrekken: Int = 0
    public var verwarmdeGemeenschappelijkeVertrekken: [Gedeeld] = []
    public var verwarmdePriveOverigeRuimten: Int = 0
    public var verwarmdeGemeenschappelijkeOverigeRuimten: [Gedeeld] = []
    public var gekoeldePriveVertrekken: Int = 0
    /// Waarde = aantal gekoelde gemeenschappelijke vertrekken met dezelfde groep kamers.
    public var gekoeldeGemeenschappelijkeVertrekken: [Gedeeld] = []
    // Rubriek 4 (energieprestatie van het hele adres)
    public var label: Energielabel?
    public var energieIndex: Double?
    public var labelOpnamedatum: Dag?
    public var bouwjaar: Int = 2000
    // Rubriek 5 en 6
    public var keukens: [KamerKeuken] = []
    public var sanitair: [KamerSanitair] = []
    // Rubriek 7 (waarde = kosten in euro, kamers = aantal gehandicapten met gebruiksrecht)
    public var gehandicaptenvoorzieningen: Gedeeld?
    // Rubriek 8 (m²)
    public var priveBuitenruimte: Double = 0
    public var gemeenschappelijkeBuitenruimten: [Gedeeld] = []
    // Rubriek 9 (m², met adressen > 1)
    public var binnenruimtenMeerdereAdressen: [Gedeeld] = []
    public var overigeRuimtenMeerdereAdressen: [Gedeeld] = []
    // Rubriek 10
    public var parkeerplaatsen: [Parkeertype: Gedeeld] = [:]
    // Rubriek 11 (gegevens van het hele adres)
    public var wozWaarde: Double?
    /// 85% hiervan telt als er geen WOZ-waarde is vastgesteld.
    public var taxatiewaarde: Double?
    public var wozPeildatum: Dag?
    public var gebruiksoppervlakteAdres: Double?
    public var coropGebied: String?
    // Rubriek 12
    public var zorgwoning: Bool = false
    public var videoIntercom: Bool = false
    public var laadpaalAdressen: Int?
    // Rubriek 13
    public var alleenViaVertrekVerhuurder: Bool = false
    public var ruitKleinerDan075: Bool = false
    public var kozijnHogerDan160: Bool = false
    // Prijs
    public var monument: KamerMonument = .geen

    public init() {}
}

public struct KamerRegels: Codable, Sendable {
    public let regelsetJaar: Int
    public let bronnen: [String: Regelset.Bron]
    public let r1: PerM2
    public let r2: PerM2
    public let r3: R3
    public let r4: R4
    public let r5: R5
    public let r6: R6
    public let r7: R7
    public let r8: R8
    public let r9: R9
    public let r10: R10
    public let r11: R11
    public let r12: R12
    public let r13: R13
    public let prijsopslagen: Opslagen
    public let corop: Corop
    public let maximaleHuurprijs: Huurtabel

    public struct PerM2: Codable, Sendable { public let privePerM2: Double; public let gemeenschappelijkPerM2: Double; public let bron: String }
    public struct R3: Codable, Sendable {
        public let vertrek: Double, overigeOfVerkeersruimte: Double, verkoelingPerVertrek: Double
        public let verkoelingMaxPrive: Double, verkoelingMaxGemeenschappelijk: Double, bron: String
    }
    public struct R4: Codable, Sendable {
        public struct Klasse: Codable, Sendable {
            public let klasse: String
            public let eiKleinerDan: Double?, eiGroterDan: Double?, eiTotEnMet: Double?
            public let bouwjaarVanaf: Int?, bouwjaarTotEnMet: Int?
            public let puntenPerM2: Double
            func bevat(ei: Double) -> Bool {
                guard eiKleinerDan != nil || eiGroterDan != nil || eiTotEnMet != nil else { return false }
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
        public let labelGeldigheidJaren: Int
        public let monumentGeenMinpunten: Bool
        public let klassen: [Klasse]
        public let bron: String
    }
    public struct R5: Codable, Sendable {
        public struct Trede: Codable, Sendable { public let vanafMeter: Double; public let punten: Double; public let alleenVanafKamers: Int? }
        public let aanrecht: [Trede]
        public let voorzieningen: [String: Double]
        public let voorzieningenMaxIsAanrechtpunten: Bool
        public let bron: String
    }
    public struct R6: Codable, Sendable {
        public let toiletApart: Double, toiletInBadkamer: Double, zwevendToiletApart: Double, zwevendToiletInBadkamer: Double
        public let wastafel: Double, wastafelMaxPerRuimte: Double, meerpersoonswastafel: Double, meerpersoonswastafelMaxPerRuimte: Double
        public let douche: Double, bad: Double, badDouche: Double
        public let extra: [String: Double]
        public let extraMaxIsBadDouchePunten: Bool
        public let bron: String
    }
    public struct R7: Codable, Sendable { public let eurosPerPunt: Double; public let bron: String }
    public struct R8: Codable, Sendable { public let priveBasis: Double, privePerM2: Double, gemeenschappelijkPerM2: Double, maximum: Double; public let bron: String }
    public struct R9: Codable, Sendable { public let vertrekPerM2: Double, overigePerM2: Double; public let bron: String }
    public struct R10: Codable, Sendable { public let typeI: Double, typeII: Double, typeIII: Double; public let bron: String }
    public struct R11: Codable, Sendable { public let hoger: Double, gelijk: Double, lager: Double, marge: Double, taxatieFactorZonderWoz: Double; public let bron: String }
    public struct R12: Codable, Sendable { public let zorgwoningPercentage: Double, videoIntercom: Double, laadpaal: Double; public let bron: String }
    public struct R13: Codable, Sendable {
        public let kleinerDan8m2: Double, viaVertrekVerhuurder: Double, ruitKleinerDan075: Double, kozijnHogerDan160: Double
        public let bron: String
    }
    public struct Opslagen: Codable, Sendable {
        public let rijksmonumentContractNaWbh: Double
        public let rijksmonumentContractVoorWbhExtraPunten: Double
        public let gemeentelijkOfProvinciaalMonument: Double
        public let bron: String
    }
    public struct Corop: Codable, Sendable {
        public let bron: String
        /// Peildatum (ISO) → COROP-gebied → gemiddelde WOZ-waarde per m².
        public let perPeildatum: [String: [String: Double]]
        public var gebieden: [String] { (perPeildatum.values.first?.keys).map { $0.sorted() } ?? [] }
    }
    public struct Huurtabel: Codable, Sendable {
        public let bron: String
        public let boven250PerPunt: Double
        public let bij250: Double
        public let tabel: [String: Double]
        public func bedrag(bijPunten p: Int) -> Double? {
            if p > 250 { return Afronding.centen(bij250 + boven250PerPunt * Double(p - 250)) }
            return tabel[String(p)]
        }
    }

    public static func laad(jaar: Int = 2026) throws -> KamerRegels {
        guard let url = Bundle.module.url(forResource: "wws-onzelfstandig-\(jaar)", withExtension: "json", subdirectory: "rules") else {
            throw WWSFout.geenRegelset("geen puntentelling voor kamers in \(jaar)")
        }
        return try JSONDecoder().decode(KamerRegels.self, from: Data(contentsOf: url))
    }
}

public struct KamerUitkomst: Sendable {
    public let rubrieken: [RubriekUitkomst]
    public let toegerekendeVertrekM2: Double
    public let totaal: Int
    public let maximaleHuur: Double?
    public let waarschuwingen: [String]
}

public enum Kamerberekening {
    public static func bereken(_ k: KamerInvoer, regels r: KamerRegels, peildatum: Dag) throws -> KamerUitkomst {
        var rubrieken: [RubriekUitkomst] = []
        var waarschuwingen: [String] = []
        func rubriek(_ nr: String, _ titel: String, _ ruw: Double, _ stappen: [String], _ bron: String) {
            rubrieken.append(RubriekUitkomst(nummer: nr, titel: titel, punten: Afronding.rubriek(ruw), stappen: stappen, bron: bron))
        }
        func gedeeld(_ lijst: [Gedeeld], factor: Double) -> Double { lijst.reduce(0) { $0 + $1.waarde * factor / $1.deler } }

        // 1. Oppervlakte van vertrekken: privé + gedeelde m², op hele m² afgerond (toelichting A, van overeenkomstige toepassing).
        let m2Vertrek = Afronding.heel(Afronding.tweeDecimalen(k.priveVertrekken) + gedeeld(k.gemeenschappelijkeVertrekken, factor: 1))
        rubriek("1", "Oppervlakte van vertrekken", m2Vertrek * r.r1.privePerM2,
                ["Toegerekend: \(NL.m2(m2Vertrek, decimalen: 0)) (privé plus uw deel van gedeelde vertrekken)."], r.r1.bron)

        // 2. Overige ruimten
        let m2Overig = Afronding.heel(Afronding.tweeDecimalen(k.priveOverigeRuimten) + gedeeld(k.gemeenschappelijkeOverigeRuimten, factor: 1))
        rubriek("2", "Oppervlakte van overige ruimten", m2Overig * r.r2.privePerM2,
                ["Toegerekend: \(NL.m2(m2Overig, decimalen: 0)) × \(NL.getal(r.r2.privePerM2))."], r.r2.bron)

        // 3. Verwarming en verkoeling
        // Ruimten die met meerdere adressen worden gedeeld, tellen in rubriek 9 (toelichting rubriek 9).
        var naar9 = 0.0
        let vGem = k.verwarmdeGemeenschappelijkeVertrekken, oGem = k.verwarmdeGemeenschappelijkeOverigeRuimten
        var p3 = Double(k.verwarmdePriveVertrekken) * r.r3.vertrek
        p3 += gedeeld(vGem.filter { $0.adressen <= 1 }, factor: r.r3.vertrek)
        naar9 += gedeeld(vGem.filter { $0.adressen > 1 }, factor: r.r3.vertrek)
        p3 += Double(k.verwarmdePriveOverigeRuimten) * r.r3.overigeOfVerkeersruimte
        p3 += gedeeld(oGem.filter { $0.adressen <= 1 }, factor: r.r3.overigeOfVerkeersruimte)
        naar9 += gedeeld(oGem.filter { $0.adressen > 1 }, factor: r.r3.overigeOfVerkeersruimte)
        p3 += min(Double(k.gekoeldePriveVertrekken) * r.r3.verkoelingPerVertrek, r.r3.verkoelingMaxPrive)
        // Maximaal 2 punten voor gekoelde gemeenschappelijke vertrekken, daarna gedeeld.
        var koelGem = 0.0, koelAantal = 0.0
        for g in k.gekoeldeGemeenschappelijkeVertrekken {
            let ruimte = max(0, r.r3.verkoelingMaxGemeenschappelijk - koelAantal)
            let telt = min(g.waarde * r.r3.verkoelingPerVertrek, ruimte)
            koelAantal += telt
            koelGem += telt / g.deler
        }
        p3 += koelGem
        rubriek("3", "Verwarming en verkoeling", p3, [], r.r3.bron)

        // 4. Energieprestatie van het adres × toegerekende m² uit rubriek 1
        var stappen4: [String] = []
        var geldig = false
        if k.label != nil || k.energieIndex != nil {
            if let o = k.labelOpnamedatum {
                geldig = peildatum < o.plusJaren(r.r4.labelGeldigheidJaren)
                if !geldig { stappen4.append("Het label is verlopen; het bouwjaar telt."); waarschuwingen.append("Het energielabel is verlopen; de punten zijn bepaald op basis van het bouwjaar.") }
            } else {
                waarschuwingen.append("Vul de opnamedatum van het energielabel in; zonder datum telt het bouwjaar.")
            }
        }
        var klasse: KamerRegels.R4.Klasse?
        if geldig, let l = k.label { klasse = r.r4.klassen.first { $0.klasse == l.rawValue } }
        else if geldig, let ei = k.energieIndex {
            let p = r.r4.klassen.filter { $0.bevat(ei: ei) }
            guard p.count == 1 else { throw WWSFout.nietEenduidig("Energie-Index \(NL.getal(ei)) valt niet in precies één klasse van rubriek 4.1") }
            klasse = p[0]
        }
        if klasse == nil {
            let p = r.r4.klassen.filter { $0.bevat(bouwjaar: k.bouwjaar) }
            guard p.count == 1 else { throw WWSFout.nietEenduidig("bouwjaar \(k.bouwjaar) valt niet in precies één klasse van rubriek 4.1") }
            klasse = p[0]
        }
        var perM2 = klasse!.puntenPerM2
        if r.r4.monumentGeenMinpunten && k.monument != .geen && perM2 < 0 { perM2 = 0 }
        stappen4.append("Klasse \(klasse!.klasse): \(NL.getal(perM2)) punt per m² × \(NL.m2(m2Vertrek, decimalen: 0)).")
        rubriek("4", "Energieprestatie", perM2 * m2Vertrek, stappen4, r.r4.bron)

        // 5. Keuken
        var p5 = 0.0
        for keuken in k.keukens {
            let tredes = r.r5.aanrecht.filter { keuken.aanrechtLengte + Afronding.marge >= $0.vanafMeter && keuken.kamers >= ($0.alleenVanafKamers ?? 0) }
            let pA = tredes.map(\.punten).max() ?? 0
            var pV = keuken.voorzieningen.reduce(0.0) { $0 + (r.r5.voorzieningen[$1.key] ?? 0) * Double($1.value) }
            if r.r5.voorzieningenMaxIsAanrechtpunten { pV = min(pV, pA) }
            if keuken.adressen > 1 { naar9 += (pA + pV) / keuken.deler } else { p5 += (pA + pV) / keuken.deler }
        }
        rubriek("5", "Keuken", p5, [], r.r5.bron)

        // 6. Sanitair
        var p6 = 0.0
        for s in k.sanitair {
            let bad = s.isBadkamer
            var p = 0.0
            switch s.toilet {
            case .geen: break
            case .staand: p += bad ? r.r6.toiletInBadkamer : r.r6.toiletApart
            case .zwevend: p += bad ? r.r6.zwevendToiletInBadkamer : r.r6.zwevendToiletApart
            }
            let wastafel = Double(s.wastafels) * r.r6.wastafel
            let meer = Double(s.meerpersoonswastafels) * r.r6.meerpersoonswastafel
            p += bad ? wastafel : min(wastafel, r.r6.wastafelMaxPerRuimte)
            p += bad ? meer : min(meer, r.r6.meerpersoonswastafelMaxPerRuimte)
            let badPunten = Double(s.douches) * r.r6.douche + Double(s.baden) * r.r6.bad + Double(s.badDouches) * r.r6.badDouche
            p += badPunten
            var extra = 0.0
            for (sleutel, aantal) in s.extra {
                var e = (r.r6.extra[sleutel] ?? 0) * Double(aantal)
                if sleutel == "kastruimte" { e = min(e, r.r6.extra["kastruimteMax"] ?? e) }
                if sleutel == "stopcontact" { e = min(e, (r.r6.extra["stopcontactMaxPerWastafel"] ?? e) * Double(s.wastafels + s.meerpersoonswastafels)) }
                extra += e
            }
            if r.r6.extraMaxIsBadDouchePunten { extra = min(extra, badPunten) }
            if s.adressen > 1 { naar9 += (p + extra) / s.deler } else { p6 += (p + extra) / s.deler }
        }
        rubriek("6", "Sanitair", p6, [], r.r6.bron)

        // 7. Gehandicaptenvoorzieningen
        let p7 = k.gehandicaptenvoorzieningen.map { $0.waarde / r.r7.eurosPerPunt / Double(max(1, $0.kamers)) } ?? 0
        rubriek("7", "Woonvoorzieningen voor gehandicapten", p7, [], r.r7.bron)

        // 8. Buitenruimten (maximaal 15)
        var p8 = k.priveBuitenruimte > 0 ? r.r8.priveBasis + r.r8.privePerM2 * k.priveBuitenruimte : 0
        p8 += gedeeld(k.gemeenschappelijkeBuitenruimten, factor: r.r8.gemeenschappelijkPerM2)
        rubriek("8", "Buitenruimten", min(p8, r.r8.maximum), p8 > r.r8.maximum ? ["Maximaal \(NL.getal(r.r8.maximum)) punten."] : [], r.r8.bron)

        // 9. Gemeenschappelijke binnenruimten gedeeld met meerdere adressen
        let p9 = gedeeld(k.binnenruimtenMeerdereAdressen, factor: r.r9.vertrekPerM2)
            + gedeeld(k.overigeRuimtenMeerdereAdressen, factor: r.r9.overigePerM2) + naar9
        rubriek("9", "Gemeenschappelijke binnenruimten (meerdere adressen)", p9, [], r.r9.bron)

        // 10. Parkeren
        var p10 = 0.0
        for (type, g) in k.parkeerplaatsen {
            let punten: Double = type == .typeI ? r.r10.typeI : type == .typeII ? r.r10.typeII : r.r10.typeIII
            p10 += g.waarde * punten / g.deler
        }
        rubriek("10", "Gemeenschappelijke parkeerruimte", p10, [], r.r10.bron)

        // 11. WOZ-waarde van het adres per m² tegenover het COROP-gemiddelde
        var p11 = 0.0
        var stappen11: [String] = []
        let waarde = k.wozWaarde ?? k.taxatiewaarde.map { $0 * r.r11.taxatieFactorZonderWoz }
        if let waarde, let opp = k.gebruiksoppervlakteAdres, opp > 0, let gebied = k.coropGebied, let peil = k.wozPeildatum {
            guard let gem = r.corop.perPeildatum[peil.iso]?[gebied] else {
                throw WWSFout.nietEenduidig("geen COROP-gemiddelde voor \(gebied) met peildatum \(peil)")
            }
            let perM2 = waarde / opp
            if perM2 > gem * (1 + r.r11.marge) + Afronding.marge { p11 = r.r11.hoger }
            else if perM2 < gem * (1 - r.r11.marge) - Afronding.marge { p11 = r.r11.lager }
            else { p11 = r.r11.gelijk }
            stappen11.append("\(NL.euro(Afronding.centen(perM2))) per m² tegenover gemiddeld \(NL.euro(gem)) in \(gebied).")
        } else {
            waarschuwingen.append("Vul WOZ-waarde, gebruiksoppervlakte en COROP-gebied van het adres in; zonder deze gegevens krijgt rubriek 11 nog geen punten.")
        }
        rubriek("11", "WOZ-waarde", p11, stappen11, r.r11.bron)

        // 12. Bijzondere voorzieningen
        let som1tot11 = rubrieken.reduce(0) { $0 + $1.punten }
        var p12 = k.zorgwoning ? som1tot11 * r.r12.zorgwoningPercentage : 0
        if k.videoIntercom { p12 += r.r12.videoIntercom }
        if let a = k.laadpaalAdressen { p12 += r.r12.laadpaal / Double(max(1, a)) }
        rubriek("12", "Bijzondere voorzieningen", p12, [], r.r12.bron)

        // 13. Aftrekpunten
        var p13 = 0.0
        if m2Vertrek < 8 { p13 += r.r13.kleinerDan8m2 }
        if k.alleenViaVertrekVerhuurder { p13 += r.r13.viaVertrekVerhuurder }
        if k.ruitKleinerDan075 { p13 += r.r13.ruitKleinerDan075 }
        if k.kozijnHogerDan160 { p13 += r.r13.kozijnHogerDan160 }
        rubriek("13", "Aftrekpunten", p13, [], r.r13.bron)

        var totaal = rubrieken.reduce(0) { $0 + $1.punten }
        if k.monument == .rijksmonumentContractVoorWbh { totaal += r.prijsopslagen.rijksmonumentContractVoorWbhExtraPunten }
        let punten = Int(Afronding.heel(totaal))
        var huur = punten >= 1 ? r.maximaleHuurprijs.bedrag(bijPunten: punten) : nil
        if let h = huur {
            switch k.monument {
            case .rijksmonumentContractNaWbh: huur = Afronding.centen(h * (1 + r.prijsopslagen.rijksmonumentContractNaWbh))
            case .gemeentelijkOfProvinciaal: huur = Afronding.centen(h * (1 + r.prijsopslagen.gemeentelijkOfProvinciaalMonument))
            default: break
            }
        } else {
            waarschuwingen.append("Bij minder dan 1 punt geeft de huurprijstabel geen bedrag.")
        }
        return KamerUitkomst(rubrieken: rubrieken, toegerekendeVertrekM2: m2Vertrek, totaal: punten, maximaleHuur: huur, waarschuwingen: waarschuwingen)
    }
}
