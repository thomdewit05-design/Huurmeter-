import XCTest
import WWSKit
@testable import HuurmeterCore

struct SleutelHaler: HTTPHaler {
    let bestand: String?
    let status: Int
    func haal(_ url: URL) async throws -> (Data, Int) { XCTFail("sleutel ontbreekt"); return (Data(), 401) }
    func haal(_ url: URL, kopteksten: [String: String]) async throws -> (Data, Int) {
        XCTAssertEqual(kopteksten["Authorization"], "test-sleutel")
        XCTAssertTrue(url.absoluteString.contains("postcode=1234AB"))
        let data = try bestand.map { try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "Fixtures/eponline/\($0)", withExtension: "json"))) } ?? Data()
        return (data, status)
    }
}

final class EPOnlineTests: XCTestCase {
    func testNieuwsteLabelWordtGekozen() async throws {
        let c = EPOnlineClient(sleutel: "test-sleutel", haler: SleutelHaler(bestand: "adres", status: 200))
        let l = try await c.haalLabel(postcode: "1234 ab", huisnummer: "10")
        XCTAssertEqual(l.label, .c)
        XCTAssertEqual(l.opnamedatum, Dag(2019, 5, 14))
        XCTAssertEqual(l.geldigTot, Dag(2029, 5, 14))
        XCTAssertNil(l.energieIndex)
    }

    func testFouten() async {
        let zonder = EPOnlineClient(sleutel: "", haler: SleutelHaler(bestand: nil, status: 200))
        XCTAssertFalse(zonder.beschikbaar)
        await verwacht(.geenSleutel) { _ = try await zonder.haalLabel(postcode: "1234AB", huisnummer: "10") }
        let c404 = EPOnlineClient(sleutel: "test-sleutel", haler: SleutelHaler(bestand: nil, status: 404))
        await verwacht(.geenLabel) { _ = try await c404.haalLabel(postcode: "1234AB", huisnummer: "10") }
        let c401 = EPOnlineClient(sleutel: "test-sleutel", haler: SleutelHaler(bestand: nil, status: 401))
        await verwacht(.sleutelGeweigerd) { _ = try await c401.haalLabel(postcode: "1234AB", huisnummer: "10") }
        await verwacht(.ongeldigAdres) { _ = try await c401.haalLabel(postcode: "12", huisnummer: "10") }
    }

    func testOnbekendeKlasseWordtNil() throws {
        let data = Data(#"[{"Energieklasse":"A+++++","Opnamedatum":"2024-01-02T00:00:00"}]"#.utf8)
        let l = try EPOnlineClient.lees(data)
        XCTAssertNil(l.first?.label)
        XCTAssertEqual(l.first?.opnamedatum, Dag(2024, 1, 2))
    }

    func verwacht(_ fout: EPOnlineClient.Fout, _ blok: () async throws -> Void) async {
        do { try await blok(); XCTFail("geen fout") } catch { XCTAssertEqual(error as? EPOnlineClient.Fout, fout) }
    }
}
