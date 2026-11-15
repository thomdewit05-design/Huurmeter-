import Foundation

/// Rekent een woning door volgens Bijlage I onder A van het Besluit huurprijzen woonruimte.
/// Alle getallen komen uit de `Regelset`; deze code bevat alleen de rekenstappen.
public struct Rekenmachine: Sendable {
    public let regels: Regelset

    public init(regels: Regelset) { self.regels = regels }

    /// Laadt de regelset die op de peildatum geldt.
    public init(peildatum: Dag) throws {
        self.regels = try RegelsetBibliotheek.regelset(op: peildatum)
    }

    // MARK: - Hoofdberekening

    public func bereken(_ w: WoningInvoer, peildatum: Dag) throws -> Uitkomst {
        guard regels.geldigVan <= peildatum && peildatum <= regels.geldigTotEnMet else {
            throw WWSFout.geenRegelset("regelset \(regels.regelsetJaar) geldt niet op \(peildatum)")
        }
        try valideer(w)
        var waarschuwingen: [String] = []
        let r = regels.rubrieken

        let r1 = rubriek1(w)
        let r2 = rubriek2(w)
        let r3 = rubriek3(w, waarschuwingen: &waarschuwingen)
        let r4 = try rubriek4(w, peildatum: peildatum, waarschuwingen: &waarschuwingen)
        let r5 = try rubriek5(w.keukens)
        let r6 = try rubriek6(w.sanitaireRuimten)
        let r7 = rubriek7(w)
        let r8 = rubriek8(w)
        let r9 = try rubriek9(w)
        let r10 = rubriek10(w)
        var woz = try rubriek11Basis(w)
        let som1tot10 = [r1, r2, r3, r4, r5, r6, r7, r8, r9, r10].map(\.punten).reduce(0, +)
        let r12 = rubriek12(w, som1tot11_1: som1tot10 + woz.punten)

        // 11.2 Uitzonderingsregel
        let u = r.r11.uitzondering
        if u.bouwjaren.contains(w.bouwjaar) {
            let basis = som1tot10 + r12.punten
            if basis >= u.drempelTotaal && woz.punten < u.minimumWozPunten {
                woz.stappen.append("11.2: bouwjaar \(w.bouwjaar) en \(NL.punten(basis)) voor de rubrieken 1 t/m 10 en 12 (≥ \(NL.getal(u.drempelTotaal))): minimaal \(NL.punten(u.minimumWozPunten)).")
                woz.punten = u.minimumWozPunten
            } else {
                woz.stappen.append("11.2 (minimaal \(NL.punten(u.minimumWozPunten)) bij bouwjaar 2015 t/m 2019 en ≥ \(NL.getal(u.drempelTotaal)) punten) is niet van toepassing of verhoogt niets.")
            }
        }

        // 11.3 Cap op de WOZ
        let overig = som1tot10 + r12.punten
        var totaal = Afronding.heel(overig + woz.punten)
        let cap = r.r11.cap
        if woz.kleineWoning {
            woz.stappen.append("11.3: de cap op de WOZ geldt niet voor woningen als bedoeld in 11.1 onder a.")
        } else if totaal < cap.geldtVanafTotaal {
            woz.stappen.append("11.3: totaal zonder cap is \(NL.getal(totaal)) punten (< \(NL.getal(cap.geldtVanafTotaal))), de cap op de WOZ geldt niet.")
        } else {
            let maxWoz = overig * cap.maximumAandeel / (1 - cap.maximumAandeel)
            if woz.punten > maxWoz {
                let begrensd = Afronding.omlaag(maxWoz)
                woz.stappen.append("11.3: WOZ-punten mogen maximaal \(NL.getal(cap.maximumAandeel * 100))% van het totaal zijn: \(NL.getal(overig)) × \(NL.getal(cap.maximumAandeel)) / \(NL.getal(1 - cap.maximumAandeel)) = \(NL.getal(maxWoz)), naar beneden afgerond \(NL.punten(begrensd)).")
                woz.punten = begrensd
                totaal = Afronding.heel(overig + woz.punten)
                if totaal < cap.geldtVanafTotaal {
                    woz.stappen.append("11.3: door de cap komt het totaal op \(NL.getal(totaal)), lager dan \(NL.getal(cap.geldtVanafTotaal)); dan geldt een waardering van \(NL.getal(cap.vangnetTotaal)) punten.")
                    totaal = cap.vangnetTotaal
                }
            } else {
                woz.stappen.append("11.3: aandeel WOZ-punten is niet groter dan \(NL.getal(cap.maximumAandeel * 100))%, geen begrenzing.")
            }
        }
        let r11 = RubriekUitkomst(nummer: "11", titel: r.r11.titel, punten: woz.punten, stappen: woz.stappen, bron: r.r11.bron)

        let rubrieken = [r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12]
        let som = rubrieken.map(\.punten).reduce(0, +)

        // Art. 8a lid 2: rijksmonument met contract van vóór de Wet betaalbare huur: +50 punten.
        var opslagStappen: [String] = []
        let po = regels.prijsopslagen
        var extraPunten = 0.0
        if w.monument == .rijksmonument {
            guard let start = w.contractStart else {
                throw WWSFout.ongeldigeInvoer("bij een rijksmonument is de ingangsdatum van het contract nodig (art. 8a lid 1 en 2)")
            }
            if start < po.inwerkingtredingWetBetaalbareHuur {
                extraPunten = po.rijksmonumentContractVoorWbhExtraPunten
                opslagStappen.append("Rijksmonument, contract vóór inwerkingtreding Wet betaalbare huur (\(po.inwerkingtredingWetBetaalbareHuur)): waardering + \(NL.punten(extraPunten)) (art. 8a lid 2).")
            }
            if !po.inwerkingtredingWetBetaalbareHuurGeverifieerd {
                waarschuwingen.append("De datum van inwerkingtreding van de Wet betaalbare huur (\(po.inwerkingtredingWetBetaalbareHuur)) is nog niet tegen een officiële bron geverifieerd.")
            }
        }
        let totaalPunten = Int(totaal + extraPunten)

        // Segment en maximale huur
        let seg = segment(totaalPunten)
        let maxZonder: Double? = seg == .vrij ? nil : regels.maximaleHuurprijs.bedrag(bijPunten: totaalPunten)
        var opslag = 0.0
        if seg != .vrij {
            opslag = prijsopslag(w, segment: seg, peildatum: peildatum, stappen: &opslagStappen)
        }
        let maxHuur = maxZonder.map { Afronding.centen($0 * (1 + opslag)) }
        if seg == .vrij {
            opslagStappen.append("Vrije sector: er geldt geen maximale huurprijs, dus ook geen prijsopslag.")
        }

        var verschil: Double? = nil
        if let huur = w.kaleHuur, let max = maxHuur {
            verschil = Afronding.centen(huur - max)
        }

        var termijn: Termijn? = nil
        if let start = w.contractStart {
            let einde = start.plusMaanden(regels.termijnen.toetsingAanvangshuurMaanden)
            if peildatum <= einde {
                termijn = Termijn(einddatum: einde, resterendeDagen: peildatum.dagen(tot: einde))
            }
        }

        if !regels.segmenten.geverifieerd {
            waarschuwingen.append("De segmentgrenzen (\(regels.segmenten.sociaalTotEnMetPunten)/\(regels.segmenten.middenTotEnMetPunten) punten) zijn nog niet volledig tegen de officiële bron geverifieerd.")
        }
        if let start = w.contractStart, start < po.inwerkingtredingWetBetaalbareHuur {
            waarschuwingen.append("Het contract is ingegaan vóór de Wet betaalbare huur (\(po.inwerkingtredingWetBetaalbareHuur)); voor zulke contracten kunnen andere regels gelden (art. 12a Besluit huurprijzen woonruimte). Deze berekening houdt daar nog geen rekening mee.")
        }

        return Uitkomst(
            regelsetJaar: regels.regelsetJaar, peildatum: peildatum, rubrieken: rubrieken,
            somRubrieken: som, totaal: totaalPunten, segment: seg,
            maximaleHuurZonderOpslag: maxZonder, prijsopslag: opslag, prijsopslagStappen: opslagStappen,
            maximaleHuur: maxHuur, verschilPerMaand: verschil, verschilPerJaar: verschil.map { Afronding.centen($0 * 12) },
            termijnAanvangshuur: termijn, waarschuwingen: waarschuwingen)
    }

