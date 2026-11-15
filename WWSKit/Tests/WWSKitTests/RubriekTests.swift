import XCTest
@testable import WWSKit

// Grensgevallen per rubriek. Waar mogelijk zijn de rekenvoorbeelden uit de toelichting bij
// Bijlage I onder A (Besluit huurprijzen woonruimte, geldend vanaf 01-01-2026) overgenomen.

final class Rubriek1Tests: XCTestCase {
    func testVoorbeeldToelichting() throws {
        let w = basisWoning {
            $0.ruimten = [RuimteInvoer(naam: "Kamer", soort: .vertrek, oppervlakte: 3.76 * 4.12),
                          RuimteInvoer(naam: "Keuken", soort: .vertrek, functie: .keuken, oppervlakte: 2.95 * 3.81)]
        }
        XCTAssertEqual(try punten(w, rubriek: "1"), 27)
    }

    func testAfrondingTotaleOppervlakte() throws {
        XCTAssertEqual(try punten(basisWoning { $0.ruimten[0].oppervlakte = 26.49 }, rubriek: "1"), 26)
        XCTAssertEqual(try punten(basisWoning { $0.ruimten[0].oppervlakte = 26.50 }, rubriek: "1"), 27)
        // Per vertrek eerst op twee decimalen: 26,495 -> 26,50 -> 27.
        XCTAssertEqual(try punten(basisWoning { $0.ruimten[0].oppervlakte = 26.495 }, rubriek: "1"), 27)
        XCTAssertEqual(try punten(basisWoning { $0.ruimten[0].oppervlakte = 26.494 }, rubriek: "1"), 26)
    }

    func testMinimumoppervlakteVertrek() throws {
        // 4,00 m² is een vertrek; 3,99 m² wordt een overige ruimte.
        let w4 = basisWoning { $0.ruimten.append(RuimteInvoer(naam: "Studeer", soort: .vertrek, oppervlakte: 4.0)) }
        XCTAssertEqual(try punten(w4, rubriek: "1"), 24)
        XCTAssertEqual(try punten(w4, rubriek: "2"), 0)
        let w3 = basisWoning { $0.ruimten.append(RuimteInvoer(naam: "Hok", soort: .vertrek, oppervlakte: 3.99)) }
        XCTAssertEqual(try punten(w3, rubriek: "1"), 20)
        XCTAssertEqual(try punten(w3, rubriek: "2"), 3) // 3,99 -> 4 m² × 0,75
        // Kleiner dan 2 m²: telt nergens.
        let w1 = basisWoning { $0.ruimten.append(RuimteInvoer(naam: "Nis", soort: .vertrek, oppervlakte: 1.99)) }
        XCTAssertEqual(try punten(w1, rubriek: "1"), 20)
        XCTAssertEqual(try punten(w1, rubriek: "2"), 0)
    }

    func testKeukenEnBadkamerZijnAltijdVertrek() throws {
        let w = basisWoning {
            $0.ruimten.append(RuimteInvoer(naam: "Keukentje", soort: .vertrek, functie: .keuken, oppervlakte: 3.0))
            $0.ruimten.append(RuimteInvoer(naam: "Douche", soort: .vertrek, functie: .badkamer, oppervlakte: 2.4))
        }
        XCTAssertEqual(try punten(w, rubriek: "1"), 25) // 20 + 3 + 2,4 = 25,4 -> 25
    }
}

final class Rubriek2Tests: XCTestCase {
    func testVoorbeeldToelichting() throws {
        let w = basisWoning {
            $0.ruimten += [RuimteInvoer(naam: "Garage", soort: .overigeRuimte, functie: .garage, oppervlakte: 3.16 * 6.12),
                           RuimteInvoer(naam: "Bijkeuken", soort: .overigeRuimte, oppervlakte: 2.11 * 2.87)]
        }
        XCTAssertEqual(try punten(w, rubriek: "2"), 18.75)
    }

