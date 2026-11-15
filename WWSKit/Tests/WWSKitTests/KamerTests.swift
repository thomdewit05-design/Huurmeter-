import XCTest
@testable import WWSKit

/// Rekenvoorbeelden uit de toelichting bij Bijlage I onder B (Besluit huurprijzen woonruimte).
final class KamerTests: XCTestCase {
    let peil = Dag(2026, 11, 15)
    func regels() throws -> KamerRegels { try KamerRegels.laad() }
    func punten(_ u: KamerUitkomst, _ nr: String) -> Double? { u.rubrieken.first { $0.nummer == nr }?.punten }

    func testRegelsetCompleet() throws {
        let r = try regels()
        XCTAssertEqual(r.maximaleHuurprijs.tabel.count, 250)
        XCTAssertEqual(r.maximaleHuurprijs.bedrag(bijPunten: 1), 10.33)
        XCTAssertEqual(r.maximaleHuurprijs.bedrag(bijPunten: 250), 1613.63)
        XCTAssertEqual(r.maximaleHuurprijs.bedrag(bijPunten: 252), 1624.17)
        XCTAssertNil(r.maximaleHuurprijs.bedrag(bijPunten: 0))
        XCTAssertEqual(r.corop.perPeildatum["2025-01-01"]?.count, 40)
        XCTAssertEqual(r.corop.perPeildatum["2025-01-01"]?["Oost-Groningen"], 2184)
        XCTAssertEqual(r.corop.perPeildatum["2024-01-01"]?["Flevoland"], 3047)
        for k in r.bronnen.keys { XCTAssertFalse(r.bronnen[k]!.url.isEmpty) }
    }

    /// Toelichting rubriek 1 en 4: 10 m² privé + 40 m² woonkamer met 4 kamers = 20 m²; label A: 20 × 0,65 = 13.
    func testVoorbeeldOppervlakteEnEnergie() throws {
        var k = KamerInvoer()
        k.priveVertrekken = 10
        k.gemeenschappelijkeVertrekken = [Gedeeld(40, kamers: 4)]
        k.label = .a
        k.labelOpnamedatum = Dag(2022, 3, 1)
        let u = try Kamerberekening.bereken(k, regels: try regels(), peildatum: peil)
        XCTAssertEqual(u.toegerekendeVertrekM2, 20)
        XCTAssertEqual(punten(u, "1"), 20)
        XCTAssertEqual(punten(u, "4"), 13)
    }

    /// Toelichting rubriek 5: keuken 7 + 3 punten, gedeeld door 4 = 2,5.
    func testVoorbeeldKeuken() throws {
        var k = KamerInvoer()
        k.keukens = [KamerKeuken(aanrechtLengte: 2.4, voorzieningen: ["koelkast": 1, "ovenElektrisch": 1, "magnetron": 1], kamers: 4)]
        XCTAssertEqual(punten(try Kamerberekening.bereken(k, regels: try regels(), peildatum: peil), "5"), 2.5)
    }

    /// Aanrecht tot 3 m: 10 punten; 13 punten bij 5 m en minimaal 8 kamers.
    func testAanrechtTredes() throws {
        let r = try regels()
        func p(_ m: Double, _ kamers: Int) throws -> Double? {
            var k = KamerInvoer(); k.keukens = [KamerKeuken(aanrechtLengte: m, kamers: kamers)]
            return punten(try Kamerberekening.bereken(k, regels: r, peildatum: peil), "5")
        }
        XCTAssertEqual(try p(0.9, 1), 0)
        XCTAssertEqual(try p(3.0, 1), 10)
        XCTAssertEqual(try p(5.0, 1), 10)
        XCTAssertEqual(try p(5.0, 7), Afronding.rubriek(10.0 / 7))
        XCTAssertEqual(try p(5.0, 8), Afronding.rubriek(13.0 / 8)) // 1,625 → 1,75
    }

    /// Toelichting rubriek 6: gedeelde badkamer (3 + 1,25 + 0,75) / 4 + eigen toilet 3 = 4,25.
    func testVoorbeeldSanitair() throws {
        var k = KamerInvoer()
        k.sanitair = [
            KamerSanitair(douches: 1, extra: ["doucheafscheiding": 1, "handdoekradiator": 1], kamers: 4),
            KamerSanitair(toilet: .staand, kamers: 1),
        ]
        XCTAssertEqual(punten(try Kamerberekening.bereken(k, regels: try regels(), peildatum: peil), "6"), 4.25)
    }

