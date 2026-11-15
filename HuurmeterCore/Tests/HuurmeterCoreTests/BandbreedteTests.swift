import XCTest
@testable import HuurmeterCore

final class BandbreedteTests: XCTestCase {
    func testBanden() {
        XCTAssertNil(Bandbreedte.voor(teVeelPerMaand: 0))
        XCTAssertNil(Bandbreedte.voor(teVeelPerMaand: 0.99))
        XCTAssertEqual(Bandbreedte.voor(teVeelPerMaand: 1), Bandbreedte(van: 0, tot: 50))
        XCTAssertEqual(Bandbreedte.voor(teVeelPerMaand: 49.99), Bandbreedte(van: 0, tot: 50))
        XCTAssertEqual(Bandbreedte.voor(teVeelPerMaand: 50), Bandbreedte(van: 50, tot: 100))
        XCTAssertEqual(Bandbreedte.voor(teVeelPerMaand: 150), Bandbreedte(van: 100, tot: 200))
        XCTAssertEqual(Bandbreedte.voor(teVeelPerMaand: 299.99), Bandbreedte(van: 200, tot: 300))
        XCTAssertEqual(Bandbreedte.voor(teVeelPerMaand: 499), Bandbreedte(van: 300, tot: 500))
        XCTAssertEqual(Bandbreedte.voor(teVeelPerMaand: 812), Bandbreedte(van: 500, tot: nil))
    }
}