    // MARK: - Invoercontrole

    func valideer(_ w: WoningInvoer) throws {
        for x in w.ruimten where x.oppervlakte < 0 || !x.oppervlakte.isFinite {
            throw WWSFout.ongeldigeInvoer("oppervlakte van '\(x.naam)' is ongeldig")
        }
        for b in w.gemeenschappelijkeBuitenruimten where b.adressen < 1 {
            throw WWSFout.ongeldigeInvoer("aantal adressen bij '\(b.naam)' moet minstens 1 zijn")
        }
        for g in w.gemeenschappelijkeRuimten {
            if g.adressen < 1 { throw WWSFout.ongeldigeInvoer("aantal adressen bij '\(g.naam)' moet minstens 1 zijn") }
            if g.soort != .vertrek && g.soort != .overigeRuimte {
                throw WWSFout.ongeldigeInvoer("gemeenschappelijke ruimte '\(g.naam)' moet een vertrek of overige ruimte zijn")
            }
        }
        for p in w.parkeerruimten where p.adressen < 1 {
            throw WWSFout.ongeldigeInvoer("aantal adressen bij '\(p.naam)' moet minstens 1 zijn")
        }
        if w.kostenGehandicaptenvoorzieningen < 0 { throw WWSFout.ongeldigeInvoer("kosten gehandicaptenvoorzieningen < 0") }
    }

    // MARK: - Classificatie van ruimten (toelichting rubriek 1 en 2)

