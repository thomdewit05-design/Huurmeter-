import XCTest
@testable import WWSKit

final class ServicekostenTests: XCTestCase {
    func procedure() throws -> Stappenplannen.Procedure { try Stappenplannen.laad().procedure("servicekosten")! }

    func testRegelsLaden() throws {
        let r = try ServicekostenRegels.laad()
        XCTAssertEqual(r.minimumGeschil.bedrag, 36)
        XCTAssertEqual(r.normbedragen.zelfstandig.overigPerJaar, 12)
        XCTAssertEqual(r.normbedragen.zelfstandig.gas, "prijs van 400 m³ gas")
        XCTAssertEqual(r.normbedragen.onzelfstandig.elektriciteit, "prijs van 500 kWh")
    }

    func testSaldoEnTermijnen() throws {
        let posten = [
            ServicekostenPost(naam: "Schoonmaak trappenhuis", voorschot: 240, kosten: 180.50),
            ServicekostenPost(naam: "Glazenwasser", voorschot: 60, kosten: 75),
            ServicekostenPost(naam: "Tuinonderhoud", voorschot: 36, kosten: nil),
        ]
        XCTAssertEqual(posten[0].saldo, 59.50)
        XCTAssertEqual(posten[1].saldo, -15)
        XCTAssertNil(posten[2].saldo)
        let u = Servicekosten.beoordeel(posten: posten, jaar: 2025, overzichtOntvangen: Dag(2026, 5, 20),
                                        vandaag: Dag(2026, 11, 15), procedure: try procedure())
        XCTAssertEqual(u.totaalVoorschot, 336)
        XCTAssertEqual(u.totaalKosten, 255.50)
        XCTAssertEqual(u.saldo, 80.50)
        XCTAssertEqual(u.overzichtUiterlijk, Dag(2026, 6, 30))
        XCTAssertFalse(u.overzichtTeLaat)
        XCTAssertEqual(u.verzoekUiterlijk, Dag(2028, 6, 30))
        XCTAssertFalse(u.verzoekVerlopen)
    }

    func testOverzichtTeLaatOfNietOntvangen() throws {
        let p = try procedure()
        XCTAssertTrue(Servicekosten.beoordeel(posten: [], jaar: 2025, overzichtOntvangen: Dag(2026, 7, 1), vandaag: Dag(2026, 11, 15), procedure: p).overzichtTeLaat)
        XCTAssertTrue(Servicekosten.beoordeel(posten: [], jaar: 2025, overzichtOntvangen: nil, vandaag: Dag(2026, 7, 1), procedure: p).overzichtTeLaat)
        XCTAssertFalse(Servicekosten.beoordeel(posten: [], jaar: 2025, overzichtOntvangen: nil, vandaag: Dag(2026, 6, 30), procedure: p).overzichtTeLaat)
    }

    func testMinimumGeschil() throws {
        let r = try ServicekostenRegels.laad()
        XCTAssertFalse(Servicekosten.ontvankelijk(geschil: 35.99, regels: r))
        XCTAssertTrue(Servicekosten.ontvankelijk(geschil: -36, regels: r))
    }
}
