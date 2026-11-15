import XCTest
@testable import WWSKit

final class AfrondingTests: XCTestCase {
    func testRubriekAfrondingOpKwartPunt() {
        XCTAssertEqual(Afronding.rubriek(9.5625), 9.5)      // toelichting rubriek 9
        XCTAssertEqual(Afronding.rubriek(4.8), 4.75)        // toelichting rubriek 10
        XCTAssertEqual(Afronding.rubriek(49.45852877), 49.5) // toelichting rubriek 11, rekenvoorbeeld 1
        XCTAssertEqual(Afronding.rubriek(49.4278455), 49.5)  // rekenvoorbeeld 2
        // Een achtste punt wordt naar boven afgerond.
        XCTAssertEqual(Afronding.rubriek(0.125), 0.25)
        XCTAssertEqual(Afronding.rubriek(0.1249), 0)
        XCTAssertEqual(Afronding.rubriek(10.375), 10.5)
        XCTAssertEqual(Afronding.rubriek(10.3749), 10.25)
        XCTAssertEqual(Afronding.rubriek(-5), -5)
        XCTAssertEqual(Afronding.rubriek(0.1 + 0.2), 0.25)
    }

    func testOppervlakteAfronding() {
        XCTAssertEqual(Afronding.tweeDecimalen(3.76 * 4.12), 15.49) // toelichting rubriek 1
        XCTAssertEqual(Afronding.tweeDecimalen(2.95 * 3.81), 11.24)
        XCTAssertEqual(Afronding.tweeDecimalen(3.16 * 6.12), 19.34) // toelichting rubriek 2
        XCTAssertEqual(Afronding.tweeDecimalen(2.11 * 2.87), 6.06)
        XCTAssertEqual(Afronding.heel(26.73), 27)
        XCTAssertEqual(Afronding.heel(26.5), 27)
        XCTAssertEqual(Afronding.heel(26.49), 26)
        XCTAssertEqual(Afronding.heel(25.40), 25)
    }

    func testCapAfrondingNaarBeneden() {
        XCTAssertEqual(Afronding.omlaag(53.687), 53)
        XCTAssertEqual(Afronding.omlaag(134 * 0.33 / 0.67), 66) // binaire fout mag 66 niet tot 65 maken
    }
}

final class DagTests: XCTestCase {
    func testMaandenOptellen() {
        XCTAssertEqual(Dag(2026, 8, 1).plusMaanden(6), Dag(2027, 2, 1))
        XCTAssertEqual(Dag(2026, 8, 31).plusMaanden(6), Dag(2027, 2, 28))
        XCTAssertEqual(Dag(2027, 8, 31).plusMaanden(6), Dag(2028, 2, 29))
        XCTAssertEqual(Dag(2016, 2, 29).plusJaren(10), Dag(2026, 2, 28))
    }

    func testDagenTussen() {
        XCTAssertEqual(Dag(2026, 11, 15).dagen(tot: Dag(2027, 2, 1)), 78)
        XCTAssertEqual(Dag(2026, 12, 31).dagen(tot: Dag(2027, 1, 1)), 1)
        XCTAssertEqual(Dag(2024, 2, 28).dagen(tot: Dag(2024, 3, 1)), 2)
    }

    func testIsoCodering() throws {
        XCTAssertEqual(Dag(iso: "2026-07-01"), Dag(2026, 7, 1))
        XCTAssertNil(Dag(iso: "2026-02-30"))
        XCTAssertNil(Dag(iso: "1-7-2026x"))
        let data = try JSONEncoder().encode([Dag(2026, 7, 1)])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"2026-07-01\"]")
    }
}

final class DagOptellenTests: XCTestCase {
    func testPlusDagen() {
        XCTAssertEqual(Dag(2026, 12, 31).plusDagen(1), Dag(2027, 1, 1))
        XCTAssertEqual(Dag(2024, 3, 1).plusDagen(-1), Dag(2024, 2, 29))
        XCTAssertEqual(Dag(2027, 1, 1).plusDagen(-14), Dag(2026, 12, 18))
        XCTAssertEqual(Dag(2026, 11, 15).plusDagen(0), Dag(2026, 11, 15))
        for n in [-400, -31, -1, 1, 59, 365, 1000] {
            XCTAssertEqual(Dag(2026, 11, 15).dagen(tot: Dag(2026, 11, 15).plusDagen(n)), n)
        }
    }
}
