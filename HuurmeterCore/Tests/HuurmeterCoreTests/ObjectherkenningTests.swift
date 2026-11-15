import XCTest
@testable import HuurmeterCore

final class ObjectherkenningTests: XCTestCase {
    func testKeuken() {
        let v = Objectherkenning.voorstellen([
            GevondenObject(.kookplaat, breedte: 0.6, hoogte: 0.9),
            GevondenObject(.oven, breedte: 0.6, hoogte: 0.6),
            GevondenObject(.vaatwasser, breedte: 0.6, hoogte: 0.85),
            GevondenObject(.koelkast, breedte: 0.6, hoogte: 1.8),
            GevondenObject(.wastafelOfSpoelbak, breedte: 0.8, hoogte: 0.9),
            GevondenObject(.kast, breedte: 1.2, hoogte: 0.9),
            GevondenObject(.kast, breedte: 0.6, hoogte: 2.1),   // hoge kast: niet onder het blad
        ], ruimte: .keuken)
        XCTAssertEqual(v.map(\.id), ["kookplaat", "oven", "vaatwasser", "koelkast", "aanrecht"])
        XCTAssertEqual(v[0].sleutel, "keuken.kookplaatInductie")
        XCTAssertEqual(v[0].opties.count, 3)
        XCTAssertFalse(v[3].overnemen, "koelkast staat standaard uit: vrijstaand telt niet")
        XCTAssertEqual(v[4].waarde, 3.2)    // 0,6 + 0,6 + 0,8 + 1,2
        XCTAssertTrue(v[4].isLengte)
        XCTAssertFalse(v[4].overnemen)
    }

    func testKiezenVeranderSleutel() {
        var v = Objectherkenning.voorstellen([GevondenObject(.kookplaat)], ruimte: .keuken)[0]
        v.gekozen = 2
        XCTAssertEqual(v.sleutel, "keuken.kookplaatGas")
    }

    func testBadkamer() {
        let v = Objectherkenning.voorstellen([
            GevondenObject(.bad), GevondenObject(.wastafelOfSpoelbak, breedte: 1.4), GevondenObject(.toilet), GevondenObject(.wasmachine),
        ], ruimte: .badkamer(2))
        XCTAssertEqual(v.map(\.sleutel), ["badkamer2.baden", "badkamer2.meerpersoonswastafels", "badkamer2.toiletStaand"])
        XCTAssertEqual(v[0].rubriek, "6")
        XCTAssertEqual(v.map(\.isAantal), [true, true, false])
    }

    func testToiletEnLeeg() {
        let v = Objectherkenning.voorstellen([GevondenObject(.toilet), GevondenObject(.wastafelOfSpoelbak, breedte: 0.4)], ruimte: .toilet)
        XCTAssertEqual(v.map(\.sleutel), ["toilet.staand", "toilet.wastafel"])
        XCTAssertEqual(v.map(\.isAantal), [true, false])
        XCTAssertTrue(Objectherkenning.voorstellen([GevondenObject(.overig)], ruimte: .keuken).isEmpty)
        XCTAssertNil(Objectherkenning.aanrechtSchatting([GevondenObject(.kast, breedte: 0.2, hoogte: 0.9)]))
    }
}