    func testMinimumoppervlakte() throws {
        XCTAssertEqual(try punten(basisWoning { $0.ruimten.append(RuimteInvoer(naam: "Kast", soort: .overigeRuimte, oppervlakte: 2.0)) }, rubriek: "2"), 1.5)
        XCTAssertEqual(try punten(basisWoning { $0.ruimten.append(RuimteInvoer(naam: "Kast", soort: .overigeRuimte, oppervlakte: 1.99)) }, rubriek: "2"), 0)
    }

    func testZolderZonderVasteTrap() throws {
        let groot = basisWoning { $0.ruimten.append(RuimteInvoer(naam: "Zolder", soort: .overigeRuimte, functie: .zolder, oppervlakte: 10, zolderZonderVasteTrap: true)) }
        XCTAssertEqual(try punten(groot, rubriek: "2"), 2.5) // 7,5 - 5
        let klein = basisWoning { $0.ruimten.append(RuimteInvoer(naam: "Zolder", soort: .overigeRuimte, functie: .zolder, oppervlakte: 4, zolderZonderVasteTrap: true)) }
        XCTAssertEqual(try punten(klein, rubriek: "2"), 0) // 3 - 3, niet onder nul
    }
}

final class Rubriek3Tests: XCTestCase {
    func testVerwarmdeVertrekkenEnOpenKeuken() throws {
        let w = basisWoning {
            $0.ruimten[0].verwarmd = true
            $0.ruimten.append(RuimteInvoer(naam: "Slaapkamer", soort: .vertrek, oppervlakte: 10, verwarmd: true))
            $0.ruimten.append(RuimteInvoer(naam: "Koud", soort: .vertrek, oppervlakte: 10, verwarmd: false))
            $0.verwarmdeOpenKeukens = 1
        }
        XCTAssertEqual(try punten(w, rubriek: "3"), 6)
    }

    func testMaximumOverigeEnVerkeersruimten() throws {
        func woning(_ n: Int) -> WoningInvoer {
            basisWoning { w in
                for i in 0..<n { w.ruimten.append(RuimteInvoer(naam: "Gang \(i)", soort: .verkeersruimte, oppervlakte: 3, verwarmd: true)) }
            }
        }
        XCTAssertEqual(try punten(woning(3), rubriek: "3"), 3)
        XCTAssertEqual(try punten(woning(4), rubriek: "3"), 4)
        XCTAssertEqual(try punten(woning(5), rubriek: "3"), 4)
    }

    func testVerkoelingAlleenMetLabelEnMaximaal2() throws {
        func woning(_ n: Int, label: Bool) -> WoningInvoer {
            basisWoning { w in
                w.ruimten.removeAll()
                for i in 0..<n { w.ruimten.append(RuimteInvoer(naam: "Kamer \(i)", soort: .vertrek, oppervlakte: 10, verkoeling: true)) }
                w.energie.koelingInLabel = label
            }
        }
        XCTAssertEqual(try punten(woning(1, label: true), rubriek: "3"), 3)  // 2 verwarming + 1 koeling
        XCTAssertEqual(try punten(woning(2, label: true), rubriek: "3"), 6)  // 4 + 2
        XCTAssertEqual(try punten(woning(3, label: true), rubriek: "3"), 8)  // 6 + 2 (max)
        XCTAssertEqual(try punten(woning(3, label: false), rubriek: "3"), 6) // alleen verwarming
    }
}

final class Rubriek4Tests: XCTestCase {
    func woning(label: Energielabel? = nil, ei: Double? = nil, opname: Dag? = Dag(2020, 1, 1),
                bouwjaar: Int = 2010, type: Woningtype = .eengezins, monument: MonumentStatus = .geen) -> WoningInvoer {
        basisWoning {
            $0.bouwjaar = bouwjaar; $0.woningtype = type; $0.monument = monument
            $0.energie = EnergieInvoer(label: label, energieIndex: ei, opnamedatum: label != nil || ei != nil ? opname : nil)
            if monument == .rijksmonument { $0.contractStart = Dag(2025, 1, 1) }
        }
    }

