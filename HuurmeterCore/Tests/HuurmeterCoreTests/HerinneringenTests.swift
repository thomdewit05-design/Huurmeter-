import XCTest
import WWSKit
@testable import HuurmeterCore

final class HerinneringenTests: XCTestCase {
    func testTermijnEnHuurverhoging() {
        let t = Termijn(einddatum: Dag(2027, 1, 1), resterendeDagen: 47)
        let lijst = Herinneringen.plan(woningId: "w1", adres: "Galerijstraat 10", termijn: t, vandaag: Dag(2026, 11, 15))
        XCTAssertEqual(lijst.map(\.datum), [Dag(2026, 12, 18), Dag(2026, 12, 29), Dag(2027, 5, 1)])
        XCTAssertEqual(lijst.map(\.id), ["w1.termijn.14", "w1.termijn.3", "w1.huurverhoging.2027"])
        XCTAssertTrue(lijst[0].tekst.contains("Galerijstraat 10"))
    }

    func testVerstrekenMomentenVervallen() {
        let t = Termijn(einddatum: Dag(2026, 11, 20), resterendeDagen: 5)
        let lijst = Herinneringen.plan(woningId: "w", adres: "", termijn: t, vandaag: Dag(2026, 11, 15))
        XCTAssertEqual(lijst.map(\.id), ["w.termijn.3", "w.huurverhoging.2027"])
        XCTAssertTrue(lijst[0].tekst.contains("uw woning"))
    }

    func testHuurverhogingDitJaarAlsMeiNogKomt() {
        let lijst = Herinneringen.plan(woningId: "w", adres: "", termijn: nil, vandaag: Dag(2027, 4, 30))
        XCTAssertEqual(lijst.map(\.datum), [Dag(2027, 5, 1)])
        XCTAssertEqual(Herinneringen.plan(woningId: "w", adres: "", termijn: nil, vandaag: Dag(2027, 5, 1)).first?.datum, Dag(2028, 5, 1))
    }
}
