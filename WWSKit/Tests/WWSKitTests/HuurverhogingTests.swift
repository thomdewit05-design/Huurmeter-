import XCTest
@testable import WWSKit

final class HuurverhogingTests: XCTestCase {
    func regels() throws -> HuurverhogingRegels { try HuurverhogingRegels.laad(jaar: 2026) }

    func beoordeel(_ i: HuurverhogingInvoer) throws -> HuurverhogingUitkomst { Huurverhoging.beoordeel(i, regels: try regels()) }

    let juli = Dag(2026, 7, 1)

    func testSociaalLaagInkomen41Procent() throws {
        let ok = try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 832.80, ingangsdatum: juli, inkomen: .laag))
        XCTAssertEqual(ok.hoogsteHuur, 832.80)
        XCTAssertEqual(ok.oordeel, .toegestaan)
        let teHoog = try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 840, ingangsdatum: juli, inkomen: .laag))
        XCTAssertEqual(teHoog.oordeel, .teHoog(teveel: 7.20))
    }

    func testSociaalHuurOnder350IsMax25Euro() throws {
        let u = try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 349.99, voorgesteldeHuur: 380, ingangsdatum: juli, inkomen: .laag))
        XCTAssertEqual(u.hoogsteHuur!, 374.99, accuracy: 0.001)
        XCTAssertEqual(u.oordeel, .teHoog(teveel: 5.01))
        let grens = try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 350, voorgesteldeHuur: 364.35, ingangsdatum: juli, inkomen: .laag))
        XCTAssertEqual(grens.hoogsteHuur, 364.35) // vanaf € 350: 4,1%
    }

    func testSociaalInkomensafhankelijk() throws {
        XCTAssertEqual(try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 850, ingangsdatum: juli, inkomen: .midden)).oordeel, .toegestaan)
        XCTAssertEqual(try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 900, ingangsdatum: juli, inkomen: .hoog)).oordeel, .toegestaan)
        XCTAssertEqual(try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 900.01, ingangsdatum: juli, inkomen: .hoog)).oordeel, .teHoog(teveel: 0.01))
        // Onbekend inkomen: alleen de inkomensonafhankelijke verhoging.
        XCTAssertEqual(try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 850, ingangsdatum: juli)).oordeel, .teHoog(teveel: 17.20))
    }

    func testSociaalNietBovenMaximaleHuur() throws {
        let u = try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 870, voorgesteldeHuur: 905.67, ingangsdatum: juli, inkomen: .laag, maximaleHuur: 877.97))
        XCTAssertEqual(u.hoogsteHuur, 877.97)
        XCTAssertEqual(u.oordeel, .teHoog(teveel: 27.70))
    }

    func testKamer() throws {
        XCTAssertEqual(try beoordeel(HuurverhogingInvoer(segment: .sociaal, zelfstandig: false, huidigeHuur: 400, voorgesteldeHuur: 416.40, ingangsdatum: juli)).oordeel, .toegestaan)
    }

    func testVrijeSector44Procent() throws {
        let u = try beoordeel(HuurverhogingInvoer(segment: .vrij, huidigeHuur: 1500, voorgesteldeHuur: 1570, ingangsdatum: Dag(2026, 9, 1)))
        XCTAssertEqual(u.hoogsteHuur, 1566)
        XCTAssertEqual(u.oordeel, .teHoog(teveel: 4))
        // Buiten 2026 geen percentage in de app.
        XCTAssertEqual(try beoordeel(HuurverhogingInvoer(segment: .vrij, huidigeHuur: 1500, voorgesteldeHuur: 1560, ingangsdatum: Dag(2027, 1, 1))).oordeel, .nietTeBepalen)
    }

    func testMiddenhuurNogNietTeBepalen() throws {
        XCTAssertEqual(try beoordeel(HuurverhogingInvoer(segment: .midden, huidigeHuur: 1100, voorgesteldeHuur: 1150, ingangsdatum: juli)).oordeel, .nietTeBepalen)
    }

    func testProcedure() throws {
        let laat = try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 820, ingangsdatum: juli,
                                                     voorstelOntvangen: Dag(2026, 5, 2), inkomen: .laag))
        XCTAssertEqual(laat.aandachtspunten.count, 1)
        let opTijd = try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 820, ingangsdatum: juli,
                                                       voorstelOntvangen: Dag(2026, 5, 1), inkomen: .laag))
        XCTAssertTrue(opTijd.aandachtspunten.isEmpty)
        let teVroeg = try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 820, ingangsdatum: juli,
                                                        vorigeVerhoging: Dag(2025, 7, 2), inkomen: .laag))
        XCTAssertEqual(teVroeg.aandachtspunten.count, 1)
    }

    func testSchemaBuitenGeldigheid() throws {
        XCTAssertEqual(try beoordeel(HuurverhogingInvoer(segment: .sociaal, huidigeHuur: 800, voorgesteldeHuur: 820, ingangsdatum: Dag(2026, 6, 30), inkomen: .laag)).oordeel, .nietTeBepalen)
    }
}