    func testLabelPerWoningtype() throws {
        XCTAssertEqual(try punten(woning(label: .aPlus4), rubriek: "4"), 62)
        XCTAssertEqual(try punten(woning(label: .aPlus4, type: .meergezins), rubriek: "4"), 58)
        XCTAssertEqual(try punten(woning(label: .b), rubriek: "4"), 34)
        XCTAssertEqual(try punten(woning(label: .b, type: .meergezins), rubriek: "4"), 30)
        XCTAssertEqual(try punten(woning(label: .c, type: .meergezins), rubriek: "4"), 15)
        XCTAssertEqual(try punten(woning(label: .g), rubriek: "4"), -15)
    }

    func testGeldigheidTienJaarVanafOpname() throws {
        // Peildatum 15-11-2026: opname 16-11-2016 is nog geldig, 15-11-2016 is verlopen.
        XCTAssertEqual(try punten(woning(label: .b, opname: Dag(2016, 11, 16)), rubriek: "4"), 34)
        XCTAssertEqual(try punten(woning(label: .b, opname: Dag(2016, 11, 15)), rubriek: "4"), 41) // bouwjaar 2010 -> A
    }

    func testZonderOpnamedatumTeltBouwjaar() throws {
        let w = basisWoning { $0.energie = EnergieInvoer(label: .aPlus4, opnamedatum: nil) }
        let u = try rekenmachine().bereken(w, peildatum: peildatum2026)
        XCTAssertEqual(u.rubriek("4")?.punten, 41)
        XCTAssertFalse(u.waarschuwingen.isEmpty)
    }

    func testBouwjaargrenzen() throws {
        let verwacht: [(Int, Double)] = [(2002, 41), (2001, 34), (2000, 34), (1999, 22), (1992, 22), (1991, 14),
                                         (1984, 14), (1983, -5), (1979, -5), (1978, -9), (1977, -9), (1976, -15), (1900, -15)]
        for (jaar, p) in verwacht {
            XCTAssertEqual(try punten(woning(bouwjaar: jaar), rubriek: "4"), p, "bouwjaar \(jaar)")
        }
    }

    func testEnergieIndexGrenzen() throws {
        XCTAssertEqual(try punten(woning(ei: 0.59), rubriek: "4"), 52)
        XCTAssertEqual(try punten(woning(ei: 0.61), rubriek: "4"), 47)
        XCTAssertEqual(try punten(woning(ei: 0.8), rubriek: "4"), 47)
        XCTAssertEqual(try punten(woning(ei: 0.81), rubriek: "4"), 41)
        XCTAssertEqual(try punten(woning(ei: 2.7), rubriek: "4"), -9)
        XCTAssertEqual(try punten(woning(ei: 2.71), rubriek: "4"), -15)
    }

    func testEnergieIndexPrecies06IsNietEenduidig() {
        // Tabel 4.1: A++ "EI < 0,6" en A+ "0,6 < EI ≤ 0,8"; EI = 0,6 valt in geen van beide.
        XCTAssertThrowsError(try punten(woning(ei: 0.6), rubriek: "4")) { fout in
            guard case WWSFout.nietEenduidig = fout else { return XCTFail("verwacht nietEenduidig, kreeg \(fout)") }
        }
    }

    func testMonumentGeenMinpunten() throws {
        XCTAssertEqual(try punten(woning(bouwjaar: 1900, monument: .gemeentelijkOfProvinciaal), rubriek: "4"), 0)
        XCTAssertEqual(try punten(woning(label: .f, monument: .rijksmonument), rubriek: "4"), 0)
        XCTAssertEqual(try punten(woning(label: .d, monument: .rijksmonument), rubriek: "4"), 14)
    }

    func testEnergieprestatievergoeding() throws {
        XCTAssertEqual(try punten(basisWoning { $0.energie = EnergieInvoer(label: .aPlus4, opnamedatum: Dag(2024, 1, 1), energieprestatievergoeding: true) }, rubriek: "4"), 32)
        XCTAssertEqual(try punten(basisWoning { $0.woningtype = .meergezins; $0.energie.energieprestatievergoeding = true }, rubriek: "4"), 28)
    }
}

