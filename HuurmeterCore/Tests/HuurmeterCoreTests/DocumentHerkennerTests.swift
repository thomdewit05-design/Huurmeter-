import XCTest
import WWSKit
@testable import HuurmeterCore

final class DocumentHerkennerTests: XCTestCase {
    func testWOZBeschikking() {
        let tekst = """
        Gemeente Voorbeeld
        Beschikking WOZ
        Adres: Galerijstraat 12, 1234 AB Voorbeeld
        Waardepeildatum: 1 januari 2025
        Vastgestelde waarde
        € 312.000
        """
        let r = DocumentHerkenner.woz(tekst)
        XCTAssertEqual(r.waarde, 312_000)
        XCTAssertEqual(r.peildatum, Dag(2025, 1, 1))
    }

    func testWOZOpZelfdeRegelEnNumeriekeDatum() {
        let r = DocumentHerkenner.woz("WOZ-waarde: 287.500 euro\nPeildatum 01-01-2024")
        XCTAssertEqual(r.waarde, 287_500)
        XCTAssertEqual(r.peildatum, Dag(2024, 1, 1))
        XCTAssertNil(DocumentHerkenner.woz("WOZ-waarde: € 950").waarde, "te klein om een WOZ-waarde te zijn")
    }

    func testEnergielabel() {
        let r = DocumentHerkenner.energielabel("Energielabel woning\nEnergieklasse: A++\nRegistratiedatum 12-03-2021")
        XCTAssertEqual(r.label, .aPlus2)
        XCTAssertEqual(r.opnamedatum, Dag(2021, 3, 12))
        XCTAssertEqual(DocumentHerkenner.energielabel("Energielabel\nC\nDatum van opname: 3 mei 2019").label, .c)
        XCTAssertNil(DocumentHerkenner.energielabel("Geen label hier").label)
    }

    func testContractAdresEnServicekosten() {
        let tekst = """
        Verhuurder: Woonstichting, Postbus 1, 9999 ZZ Elders
        Het gehuurde betreft de woonruimte gelegen aan
        Galerijstraat 12A, 1234 AB Voorbeeld
        Kale huur € 875,00 per maand
        Voorschot servicekosten € 45,50
        Ingangsdatum 1 juli 2026
        """
        let v = ContractHerkenner.herken(tekst)
        XCTAssertEqual(v.postcode, "1234AB")
        XCTAssertEqual(v.huisnummer, "12A")
        XCTAssertEqual(v.servicekostenPerMaand, 45.50)
        XCTAssertEqual(v.kaleHuur, 875)
        XCTAssertFalse(v.isLeeg)
    }

    func testAdresVanVerhuurderWordtNietOvergenomen() {
        let v = ContractHerkenner.herken("Verhuurder: Woonstichting\nDorpsweg 1, 9999 ZZ Elders\nKale huur € 700,00")
        XCTAssertNil(v.postcode)
    }
}
