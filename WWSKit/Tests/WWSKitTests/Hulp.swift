import XCTest
@testable import WWSKit

let peildatum2026 = Dag(2026, 11, 15)

func regels2026() throws -> Regelset { try RegelsetBibliotheek.regelset(op: peildatum2026) }
func rekenmachine() throws -> Rekenmachine { Rekenmachine(regels: try regels2026()) }

/// Minimale geldige woning: één vertrek van 20 m², bouwjaar 2010, eengezins, WOZ € 200.000 (peildatum 2025).
func basisWoning(_ aanpassen: (inout WoningInvoer) -> Void = { _ in }) -> WoningInvoer {
    var w = WoningInvoer(
        bouwjaar: 2010, woningtype: .eengezins,
        ruimten: [RuimteInvoer(naam: "Woonkamer", soort: .vertrek, functie: .woonkamer, oppervlakte: 20)],
        woz: WozInvoer(waarde: 200_000, waardepeildatum: Dag(2025, 1, 1)))
    aanpassen(&w)
    return w
}

func punten(_ w: WoningInvoer, rubriek: String, file: StaticString = #filePath, line: UInt = #line) throws -> Double {
    let u = try rekenmachine().bereken(w, peildatum: peildatum2026)
    return try XCTUnwrap(u.rubriek(rubriek), file: file, line: line).punten
}