final class Rubriek5Tests: XCTestCase {
    func keuken(_ lengte: Double, _ v: [String: Int] = [:], basis: Bool = true) -> WoningInvoer {
        basisWoning { $0.keukens = [KeukenInvoer(voldoetAanBasisniveau: basis, aanrechtLengte: lengte, voorzieningen: v)] }
    }

    func testAanrechtLengte() throws {
        XCTAssertEqual(try punten(keuken(0.99), rubriek: "5"), 0)
        XCTAssertEqual(try punten(keuken(1.0), rubriek: "5"), 4)
        XCTAssertEqual(try punten(keuken(1.99), rubriek: "5"), 4)
        XCTAssertEqual(try punten(keuken(2.0), rubriek: "5"), 7)
        XCTAssertEqual(try punten(keuken(3.5), rubriek: "5"), 7)
    }

    func testVoorzieningenBegrensdOpAanrechtpunten() throws {
        let veel = ["kookplaatInductie": 1, "vaatwasmachine": 1, "ovenElektrisch": 1, "koelkast": 1, "vrieskast": 1,
                    "magnetron": 1, "afzuiginstallatie": 1, "extraKastruimtePer60cm": 2]
        XCTAssertEqual(try punten(keuken(1.5, veel), rubriek: "5"), 8)   // 4 + max 4
        XCTAssertEqual(try punten(keuken(2.4, veel), rubriek: "5"), 14)  // 7 + max 7
        XCTAssertEqual(try punten(keuken(2.4, ["kookplaatGas": 1, "eenhandsmengkraan": 1, "kokendwaterfunctie": 1]), rubriek: "5"), 8.25)
        XCTAssertEqual(try punten(keuken(0.8, ["kookplaatInductie": 1]), rubriek: "5"), 0)
    }

    func testGeenBasisniveauGeenPunten() throws {
        XCTAssertEqual(try punten(keuken(2.5, ["koelkast": 1], basis: false), rubriek: "5"), 0)
    }

    func testOnbekendeVoorzieningGeeftFout() {
        XCTAssertThrowsError(try punten(keuken(2, ["jacuzzi": 1]), rubriek: "5"))
    }
}

final class Rubriek6Tests: XCTestCase {
    func sanitair(_ s: [SanitaireRuimteInvoer]) -> WoningInvoer { basisWoning { $0.sanitaireRuimten = s } }

    func testToiletten() throws {
        XCTAssertEqual(try punten(sanitair([.init(naam: "Wc", soort: .toiletruimte, staandeToiletten: 1)]), rubriek: "6"), 3)
        XCTAssertEqual(try punten(sanitair([.init(naam: "Wc", soort: .toiletruimte, hangendeToiletten: 1)]), rubriek: "6"), 3.75)
        XCTAssertEqual(try punten(sanitair([.init(naam: "Bad", soort: .badkamer, staandeToiletten: 1)]), rubriek: "6"), 2)
        XCTAssertEqual(try punten(sanitair([.init(naam: "Bad", soort: .badkamer, hangendeToiletten: 1)]), rubriek: "6"), 2.75)
        XCTAssertEqual(try punten(sanitair([.init(naam: "Schuur", soort: .anders, staandeToiletten: 1)]), rubriek: "6"), 0)
    }

    func testWastafelsMaximumBuitenBadkamer() throws {
        XCTAssertEqual(try punten(sanitair([.init(naam: "Slaapkamer", soort: .anders, wastafels: 2)]), rubriek: "6"), 1)
        XCTAssertEqual(try punten(sanitair([.init(naam: "Slaapkamer", soort: .anders, meerpersoonswastafels: 2)]), rubriek: "6"), 1.5)
        XCTAssertEqual(try punten(sanitair([.init(naam: "Bad", soort: .badkamer, wastafels: 2)]), rubriek: "6"), 2)
        XCTAssertEqual(try punten(sanitair([.init(naam: "Bad", soort: .badkamer, meerpersoonswastafels: 1)]), rubriek: "6"), 1.5)
    }

