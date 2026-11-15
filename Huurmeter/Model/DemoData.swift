import Foundation
import SwiftData
import WWSKit
import HuurmeterCore

/// Voorbeeldwoning voor schermafbeeldingen en UI-tests. Alleen actief met de opstartvlag
/// `-demo` in een ontwikkelbuild (DEBUG); de gegevens staan dan in een tijdelijke opslag en raken echte gegevens niet.
enum DemoData {
    static var actief: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-demo")
        #else
        return false
        #endif
    }

    /// Eén tijdelijke opslag voor de hele looptijd van de app.
    @MainActor static let container: ModelContainer = maakContainer()

    @MainActor
    private static func maakContainer() -> ModelContainer {
        let schema = Schema([Woning.self, Ruimte.self, Voorziening.self, Berekening.self, Gebrek.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        vulIn(container.mainContext)
        return container
    }

    @MainActor
    static func vulIn(_ context: ModelContext) {
        let w = Woning()
        context.insert(w)
        w.postcode = "1234AB"
        w.huisnummer = "10"
        w.straat = "Galerijstraat"
        w.plaats = "Voorbeeldstad"
        w.bouwjaar = 1972
        w.woningtype = .meergezins
        w.kaleHuur = 975
        // Contract van twee maanden geleden, zodat de teller voor de aanvangshuur zichtbaar is.
        w.contractStart = Calendar.current.date(byAdding: .month, value: -2, to: Date())
        w.energielabel = .c
        w.labelDatum = Calendar.current.date(from: DateComponents(year: 2019, month: 5, day: 14))
        w.wozWaarde = 238_000
        w.wozPeildatum = Dag(2025, 1, 1).datum()

        let ruimten: [(String, RuimteFunctie, RuimteSoort, Double, Bool)] = [
            ("Woonkamer", .woonkamer, .vertrek, 24.35, true),
            ("Slaapkamer 1", .slaapkamer, .vertrek, 12.10, true),
            ("Slaapkamer 2", .slaapkamer, .vertrek, 8.42, true),
            ("Keuken", .keuken, .vertrek, 6.20, true),
            ("Badkamer", .badkamer, .vertrek, 3.60, true),
            ("Toilet", .toilet, .overigeRuimte, 1.10, false),
            ("Berging", .berging, .overigeRuimte, 5.80, false),
            ("Hal", .gang, .verkeersruimte, 6.50, true),
            ("Balkon", .overig, .buitenruimte, 4.80, false),
        ]
        for (i, r) in ruimten.enumerated() {
            let ruimte = Ruimte(naam: r.0, functie: r.1, volgorde: i)
            ruimte.soort = r.2
            ruimte.oppervlakte = r.3
            ruimte.verwarmd = r.4
            w.ruimten.append(ruimte)
        }
        // De woonkamer als gescande, L-vormige ruimte met plattegrond.
        if let woonkamer = w.ruimten.first(where: { $0.naam == "Woonkamer" }) {
            let scan = ScanResultaat(
                vloer: [Punt2(0, 0), Punt2(6.1, 0), Punt2(6.1, 2.5), Punt2(3.4, 2.5), Punt2(3.4, 4.3), Punt2(0, 4.3)],
                muren: [Lijnstuk(van: Punt2(0, 0), naar: Punt2(6.1, 0)), Lijnstuk(van: Punt2(6.1, 0), naar: Punt2(6.1, 2.5)),
                        Lijnstuk(van: Punt2(6.1, 2.5), naar: Punt2(3.4, 2.5)), Lijnstuk(van: Punt2(3.4, 2.5), naar: Punt2(3.4, 4.3)),
                        Lijnstuk(van: Punt2(3.4, 4.3), naar: Punt2(0, 4.3)), Lijnstuk(van: Punt2(0, 4.3), naar: Punt2(0, 0))],
                deuren: [Lijnstuk(van: Punt2(1.2, 4.3), naar: Punt2(2.1, 4.3))],
                ramen: [Lijnstuk(van: Punt2(1.0, 0), naar: Punt2(4.6, 0))])
            woonkamer.neemScanOver(scan, plattegrond: Plattegrond.png(scan, naam: "Woonkamer"))
        }

        let antwoorden: [(String, String, Double)] = [
            ("5", "keuken.aanrecht", 2.1), ("5", "keuken.kookplaatGas", 1), ("5", "keuken.afzuiginstallatie", 1),
            ("5", "keuken.eenhandsmengkraan", 1), ("6", "toilet.staand", 1), ("6", "badkamer1.wastafels", 1),
            ("6", "badkamer1.douches", 1), ("6", "badkamer1.thermostatischeMengkraan", 1),
        ]
        for a in antwoorden { w.zetAntwoord(a.1, a.2, rubriek: a.0) }
    }
}
