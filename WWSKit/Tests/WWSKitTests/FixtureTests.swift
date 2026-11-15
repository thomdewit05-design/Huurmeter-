import XCTest
@testable import WWSKit

/// Volledige voorbeeldwoningen uit Tests/Fixtures. De verwachte uitkomsten komen uit de officiële
/// Huurprijscheck van de Huurcommissie en worden door Thom ingevuld. Zolang een verwachting ontbreekt
/// of afwijkt, faalt deze test: de build is pas groen als alle woningen exact overeenkomen (spec §4).
final class FixtureTests: XCTestCase {
    struct Fixture: Decodable {
        let naam: String
        let omschrijving: String
        let peildatum: Dag
        let invoer: WoningInvoer
        let verwacht: Verwacht?
    }

    struct Verwacht: Decodable {
        let totaal: Int
        let maximaleHuur: Double?
        let rubrieken: [String: Double]?
    }

    func laadFixtures() throws -> [Fixture] {
        let map = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let bestanden = try FileManager.default.contentsOfDirectory(at: map, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try bestanden.map { url in
            do { return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url)) }
            catch { throw WWSFout.ongeldigeInvoer("\(url.lastPathComponent): \(error)") }
        }
    }

    func testMinimaalTienFixtures() throws {
        XCTAssertGreaterThanOrEqual(try laadFixtures().count, 10)
    }

    /// Alle fixtures zijn door te rekenen (los van de verwachte uitkomst).
    func testFixturesZijnDoorTeRekenen() throws {
        for f in try laadFixtures() {
            XCTAssertNoThrow(try Rekenmachine(peildatum: f.peildatum).bereken(f.invoer, peildatum: f.peildatum), f.naam)
        }
    }

    func testFixturesKomenOvereenMetHuurprijscheck() throws {
        for f in try laadFixtures() {
            let u = try Rekenmachine(peildatum: f.peildatum).bereken(f.invoer, peildatum: f.peildatum)
            let berekend = u.rubrieken.map { "r\($0.nummer)=\(NL.getal($0.punten))" }.joined(separator: " ")
            guard let v = f.verwacht else {
                XCTFail("\(f.naam): verwachte uitkomst uit de Huurprijscheck nog niet ingevuld. Berekend: totaal \(u.totaal), max. huur \(u.maximaleHuur.map { NL.euro($0) } ?? "geen") [\(berekend)]")
                continue
            }
            XCTAssertEqual(u.totaal, v.totaal, "\(f.naam): totaal [\(berekend)]")
            XCTAssertEqual(u.maximaleHuur, v.maximaleHuur, "\(f.naam): maximale huur")
            for (nr, p) in v.rubrieken ?? [:] {
                XCTAssertEqual(u.rubriek(nr)?.punten, p, "\(f.naam): rubriek \(nr)")
            }
        }
    }
}
