import XCTest
@testable import WWSKit

final class RegelsetTests: XCTestCase {
    func testRegelset2026WordtGekozenOpPeildatum() throws {
        XCTAssertEqual(try RegelsetBibliotheek.regelset(op: Dag(2026, 1, 1)).regelsetJaar, 2026)
        XCTAssertEqual(try RegelsetBibliotheek.regelset(op: Dag(2026, 12, 31)).regelsetJaar, 2026)
    }

    func testGeenRegelsetBuitenGeldigheid() {
        XCTAssertThrowsError(try RegelsetBibliotheek.regelset(op: Dag(2025, 12, 31)))
        XCTAssertThrowsError(try RegelsetBibliotheek.regelset(op: Dag(2027, 1, 1)))
    }

    func testRekenmachineWeigertPeildatumBuitenRegelset() throws {
        XCTAssertThrowsError(try rekenmachine().bereken(basisWoning(), peildatum: Dag(2027, 1, 1)))
    }

    /// Controlewaarden uit de spec, vergeleken met de officiële tabel (Uitvoeringsregeling huurprijzen woonruimte, bijlage I).
    func testHuurtabel2026Controlewaarden() throws {
        let t = try regels2026().maximaleHuurprijs
        XCTAssertEqual(t.bedrag(bijPunten: 143), 932.93)
        XCTAssertEqual(t.bedrag(bijPunten: 144), 939.73)
        XCTAssertEqual(t.bedrag(bijPunten: 186), 1228.07)
        XCTAssertEqual(t.bedrag(bijPunten: 187), 1234.92)
        XCTAssertEqual(t.bedrag(bijPunten: 40), 250.26)
        XCTAssertEqual(t.bedrag(bijPunten: 250), 1667.40)
        // Minder dan 40 punten: bedrag bij 40 punten.
        XCTAssertEqual(t.bedrag(bijPunten: 12), 250.26)
        XCTAssertEqual(t.tabel.count, 211)
    }

    func testElkeBronverwijzingIsIngevuld() throws {
        let r = try regels2026()
        let rb = r.rubrieken
        let bronnen = [rb.r1.bron, rb.r2.bron, rb.r3.bron, rb.r4.klassenBron, rb.r4.labelGeldigheidBron,
                       rb.r4.monumentBron, rb.r4.energieprestatievergoedingBron, rb.r5.bron, rb.r6.bron,
                       rb.r7.bron, rb.r8.bron, rb.r9.bron, rb.r10.bron, rb.r11.bron, rb.r12.bron,
                       r.prijsopslagen.bron, r.segmenten.bron, r.termijnen.bron, r.maximaleHuurprijs.bron,
                       r.afronding.rubriekBron, r.afronding.oppervlakteBron, r.afronding.totaalBron]
        for b in bronnen {
            XCTAssertFalse(b.isEmpty)
            let sleutel = b.split(separator: ",").first.map(String.init) ?? ""
            let bekend = r.bronnen.keys.contains { b.hasPrefix($0) || sleutel.hasPrefix($0) }
            XCTAssertTrue(bekend, "bron verwijst niet naar een sleutel uit 'bronnen': \(b.prefix(60))")
        }
    }

    func testValidatieVangtGatInHuurtabel() throws {
        let data = try JSONEncoder().encode(try regels2026())
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var mh = try XCTUnwrap(json["maximaleHuurprijs"] as? [String: Any])
        var tabel = try XCTUnwrap(mh["tabel"] as? [String: Any])
        tabel.removeValue(forKey: "100")
        mh["tabel"] = tabel
        json["maximaleHuurprijs"] = mh
        let kapot = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try RegelsetBibliotheek.laad(data: kapot))
        // Ongewijzigd opnieuw inlezen werkt wel.
        XCTAssertNoThrow(try RegelsetBibliotheek.laad(data: data))
    }
}
