import XCTest
@testable import WWSKit

final class StappenplanTests: XCTestCase {
    func plannen() throws -> Stappenplannen { try Stappenplannen.laad() }

    func testAlleProceduresHebbenBronnen() throws {
        let p = try plannen()
        XCTAssertEqual(p.procedures.map(\.id), ["aanvangshuur", "huurverlaging", "bezwaarHuurverhoging", "gebreken", "servicekosten"])
        for proc in p.procedures {
            XCTAssertFalse(proc.uiterste.bron.isEmpty, proc.id)
            XCTAssertFalse(proc.stappen.isEmpty, proc.id)
            XCTAssertTrue(proc.stappen.contains { $0.bron != nil }, proc.id)
        }
        XCTAssertEqual(p.leges.huurder, 25)
        XCTAssertEqual(p.leges.verhuurder, 500)
        XCTAssertEqual(p.bezwaarRechter.weken, 8)
    }

    func testAanvangshuurZesMaanden() throws {
        let t = try plannen().procedure("aanvangshuur")!.termijnen(anker: Dag(2026, 8, 31), vandaag: Dag(2026, 11, 15))
        XCTAssertEqual(t.uiterlijk, Dag(2027, 2, 28))
        XCTAssertEqual(t.dagenOver, 105)
        XCTAssertFalse(t.verlopen)
    }

    func testHuurverlagingZesWekenNaIngangEnTweeMaandenVooraf() throws {
        let t = try plannen().procedure("huurverlaging")!.termijnen(anker: Dag(2027, 2, 1), vandaag: Dag(2026, 11, 15))
        XCTAssertEqual(t.uiterlijk, Dag(2027, 3, 15))
        XCTAssertEqual(t.vroegst, Dag(2027, 1, 15))
    }

    func testBezwaarVoorIngangsdatum() throws {
        let t = try plannen().procedure("bezwaarHuurverhoging")!.termijnen(anker: Dag(2027, 7, 1), vandaag: Dag(2027, 6, 1))
        XCTAssertEqual(t.uiterlijk, Dag(2027, 6, 30))
    }

    func testGebrekenZesWekenTotZesMaanden() throws {
        let t = try plannen().procedure("gebreken")!.termijnen(anker: Dag(2026, 10, 1), vandaag: Dag(2026, 11, 15))
        XCTAssertEqual(t.vroegst, Dag(2026, 11, 13))
        XCTAssertEqual(t.uiterlijk, Dag(2027, 4, 2))
    }

    func testServicekostenOverzichtEnVierentwintigMaanden() throws {
        let t = try plannen().procedure("servicekosten")!.termijnen(anker: Dag(2025, 12, 31), vandaag: Dag(2026, 11, 15))
        XCTAssertEqual(t.overzichtUiterlijk, Dag(2026, 6, 30))
        XCTAssertEqual(t.uiterlijk, Dag(2028, 6, 30))
    }

    func testVerlopen() throws {
        let t = try plannen().procedure("aanvangshuur")!.termijnen(anker: Dag(2025, 1, 1), vandaag: Dag(2026, 11, 15))
        XCTAssertTrue(t.verlopen)
    }
}
