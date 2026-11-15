# Huurmeter

iOS-app die met de camera een huurwoning inmeet en uitrekent hoeveel WWS-punten die heeft, wat de maximale kale huur
is en hoeveel de huurder te veel betaalt. Zie [HUURMETER_SPEC.md](HUURMETER_SPEC.md).

## Stand

- **Fase 1 (rekenregels)**: klaar, wacht op de verwachte uitkomsten van de tien voorbeeldwoningen.
- **Fase 2 (schermen 1 t/m 7, handmatige invoer)**: gebouwd.
- **Fase 3 (inmeten met RoomPlan, plattegrond per ruimte)**: gebouwd, nog niet op een toestel met LiDAR getest.
- **Fase 4 (PDF-dossier, conceptbrief, eenmalige aankoop via StoreKit 2)**: gebouwd. Aankoop testen kan in de simulator met `Configuratie/Huurmeter.storekit`.

| Map | Inhoud |
|-----|--------|
| `WWSKit/` | Rekenregels (Swift-package zonder UI). Regelbestand: `Sources/WWSKit/rules/wws-zelfstandig-2026.json`. |
| `HuurmeterCore/` | Logica achter de schermen zonder UI: PDOK-adres en bouwjaar, vragenlijst, omzetting naar WWSKit, teksten. |
| `Huurmeter/` | De iOS-app (SwiftUI, SwiftData, iOS 17+, alleen iPhone). |
| `project.yml` | XcodeGen-beschrijving van het Xcode-project. |
| `docs/` | Bronnen en open punten. |

## App openen in Xcode

```bash
brew install xcodegen
```

```bash
xcodegen generate && open Huurmeter.xcodeproj
```

Kies in Xcode bij *Signing & Capabilities* je eigen team; het bundel-ID `nl.huurmeter.app` is voorlopig.

## Testen

```bash
cd WWSKit && swift test
```

```bash
cd HuurmeterCore && swift test
```

GitHub Actions (`.github/workflows/ci.yml`) bouwt bij elke push de app en draait alle tests. De job
"Voorbeeldwoningen = Huurprijscheck" vergelijkt de voorbeeldwoningen in `WWSKit/Tests/Fixtures/` met de officiële
Huurprijscheck. Woningen zonder ingevulde uitkomst worden overgeslagen; een ingevulde uitkomst die afwijkt, faalt.

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
