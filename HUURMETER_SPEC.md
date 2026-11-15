# Huurmeter — bouwspecificatie voor Claude Code

Werknaam: Huurmeter (controleer vóór release of de naam vrij is in de App Store).

## 1. Doel

Een iOS-app waarmee een huurder in Nederland in ongeveer tien minuten uitrekent
hoeveel punten zijn woning heeft volgens het woningwaarderingsstelsel (WWS),
wat de maximale kale huur is, en hoeveel hij te veel betaalt. De app meet de
vertrekken in met de camera (LiDAR) en levert een brief en een dossier op.

Verschil met bestaande tools (Huurprijscheck van de Huurcommissie, HuurScan):
die zijn invulformulieren. Huurmeter meet zelf in, legt bewijs vast en maakt
de vervolgstap klaar.

## 2. Afbakening eerste versie (MVP)

Wel:
- Alleen zelfstandige woningen (WWS zelfstandige woonruimte).
- Inmeten met RoomPlan, met handmatige invoer als terugvaloptie.
- Puntentelling per rubriek, maximale huur, verschil met huidige kale huur.
- PDF-dossier en conceptbrief aan de verhuurder.
- Nederlands. Alles lokaal op het toestel, geen account.

Niet (latere fases):
- Kamers / onzelfstandige woonruimte (WWSO), woonwagens.
- Automatisch ophalen van energielabel en WOZ-waarde.
- Verhuurdersmodus, Engels, iPad-layout, delen tussen toestellen.

## 3. Techniek

- Swift, SwiftUI, minimaal iOS 17, alleen iPhone.
- SwiftData voor opslag.
- RoomPlan voor inmeten. Controleer `RoomCaptureSession.isSupported`; zonder
  LiDAR direct de handmatige invoer tonen, zonder foutmelding.
- PDFKit voor het dossier, StoreKit 2 voor de eenmalige aankoop.
- Geen eigen server, geen externe SDK's, geen analytics.
- Architectuur: MVVM. De rekenregels staan in een losse Swift-package
  `WWSKit` zonder UI-afhankelijkheden, zodat ze volledig te testen zijn.

## 4. De rekenregels (belangrijkste onderdeel)

HARDE REGEL: verzin geen puntenwaarden. Elke waarde komt uit een officiële
bron en krijgt een bronverwijzing in de data. Ontbreekt een waarde, zet dan
een TODO en vraag het na, in plaats van te schatten.

Bronnen:
- Besluit huurprijzen woonruimte, bijlage I (wetten.overheid.nl/BWBR0003237).
- Beleidsboek waarderingsstelsel zelfstandige woonruimte (Huurcommissie).
- Maximale-huurprijstabel van het lopende jaar (Huurcommissie / Rijksoverheid).

Opzet:
- Regels staan als data in `rules/wws-zelfstandig-<jaar>.json`, niet in code.
  Elk jaar komt er één bestand bij. De app kiest het bestand op peildatum.
- `WWSKit` leest het bestand en rekent per rubriek. Uitvoer: punten per
  rubriek, tussenstappen in gewone taal, totaal, segment, maximale huur.
- Afronding gebeurt precies zoals de bron voorschrijft; leg per rubriek vast
  waar wordt afgerond.

Rubrieken om te implementeren (waarden uit de bron halen):
1. Oppervlakte van vertrekken
2. Oppervlakte van overige ruimten
3. Verwarming en koeling
4. Energieprestatie (label of Energie-Index, afhankelijk van type en datum;
   een verlopen label telt niet mee, dan geldt de bouwjaartabel)
5. Keuken (aanrechtlengte plus extra voorzieningen)
6. Sanitair
7. Woonvoorzieningen voor gehandicapten
8. Buitenruimten (privé en gemeenschappelijk)
9. Gemeenschappelijke ruimten en voorzieningen
10. WOZ-waarde (inclusief minimumwaarde en de begrenzing van het aandeel
    WOZ-punten)
11. Bijzondere voorzieningen (zorgwoning)
12. Prijsopslagen (onder meer monument en nieuwbouw)

Segmenten ter controle voor 2026 (verifieer tegen de officiële tabel):
- t/m 143 punten: sociale huur, maximum €932,93
- 144 t/m 186 punten: middenhuur, maximum €1.228,07
- vanaf 187 punten: vrije sector, geen maximum

Tests:
- Unit-tests per rubriek met grensgevallen (net onder en boven elke drempel).
- Minimaal 10 volledige voorbeeldwoningen in `Tests/Fixtures/`. De verwachte
  uitkomsten vult Thom in door dezelfde woningen in de officiële
  Huurprijscheck in te voeren. De build mag pas groen zijn als alle tien
  exact overeenkomen.

## 5. Schermen