    func testDoucheEnBad() throws {
        XCTAssertEqual(try punten(sanitair([.init(naam: "Bad", soort: .badkamer, douches: 1)]), rubriek: "6"), 4)
        XCTAssertEqual(try punten(sanitair([.init(naam: "Bad", soort: .badkamer, baden: 1)]), rubriek: "6"), 6)
        XCTAssertEqual(try punten(sanitair([.init(naam: "Bad", soort: .badkamer, douches: 1, baden: 1)]), rubriek: "6"), 7)
    }

    func testExtraVoorzieningenBegrensd() throws {
        let alles = ["bubbelfunctieBad": 1, "volledigeDoucheafscheiding": 1, "handdoekenradiator": 1, "kastjeMetWastafel": 1,
                     "kastruimte": 1, "stopcontact": 2, "thermostatischeMengkraan": 1]
        // Douche (4) met 6,25 aan extra's: extra's begrensd op 4.
        let douche = SanitaireRuimteInvoer(naam: "Bad", soort: .badkamer, wastafels: 1, douches: 1,
                                           voldoetAanEisenBadruimte: true, voorzieningen: alles)
        XCTAssertEqual(try punten(sanitair([douche]), rubriek: "6"), 1 + 4 + 4)
        // Onder de grens: alles telt.
        let weinig = SanitaireRuimteInvoer(naam: "Bad", soort: .badkamer, wastafels: 1, douches: 1,
                                           voldoetAanEisenBadruimte: true, voorzieningen: ["handdoekenradiator": 1, "thermostatischeMengkraan": 1])
        XCTAssertEqual(try punten(sanitair([weinig]), rubriek: "6"), 1 + 4 + 1.25)
    }

    func testMaximaKastruimteEnStopcontact() throws {
        let s = SanitaireRuimteInvoer(naam: "Bad", soort: .badkamer, wastafels: 1, baden: 1, voldoetAanEisenBadruimte: true,
                                      voorzieningen: ["kastruimte": 3, "stopcontact": 4])
        XCTAssertEqual(try punten(sanitair([s]), rubriek: "6"), 1 + 6 + 0.75 + 0.5)
    }

    func testExtraVoorzieningenAlleenAlsBadruimteVoldoet() throws {
        let s = SanitaireRuimteInvoer(naam: "Bad", soort: .badkamer, wastafels: 1, douches: 1, voldoetAanEisenBadruimte: false,
                                      voorzieningen: ["handdoekenradiator": 1])
        XCTAssertEqual(try punten(sanitair([s]), rubriek: "6"), 5)
    }
}

final class Rubriek7Tests: XCTestCase {
    func testKostenPerPunt() throws {
        XCTAssertEqual(try punten(basisWoning { $0.kostenGehandicaptenvoorzieningen = 664 }, rubriek: "7"), 2)
        XCTAssertEqual(try punten(basisWoning { $0.kostenGehandicaptenvoorzieningen = 331 }, rubriek: "7"), 1)    // 0,997 -> 1
        XCTAssertEqual(try punten(basisWoning { $0.kostenGehandicaptenvoorzieningen = 0 }, rubriek: "7"), 0)
    }
}

final class Rubriek8Tests: XCTestCase {
    func tuin(_ m2: Double) -> RuimteInvoer { RuimteInvoer(naam: "Tuin", soort: .buitenruimte, oppervlakte: m2) }

    func testVoorbeeldPrive() throws {
        XCTAssertEqual(try punten(basisWoning { $0.ruimten.append(tuin(10)) }, rubriek: "8"), 5.5) // 2 + 10 × 0,35
    }

    func testVoorbeeldGemeenschappelijk() throws {
        let w = basisWoning { $0.gemeenschappelijkeBuitenruimten = [.init(naam: "Dakterras", oppervlakte: 30, adressen: 3)] }
        XCTAssertEqual(try punten(w, rubriek: "8"), 7.5)
    }

    func testGeenBuitenruimte() throws {
        XCTAssertEqual(try punten(basisWoning(), rubriek: "8"), -5)
    }

    func testAfrondingOppervlakte() throws {
        XCTAssertEqual(try punten(basisWoning { $0.ruimten.append(tuin(10.49)) }, rubriek: "8"), 5.5)
        XCTAssertEqual(try punten(basisWoning { $0.ruimten.append(tuin(10.5)) }, rubriek: "8"), 5.75) // 5,85 -> 5,75
    }