    /// Toelichting rubriek 8: 2,35 + 0,84375 + 1,95 = 5,14375, afgerond 5,25.
    func testVoorbeeldBuitenruimten() throws {
        var k = KamerInvoer()
        k.priveBuitenruimte = 1
        k.gemeenschappelijkeBuitenruimten = [Gedeeld(4.5, kamers: 4), Gedeeld(52, kamers: 4, adressen: 5)]
        XCTAssertEqual(punten(try Kamerberekening.bereken(k, regels: try regels(), peildatum: peil), "8"), 5.25)
    }

    /// Toelichting rubriek 9: (20 + 1,5 + 2 + 10 + 4,75) / 4 adressen / 4 kamers = 2,390625, afgerond 2,50.
    func testVoorbeeldBinnenruimteMeerdereAdressen() throws {
        var k = KamerInvoer()
        k.binnenruimtenMeerdereAdressen = [Gedeeld(20, kamers: 4, adressen: 4)]
        k.overigeRuimtenMeerdereAdressen = [Gedeeld(2, kamers: 4, adressen: 4)]
        k.verwarmdeGemeenschappelijkeVertrekken = [Gedeeld(1, kamers: 4, adressen: 4)]
        k.keukens = [KamerKeuken(aanrechtLengte: 2.4, voorzieningen: ["koelkast": 1, "ovenElektrisch": 1, "magnetron": 1], kamers: 4, adressen: 4)]
        k.sanitair = [KamerSanitair(toilet: .zwevend, wastafels: 1, kamers: 4, adressen: 4)]
        let u = try Kamerberekening.bereken(k, regels: try regels(), peildatum: peil)
        XCTAssertEqual(punten(u, "9"), 2.5)
        XCTAssertEqual(punten(u, "3"), 0)
        XCTAssertEqual(punten(u, "5"), 0)
        XCTAssertEqual(punten(u, "6"), 0)
    }

    func testWozTegenCorop() throws {
        let r = try regels()
        func p11(_ woz: Double) throws -> Double? {
            var k = KamerInvoer()
            k.wozWaarde = woz; k.gebruiksoppervlakteAdres = 100; k.coropGebied = "Oost-Groningen"; k.wozPeildatum = Dag(2025, 1, 1)
            return punten(try Kamerberekening.bereken(k, regels: r, peildatum: peil), "11")
        }
        // Gemiddelde 2.184 per m²: grenzen 2.402,40 en 1.965,60.
        XCTAssertEqual(try p11(240_241), 14)
        XCTAssertEqual(try p11(240_240), 12)
        XCTAssertEqual(try p11(196_560), 12)
        XCTAssertEqual(try p11(196_559), 10)
        var k = KamerInvoer(); k.wozWaarde = 1; k.gebruiksoppervlakteAdres = 1; k.coropGebied = "Oost-Groningen"; k.wozPeildatum = Dag(2023, 1, 1)
        XCTAssertThrowsError(try Kamerberekening.bereken(k, regels: r, peildatum: peil))
    }

    func testTotaalAftrekEnHuur() throws {
        var k = KamerInvoer()
        k.priveVertrekken = 7.4
        k.verwarmdePriveVertrekken = 1
        k.bouwjaar = 1965
        k.ruitKleinerDan075 = true
        let r = try regels()
        let u = try Kamerberekening.bereken(k, regels: r, peildatum: peil)
        // 7 m² (afgerond) = 7; verwarming 2; bouwjaar 1965 → klasse G: 7 × −0,15 = −1,05 → −1; aftrek 2 × −4.
        XCTAssertEqual(punten(u, "4"), -1)
        XCTAssertEqual(punten(u, "13"), -8)
        XCTAssertEqual(u.totaal, 0)
        XCTAssertNil(u.maximaleHuur)

        k.priveVertrekken = 14; k.ruitKleinerDan075 = false; k.monument = .gemeentelijkOfProvinciaal
        let m = try Kamerberekening.bereken(k, regels: r, peildatum: peil)
        XCTAssertEqual(punten(m, "4"), 0) // monument: geen minpunten
        XCTAssertEqual(m.totaal, 16)
        XCTAssertEqual(m.maximaleHuur, Afronding.centen(r.maximaleHuurprijs.bedrag(bijPunten: 16)! * 1.15))
    }
}
