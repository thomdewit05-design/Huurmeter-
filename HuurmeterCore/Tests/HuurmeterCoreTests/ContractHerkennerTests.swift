import XCTest
import WWSKit
@testable import HuurmeterCore

final class ContractHerkennerTests: XCTestCase {
    func testTypischContract() {
        let tekst = """
        HUUROVEREENKOMST WOONRUIMTE
        Artikel 3 Duur
        Deze overeenkomst gaat in op 1 juli 2026 en is aangegaan voor onbepaalde tijd.
        Artikel 4 Betalingsverplichting
        De kale huurprijs bedraagt € 975,00 per maand.
        Het voorschot op de servicekosten bedraagt € 45,00 per maand.
        Totaal per maand € 1.020,00
        """
        let v = ContractHerkenner.herken(tekst)
        XCTAssertEqual(v.kaleHuur, 975)
        XCTAssertEqual(v.ingangsdatum, Dag(2026, 7, 1))
    }

    func testServicekostenEnTotaalWordenNietGekozen() {
        let tekst = """
        Servicekosten: € 60,00
        Totale huurprijs: € 1.210,00
        Huurprijs per maand: EUR 1.150,-
        Ingangsdatum: 15-09-2026
        """
        let v = ContractHerkenner.herken(tekst)
        XCTAssertEqual(v.kaleHuur, 1150)
        XCTAssertEqual(v.ingangsdatum, Dag(2026, 9, 15))
    }

    func testBedragOpVolgendeRegelEnNumeriekeDatum() {
        let tekst = "Netto huur\n875,50 euro\nmet ingang van\n1/3/2025"
        let v = ContractHerkenner.herken(tekst)
        XCTAssertEqual(v.kaleHuur, 875.50)
        XCTAssertEqual(v.ingangsdatum, Dag(2025, 3, 1))
    }

    func testNietsHerkend() {
        let v = ContractHerkenner.herken("Algemene bepalingen huurovereenkomst woonruimte")
        XCTAssertNil(v.kaleHuur)
        XCTAssertNil(v.ingangsdatum)
    }

    func testBedragen() {
        XCTAssertEqual(ContractHerkenner.bedrag(in: "€975"), 975)
        XCTAssertEqual(ContractHerkenner.bedrag(in: "EUR 2.250,00"), 2250)
        XCTAssertEqual(ContractHerkenner.bedrag(in: "€ 1 150,25"), 1150.25)
        XCTAssertNil(ContractHerkenner.bedrag(in: "artikel 7:249"))
    }

    func testOngeldigeDatumWordtOvergeslagen() {
        XCTAssertNil(ContractHerkenner.datum(in: "31-02-2026"))
        XCTAssertEqual(ContractHerkenner.datum(in: "vanaf 1 sept. 2026"), Dag(2026, 9, 1))
    }
}
