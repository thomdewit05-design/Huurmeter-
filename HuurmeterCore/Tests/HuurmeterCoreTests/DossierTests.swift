import XCTest
import WWSKit
@testable import HuurmeterCore

final class DossierTests: XCTestCase {
    func uitkomst(_ c: WoningConcept) throws -> Uitkomst {
        guard case .uitkomst(let u) = Rekenservice().bereken(c, peildatum: peildatum) else { throw WWSFout.ongeldigeInvoer("geen uitkomst") }
        return u
    }

    func testDossierBevatKerncijfersBronEnDisclaimer() throws {
        var c = galerijflat()
        c.ruimten[0].bron = .scan
        let d = DossierInhoud(concept: c, uitkomst: try uitkomst(c), regels: try regels())
        XCTAssertEqual(d.adres, "10, 1234 AB")
        XCTAssertTrue(d.kerncijfers.contains { $0.0 == "Puntentotaal" && $0.1 == "135 punten" })
        XCTAssertTrue(d.kerncijfers.contains { $0.0 == "Te veel per maand" && $0.1 == "€ 97,03" })
        XCTAssertTrue(d.kerncijfers.contains { $0.0 == "Aanvangshuur laten toetsen" })
        XCTAssertEqual(d.ruimten.first?.bron, "gescand")
        XCTAssertEqual(d.ruimten.last?.bron, "handmatig")
        XCTAssertEqual(d.ruimten.first?.oppervlakte, "24,4 m²")   // één decimaal
        XCTAssertEqual(d.rubrieken.count, 12)
        XCTAssertFalse(d.rubrieken[0].bron.isEmpty)
        XCTAssertEqual(d.bronnen.count, try regels().bronnen.count)
        XCTAssertTrue(d.voetnoten.contains(Uitkomst.disclaimer))
        XCTAssertTrue(d.voetnoten.contains(DossierInhoud.nietVanDeOverheid))
    }

    func testBriefBijTeHogeHuur() throws {
        let c = galerijflat()
        let t = try Brief.tekst(concept: c, uitkomst: try uitkomst(c), vandaag: Dag(2026, 11, 15))
        XCTAssertTrue(t.contains("135 punten"))
        XCTAssertTrue(t.contains("€ 877,97 per maand"))
        XCTAssertTrue(t.contains("€ 97,03 per maand hoger"))
        XCTAssertTrue(t.contains("sinds 01-07-2026"))
        XCTAssertTrue(t.contains("tot en met 01-01-2027"))   // zes maanden na 1 juli 2026
        XCTAssertTrue(t.contains("[Naam verhuurder]"))
    }

    func testGeenBriefAlsHuurNietTeHoogOfVrijeSector() throws {
        var c = galerijflat()
        c.kaleHuur = 800
        XCTAssertThrowsError(try Brief.tekst(concept: c, uitkomst: try uitkomst(c), vandaag: peildatum)) {
            XCTAssertEqual($0 as? Brief.Fout, .geenTeHogeHuur)
        }
        c.kaleHuur = nil
        XCTAssertThrowsError(try Brief.tekst(concept: c, uitkomst: try uitkomst(c), vandaag: peildatum)) {
            XCTAssertEqual($0 as? Brief.Fout, .kaleHuurOntbreekt)
        }
        c = galerijflat()
        c.ruimten.append(RuimteConcept(naam: "Zaal", soort: .vertrek, oppervlakte: 150, verwarmd: true))
        XCTAssertThrowsError(try Brief.tekst(concept: c, uitkomst: try uitkomst(c), vandaag: peildatum)) {
            XCTAssertEqual($0 as? Brief.Fout, .vrijeSector)
        }
    }
}
