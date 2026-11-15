# Huurmeter

iOS-app die met de camera een huurwoning inmeet en uitrekent hoeveel WWS-punten die heeft, wat de maximale kale huur
is en hoeveel de huurder te veel betaalt. Zie [HUURMETER_SPEC.md](HUURMETER_SPEC.md).

## Stand

**Fase 1 (rekenregels) is gebouwd en wacht op overleg.** Er is nog geen UI.

- `WWSKit/`: Swift-package zonder UI-afhankelijkheden (iOS 17+, ook te bouwen op macOS en Linux).
- `WWSKit/Sources/WWSKit/rules/wws-zelfstandig-2026.json`: alle puntenwaarden en de huurtabel 2026, elk met bron.
- `docs/BRONNEN.md`: geraadpleegde officiële bronnen.
- `docs/OPEN-PUNTEN.md`: wat niet geverifieerd is en welke interpretaties bevestigd moeten worden.

## Testen

```bash
cd WWSKit && swift test
```

De unit-tests (per rubriek, met grensgevallen en de rekenvoorbeelden uit de officiële toelichting) slagen.
`FixtureTests.testFixturesKomenOvereenMetHuurprijscheck` faalt bewust zolang de verwachte uitkomsten van de tien
voorbeeldwoningen in `WWSKit/Tests/Fixtures/` niet zijn ingevuld vanuit de officiële Huurprijscheck. De foutmelding
toont per woning wat WWSKit berekent.

## Gebruik

```swift
import WWSKit

let peildatum = Dag(2026, 11, 15)
let rekenmachine = try Rekenmachine(peildatum: peildatum)   // kiest het regelbestand dat op de peildatum geldt
let uitkomst = try rekenmachine.bereken(woning, peildatum: peildatum)
uitkomst.totaal            // punten
uitkomst.segment           // .sociaal / .midden / .vrij
uitkomst.maximaleHuur      // incl. prijsopslag, nil in de vrije sector
uitkomst.rubrieken         // punten en tussenstappen per rubriek
Uitkomst.disclaimer        // "Indicatie op basis van uw invoer. ..."
```

Huurmeter is niet van of namens de overheid.