    enum Effectief { case vertrek, overigeRuimte, verkeersruimte, buitenruimte, teltNiet }

    func classificeer(_ x: RuimteInvoer) -> (Effectief, String?) {
        let opp = Afronding.tweeDecimalen(x.oppervlakte)
        let minV = regels.rubrieken.r1.minimumOppervlakteM2
        let minO = regels.rubrieken.r2.minimumOppervlakteM2
        switch x.soort {
        case .buitenruimte: return (.buitenruimte, nil)
        case .verkeersruimte: return (.verkeersruimte, nil)
        case .vertrek:
            if x.functie == .keuken || x.functie == .badkamer { return (.vertrek, nil) }
            if opp >= minV { return (.vertrek, nil) }
            if opp >= minO {
                return (.overigeRuimte, "\(x.naam): kleiner dan \(NL.m2(minV, decimalen: 0)), telt als overige ruimte.")
            }
            return (.teltNiet, "\(x.naam): kleiner dan \(NL.m2(minO, decimalen: 0)), telt niet mee.")
        case .overigeRuimte:
            if opp >= minO { return (.overigeRuimte, nil) }
            return (.teltNiet, "\(x.naam): kleiner dan \(NL.m2(minO, decimalen: 0)), telt niet mee.")
        }
    }

    /// Opgetelde oppervlakte (per ruimte op 2 decimalen) en de afronding op hele m².
    func oppervlakteSom(_ lijst: [RuimteInvoer], stappen: inout [String]) -> (som: Double, heel: Double) {
        var som = 0.0
        for x in lijst {
            let a = Afronding.tweeDecimalen(x.oppervlakte)
            som += a
            stappen.append("\(x.naam): \(NL.m2(a))\(x.bron == .scan ? " (gescand)" : "")")
        }
        som = Afronding.tweeDecimalen(som)
        return (som, Afronding.heel(som))
    }

    // MARK: - Rubriek 1