1. Start: lijst met opgeslagen woningen, knop "Nieuwe woning".
2. Adres: postcode en huisnummer, automatisch aanvullen van straat, plaats
   en bouwjaar via PDOK Locatieserver / BAG (gratis; controleer de actuele
   documentatie). Handmatig aanpasbaar.
3. Huur: kale huur per maand, ingangsdatum contract, type woning.
4. Ruimtes: lijst met vertrekken en overige ruimten. Per ruimte "Scannen" of
   "Handmatig". Na een scan: naam, type (vertrek / overige ruimte /
   buitenruimte) en oppervlakte tonen, alles aanpasbaar.
5. Voorzieningen: korte vragen per rubriek (verwarming, keuken, sanitair,
   buitenruimte), elk met optionele foto als bewijs. Alleen vragen tonen die
   punten kunnen opleveren.
6. Energie en WOZ: label en registratiedatum invoeren, WOZ-waarde invoeren,
   met een link naar ep-online.nl en wozwaardeloket.nl om het op te zoeken.
7. Uitkomst: punten, segment, maximale huur, verschil per maand en per jaar.
   Uitklapbaar per rubriek met de tussenstappen. Bij een contract jonger dan
   zes maanden: een teller met de resterende dagen om huur terug te vragen.
8. Actie (betaald): PDF-dossier en conceptbrief, delen via de deelknop.
9. Info: uitleg, bronnen, disclaimer, privacy.

## 6. Inmeten met RoomPlan

- Eén scan per ruimte, geen hele woning in één keer.
- Oppervlakte berekenen uit de vloerpolygoon van `CapturedRoom`, niet uit
  lengte maal breedte van de omhullende rechthoek.
- De meetregels van het WWS volgen (onder meer delen met een lage vrije
  hoogte en vaste kasten). Haal de precieze regels uit het Beleidsboek en leg
  ze vast in `WWSKit`; laat de gebruiker de schuine-dak-situatie zelf
  aangeven, want RoomPlan herkent die niet betrouwbaar.
- Toon altijd de gemeten waarde met één decimaal en laat de gebruiker
  corrigeren. Bewaar of een waarde gescand of handmatig is; dat komt in het
  dossier.
- Bewaar een plattegrondafbeelding per ruimte voor de PDF.

## 7. Datamodel (SwiftData)

- `Woning`: adres, bouwjaar, type, kaleHuur, contractStart, wozWaarde,
  energielabel, labelDatum, aangemaakt, gewijzigd.
- `Ruimte`: naam, soort, oppervlakte, bron (scan/handmatig), plattegrond,
  relatie naar Woning.
- `Voorziening`: rubriek, sleutel, waarde, foto, relatie naar Woning.
- `Berekening`: regelsetJaar, puntenPerRubriek, totaal, maxHuur, datum,
  relatie naar Woning.

## 8. Verdienmodel

- Gratis: alles tot en met de uitkomst.
- Eenmalige aankoop (richtprijs €9,99, niet-verbruikbaar): PDF-dossier en
  brief, voor onbeperkt veel woningen.
- Geen abonnement, geen advertenties.

## 9. Juridisch en App Store

- Overal waar de uitkomst staat: "Indicatie op basis van uw invoer. Alleen de
  Huurcommissie of de rechter stelt de huurprijs bindend vast."
- De app is niet van of namens de overheid; vermeld dat in de Info en in de
  App Store-tekst, en gebruik geen logo's of namen van de Huurcommissie in
  icoon of schermafbeeldingen.
- Camera-toestemming met duidelijke reden. Privacy-label: geen gegevens
  verzameld.

## 10. Bouwvolgorde

Fase 1 — `WWSKit` met regelbestand 2026 en alle tests. Geen UI.
Fase 2 — Schermen 1 t/m 7 met handmatige invoer.
Fase 3 — RoomPlan-scan en plattegrondafbeelding.
Fase 4 — PDF-dossier, brief en StoreKit.
Fase 5 — Afwerking: toegankelijkheid, lege toestanden, App Store-materiaal.

Rond elke fase af met werkende tests en een korte samenvatting van open
punten voordat de volgende begint.

## 11. Open punten voor Thom

- Tien voorbeeldwoningen door de officiële Huurprijscheck halen (fase 1).
- Controleren of EP-Online en het WOZ-waardeloket een bruikbare koppeling
  bieden voor een latere versie.
- Brieftekst laten nalezen door iemand met huurrechtkennis.
- Apple Developer-account en bundel-ID.

## 12. Eerste opdracht aan Claude Code

"Lees HUURMETER_SPEC.md. Begin met fase 1: maak de Swift-package WWSKit en
het regelbestand voor 2026. Haal elke waarde uit de officiële bronnen in
hoofdstuk 4 en noteer de bron erbij. Schat niets; maak een lijst van alles
wat je niet kon verifiëren en stop daarna voor overleg."
