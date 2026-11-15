import XCTest
import WWSKit
@testable import HuurmeterCore

final class WidgetGegevensTests: XCTestCase {
    func testUitUitkomstEnOpslag() throws {
        guard case .uitkomst(let u) = Rekenservice().bereken(galerijflat(), peildatum: peildatum) else { return XCTFail() }
        let g = WidgetGegevens(adres: "Galerijstraat 10", uitkomst: u)
        XCTAssertEqual(g.punten, 135)
        XCTAssertEqual(g.teVeelPerMaand, 97.03)
        XCTAssertEqual(g.segment, "Sociale huur")
        XCTAssertEqual(g.resterendeDagen(op: Dag(2026, 12, 31)), 1)
        XCTAssertNil(g.resterendeDagen(op: Dag(2027, 1, 2)))

        let opslag = try XCTUnwrap(UserDefaults(suiteName: "test.widget.\(UUID().uuidString)"))
        g.bewaar(in: opslag)
        XCTAssertEqual(WidgetGegevens.lees(uit: opslag), g)
    }

    func testGeenTeVeelBijLageHuur() throws {
        var c = galerijflat(); c.kaleHuur = 700
        guard case .uitkomst(let u) = Rekenservice().bereken(c, peildatum: peildatum) else { return XCTFail() }
        XCTAssertNil(WidgetGegevens(adres: "", uitkomst: u).teVeelPerMaand)
    }
}