    func testMaximum15() throws {
        XCTAssertEqual(try punten(basisWoning { $0.ruimten.append(tuin(37)) }, rubriek: "8"), 15) // 14,95 -> 15 (kwartafronding)
        XCTAssertEqual(try punten(basisWoning { $0.ruimten.append(tuin(38)) }, rubriek: "8"), 15) // 15,3 -> max 15
        XCTAssertEqual(try punten(basisWoning { $0.ruimten.append(tuin(200)) }, rubriek: "8"), 15)
    }
}

final class Rubriek9Tests: XCTestCase {
    func testVoorbeeldToelichting() throws {
        // Gemeenschappelijke ruimte met keuken (20 m², verwarmd, aanrecht 7 + voorzieningen 3)
        // en gedeelde toiletruimte (2 m², hangend toilet + wastafel), 4 adressen: 38,25 / 4 = 9,5625 -> 9,50.
        let w = basisWoning {
            $0.gemeenschappelijkeRuimten = [
                .init(naam: "Ruimte A", soort: .vertrek, oppervlakte: 20, verwarmd: true,
                      keuken: KeukenInvoer(aanrechtLengte: 2.0, voorzieningen: ["kookplaatInductie": 1, "koelkast": 1, "eenhandsmengkraan": 1]),
                      adressen: 4),
                .init(naam: "Ruimte B", soort: .overigeRuimte, oppervlakte: 2, verwarmd: false,
                      sanitair: SanitaireRuimteInvoer(naam: "Toilet", soort: .toiletruimte, hangendeToiletten: 1, wastafels: 1),
                      adressen: 4),
            ]
        }
        XCTAssertEqual(try punten(w, rubriek: "9"), 9.5)
    }

    func testOngeldigAantalAdressen() {
        let w = basisWoning { $0.gemeenschappelijkeRuimten = [.init(naam: "X", soort: .vertrek, oppervlakte: 20, adressen: 0)] }
        XCTAssertThrowsError(try punten(w, rubriek: "9"))
    }
}

final class Rubriek10En12Tests: XCTestCase {
    func testVoorbeeldToelichtingParkeren() throws {
        // Tien adressen delen vijf type II-plekken met laadpaal en twee type III-plekken.
        // Toelichting rubriek 10: 48 / 10 = 4,8 -> 4,75. In de bijlage staat de laadpaal onder rubriek 12;
        // de rekenmachine boekt hem daar: rubriek 10 = 38/10 = 3,8 -> 3,75 en rubriek 12 = 10/10 = 1.
        let w = basisWoning { $0.parkeerruimten = [.init(naam: "Parkeerterrein", plekkenTypeII: 5, plekkenTypeIII: 2, plekkenMetLaadpaal: 5, adressen: 10)] }
        let u = try rekenmachine().bereken(w, peildatum: peildatum2026)
        XCTAssertEqual(u.rubriek("10")?.punten, 3.75)
        XCTAssertEqual(u.rubriek("12")?.punten, 1)
        XCTAssertEqual((u.rubriek("10")?.punten ?? 0) + (u.rubriek("12")?.punten ?? 0), 4.75)
    }

    func testTypeI() throws {
        let w = basisWoning { $0.parkeerruimten = [.init(naam: "Garage", plekkenTypeI: 1, oppervlakteTypeI: 12, adressen: 4)] }
        XCTAssertEqual(try punten(w, rubriek: "10"), 2.25)
    }

    func testZorgwoningEnVideoAanbel() throws {
        let gewoon = try rekenmachine().bereken(basisWoning(), peildatum: peildatum2026)
        let som1tot11 = gewoon.rubrieken.filter { $0.nummer != "12" }.map(\.punten).reduce(0, +)
        let zorg = try rekenmachine().bereken(basisWoning { $0.zorgwoning = true; $0.videoAanbelfunctie = true }, peildatum: peildatum2026)
        XCTAssertEqual(zorg.rubriek("12")?.punten, Afronding.rubriek(som1tot11 * 0.35 + 0.25))
    }
}
