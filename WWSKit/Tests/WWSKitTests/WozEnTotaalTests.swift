import XCTest
@testable import WWSKit

/// Woning waarvan de rubrieken 1 t/m 10 en 12 samen precies `overig` punten zijn:
/// één verwarmd vertrek (m² + 2), label A eengezins (41) en geen buitenruimte (-5).
func capWoning(overig: Int, woz: Double, bouwjaar: Int = 2010) -> WoningInvoer {
    basisWoning {
        $0.bouwjaar = bouwjaar
        $0.ruimten = [RuimteInvoer(naam: "Woonkamer", soort: .vertrek, oppervlakte: Double(overig - 38), verwarmd: true)]
        $0.energie = EnergieInvoer(label: .a, opnamedatum: Dag(2022, 1, 1))
        $0.woz = WozInvoer(waarde: woz, waardepeildatum: Dag(2025, 1, 1))
    }
}

final class Rubriek11Tests: XCTestCase {
    func woning(m2: Double, woz: Double?, peildatum: Dag? = Dag(2025, 1, 1)) -> WoningInvoer {
        basisWoning {
            $0.ruimten = [RuimteInvoer(naam: "Woonkamer", soort: .vertrek, oppervlakte: m2)]
            $0.woz = WozInvoer(waarde: woz, waardepeildatum: woz == nil ? nil : peildatum)
        }
    }

    func testRekenvoorbeeld1Peildatum2024() throws {
        XCTAssertEqual(try punten(woning(m2: 70, woz: 398_000, peildatum: Dag(2024, 1, 1)), rubriek: "11"), 49.5)
    }

    func testRekenvoorbeeld2Peildatum2025() throws {
        XCTAssertEqual(try punten(woning(m2: 70, woz: 440_188), rubriek: "11"), 49.5)
    }

    func testOnbekendeWaardepeildatum() {
        XCTAssertThrowsError(try punten(woning(m2: 70, woz: 300_000, peildatum: Dag(2023, 1, 1)), rubriek: "11"))
    }

    func testMinimumwaardeZonderWoz() throws {
        // 85.806 / 16.954 + (85.806 / 70 = 1.225,80) / 268
        let verwacht = Afronding.rubriek(85_806 / 16_954 + 1225.80 / 268)
        XCTAssertEqual(try punten(woning(m2: 70, woz: nil), rubriek: "11"), verwacht)
    }

    func testTaxatiewaarde85Procent() throws {
        let w = basisWoning {
            $0.ruimten = [RuimteInvoer(naam: "Woonkamer", soort: .vertrek, oppervlakte: 70)]
            $0.woz = WozInvoer(taxatiewaarde: 400_000)
        }
        let waarde = 340_000.0
        let verwacht = Afronding.rubriek(waarde / 16_954 + Afronding.centen(waarde / 70) / 268)
        XCTAssertEqual(try punten(w, rubriek: "11"), verwacht)
    }

    func testOverigeRuimtenEnTypeIParkeerplekTellenMeeInOppervlakte() throws {
        let w = basisWoning {
            $0.ruimten = [RuimteInvoer(naam: "Woonkamer", soort: .vertrek, oppervlakte: 50),
                          RuimteInvoer(naam: "Berging", soort: .overigeRuimte, oppervlakte: 8),
                          RuimteInvoer(naam: "Gang", soort: .verkeersruimte, oppervlakte: 6)]
            $0.parkeerruimten = [.init(naam: "Garage", plekkenTypeI: 1, oppervlakteTypeI: 12, adressen: 1)]
        }
        XCTAssertEqual(try rekenmachine().wozOppervlakte(w), 70) // gang telt niet
    }

    func testKleineWoningAmsterdamUtrecht() throws {
        func w(m2: Double, bouwjaar: Int, corop: Bool) -> WoningInvoer {
            basisWoning {
                $0.ruimten = [RuimteInvoer(naam: "Studio", soort: .vertrek, oppervlakte: m2)]
                $0.bouwjaar = bouwjaar; $0.coropAmsterdamOfUtrecht = corop
                $0.woz = WozInvoer(waarde: 250_000, waardepeildatum: Dag(2025, 1, 1))
            }
        }
        let klein = Afronding.rubriek(250_000 / 16_954 + Afronding.centen(250_000.0 / 35) / 114)
        let gewoon = Afronding.rubriek(250_000 / 16_954 + Afronding.centen(250_000.0 / 35) / 268)
        XCTAssertEqual(try punten(w(m2: 35, bouwjaar: 2020, corop: true), rubriek: "11"), klein)
        XCTAssertEqual(try punten(w(m2: 35, bouwjaar: 2020, corop: false), rubriek: "11"), gewoon)
        XCTAssertEqual(try punten(w(m2: 35, bouwjaar: 2017, corop: true), rubriek: "11"), gewoon)
        XCTAssertEqual(try punten(w(m2: 35, bouwjaar: 2023, corop: true), rubriek: "11"), gewoon)
        // "tot 40 m2": 40 m² valt erbuiten, 39,49 m² (afgerond 39) erbinnen.
        XCTAssertEqual(try punten(w(m2: 40, bouwjaar: 2020, corop: true), rubriek: "11"),
                       Afronding.rubriek(250_000 / 16_954 + Afronding.centen(250_000.0 / 40) / 268))
        XCTAssertEqual(try punten(w(m2: 39.49, bouwjaar: 2020, corop: true), rubriek: "11"),
                       Afronding.rubriek(250_000 / 16_954 + Afronding.centen(250_000.0 / 39) / 114))
    }