    func rubriek1(_ w: WoningInvoer) -> RubriekUitkomst {
        let regel = regels.rubrieken.r1
        var stappen: [String] = []
        for x in w.ruimten where x.soort == .vertrek {
            if let s = classificeer(x).1 { stappen.append(s) }
        }
        let vertrekken = w.ruimten.filter { classificeer($0).0 == .vertrek }
        let (som, heel) = oppervlakteSom(vertrekken, stappen: &stappen)
        let p = Afronding.rubriek(heel * regel.puntenPerM2)
        stappen.append("Totaal \(NL.m2(som)), afgerond \(NL.m2(heel, decimalen: 0)) × \(NL.getal(regel.puntenPerM2)) = \(NL.punten(p)).")
        return RubriekUitkomst(nummer: "1", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Rubriek 2

    func rubriek2(_ w: WoningInvoer) -> RubriekUitkomst {
        let regel = regels.rubrieken.r2
        var stappen: [String] = []
        for x in w.ruimten where x.soort == .overigeRuimte {
            if let s = classificeer(x).1 { stappen.append(s) }
        }
        let overige = w.ruimten.filter { classificeer($0).0 == .overigeRuimte }
        let (som, heel) = oppervlakteSom(overige, stappen: &stappen)
        var p = heel * regel.puntenPerM2
        stappen.append("Totaal \(NL.m2(som)), afgerond \(NL.m2(heel, decimalen: 0)) × \(NL.getal(regel.puntenPerM2)) = \(NL.punten(p)).")
        for z in overige where z.zolderZonderVasteTrap {
            let zolderPunten = Afronding.tweeDecimalen(z.oppervlakte) * regel.puntenPerM2
            let aftrek = min(regel.zolderZonderVasteTrapAftrek, zolderPunten)
            p -= aftrek
            stappen.append("\(z.naam): geen vaste trap, af \(NL.punten(aftrek)) (niet meer dan de punten voor de zolder).")
        }
        p = Afronding.rubriek(p)
        return RubriekUitkomst(nummer: "2", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Rubriek 3

    func rubriek3(_ w: WoningInvoer, waarschuwingen: inout [String]) -> RubriekUitkomst {
        let regel = regels.rubrieken.r3
        var stappen: [String] = []
        let ingedeeld = w.ruimten.map { ($0, classificeer($0).0) }
        let vertrekken = ingedeeld.filter { $0.1 == .vertrek }.map(\.0)
        let verwarmdeVertrekken = vertrekken.filter { $0.verwarmd || $0.verkoeling }.count + w.verwarmdeOpenKeukens
        let pV = Double(verwarmdeVertrekken) * regel.puntenPerVerwarmdVertrek
        stappen.append("\(verwarmdeVertrekken) verwarmde vertrekken\(w.verwarmdeOpenKeukens > 0 ? " (waarvan \(w.verwarmdeOpenKeukens) open keuken)" : "") × \(NL.getal(regel.puntenPerVerwarmdVertrek)) = \(NL.punten(pV)).")

        let overig = ingedeeld.filter { ($0.1 == .overigeRuimte || $0.1 == .verkeersruimte) && $0.0.verwarmd }.count
        let pO = min(Double(overig) * regel.puntenPerVerwarmdeOverigeOfVerkeersruimte, regel.maximumOverigeEnVerkeersruimten)
        stappen.append("\(overig) verwarmde overige ruimten en verkeersruimten × \(NL.getal(regel.puntenPerVerwarmdeOverigeOfVerkeersruimte)) = \(NL.punten(pO)) (maximaal \(NL.getal(regel.maximumOverigeEnVerkeersruimten))).")

        var pK = 0.0
        let koel = vertrekken.filter(\.verkoeling).count
        if koel > 0 {
            if w.energie.koelingInLabel {
                pK = min(Double(koel) * regel.puntenPerVertrekMetVerkoeling, regel.maximumVerkoeling)
                stappen.append("\(koel) vertrekken met verkoeling × \(NL.getal(regel.puntenPerVertrekMetVerkoeling)) = \(NL.punten(pK)) (maximaal \(NL.getal(regel.maximumVerkoeling))).")
            } else {
                stappen.append("Verkoeling telt niet: de koelfunctie moet zijn meegenomen in een geldig NTA 8800-energielabel.")
                waarschuwingen.append("Verkoeling is opgegeven, maar niet bevestigd in het energielabel; daarvoor zijn geen punten gegeven.")
            }
        }
        let p = Afronding.rubriek(pV + pO + pK)
        return RubriekUitkomst(nummer: "3", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Rubriek 4

    func rubriek4(_ w: WoningInvoer, peildatum: Dag, waarschuwingen: inout [String]) throws -> RubriekUitkomst {
        let regel = regels.rubrieken.r4
        var stappen: [String] = []
        let bron = [regel.klassenBron, regel.labelGeldigheidBron].joined(separator: "; ")

        if w.energie.energieprestatievergoeding {
            let p = Afronding.rubriek(regel.energieprestatievergoeding.punten(w.woningtype))
            stappen.append("Energieprestatievergoeding overeengekomen: \(NL.punten(p)) voor een \(w.woningtype == .eengezins ? "eengezinswoning" : "meergezinswoning") (4.3).")
            return RubriekUitkomst(nummer: "4", titel: regel.titel, punten: p, stappen: stappen,
                                   bron: regel.energieprestatievergoedingBron)
        }

        var klasse: Regelset.Energieprestatie.Klasse?
        var geldig = false
        if w.energie.label != nil || w.energie.energieIndex != nil {
            if let opname = w.energie.opnamedatum {
                let vervalt = opname.plusJaren(regel.labelGeldigheidJaren)
                geldig = peildatum < vervalt
                if !geldig {
                    stappen.append("Het energielabel (opname \(opname)) was \(regel.labelGeldigheidJaren) jaar geldig en is verlopen op \(vervalt); het bouwjaar telt.")
                    waarschuwingen.append("Het energielabel is verlopen; de punten zijn bepaald op basis van het bouwjaar.")
                }
            } else {
                stappen.append("Geen opnamedatum van het label bekend; de geldigheid is niet vast te stellen, het bouwjaar telt.")
                waarschuwingen.append("Vul de opnamedatum van het energielabel in; zonder datum telt het bouwjaar.")
            }
        }
        if geldig, let label = w.energie.label {
            klasse = regel.klassen.first { $0.klasse == label.rawValue }
            stappen.append("Geldig energielabel \(label.rawValue).")
        } else if geldig, let ei = w.energie.energieIndex {
            let passend = regel.klassen.filter { $0.bevat(ei: ei) }
            guard passend.count == 1 else {
                throw WWSFout.nietEenduidig("Energie-Index \(NL.getal(ei)) valt niet in precies één klasse van tabel 4.1")
            }
            klasse = passend[0]
            stappen.append("Energie-Index \(NL.getal(ei)) valt in klasse \(passend[0].klasse).")
        }
        if klasse == nil {
            let passend = regel.klassen.filter { $0.bevat(bouwjaar: w.bouwjaar) }
            guard passend.count == 1 else {
                throw WWSFout.nietEenduidig("bouwjaar \(w.bouwjaar) valt niet in precies één klasse van tabel 4.1")
            }
            klasse = passend[0]
            stappen.append("Geen geldig label: bouwjaar \(w.bouwjaar) valt in klasse \(passend[0].klasse).")
        }
        var p = klasse!.punten(w.woningtype)
        stappen.append("Klasse \(klasse!.klasse), \(w.woningtype == .eengezins ? "eengezinswoning" : "meergezinswoning"): \(NL.punten(p)).")
        if regel.monumentGeenMinpunten && w.monument != .geen && p < 0 {
            p = 0
            stappen.append("Monument: geen minpunten, dus 0 punten (4.2).")
        }
        p = Afronding.rubriek(p)
        return RubriekUitkomst(nummer: "4", titel: regel.titel, punten: p, stappen: stappen, bron: bron)
    }

    // MARK: - Rubriek 5

    func keukenPunten(_ k: KeukenInvoer, naam: String, stappen: inout [String]) throws -> Double {
        let regel = regels.rubrieken.r5
        guard k.voldoetAanBasisniveau else {
            stappen.append("\(naam): voldoet niet aan het basisniveau, geen punten.")
            return 0
        }
        let trede = regel.aanrechtLengte.filter { k.aanrechtLengte + Afronding.marge >= $0.vanafMeter }
            .max { $0.vanafMeter < $1.vanafMeter }
        let pA = trede?.punten ?? 0
        stappen.append("\(naam): aanrecht \(NL.getal(k.aanrechtLengte, decimalen: 2)) m = \(NL.punten(pA)).")
        var pV = 0.0
        for (sleutel, aantal) in k.voorzieningen.sorted(by: { $0.key < $1.key }) where aantal > 0 {
            guard let w = regel.voorzieningen[sleutel] else {
                throw WWSFout.ongeldigeInvoer("onbekende keukenvoorziening '\(sleutel)'")
            }
            pV += Double(aantal) * w
            stappen.append("  \(sleutel) × \(aantal) = \(NL.punten(Double(aantal) * w))")
        }
        if regel.maximumVoorzieningenIsAanrechtPunten && pV > pA {
            stappen.append("  Voorzieningen \(NL.punten(pV)), begrensd op de punten voor het aanrecht: \(NL.punten(pA)).")
            pV = pA
        }
        return pA + pV
    }

    func rubriek5(_ keukens: [KeukenInvoer]) throws -> RubriekUitkomst {
        let regel = regels.rubrieken.r5
        var stappen: [String] = []
        var p = 0.0
        for (i, k) in keukens.enumerated() {
            p += try keukenPunten(k, naam: keukens.count > 1 ? "Keuken \(i + 1)" : "Keuken", stappen: &stappen)
        }
        if keukens.isEmpty { stappen.append("Geen keuken opgegeven.") }
        p = Afronding.rubriek(p)
        return RubriekUitkomst(nummer: "5", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Rubriek 6

    /// Geeft (punten 6.1, punten douche/bad, punten 6.2 vóór de woningbrede begrenzing).
    func sanitairPunten(_ s: SanitaireRuimteInvoer, stappen: inout [String]) throws -> (algemeen: Double, doucheBad: Double, extra: Double) {
        let regel = regels.rubrieken.r6
        var algemeen = 0.0

        let toiletten = s.staandeToiletten + s.hangendeToiletten
        if toiletten > 0 {
            switch s.soort {
            case .toiletruimte:
                let t = Double(s.staandeToiletten) * regel.toilet.aparteToiletruimte + Double(s.hangendeToiletten) * regel.toilet.hangendAparteToiletruimte
                algemeen += t
                stappen.append("\(s.naam): toilet in aparte toiletruimte = \(NL.punten(t)).")
            case .badkamer:
                let t = Double(s.staandeToiletten) * regel.toilet.inBadkamer + Double(s.hangendeToiletten) * regel.toilet.hangendInBadkamer
                algemeen += t
                stappen.append("\(s.naam): toilet in badkamer = \(NL.punten(t)).")
            case .anders:
                stappen.append("\(s.naam): een toilet buiten toiletruimte of badkamer telt niet.")
            }
        }

        var wast = Double(s.wastafels) * regel.wastafel
        var meer = Double(s.meerpersoonswastafels) * regel.meerpersoonswastafel
        if s.soort != .badkamer {
            wast = min(wast, regel.wastafelMaximumPerRuimteBuitenBadkamer)
            meer = min(meer, regel.meerpersoonswastafelMaximumPerRuimteBuitenBadkamer)
        }
        if wast > 0 { stappen.append("\(s.naam): wastafel(s) = \(NL.punten(wast)).") }
        if meer > 0 { stappen.append("\(s.naam): meerpersoonswastafel(s) = \(NL.punten(meer)).") }
        algemeen += wast + meer

        let paren = min(s.baden, s.douches)
        let doucheBad = Double(paren) * regel.badEnDouche + Double(s.baden - paren) * regel.bad + Double(s.douches - paren) * regel.douche
        if doucheBad > 0 {
            stappen.append("\(s.naam): \(paren > 0 ? "bad en aparte douche" : (s.baden > 0 ? "bad" : "douche")) = \(NL.punten(doucheBad)).")
        }
        algemeen += doucheBad

        var extra = 0.0
        let heeftVoorzieningen = s.voorzieningen.values.contains { $0 > 0 }
        if heeftVoorzieningen {
            if s.soort == .badkamer && s.voldoetAanEisenBadruimte {
                let wastafels = s.wastafels + s.meerpersoonswastafels
                for (sleutel, aantal) in s.voorzieningen.sorted(by: { $0.key < $1.key }) where aantal > 0 {
                    guard let w = regel.voorzieningenBadruimte[sleutel] else {
                        throw WWSFout.ongeldigeInvoer("onbekende sanitairvoorziening '\(sleutel)'")
                    }
                    var v = Double(aantal) * w
                    if sleutel == "kastruimte" { v = min(v, regel.kastruimteMaximumPerRuimte) }
                    if sleutel == "stopcontact" { v = min(v, regel.stopcontactMaximumPerWastafel * Double(wastafels)) }
                    extra += v
                    stappen.append("  \(sleutel) × \(aantal) = \(NL.punten(v))")
                }
            } else {
                stappen.append("\(s.naam): extra voorzieningen tellen alleen in een bad- of doucheruimte die aan de eisen voldoet.")
            }
        }
        return (algemeen, doucheBad, extra)
    }

    func rubriek6(_ ruimten: [SanitaireRuimteInvoer]) throws -> RubriekUitkomst {
        let regel = regels.rubrieken.r6
        var stappen: [String] = []
        var algemeen = 0.0, doucheBad = 0.0, extra = 0.0
        for s in ruimten {
            let r = try sanitairPunten(s, stappen: &stappen)
            algemeen += r.algemeen; doucheBad += r.doucheBad; extra += r.extra
        }
        if regel.maximumVoorzieningenIsDoucheBadPunten && extra > doucheBad {
            stappen.append("Extra voorzieningen \(NL.punten(extra)), begrensd op de punten voor douche/bad: \(NL.punten(doucheBad)).")
            extra = doucheBad
        }
        if ruimten.isEmpty { stappen.append("Geen sanitair opgegeven.") }
        let p = Afronding.rubriek(algemeen + extra)
        return RubriekUitkomst(nummer: "6", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Rubriek 7

    func rubriek7(_ w: WoningInvoer) -> RubriekUitkomst {
        let regel = regels.rubrieken.r7
        let ruw = w.kostenGehandicaptenvoorzieningen / regel.kostenPerPunt
        let p = Afronding.rubriek(ruw)
        var stappen: [String] = []
        if w.kostenGehandicaptenvoorzieningen > 0 {
            stappen.append("\(NL.euro(w.kostenGehandicaptenvoorzieningen)) / \(NL.euro(regel.kostenPerPunt)) = \(NL.getal(ruw)), afgerond \(NL.punten(p)).")
        } else {
            stappen.append("Geen woonvoorzieningen voor gehandicapten opgegeven.")
        }
        return RubriekUitkomst(nummer: "7", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Rubriek 8

    func rubriek8(_ w: WoningInvoer) -> RubriekUitkomst {
        let regel = regels.rubrieken.r8
        var stappen: [String] = []
        let prive = w.ruimten.filter { $0.soort == .buitenruimte && $0.oppervlakte > 0 }
        var p = 0.0
        if !prive.isEmpty {
            let (som, heel) = oppervlakteSom(prive, stappen: &stappen)
            let pp = regel.priveBasisPunten + heel * regel.privePuntenPerM2
            stappen.append("Privé: \(NL.m2(som)), afgerond \(NL.m2(heel, decimalen: 0)): \(NL.getal(regel.priveBasisPunten)) + \(NL.m2(heel, decimalen: 0)) × \(NL.getal(regel.privePuntenPerM2)) = \(NL.punten(pp)).")
            p += pp
        }
        let gem = w.gemeenschappelijkeBuitenruimten.filter { $0.oppervlakte > 0 }
        for g in gem {
            let heel = Afronding.heel(Afronding.tweeDecimalen(g.oppervlakte))
            let pg = heel * regel.gemeenschappelijkPuntenPerM2 / Double(g.adressen)
            stappen.append("Gemeenschappelijk '\(g.naam)': \(NL.m2(heel, decimalen: 0)) × \(NL.getal(regel.gemeenschappelijkPuntenPerM2)) / \(g.adressen) adressen = \(NL.getal(pg)).")
            p += pg
        }
        if prive.isEmpty && gem.isEmpty {
            p = -regel.aftrekGeenBuitenruimte
            stappen.append("Geen buitenruimte: af \(NL.punten(regel.aftrekGeenBuitenruimte)).")
        } else if p > regel.maximum {
            stappen.append("Totaal \(NL.getal(p)), maximaal \(NL.punten(regel.maximum)).")
            p = regel.maximum
        }
        p = Afronding.rubriek(p)
        return RubriekUitkomst(nummer: "8", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Rubriek 9

    func rubriek9(_ w: WoningInvoer) throws -> RubriekUitkomst {
        let regel = regels.rubrieken.r9
        let r3 = regels.rubrieken.r3
        var stappen: [String] = []
        var p = 0.0
        for g in w.gemeenschappelijkeRuimten {
            let ruimte = RuimteInvoer(naam: g.naam, soort: g.soort, oppervlakte: g.oppervlakte, verwarmd: g.verwarmd)
            let (eff, opm) = classificeer(ruimte)
            if let opm { stappen.append(opm) }
            let heel = Afronding.heel(Afronding.tweeDecimalen(g.oppervlakte))
            var sub = 0.0
            switch eff {
            case .vertrek:
                sub += heel * regel.vertrekPuntenPerM2
                if g.verwarmd { sub += r3.puntenPerVerwarmdVertrek }
            case .overigeRuimte:
                sub += heel * regel.overigeRuimtePuntenPerM2
                if g.verwarmd { sub += r3.puntenPerVerwarmdeOverigeOfVerkeersruimte }
            default:
                break
            }
            var extraStappen: [String] = []
            if let k = g.keuken { sub += try keukenPunten(k, naam: "keuken", stappen: &extraStappen) }
            if let s = g.sanitair {
                let r = try sanitairPunten(s, stappen: &extraStappen)
                sub += r.algemeen + min(r.extra, r.doucheBad)
            }
            let perAdres = sub / Double(g.adressen)
            stappen.append("'\(g.naam)': \(NL.getal(sub)) punten / \(g.adressen) adressen = \(NL.getal(perAdres)).")
            stappen.append(contentsOf: extraStappen.map { "  " + $0 })
            p += perAdres
        }
        if w.gemeenschappelijkeRuimten.isEmpty { stappen.append("Geen gemeenschappelijke binnenruimten.") }
        p = Afronding.rubriek(p)
        return RubriekUitkomst(nummer: "9", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Rubriek 10

    func rubriek10(_ w: WoningInvoer) -> RubriekUitkomst {
        let regel = regels.rubrieken.r10
        var stappen: [String] = []
        var p = 0.0
        for x in w.parkeerruimten {
            let som = Double(x.plekkenTypeI) * regel.typeI + Double(x.plekkenTypeII) * regel.typeII + Double(x.plekkenTypeIII) * regel.typeIII
            let perAdres = som / Double(x.adressen)
            stappen.append("'\(x.naam)': \(x.plekkenTypeI)×type I, \(x.plekkenTypeII)×type II, \(x.plekkenTypeIII)×type III = \(NL.getal(som)) / \(x.adressen) adressen = \(NL.getal(perAdres)).")
            p += perAdres
        }
        if w.parkeerruimten.isEmpty { stappen.append("Geen gemeenschappelijke parkeerruimte.") }
        p = Afronding.rubriek(p)
        return RubriekUitkomst(nummer: "10", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Rubriek 11

    struct WozTussen {
        var punten: Double
        var stappen: [String]
        var kleineWoning: Bool
    }

    /// WOZ-oppervlakte: vertrekken, overige ruimten en type I-parkeerplekken, afgerond op hele m².
    func wozOppervlakte(_ w: WoningInvoer) -> Double {
        var som = 0.0
        for x in w.ruimten {
            let e = classificeer(x).0
            if e == .vertrek || e == .overigeRuimte { som += Afronding.tweeDecimalen(x.oppervlakte) }
        }
        for p in w.parkeerruimten where p.plekkenTypeI > 0 { som += Afronding.tweeDecimalen(p.oppervlakteTypeI) }
        return Afronding.heel(som)
    }

    func rubriek11Basis(_ w: WoningInvoer) throws -> WozTussen {
        let regel = regels.rubrieken.r11
        var stappen: [String] = []
        let waarde: Double
        let cohort: Regelset.Woz.Cohort
        let standaard = regel.cohorten.first(where: \.ookVoorTaxatieEnMinimum)!
        if let wz = w.woz.waarde {
            guard let pd = w.woz.waardepeildatum else {
                throw WWSFout.ongeldigeInvoer("de waardepeildatum van de WOZ-beschikking is nodig")
            }
            guard let c = regel.cohorten.first(where: { $0.waardepeildatum == pd }) else {
                throw WWSFout.ongeldigeInvoer("geen rekencijfers voor WOZ-waardepeildatum \(pd) in regelset \(regels.regelsetJaar)")
            }
            waarde = wz; cohort = c
            stappen.append("WOZ-waarde \(NL.euro(wz)) (waardepeildatum \(pd)).")
        } else if let t = w.woz.taxatiewaarde {
            waarde = t * regel.taxatieFactor; cohort = standaard
            stappen.append("Geen WOZ-waarde: \(NL.getal(regel.taxatieFactor * 100))% van de taxatiewaarde \(NL.euro(t)) = \(NL.euro(waarde)).")
        } else {
            waarde = regel.minimumwaarde; cohort = standaard
            stappen.append("Geen WOZ-waarde of taxatie: minimumwaarde \(NL.euro(waarde)).")
        }

        let opp = wozOppervlakte(w)
        guard opp > 0 else { throw WWSFout.ongeldigeInvoer("geen oppervlakte voor de WOZ-berekening") }

        let deel1 = waarde / cohort.bedragPerPunt
        stappen.append("\(NL.euro(waarde)) / \(NL.euro(cohort.bedragPerPunt)) = \(NL.getal(deel1)).")

        let kw = regel.kleineWoning
        let klein = opp < kw.oppervlakteKleinerDanM2 && kw.bouwjaren.contains(w.bouwjaar) && w.coropAmsterdamOfUtrecht
        var perM2 = waarde / opp
        if regel.waardePerM2AfrondenOpCenten { perM2 = Afronding.centen(perM2) }
        let deler = klein ? cohort.delerPerM2KleineWoning : cohort.delerPerM2
        let deel2 = perM2 / deler
        stappen.append("\(NL.euro(waarde)) / \(NL.m2(opp, decimalen: 0)) = \(NL.euro(perM2)) per m²; / \(NL.euro(deler))\(klein ? " (kleine woning, 11.1 onder a)" : "") = \(NL.getal(deel2)).")

        let p = Afronding.rubriek(deel1 + deel2)
        stappen.append("Samen \(NL.getal(deel1 + deel2)), afgerond \(NL.punten(p)).")
        return WozTussen(punten: p, stappen: stappen, kleineWoning: klein)
    }

    // MARK: - Rubriek 12

    func rubriek12(_ w: WoningInvoer, som1tot11_1: Double) -> RubriekUitkomst {
        let regel = regels.rubrieken.r12
        var stappen: [String] = []
        var p = 0.0
        if w.zorgwoning {
            let z = som1tot11_1 * regel.zorgwoningOpslag
            stappen.append("Zorgwoning: \(NL.getal(regel.zorgwoningOpslag * 100))% van \(NL.getal(som1tot11_1)) (rubriek 1 t/m 11.1) = \(NL.getal(z)).")
            p += z
        }
        if w.videoAanbelfunctie {
            p += regel.videoAanbelfunctie
            stappen.append("Aanbelfunctie met video en audio: \(NL.punten(regel.videoAanbelfunctie)).")
        }
        for x in w.parkeerruimten where x.plekkenMetLaadpaal > 0 {
            let l = Double(x.plekkenMetLaadpaal) * regel.laadpaalPunten / Double(x.adressen)
            stappen.append("Laadpaal '\(x.naam)': \(x.plekkenMetLaadpaal) × \(NL.getal(regel.laadpaalPunten)) / \(x.adressen) adressen = \(NL.getal(l)).")
            p += l
        }
        if stappen.isEmpty { stappen.append("Geen bijzondere voorzieningen.") }
        p = Afronding.rubriek(p)
        return RubriekUitkomst(nummer: "12", titel: regel.titel, punten: p, stappen: stappen, bron: regel.bron)
    }

    // MARK: - Segment en prijsopslag

    public func segment(_ punten: Int) -> Segment {
        if punten <= regels.segmenten.sociaalTotEnMetPunten { return .sociaal }
        if punten <= regels.segmenten.middenTotEnMetPunten { return .midden }
        return .vrij
    }

    func prijsopslag(_ w: WoningInvoer, segment: Segment, peildatum: Dag, stappen: inout [String]) -> Double {
        let po = regels.prijsopslagen
        var opslag = 0.0
        switch w.monument {
        case .rijksmonument:
            if let start = w.contractStart, start >= po.inwerkingtredingWetBetaalbareHuur {
                opslag += po.rijksmonumentContractNaWbh
                stappen.append("Rijksmonument, contract na inwerkingtreding Wet betaalbare huur: + \(NL.getal(po.rijksmonumentContractNaWbh * 100))% (art. 8a lid 1).")
            }
        case .gemeentelijkOfProvinciaal:
            opslag += po.gemeentelijkOfProvinciaalMonument
            stappen.append("Gemeentelijk of provinciaal monument: + \(NL.getal(po.gemeentelijkOfProvinciaalMonument * 100))% (art. 8a lid 3).")
        case .geen:
            break
        }
        let nb = po.nieuwbouwMiddenhuur
        if segment == .midden, let ing = w.ingebruiknameDatum, ing > nb.ingebruiknameNa, w.bouwGestartVoor2028,
           peildatum < ing.plusJaren(nb.duurJaren) {
            opslag += nb.opslag
            stappen.append("Nieuwbouw middenhuur (in gebruik na \(nb.ingebruiknameNa), bouw gestart vóór \(nb.bouwGestartVoor)): + \(NL.getal(nb.opslag * 100))% tot \(ing.plusJaren(nb.duurJaren)) (art. 8a lid 4).")
        }
        let bg = po.beschermdStadsOfDorpsgezicht
        if w.beschermdStadsOfDorpsgezicht && w.bouwjaar < bg.gebouwdVoor && w.monument == .geen {
            opslag += bg.opslag
            stappen.append("Rijksbeschermd stads- of dorpsgezicht, gebouwd vóór \(bg.gebouwdVoor): + \(NL.getal(bg.opslag * 100))% (art. 8a lid 5).")
        }
        if opslag == 0 { stappen.append("Geen prijsopslag van toepassing.") }
        return opslag
    }
}
