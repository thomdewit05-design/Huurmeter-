import XCTest
import WWSKit
@testable import HuurmeterCore

let peildatum = Dag(2026, 11, 15)
func regels() throws -> Regelset { try RegelsetBibliotheek.regelset(op: peildatum) }

/// Galerijflat uit WWSKit-fixture 01, maar ingevoerd zoals de app dat doet.
func galerijflat() -> WoningConcept {
    WoningConcept(
        adres: AdresGegevens(postcode: "1234AB", huisnummer: "10"), bouwjaar: 1972, woningtype: .meergezins,
        kaleHuur: 975, contractStart: Dag(2026, 7, 1),
        ruimten: [
            RuimteConcept(naam: "Woonkamer", soort: .vertrek, functie: .woonkamer, oppervlakte: 24.35, verwarmd: true),
            RuimteConcept(naam: "Slaapkamer 1", soort: .vertrek, functie: .slaapkamer, oppervlakte: 12.10, verwarmd: true),
            RuimteConcept(naam: "Slaapkamer 2", soort: .vertrek, functie: .slaapkamer, oppervlakte: 8.42, verwarmd: true),
            RuimteConcept(naam: "Keuken", soort: .vertrek, functie: .keuken, oppervlakte: 6.20, verwarmd: true),
            RuimteConcept(naam: "Badkamer", soort: .vertrek, functie: .badkamer, oppervlakte: 3.60, verwarmd: true),
            RuimteConcept(naam: "Toilet", soort: .overigeRuimte, functie: .toilet, oppervlakte: 1.10),
            RuimteConcept(naam: "Berging", soort: .overigeRuimte, functie: .berging, oppervlakte: 5.80),
            RuimteConcept(naam: "Hal", soort: .verkeersruimte, functie: .gang, oppervlakte: 6.5, verwarmd: true),
            RuimteConcept(naam: "Balkon", soort: .buitenruimte, oppervlakte: 4.8),
        ],
        antwoorden: ["keuken.aanrecht": 2.1, "keuken.kookplaatGas": 1, "keuken.afzuiginstallatie": 1,
                     "keuken.eenhandsmengkraan": 1, "toilet.staand": 1,
                     "badkamer1.wastafels": 1, "badkamer1.douches": 1, "badkamer1.thermostatischeMengkraan": 1],
        energielabel: .c, labelOpnamedatum: Dag(2019, 5, 14),
        wozWaarde: 238_000, wozPeildatum: Dag(2025, 1, 1))
}

final class InvoerbouwerTests: XCTestCase {
    func testZelfdeUitkomstAlsWWSKitFixture() throws {
        guard case .uitkomst(let u) = Rekenservice().bereken(galerijflat(), peildatum: peildatum) else {
            return XCTFail("geen uitkomst")
        }
        // Zelfde woning als WWSKit/Tests/Fixtures/01-galerijflat-1972.json: 135 punten, € 877,97.
        XCTAssertEqual(u.totaal, 135)
        XCTAssertEqual(u.maximaleHuur, 877.97)
        XCTAssertEqual(u.verschilPerMaand, 97.03)
        XCTAssertEqual(u.rubriek("5")?.punten, 8.5)
        XCTAssertEqual(u.rubriek("6")?.punten, 8.5)
    }

    func testOntbrekendeGegevens() {
        var c = galerijflat(); c.bouwjaar = nil
        guard case .melding(let m) = Rekenservice().bereken(c, peildatum: peildatum) else { return XCTFail() }
        XCTAssertTrue(m.contains("bouwjaar"))
        c = galerijflat(); c.woningtype = nil
        guard case .melding = Rekenservice().bereken(c, peildatum: peildatum) else { return XCTFail() }
        c = galerijflat(); c.ruimten = c.ruimten.filter { $0.soort != .vertrek }
        guard case .melding = Rekenservice().bereken(c, peildatum: peildatum) else { return XCTFail() }
    }

    func testNietEenduidigWordtMelding() {
        var c = galerijflat(); c.energielabel = nil; c.energieIndex = 0.6
        guard case .melding(let m) = Rekenservice().bereken(c, peildatum: peildatum) else { return XCTFail() }
        XCTAssertTrue(m.contains("eenduidig"))
    }