    func testUitzonderingsregelMinimaal40() throws {
        // Bouwjaar 2016, ruim 110 punten in de overige rubrieken, lage WOZ-waarde.
        func w(_ bouwjaar: Int, m2: Double = 100) -> WoningInvoer {
            basisWoning {
                $0.bouwjaar = bouwjaar
                $0.ruimten = [RuimteInvoer(naam: "Woonkamer", soort: .vertrek, oppervlakte: m2, verwarmd: true),
                              RuimteInvoer(naam: "Tuin", soort: .buitenruimte, oppervlakte: 20)]
                $0.woz = WozInvoer(waarde: 150_000, waardepeildatum: Dag(2025, 1, 1))
            }
        }
        XCTAssertEqual(try punten(w(2016), rubriek: "11"), 40)
        XCTAssertEqual(try punten(w(2015), rubriek: "11"), 40)
        XCTAssertEqual(try punten(w(2019), rubriek: "11"), 40)
        XCTAssertLessThan(try punten(w(2020), rubriek: "11"), 40)
        XCTAssertLessThan(try punten(w(2014), rubriek: "11"), 40)
        // Onder de drempel van 110 punten geldt de regel niet: 40 + 2 + 41 + 9 = 92.
        XCTAssertLessThan(try punten(w(2016, m2: 40), rubriek: "11"), 40)
    }

    // MARK: 11.3 Cap op de WOZ

    func testRekenvoorbeeld3CapBlijftBoven187() throws {
        let u = try rekenmachine().bereken(capWoning(overig: 134, woz: 1_500_000), peildatum: peildatum2026)
        XCTAssertEqual(u.somRubrieken - (u.rubriek("11")?.punten ?? 0), 134)
        XCTAssertEqual(u.rubriek("11")?.punten, 66)
        XCTAssertEqual(u.totaal, 200)
        XCTAssertEqual(u.segment, .vrij)
    }

    func testRekenvoorbeeld5CapZaktOnder187Wordt186() throws {
        let u = try rekenmachine().bereken(capWoning(overig: 109, woz: 800_000), peildatum: peildatum2026)
        XCTAssertEqual(u.rubriek("11")?.punten, 53)
        XCTAssertEqual(u.totaal, 186)
        XCTAssertEqual(u.segment, .midden)
        XCTAssertEqual(u.maximaleHuur, 1228.07)
    }

    func testRekenvoorbeeld4GeenCapOnder187() throws {
        let u = try rekenmachine().bereken(capWoning(overig: 80, woz: 600_000), peildatum: peildatum2026)
        let woz = try XCTUnwrap(u.rubriek("11")?.punten)
        XCTAssertLessThan(Double(u.totaal), 187)
        XCTAssertGreaterThan(woz / Double(u.totaal), 0.33)
    }

    func testCapGeldtNietVoorKleineWoning() throws {
        var w = capWoning(overig: 76, woz: 2_000_000, bouwjaar: 2020) // 38 m²
        w.coropAmsterdamOfUtrecht = true
        let u = try rekenmachine().bereken(w, peildatum: peildatum2026)
        XCTAssertGreaterThanOrEqual(u.totaal, 187)
        XCTAssertGreaterThan((u.rubriek("11")?.punten ?? 0) / Double(u.totaal), 0.33)
    }
}

final class TotaalEnHuurTests: XCTestCase {
    func testSegmentgrenzen() throws {
        let r = try rekenmachine()
        XCTAssertEqual(r.segment(143), .sociaal)
        XCTAssertEqual(r.segment(144), .midden)
        XCTAssertEqual(r.segment(186), .midden)
        XCTAssertEqual(r.segment(187), .vrij)
    }

    func testTotaalIsSomVanRubriekenAfgerond() throws {
        let u = try rekenmachine().bereken(basisWoning(), peildatum: peildatum2026)
        XCTAssertEqual(Double(u.totaal), Afronding.heel(u.somRubrieken))
        XCTAssertEqual(u.rubrieken.map(\.nummer), (1...12).map(String.init))
        for r in u.rubrieken { XCTAssertEqual(r.punten, Afronding.rubriek(r.punten), "rubriek \(r.nummer) niet op 0,25") }
    }

    func testMaximaleHuurEnVerschil() throws {
        let u = try rekenmachine().bereken(basisWoning { $0.kaleHuur = 900 }, peildatum: peildatum2026)
        let max = try XCTUnwrap(u.maximaleHuur)
        XCTAssertEqual(max, try regels2026().maximaleHuurprijs.bedrag(bijPunten: u.totaal))
        XCTAssertEqual(u.verschilPerMaand, Afronding.centen(900 - max))
        XCTAssertEqual(u.verschilPerJaar, Afronding.centen(Afronding.centen(900 - max) * 12))
    }

