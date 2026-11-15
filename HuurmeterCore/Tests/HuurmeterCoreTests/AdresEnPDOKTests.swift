import XCTest
@testable import HuurmeterCore

final class AdresTests: XCTestCase {
    func testPostcode() {
        XCTAssertEqual(Postcode("2513aa")?.waarde, "2513AA")
        XCTAssertEqual(Postcode(" 2513 AA ")?.description, "2513 AA")
        XCTAssertNil(Postcode("0123AB"))
        XCTAssertNil(Postcode("2513A"))
        XCTAssertNil(Postcode("25134A"))
        XCTAssertNil(Postcode("ABCD12"))
    }

    func testHuisnummer() {
        XCTAssertEqual(Huisnummer("12"), Huisnummer(nummer: 12))
        XCTAssertEqual(Huisnummer("12a"), Huisnummer(nummer: 12, letter: "A"))
        XCTAssertEqual(Huisnummer("12-2"), Huisnummer(nummer: 12, toevoeging: "2"))
        XCTAssertEqual(Huisnummer("12 A 3"), Huisnummer(nummer: 12, letter: "A", toevoeging: "3"))
        XCTAssertEqual(Huisnummer("12 bis"), Huisnummer(nummer: 12, toevoeging: "BIS"))
        XCTAssertEqual(Huisnummer("12A-3")?.description, "12A-3")
        XCTAssertNil(Huisnummer("A12"))
        XCTAssertNil(Huisnummer("0"))
        XCTAssertNil(Huisnummer(""))
    }

    func testWeergave() {
        let a = AdresGegevens(postcode: "2513AA", huisnummer: "1", straat: "Binnenhof", plaats: "'s-Gravenhage")
        XCTAssertEqual(a.weergave, "Binnenhof 1, 2513 AA 's-Gravenhage")
    }
}

/// Vaste antwoorden van de PDOK-API's (opgehaald op 15-11-2026).
struct NepHaler: HTTPHaler {
    let antwoorden: [(bevat: String, bestand: String, status: Int)]

    func haal(_ url: URL) async throws -> (Data, Int) {
        let s = url.absoluteString
        guard let a = antwoorden.first(where: { s.contains($0.bevat) }) else { return (Data(), 404) }
        return (try fixture(a.bestand), a.status)
    }
}

func fixture(_ naam: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/pdok/\(naam)", withExtension: "json"))
    return try Data(contentsOf: url)
}

final class PDOKTests: XCTestCase {
    func testLeesLocatieserver() throws {
        let docs = try PDOKClient.leesLocatieserver(fixture("locatieserver"))
        XCTAssertEqual(docs.first?.straatnaam, "Binnenhof")
        XCTAssertEqual(docs.first?.adresseerbaarobject_id, "0518010000625536")
        XCTAssertTrue(try PDOKClient.leesLocatieserver(fixture("locatieserver-leeg")).isEmpty)
    }

    func testKiesOpHuisletterEnToevoeging() throws {
        let docs = try PDOKClient.leesLocatieserver(fixture("locatieserver"))
        XCTAssertNotNil(PDOKClient.kies(docs, huisnummer: Huisnummer(nummer: 1)))
        XCTAssertNil(PDOKClient.kies(docs, huisnummer: Huisnummer(nummer: 1, letter: "B")))
        XCTAssertNil(PDOKClient.kies(docs, huisnummer: Huisnummer(nummer: 2)))
    }

    func testLeesBagPandEnBouwjaar() throws {
        XCTAssertEqual(try PDOKClient.leesPandLinks(fixture("verblijfsobject")).count, 1)
        XCTAssertEqual(try PDOKClient.leesBouwjaar(fixture("pand")), 1620)
        XCTAssertNil(try PDOKClient.leesBouwjaar(Data(#"{"properties":{"bouwjaar":9999}}"#.utf8)))
        XCTAssertThrowsError(try PDOKClient.leesBouwjaar(Data("geen json".utf8)))
    }

    func testVulAanVolledig() async throws {
        let client = PDOKClient(haler: NepHaler(antwoorden: [
            ("locatieserver", "locatieserver", 200),
            ("collections/verblijfsobject", "verblijfsobject", 200),
            ("collections/pand", "pand", 200),
        ]))
        let a = try await client.vulAan(postcode: "2513 aa", huisnummer: "1")
        XCTAssertEqual(a.straat, "Binnenhof")
        XCTAssertEqual(a.plaats, "'s-Gravenhage")
        XCTAssertEqual(a.postcode, "2513AA")
        XCTAssertEqual(a.bouwjaar, 1620)
    }

    func testBouwjaarMisluktIsGeenFout() async throws {
        let client = PDOKClient(haler: NepHaler(antwoorden: [("locatieserver", "locatieserver", 200)]))
        let a = try await client.vulAan(postcode: "2513AA", huisnummer: "1")
        XCTAssertEqual(a.straat, "Binnenhof")
        XCTAssertNil(a.bouwjaar)
    }

    func testFoutmeldingen() async {
        let client = PDOKClient(haler: NepHaler(antwoorden: [("locatieserver", "locatieserver-leeg", 200)]))
        await XCTAssertThrowsAsync(try await client.vulAan(postcode: "9999ZZ", huisnummer: "1"), PDOKFout.adresNietGevonden)
        await XCTAssertThrowsAsync(try await client.vulAan(postcode: "999", huisnummer: "1"), PDOKFout.ongeldigePostcode)
        await XCTAssertThrowsAsync(try await client.vulAan(postcode: "9999ZZ", huisnummer: "x"), PDOKFout.ongeldigHuisnummer)
        let kapot = PDOKClient(haler: NepHaler(antwoorden: [("locatieserver", "locatieserver", 503)]))
        await XCTAssertThrowsAsync(try await kapot.vulAan(postcode: "2513AA", huisnummer: "1"), PDOKFout.serverfout(503))
    }
}

func XCTAssertThrowsAsync<T>(_ expressie: @autoclosure () async throws -> T, _ verwacht: PDOKFout,
                             file: StaticString = #filePath, line: UInt = #line) async {
    do {
        _ = try await expressie()
        XCTFail("geen fout gegooid", file: file, line: line)
    } catch {
        XCTAssertEqual(error as? PDOKFout, verwacht, file: file, line: line)
    }
}