    func testSanitairOmzetting() throws {
        var c = WoningConcept(bouwjaar: 2000, woningtype: .eengezins)
        c.antwoorden = ["toilet.staand": 1, "toilet.hangend": 1, "toilet.wastafel": 1, "badkamers": 2,
                        "badkamer1.baden": 1, "badkamer1.douches": 1, "badkamer1.handdoekenradiator": 1,
                        "badkamer2.douches": 1, "badkamer2.voldoetEisen": 0, "badkamer2.handdoekenradiator": 1,
                        "wastafels.overig": 2]
        let s = Invoerbouwer.sanitair(c, regels: try regels())
        XCTAssertEqual(s.map(\.soort), [.toiletruimte, .toiletruimte, .badkamer, .badkamer, .anders, .anders])
        XCTAssertEqual(s[0].staandeToiletten, 1); XCTAssertEqual(s[0].wastafels, 1)
        XCTAssertEqual(s[1].hangendeToiletten, 1); XCTAssertEqual(s[1].wastafels, 0)
        XCTAssertTrue(s[2].voldoetAanEisenBadruimte)     // standaard ja
        XCTAssertEqual(s[2].voorzieningen, ["handdoekenradiator": 1])
        XCTAssertFalse(s[3].voldoetAanEisenBadruimte)
    }

    func testGeenBadkamer() throws {
        let c = WoningConcept(bouwjaar: 2000, woningtype: .eengezins, antwoorden: ["badkamers": 0])
        XCTAssertTrue(Invoerbouwer.sanitair(c, regels: try regels()).isEmpty)
    }

    func testKeukenAlleenMetAanrechtOfZonderBasisniveau() throws {
        let r = try regels()
        XCTAssertTrue(Invoerbouwer.keukens(WoningConcept(), regels: r).isEmpty)
        let geenBasis = WoningConcept(antwoorden: ["keuken.basisniveau": 0])
        XCTAssertEqual(Invoerbouwer.keukens(geenBasis, regels: r).first?.voldoetAanBasisniveau, false)
    }

    func testOverigeVragen() throws {
        var c = galerijflat()
        c.antwoorden.merge(["gemBuiten.oppervlakte": 30, "gemBuiten.adressen": 3, "parkeren.typeII": 5,
                            "parkeren.typeIII": 2, "parkeren.laadpalen": 9, "parkeren.adressen": 10,
                            "monument": 2, "zorgwoning": 1, "nieuwbouw.ingebruikname": 20250301]) { $1 }
        let w = try Invoerbouwer.invoer(c, regels: try regels())
        XCTAssertEqual(w.gemeenschappelijkeBuitenruimten.first?.adressen, 3)
        XCTAssertEqual(w.parkeerruimten.first?.plekkenMetLaadpaal, 7) // niet meer laadpalen dan plekken
        XCTAssertEqual(w.monument, .gemeentelijkOfProvinciaal)
        XCTAssertTrue(w.zorgwoning)
        XCTAssertEqual(w.ingebruiknameDatum, Dag(2025, 3, 1))
    }
}

final class VragenlijstTests: XCTestCase {
    func testElkeRegelsleutelHeeftEenOmschrijving() throws {
        let r = try regels()
        for k in Array(r.rubrieken.r5.voorzieningen.keys) + Array(r.rubrieken.r6.voorzieningenBadruimte.keys) {
            XCTAssertNotNil(Vragenlijst.omschrijvingen[k], "geen omschrijving voor \(k)")
        }
    }

    func testSleutelsUniekEnStandaardenConsistent() throws {
        let vragen = Vragenlijst.alleVragen(regels: try regels())
        XCTAssertEqual(Set(vragen.map(\.sleutel)).count, vragen.count)
        for k in Vragenlijst.standaarden.keys { XCTAssertTrue(vragen.contains { $0.sleutel == k }, k) }
    }

