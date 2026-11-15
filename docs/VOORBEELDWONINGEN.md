# Voorbeeldwoningen voor de Huurprijscheck

Voer elke woning in de officiële [Huurprijscheck van de Huurcommissie](https://www.huurcommissie.nl) in, met peildatum **15-11-2026** en precies de gegevens hieronder. Noteer het **puntentotaal** en de **maximale kale huur** (en als het kan de punten per rubriek). Stuur die naar Claude, of vul ze zelf in bij `verwacht` in het bijbehorende bestand in `WWSKit/Tests/Fixtures/`:

```json
"verwacht": { "totaal": 135, "maximaleHuur": 877.97, "rubrieken": { "1": 55, "2": 4.5 } }
```

`maximaleHuur` is `null` in de vrije sector. `rubrieken` mag je weglaten.

Ter vergelijking staat bij elke woning wat Huurmeter nu berekent. **Neem dat niet over:** de waarden moeten uit de Huurprijscheck komen.

## 01-galerijflat-1972

Galerijflat 3-kamer, bouwjaar 1972, label C (2019), balkon, aparte wc, badkamer met douche.

Bestand: `01-galerijflat-1972.json` · Huurmeter berekent nu: 135 punten, € 877,97

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 1972 |
| Type | meergezinswoning (appartement) |
| Energielabel | C (opname 2019-05-14) |
| WOZ-waarde | € 238.000,00 (waardepeildatum 2025-01-01) |
| Contract | ingang 2026-07-01, kale huur € 975,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Woonkamer | kamer (vertrek) | 24,35 | ja |  |
| Slaapkamer 1 | kamer (vertrek) | 12,10 | ja |  |
| Slaapkamer 2 | kamer (vertrek) | 8,42 | ja |  |
| Keuken | kamer (vertrek) | 6,20 | ja |  |
| Badkamer | kamer (vertrek) | 3,60 | ja |  |
| Toilet | overige ruimte | 1,10 | nee |  |
| Berging | overige ruimte | 5,80 | nee |  |
| Hal | gang/hal | 6,50 | ja |  |
| Balkon | privé buitenruimte | 4,80 |  |  |

**Keuken en sanitair**

- Keuken: aanrecht 2,10 m; gaskookplaat, afzuigkap, eenhendelmengkraan
- Toilet (aparte toiletruimte): staand toilet ×1
- Badkamer (badkamer): wastafel ×1, douche ×1, thermostaatkraan

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______


## 02-rijtjeshuis-1965

Tussenwoning 1965, geen label, zolder met vaste trap, achtertuin 42 m².

Bestand: `02-rijtjeshuis-1965.json` · Huurmeter berekent nu: 147 punten, € 960,33

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 1965 |
| Type | eengezinswoning |
| Energielabel | geen |
| WOZ-waarde | € 312.000,00 (waardepeildatum 2025-01-01) |
| Contract | ingang 2023-03-01, kale huur € 1.150,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Woonkamer | kamer (vertrek) | 28,60 | ja |  |
| Keuken | kamer (vertrek) | 8,10 | ja |  |
| Slaapkamer 1 | kamer (vertrek) | 13,40 | ja |  |
| Slaapkamer 2 | kamer (vertrek) | 9,20 | ja |  |
| Slaapkamer 3 | kamer (vertrek) | 6,30 | nee |  |
| Badkamer | kamer (vertrek) | 4,10 | ja |  |
| Zolder | overige ruimte | 14,80 | nee |  |
| Toilet | overige ruimte | 1,05 | nee |  |
| Hal | gang/hal | 4,20 | ja |  |
| Overloop | gang/hal | 3,10 | nee |  |
| Achtertuin | privé buitenruimte | 42,00 |  |  |
| Voortuin | privé buitenruimte | 9,50 |  |  |

**Keuken en sanitair**

- Keuken: aanrecht 2,60 m; keramische kookplaat, afzuigkap, elektrische oven, koelkast
- Toilet (aparte toiletruimte): staand toilet ×1
- Badkamer (badkamer): wastafel ×1, douche ×1, bad ×1, handdoekradiator, thermostaatkraan

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______


## 03-studio-amsterdam-2020

Studio 34 m² in Amsterdam, opgeleverd 2020, label A+ (2020), gemeenschappelijke daktuin.

Bestand: `03-studio-amsterdam-2020.json` · Huurmeter berekent nu: 202 punten, vrije sector

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 2020 |
| Type | meergezinswoning (appartement) |
| Energielabel | A+ (opname 2020-09-01) |
| WOZ-waarde | € 295.000,00 (waardepeildatum 2025-01-01) |
| COROP Amsterdam/Utrecht | ja |
| Open keuken | ja, verwarmd |
| Contract | ingang 2026-09-15, kale huur € 1.195,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Woon-/slaapkamer | kamer (vertrek) | 26,40 | ja |  |
| Badkamer | kamer (vertrek) | 3,90 | ja |  |
| Entree | gang/hal | 3,20 | ja |  |

**Keuken en sanitair**

- Keuken: aanrecht 1,80 m; inductiekookplaat, koelkast, afzuigkap
- Badkamer (badkamer): hangend toilet ×1, wastafel ×1, douche ×1, vaste douchewand
- Gedeelde buitenruimte: 120,00 m², 48 adressen

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______


## 04-benedenwoning-1930-monument

Benedenwoning 1930, gemeentelijk monument, label E (2018), tuin.

Bestand: `04-benedenwoning-1930-monument.json` · Huurmeter berekent nu: 145 punten, € 1.088,60 (incl. 15% monument)

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 1930 |
| Type | meergezinswoning (appartement) |
| Energielabel | E (opname 2018-02-20) |
| WOZ-waarde | € 405.000,00 (waardepeildatum 2025-01-01) |
| Monument | gemeentelijkOfProvinciaal |
| Contract | ingang 2025-01-01, kale huur € 1.350,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Voorkamer | kamer (vertrek) | 18,20 | ja |  |
| Achterkamer | kamer (vertrek) | 15,90 | ja |  |
| Slaapkamer | kamer (vertrek) | 11,30 | ja |  |
| Keuken | kamer (vertrek) | 7,40 | ja |  |
| Badkamer | kamer (vertrek) | 3,20 | ja |  |
| Kelder | overige ruimte | 6,10 | nee |  |
| Gang | gang/hal | 5,40 | ja |  |
| Tuin | privé buitenruimte | 31,00 |  |  |

**Keuken en sanitair**

- Keuken: aanrecht 1,60 m; gaskookplaat, gasoven
- Badkamer (badkamer): staand toilet ×1, wastafel ×1, douche ×1

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______


## 05-portiekflat-verlopen-label

Portiekflat 1958, label D uit 2015 (verlopen), geen buitenruimte.

Bestand: `05-portiekflat-verlopen-label.json` · Huurmeter berekent nu: 70 punten, € 437,81

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 1958 |
| Type | meergezinswoning (appartement) |
| Energielabel | D (opname 2015-06-10) |
| WOZ-waarde | € 189.000,00 (waardepeildatum 2025-01-01) |
| Contract | ingang 2026-06-01, kale huur € 850,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Woonkamer | kamer (vertrek) | 19,80 | ja |  |
| Slaapkamer | kamer (vertrek) | 10,40 | ja |  |
| Keuken | kamer (vertrek) | 5,10 | ja |  |
| Douche | kamer (vertrek) | 2,30 | ja |  |
| Toilet | overige ruimte | 0,95 | nee |  |
| Zolderberging | overige ruimte | 4,50 | nee |  |
| Hal | gang/hal | 3,00 | nee |  |

**Keuken en sanitair**

- Keuken: aanrecht 1,20 m; gaskookplaat
- Toilet (aparte toiletruimte): staand toilet ×1
- Douche (badkamer (voldoet níet aan de eisen voor extra's)): wastafel ×1, douche ×1

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______


## 06-nieuwbouw-2016

Appartement 2016, label A (2016, nog geldig), balkon, parkeergarage type I gedeeld.

Bestand: `06-nieuwbouw-2016.json` · Huurmeter berekent nu: 194 punten, vrije sector

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 2016 |
| Type | meergezinswoning (appartement) |
| Energielabel | A (opname 2016-12-01) |
| WOZ-waarde | € 335.000,00 (waardepeildatum 2025-01-01) |
| Open keuken | ja, verwarmd |
| Contract | ingang 2024-11-01, kale huur € 1.425,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Woonkamer met keuken | kamer (vertrek) | 34,50 | ja |  |
| Slaapkamer 1 | kamer (vertrek) | 13,20 | ja |  |
| Slaapkamer 2 | kamer (vertrek) | 9,10 | ja |  |
| Badkamer | kamer (vertrek) | 5,40 | ja |  |
| Toilet | overige ruimte | 1,30 | nee |  |
| Berging | overige ruimte | 6,20 | nee |  |
| Hal | gang/hal | 7,10 | ja |  |
| Balkon | privé buitenruimte | 8,60 |  |  |

**Keuken en sanitair**

- Keuken: aanrecht 2,80 m; inductiekookplaat, afzuigkap, elektrische oven, koelkast, vaatwasser, magnetron
- Toilet (aparte toiletruimte): hangend toilet ×1, wastafel ×1
- Badkamer (badkamer): wastafel ×2, douche ×1, vaste douchewand, handdoekradiator, thermostaatkraan, stopcontact
- Gedeelde parkeergarage: 30 plekken type I (eigen plek 12,50 m²), 40 adressen

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______


## 07-tussenwoning-label-a-plus

Tussenwoning 1985, label A+ (2023) na renovatie, verkoeling via warmtepomp in 2 vertrekken.

Bestand: `07-tussenwoning-label-a-plus.json` · Huurmeter berekent nu: 243 punten, vrije sector

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 1985 |
| Type | eengezinswoning |
| Energielabel | A+ (opname 2023-04-18) · koeling in label |
| WOZ-waarde | € 398.000,00 (waardepeildatum 2025-01-01) |
| Contract | ingang 2025-10-01, kale huur € 1.495,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Woonkamer | kamer (vertrek) | 31,20 | ja | vaste koeling |
| Keuken | kamer (vertrek) | 9,60 | ja |  |
| Slaapkamer 1 | kamer (vertrek) | 14,10 | ja | vaste koeling |
| Slaapkamer 2 | kamer (vertrek) | 10,20 | ja |  |
| Slaapkamer 3 | kamer (vertrek) | 7,40 | ja |  |
| Badkamer | kamer (vertrek) | 5,10 | ja |  |
| Zolder | overige ruimte | 11,40 | nee |  |
| Schuur | overige ruimte | 7,80 | nee |  |
| Toilet | overige ruimte | 1,20 | nee |  |
| Hal | gang/hal | 4,60 | ja |  |
| Overloop | gang/hal | 3,40 | ja |  |
| Achtertuin | privé buitenruimte | 55,00 |  |  |
| Voortuin | privé buitenruimte | 12,00 |  |  |

**Keuken en sanitair**

- Keuken: aanrecht 3,10 m; inductiekookplaat, afzuigkap, elektrische oven, koelkast, vriezer, vaatwasser
- Toilet (aparte toiletruimte): hangend toilet ×1, wastafel ×1
- Badkamer (badkamer): hangend toilet ×1, meerpersoonswastafel ×1, douche ×1, bad ×1, vaste douchewand, handdoekradiator, wastafel in kastje, thermostaatkraan ×2

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______


## 08-bovenwoning-zolder-zonder-trap

Bovenwoning 1910, beschermd stadsgezicht, zolder met vlizotrap, geen label.

Bestand: `08-bovenwoning-zolder-zonder-trap.json` · Huurmeter berekent nu: 112 punten, € 756,05

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 1910 |
| Type | meergezinswoning (appartement) |
| Energielabel | geen |
| WOZ-waarde | € 365.000,00 (waardepeildatum 2025-01-01) |
| Beschermd stadsgezicht | ja |
| Contract | ingang 2026-10-01, kale huur € 1.100,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Woonkamer | kamer (vertrek) | 22,40 | ja |  |
| Slaapkamer | kamer (vertrek) | 12,60 | ja |  |
| Keuken | kamer (vertrek) | 6,80 | ja |  |
| Badkamer | kamer (vertrek) | 3,40 | ja |  |
| Zolder | overige ruimte | 16,20 | nee | geen vaste trap |
| Toilet | overige ruimte | 1,00 | nee |  |
| Trap/overloop | gang/hal | 4,00 | nee |  |
| Dakterras | privé buitenruimte | 9,00 |  |  |

**Keuken en sanitair**

- Keuken: aanrecht 2,00 m; gaskookplaat, afzuigkap
- Toilet (aparte toiletruimte): staand toilet ×1
- Badkamer (badkamer): wastafel ×1, bad ×1

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______


## 09-flat-woz-2024

Flat 1995, WOZ-beschikking met waardepeildatum 2024, label B (2021), gemeenschappelijke binnentuin.

Bestand: `09-flat-woz-2024.json` · Huurmeter berekent nu: 167 punten, € 1.097,61

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 1995 |
| Type | meergezinswoning (appartement) |
| Energielabel | B (opname 2021-03-03) |
| WOZ-waarde | € 276.000,00 (waardepeildatum 2024-01-01) |
| Contract | ingang 2022-05-01, kale huur € 1.050,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Woonkamer | kamer (vertrek) | 25,70 | ja |  |
| Slaapkamer 1 | kamer (vertrek) | 11,80 | ja |  |
| Slaapkamer 2 | kamer (vertrek) | 7,90 | ja |  |
| Keuken | kamer (vertrek) | 6,60 | ja |  |
| Badkamer | kamer (vertrek) | 4,20 | ja |  |
| Toilet | overige ruimte | 1,15 | nee |  |
| Berging | overige ruimte | 4,90 | nee |  |
| Hal | gang/hal | 5,20 | ja |  |
| Balkon | privé buitenruimte | 6,20 |  |  |

**Keuken en sanitair**

- Keuken: aanrecht 2,40 m; keramische kookplaat, afzuigkap, koelkast, elektrische oven
- Toilet (aparte toiletruimte): staand toilet ×1
- Badkamer (badkamer): wastafel ×1, douche ×1, thermostaatkraan
- Gedeelde buitenruimte: 240,00 m², 32 adressen

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______


## 10-ruime-woning-hoge-woz

Hoekwoning 2005 in Utrecht, label A (2022), hoge WOZ-waarde, vrije sector.

Bestand: `10-ruime-woning-hoge-woz.json` · Huurmeter berekent nu: 305 punten, vrije sector

| Gegeven | Waarde |
|---|---|
| Bouwjaar | 2005 |
| Type | eengezinswoning |
| Energielabel | A (opname 2022-08-30) |
| WOZ-waarde | € 725.000,00 (waardepeildatum 2025-01-01) |
| COROP Amsterdam/Utrecht | ja |
| Contract | ingang 2026-04-01, kale huur € 2.250,00 |

**Ruimtes**

| Ruimte | Soort | m² | Verwarmd | Bijzonder |
|---|---|---|---|---|
| Woonkamer | kamer (vertrek) | 42,30 | ja |  |
| Keuken | kamer (vertrek) | 12,40 | ja |  |
| Slaapkamer 1 | kamer (vertrek) | 16,20 | ja |  |
| Slaapkamer 2 | kamer (vertrek) | 12,10 | ja |  |
| Slaapkamer 3 | kamer (vertrek) | 10,30 | ja |  |
| Werkkamer | kamer (vertrek) | 8,60 | ja |  |
| Badkamer | kamer (vertrek) | 7,20 | ja |  |
| Zolder | overige ruimte | 18,50 | nee |  |
| Garage | overige ruimte | 16,40 | nee |  |
| Toilet | overige ruimte | 1,40 | nee |  |
| Hal | gang/hal | 6,80 | ja |  |
| Overloop | gang/hal | 5,20 | ja |  |
| Tuin | privé buitenruimte | 85,00 |  |  |

**Keuken en sanitair**

- Keuken: aanrecht 3,60 m; inductiekookplaat, afzuigkap, elektrische oven, magnetron, koelkast, vriezer, vaatwasser, kokendwaterkraan
- Toilet (aparte toiletruimte): hangend toilet ×1, wastafel ×1
- Badkamer (badkamer): hangend toilet ×1, meerpersoonswastafel ×1, douche ×1, bad ×1, bubbelbad, vaste douchewand, handdoekradiator, wastafel in kastje, stopcontact ×2, thermostaatkraan ×2

**Uitkomst Huurprijscheck:** totaal ______ punten · maximale huur € ______

