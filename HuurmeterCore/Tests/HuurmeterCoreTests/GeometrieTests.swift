import XCTest
@testable import HuurmeterCore

final class GeometrieTests: XCTestCase {
    func testRechthoekInHetVloervlak() {
        // 4 × 3 m in het x-z-vlak (RoomPlan: y omhoog).
        let vloer = [Punt3(0, 0, 0), Punt3(4, 0, 0), Punt3(4, 0, 3), Punt3(0, 0, 3)]
        XCTAssertEqual(Geometrie.oppervlakte(vloer), 12, accuracy: 1e-9)
    }

    func testLVormIsKleinerDanOmhullendeRechthoek() {
        // L-vormige kamer: 5 × 4 min een hoek van 2 × 2 = 16 m² (omhullende rechthoek zou 20 geven).
        let l = [Punt2(0, 0), Punt2(5, 0), Punt2(5, 2), Punt2(3, 2), Punt2(3, 4), Punt2(0, 4)]
        XCTAssertEqual(Geometrie.oppervlakte(l), 16, accuracy: 1e-9)
        XCTAssertEqual(Geometrie.oppervlakte(l.map { Punt3($0.x, 1.2, $0.y) }), 16, accuracy: 1e-9)
    }

    func testRichtingEnKantelingMakenNietUit() {
        let rechthoek = [Punt3(0, 0, 0), Punt3(4, 0, 0), Punt3(4, 0, 3), Punt3(0, 0, 3)]
        XCTAssertEqual(Geometrie.oppervlakte(Array(rechthoek.reversed())), 12, accuracy: 1e-9)
        // Lokaal assenstelsel waarin de vloer in het x-y-vlak ligt (zoals een gekanteld oppervlak).
        let gekanteld = [Punt3(0, 0, 0), Punt3(4, 0, 0), Punt3(4, 3, 0), Punt3(0, 3, 0)]
        XCTAssertEqual(Geometrie.oppervlakte(gekanteld), 12, accuracy: 1e-9)
        // Willekeurig gedraaid vlak.
        let hoek = 0.7
        let gedraaid = rechthoek.map { p in Punt3(p.x * cos(hoek) - p.z * sin(hoek), p.x * 0.1, p.x * sin(hoek) + p.z * cos(hoek)) }
        XCTAssertGreaterThan(Geometrie.oppervlakte(gedraaid), 12)  // schuin vlak is groter dan zijn projectie
    }

    func testTeWeinigPunten() {
        XCTAssertEqual(Geometrie.oppervlakte([Punt2(0, 0), Punt2(1, 1)]), 0)
        XCTAssertEqual(Geometrie.oppervlakte([Punt3]()), 0)
    }

    func testInpassenBehoudtVerhoudingEnMarge() throws {
        let p = [Punt2(0, 0), Punt2(4, 0), Punt2(4, 2), Punt2(0, 2)]
        let (omzetten, schaal) = try XCTUnwrap(Geometrie.inpassen(p, breedte: 1000, hoogte: 1000, marge: 100))
        XCTAssertEqual(schaal, 200, accuracy: 1e-9) // 800 px voor 4 m
        XCTAssertEqual(omzetten(Punt2(0, 0)), Punt2(100, 300))
        XCTAssertEqual(omzetten(Punt2(4, 2)), Punt2(900, 700))
        XCTAssertNil(Geometrie.inpassen([], breedte: 10, hoogte: 10, marge: 1))
    }

    func testScanResultaatEnInmeting() {
        let s = ScanResultaat(vloer: [Punt2(0, 0), Punt2(3, 0), Punt2(3, 3), Punt2(0, 3)],
                              muren: [Lijnstuk(van: Punt2(0, 0), naar: Punt2(3, 0))])
        XCTAssertEqual(s.vloeroppervlakte, 9, accuracy: 1e-9)
        XCTAssertEqual(s.muren[0].lengte, 3, accuracy: 1e-9)
        XCTAssertEqual(Inmeting.voorstel(gescand: 14.26, aftrek: 2.1), 12.16, accuracy: 1e-9)
        XCTAssertEqual(Inmeting.voorstel(gescand: 2, aftrek: 5), 0)
        XCTAssertEqual(Inmeting.voorstel(gescand: 10, aftrek: -3), 10)
        XCTAssertEqual(Inmeting.weergave(12.16), "12,2 m²")
    }

    func testAfstandEnAanrecht() {
        XCTAssertEqual(Geometrie.afstand(Punt3(0, 0, 0), Punt3(3, 0, 4)), 5, accuracy: 1e-12)
        XCTAssertEqual(Geometrie.aanrechtLengte([1.234, 0.876]), 2.11)
        XCTAssertEqual(Geometrie.aanrechtLengte([1.996]), 2.0)
        XCTAssertEqual(Geometrie.aanrechtLengte([-1, 0.5]), 0.5)
        XCTAssertEqual(Geometrie.aanrechtLengte([]), 0)
    }
}

final class KamerherkenningTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(Kamerherkenning.functie(voorLabel: "bathroom"), .badkamer)
        XCTAssertEqual(Kamerherkenning.functie(voorLabel: "livingRoom"), .woonkamer)
        XCTAssertEqual(Kamerherkenning.functie(voorLabel: "unidentified"), .overig)
    }

    func testNamen() {
        XCTAssertEqual(Kamerherkenning.namen(voor: [.woonkamer, .slaapkamer, .slaapkamer, .overig]),
                       ["Woonkamer", "Slaapkamer 1", "Slaapkamer 2", "Kamer"])
    }

    func testGrondOppervlakteUitAangetikteHoeken() {
        // Tuin van 5 × 4 m, met kleine hoogteverschillen tussen de tikken.
        let tuin = [Punt3(0, 0, 0), Punt3(5, 0.03, 0), Punt3(5, -0.02, 4), Punt3(0, 0.01, 4)]
        XCTAssertEqual(Geometrie.grondOppervlakte(tuin), 20)
        // L-vormig balkon: 3 × 1,5 plus 1 × 1 = 5,5 m².
        let l = [Punt3(0, 0, 0), Punt3(3, 0, 0), Punt3(3, 0, 1.5), Punt3(1, 0, 1.5), Punt3(1, 0, 2.5), Punt3(0, 0, 2.5)]
        XCTAssertEqual(Geometrie.grondOppervlakte(l), 5.5)
        XCTAssertEqual(Geometrie.grondOppervlakte([Punt3(0, 0, 0), Punt3(1, 0, 0)]), 0)
        // Tegen de klok in of met de klok mee: zelfde uitkomst.
        XCTAssertEqual(Geometrie.grondOppervlakte(tuin.reversed()), 20)
    }
}