    func testVoorzieningenAlleenAlsZePuntenKunnenOpleveren() throws {
        let r = try regels()
        func zichtbaar(_ c: WoningConcept) -> Set<String> {
            Set(Vragenlijst.zichtbareGroepen(regels: r, concept: c).flatMap(\.vragen).map(\.sleutel))
        }
        var c = WoningConcept(bouwjaar: 1990, woningtype: .eengezins)
        XCTAssertTrue(zichtbaar(c).contains("keuken.aanrecht"))
        XCTAssertFalse(zichtbaar(c).contains("keuken.koelkast"))          // aanrecht < 1 m
        c.antwoorden["keuken.aanrecht"] = 1.0
        XCTAssertTrue(zichtbaar(c).contains("keuken.koelkast"))
        c.antwoorden["keuken.basisniveau"] = 0
        XCTAssertFalse(zichtbaar(c).contains("keuken.aanrecht"))
        XCTAssertFalse(zichtbaar(c).contains("keuken.koelkast"))

        XCTAssertFalse(zichtbaar(c).contains("badkamer1.handdoekenradiator")) // geen douche of bad
        c.antwoorden["badkamer1.douches"] = 1
        XCTAssertTrue(zichtbaar(c).contains("badkamer1.handdoekenradiator"))
        XCTAssertFalse(zichtbaar(c).contains("badkamer2.douches"))
        c.antwoorden["badkamer1.voldoetEisen"] = 0
        XCTAssertFalse(zichtbaar(c).contains("badkamer1.handdoekenradiator"))

        XCTAssertFalse(zichtbaar(c).contains("gemBuiten.adressen"))
        XCTAssertFalse(zichtbaar(c).contains("videoAanbel"))               // alleen meergezins
        XCTAssertFalse(zichtbaar(c).contains("beschermdGezicht"))          // gebouwd na 1965
        XCTAssertFalse(zichtbaar(c).contains("nieuwbouw.ingebruikname"))
        XCTAssertFalse(zichtbaar(c).contains("coropAmsterdamUtrecht"))
        c.bouwjaar = 2020
        c.ruimten = [RuimteConcept(naam: "Studio", soort: .vertrek, oppervlakte: 30)]
        XCTAssertTrue(zichtbaar(c).contains("coropAmsterdamUtrecht"))
    }
}

final class OpmaakEnStappenTests: XCTestCase {
    func testOpmaak() {
        XCTAssertEqual(Opmaak.euro(1228.07), "€ 1.228,07")
        XCTAssertEqual(Opmaak.oppervlakte(12.34), "12,3 m²")
        XCTAssertEqual(Opmaak.punten(1), "1 punt")
        XCTAssertEqual(Opmaak.punten(8.5), "8,50 punten")
    }

    func testSamenvatting() throws {
        guard case .uitkomst(let u) = Rekenservice().bereken(galerijflat(), peildatum: peildatum) else { return XCTFail() }
        let s = Opmaak.samenvatting(u, kaleHuur: 975)
        XCTAssertTrue(s.teVeel)
        XCTAssertEqual(s.kop, "Mogelijk € 97,03 per maand te veel")
        XCTAssertTrue(s.regels.contains { $0.contains("€ 1.164,36 per jaar") })
        XCTAssertFalse(Opmaak.samenvatting(u, kaleHuur: nil).teVeel)
    }

    func testTermijntekst() {
        let t = Termijn(einddatum: Dag(2027, 1, 1), resterendeDagen: 47)
        XCTAssertTrue(Opmaak.termijn(t).hasPrefix("Nog 47 dagen"))
    }

    func testStapStatus() {
        var c = WoningConcept()
        XCTAssertEqual(Stap.adres.status(c), .leeg)
        c.adres = AdresGegevens(postcode: "2513AA", huisnummer: "1")
        XCTAssertEqual(Stap.adres.status(c), .deels("Bouwjaar ontbreekt"))
        c.bouwjaar = 1900
        XCTAssertEqual(Stap.adres.status(c), .klaar)
        XCTAssertEqual(Stap.ruimtes.status(galerijflat()), .klaar)
        XCTAssertEqual(Stap.energieWoz.status(galerijflat()), .klaar)
    }

    func testDagEnDate() {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        let d = Dag(2026, 3, 29)
        XCTAssertEqual(Dag(d.datum(kalender: k), kalender: k), d)
        XCTAssertEqual(Dag(getal: 20250301), Dag(2025, 3, 1))
        XCTAssertNil(Dag(getal: 0))
        XCTAssertEqual(Dag(2025, 3, 1).alsGetal, 20250301)
    }

    func testWozPeildata() {
        XCTAssertEqual(Rekenservice.wozPeildata(op: peildatum), [Dag(2025, 1, 1), Dag(2024, 1, 1)])
    }
}