    func testVrijeSectorGeenMaximum() throws {
        let u = try rekenmachine().bereken(capWoning(overig: 134, woz: 1_500_000), peildatum: peildatum2026)
        XCTAssertNil(u.maximaleHuur)
        XCTAssertNil(u.verschilPerMaand)
    }

    func testTermijnAanvangshuur() throws {
        let r = try rekenmachine()
        let binnen = try r.bereken(basisWoning { $0.contractStart = Dag(2026, 8, 1) }, peildatum: peildatum2026)
        XCTAssertEqual(binnen.termijnAanvangshuur?.einddatum, Dag(2027, 2, 1))
        XCTAssertEqual(binnen.termijnAanvangshuur?.resterendeDagen, 78)
        let laatsteDag = try r.bereken(basisWoning { $0.contractStart = Dag(2026, 5, 15) }, peildatum: peildatum2026)
        XCTAssertEqual(laatsteDag.termijnAanvangshuur?.resterendeDagen, 0)
        let verlopen = try r.bereken(basisWoning { $0.contractStart = Dag(2026, 5, 14) }, peildatum: peildatum2026)
        XCTAssertNil(verlopen.termijnAanvangshuur)
    }

    // MARK: Prijsopslagen (art. 8a)

    func opslag(_ aanpassen: @escaping (inout WoningInvoer) -> Void) throws -> Uitkomst {
        try rekenmachine().bereken(basisWoning(aanpassen), peildatum: peildatum2026)
    }

    func testGemeentelijkMonument15Procent() throws {
        let u = try opslag { $0.monument = .gemeentelijkOfProvinciaal }
        XCTAssertEqual(u.prijsopslag, 0.15, accuracy: 1e-12)
        XCTAssertEqual(u.maximaleHuur, Afronding.centen(u.maximaleHuurZonderOpslag! * 1.15))
    }

    func testRijksmonumentNaWbh35Procent() throws {
        let u = try opslag { $0.monument = .rijksmonument; $0.contractStart = Dag(2024, 7, 1) }
        XCTAssertEqual(u.prijsopslag, 0.35, accuracy: 1e-12)
    }

    func testRijksmonumentVoorWbhPlus50Punten() throws {
        let zonder = try opslag { $0.monument = .rijksmonument; $0.contractStart = Dag(2024, 7, 1) }
        let met = try opslag { $0.monument = .rijksmonument; $0.contractStart = Dag(2024, 6, 30) }
        XCTAssertEqual(met.totaal, zonder.totaal + 50)
        XCTAssertEqual(met.prijsopslag, 0)
    }

    func testRijksmonumentZonderContractdatumGeeftFout() {
        XCTAssertThrowsError(try opslag { $0.monument = .rijksmonument })
    }

    func testBeschermdGezicht5ProcentAlleenVoor1965EnGeenMonument() throws {
        XCTAssertEqual(try opslag { $0.beschermdStadsOfDorpsgezicht = true; $0.bouwjaar = 1964 }.prijsopslag, 0.05, accuracy: 1e-12)
        XCTAssertEqual(try opslag { $0.beschermdStadsOfDorpsgezicht = true; $0.bouwjaar = 1965 }.prijsopslag, 0)
        XCTAssertEqual(try opslag { $0.beschermdStadsOfDorpsgezicht = true; $0.bouwjaar = 1964; $0.monument = .gemeentelijkOfProvinciaal }.prijsopslag, 0.15, accuracy: 1e-12)
    }

    func testOpslagenWordenOpgeteld() throws {
        // Rijksmonument (35%) en nieuwbouw middenhuur (10%) zijn in theorie samen mogelijk; hier gemeentelijk + nieuwbouw.
        let u = try opslag {
            $0.monument = .gemeentelijkOfProvinciaal
            $0.ruimten[0].oppervlakte = 60
            $0.ruimten.append(RuimteInvoer(naam: "Tuin", soort: .buitenruimte, oppervlakte: 30))
            $0.energie = EnergieInvoer(label: .aPlus4, opnamedatum: Dag(2025, 1, 1))
            $0.woz = WozInvoer(waarde: 300_000, waardepeildatum: Dag(2025, 1, 1))
            $0.ingebruiknameDatum = Dag(2025, 3, 1); $0.bouwGestartVoor2028 = true; $0.bouwjaar = 2025
        }
        XCTAssertEqual(u.segment, .midden, "testwoning moet in middenhuur vallen (totaal \(u.totaal))")
        XCTAssertEqual(u.prijsopslag, 0.25, accuracy: 1e-12)
    }

    func testNieuwbouwopslagNietInSociaalSegment() throws {
        let u = try opslag { $0.ingebruiknameDatum = Dag(2025, 3, 1); $0.bouwGestartVoor2028 = true }
        XCTAssertEqual(u.segment, .sociaal)
        XCTAssertEqual(u.prijsopslag, 0)
    }
}
