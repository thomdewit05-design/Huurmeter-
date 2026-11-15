import XCTest

/// Loopt de app door met de demowoning. Maakt schermafbeeldingen voor de App Store (bewaard als
/// bijlage in het testresultaat) en draait Apple's toegankelijkheidscontrole per scherm.
final class HuurmeterUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demo", "-demoOntgrendeld", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launch()
    }

    // MARK: Hulp

    func knop(_ begin: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", begin)).firstMatch
    }

    func tik(_ begin: String, file: StaticString = #filePath, line: UInt = #line) {
        let k = knop(begin)
        XCTAssertTrue(k.waitForExistence(timeout: 10), "knop '\(begin)' niet gevonden", file: file, line: line)
        k.tap()
    }

    func terug() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func openWoning() {
        let rij = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Galerijstraat")).firstMatch
        XCTAssertTrue(rij.waitForExistence(timeout: 10), "demowoning niet gevonden")
        rij.tap()
    }

    /// Wacht op een tekst die het gegeven stuk bevat (labels worden soms samengevoegd voor VoiceOver).
    func wachtOpTekst(_ deel: String, file: StaticString = #filePath, line: UInt = #line) {
        let e = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", deel)).firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 10), "tekst '\(deel)' niet gevonden", file: file, line: line)
    }

    func vastleggen(_ naam: String) {
        let bijlage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        bijlage.name = naam
        bijlage.lifetime = .keepAlways
        add(bijlage)
    }

    // MARK: Schermafbeeldingen

    func testSchermafbeeldingen() throws {
        vastleggen("01-start")

        openWoning()
        vastleggen("02-woning")

        tik("Uitkomst")
        XCTAssertTrue(knop("Dossier en brief").waitForExistence(timeout: 10))
        vastleggen("03-uitkomst")
        tik("1. Oppervlakte van vertrekken")
        vastleggen("04-rubriek")
        terug()

        tik("Ruimtes")
        vastleggen("05-ruimtes")
        tik("Woonkamer")
        wachtOpTekst("Gemeten vloer")
        vastleggen("06-ruimte-gescand")
        tik("Klaar")
        terug()

        tik("Voorzieningen")
        vastleggen("07-voorzieningen")
        terug()

        tik("Uitkomst")
        tik("Dossier en brief")
        wachtOpTekst("Conceptbrief")
        vastleggen("08-dossier-en-brief")
    }

    // MARK: Toegankelijkheid (fase 5)

    func testToegankelijkheid() throws {
        try app.performAccessibilityAudit()

        openWoning()
        try app.performAccessibilityAudit()

        tik("Uitkomst")
        XCTAssertTrue(knop("Dossier en brief").waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
        terug()

        tik("Ruimtes")
        try app.performAccessibilityAudit()
        terug()

        tik("Voorzieningen")
        try app.performAccessibilityAudit()
    }
}
