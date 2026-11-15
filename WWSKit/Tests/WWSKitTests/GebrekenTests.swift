import XCTest
@testable import WWSKit

final class GebrekenTests: XCTestCase {
    func testCategorieenUitBesluit() throws {
        let r = try GebrekenRegels.laad()
        XCTAssertEqual(r.categorieen.map(\.code), [.A, .B, .C])
        XCTAssertEqual(r.categorie(.A)?.laagsteHuurPercentage, 0.20)
        XCTAssertEqual(r.categorie(.B)?.laagsteHuurPercentage, 0.30)
        XCTAssertEqual(r.categorie(.C)?.laagsteHuurPercentage, 0.40)
        XCTAssertEqual(r.categorie(.A)?.voorbeelden.count, 8)
        XCTAssertEqual(r.categorie(.B)?.voorbeelden.count, 8)
        XCTAssertTrue(r.categorieen.allSatisfy { $0.bron.contains("art. 6 lid 1") })
    }

    func testLaagsteHuurBijMeerdereGebreken() throws {
        let r = try GebrekenRegels.laad()
        XCTAssertNil(r.laagsteHuur(huur: 900, categorieen: []))
        XCTAssertEqual(r.laagsteHuur(huur: 900, categorieen: [.C])?.huur, 360)
        let twee = r.laagsteHuur(huur: 900, categorieen: [.B, .C])
        XCTAssertEqual(twee?.huur, 270)
        XCTAssertEqual(twee?.percentage, 0.30)
        XCTAssertEqual(r.laagsteHuur(huur: 812.37, categorieen: [.A, .C])?.huur, 162.47)
    }
}
