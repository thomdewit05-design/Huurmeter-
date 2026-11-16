import XCTest
@testable import HuurmeterCore

final class GrondrasterTests: XCTestCase {
    /// Vloer van b × d meter op hoogte y, opgedeeld in vierkantjes van 0,5 m (zoals een scan in stukjes).
    func vloer(_ b: Double, _ d: Double, y: Double = 0, verschuif: Double = 0) -> [Grondraster.Driehoek] {
        var lijst: [Grondraster.Driehoek] = []
        var x = 0.0
        while x < b - 1e-9 {
            var z = 0.0
            while z < d - 1e-9 {
                let a = Punt3(x + verschuif, y, z), b1 = Punt3(x + 0.5 + verschuif, y, z)
                let c = Punt3(x + 0.5 + verschuif, y, z + 0.5), e = Punt3(x + verschuif, y, z + 0.5)
                lijst.append((a, b1, c)); lijst.append((a, c, e))
                z += 0.5
            }
            x += 0.5
        }
        return lijst
    }

    func testVloerVanZesVierkanteMeter() {
        let d = vloer(2, 3)
        XCTAssertEqual(Grondraster.vloerHoogte(d), 0)
        let cellen = Grondraster.cellen(d, vloerHoogte: 0)
        XCTAssertEqual(Grondraster.oppervlakte([cellen]), 6, accuracy: 0.05)
    }

    func testOverlapTeltNietDubbel() {
        // Twee scanstukken die elkaar voor de helft overlappen: 2×2 en 2×2 verschoven met 1 m = 3×2.
        let a = Grondraster.cellen(vloer(2, 2), vloerHoogte: 0)
        let b = Grondraster.cellen(vloer(2, 2, verschuif: 1), vloerHoogte: 0)
        XCTAssertEqual(Grondraster.oppervlakte([a, b]), 6, accuracy: 0.05)
    }

    func testTafelEnMurenTellenNiet() {
        var d = vloer(4, 3)                                   // 12 m² vloer
        d += vloer(1, 1, y: 0.75)                             // tafelblad
        d.append((Punt3(0, 0, 0), Punt3(4, 0, 0), Punt3(4, 2.5, 0)))   // muur (verticaal)
        let y = Grondraster.vloerHoogte(d)!
        XCTAssertEqual(y, 0, accuracy: 0.001)
        XCTAssertEqual(Grondraster.oppervlakte([Grondraster.cellen(d, vloerHoogte: y)]), 12, accuracy: 0.05)
    }

    func testLeegEnHelling() {
        XCTAssertNil(Grondraster.vloerHoogte([]))
        // Steile helling (45°) telt niet als vloer.
        let steil: Grondraster.Driehoek = (Punt3(0, 0, 0), Punt3(1, 1, 0), Punt3(0, 0, 1))
        XCTAssertTrue(Grondraster.cellen([steil], vloerHoogte: 0).isEmpty)
    }
}
