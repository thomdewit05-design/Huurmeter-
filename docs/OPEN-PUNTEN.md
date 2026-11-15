# Open punten

Stand: 15-11-2026. Geraadpleegde bronnen: zie [BRONNEN.md](BRONNEN.md).

## A. Niet geverifieerd (waarde staat er, maar niet uit een geraadpleegde officiële tekst)

| # | Wat | Waar | Status |
|---|-----|------|--------|
| A1 | Datum inwerkingtreding Wet betaalbare huur = **2024-07-01** | `prijsopslagen.inwerkingtredingWetBetaalbareHuur` | Art. 8a noemt alleen "het tijdstip van inwerkingtreding". Gemarkeerd `geverifieerd: false`; de app toont een waarschuwing als de datum gebruikt wordt. Graag bevestigen (Staatsblad / inwerkingtredingsbesluit). |
| A2 | Segmentgrenzen **143 / 186 punten** | `segmenten` | Huisvestingswet 2014 art. 1 definieert middenhuur via twee bedragen (art. 13 lid 1 onder a Wet op de huurtoeslag; art. 3 lid 2 Uitvoeringswet huurprijzen woonruimte). Die bedragen voor 2026 heb ik niet opgezocht. De puntgrenzen komen uit de spec en kloppen met de huurtabel (143 → € 932,93; 186 → € 1.228,07) en met 11.3 (187/186). |
| A3 | Verwachte uitkomsten van de tien voorbeeldwoningen | `WWSKit/Tests/Fixtures/*.json`, veld `verwacht` | **Thom**: invoeren in de officiële Huurprijscheck en het totaal, de maximale huur en (liefst) de punten per rubriek invullen. Tot dan faalt `FixtureTests` (zo bedoeld). |
| A4 | Beleidsboek waarderingsstelsel zelfstandige woonruimte (Huurcommissie) | – | **Niet geraadpleegd.** Alles is gebaseerd op de wettekst en de toelichting. Het Beleidsboek kan veel van de punten in B oplossen; het is ook de bron voor de meetregels in fase 3. |

## B. De bron is hier niet eenduidig; gekozen interpretatie graag bevestigen

1. **Rubrieknummering wijkt af van de spec.** De wet nummert: 10 = gemeenschappelijke parkeerruimten,
   11 = WOZ-waarde, 12 = bijzondere voorzieningen (zorgwoning, video-aanbel, laadpaal). Prijsopslagen zijn
   geen rubriek maar een opslag op de maximale huur (art. 8a). WWSKit volgt de wet.
2. **Energie-Index precies 0,6** valt in geen klasse (A++: "EI < 0,6"; A+: "0,6 < EI ≤ 0,8").
   WWSKit geeft dan de fout `nietEenduidig`, in plaats van te gokken.
3. **Laadpaal**: in de tabel valt die onder rubriek 12, in de toelichting bij rubriek 10 wordt hij in rubriek 10
   meegeteld. Gekozen: rubriek 12. Verschil zit alleen in de afronding per rubriek en in de grondslag voor de zorgwoningopslag.
4. **WOZ-minimumwaarde (€ 85.806)**: de tekst zegt "en anders een minimumwaarde". Gekozen: alleen als terugval
   (geen WOZ-waarde en geen taxatie), **niet** als ondergrens bij een lagere WOZ-waarde. De spec spreekt van "inclusief minimumwaarde"; graag checken.
5. **WOZ per m² afronden op centen**: staat niet in de regel, maar volgt uit rekenvoorbeeld 1 van de toelichting
   (€ 398.000 / 70 m² → 23,49466942). Overgenomen.
6. **11.2 uitzonderingsregel**: de bijlage zegt "onderdelen 1 tot en met 10 en 12", de toelichting
   "1 tot en met 8 en 12". Gekozen: de bijlage.
7. **11.2 en zorgwoning lopen in een cirkel** (de zorgopslag rekent met 11.1; 11.2 rekent met 12).
   Gekozen: zorgopslag op 11.1 vóór de verhoging naar 40 punten.
8. **+50 punten rijksmonument** (contract vóór de Wet betaalbare huur, art. 8a lid 2): opgeteld bij het
   eindtotaal, ná de cap op de WOZ.
9. **"Woning tot 40 m²"** (11.1 onder a): opgevat als kleiner dan 40 m², na afronding op hele m².
10. **Rubriek 7 (€ 332 per punt)**: gekozen voor gewone deling gevolgd door afronding op 0,25 (dus geen hele
    punten per volle € 332).
11. **Rubriek 6**: de grens voor extra voorzieningen (maximaal de punten voor douche/bad) is toegepast op de hele
    woning, niet per badkamer. Meerdere baden en douches in één ruimte worden in paren van 7 punten geteld.
    Mengkranen tellen per stuk. Wastafel en meerpersoonswastafel in hetzelfde vertrek hebben elk een eigen maximum.
12. **Rubriek 8 en 9**: als gedeelde ruimten verschillende aantallen adressen hebben, wordt de oppervlakte per
    ruimte op hele m² afgerond (de toelichting zegt "per categorie").
13. **Rubriek 3**: "woningen die zonder koeling voldoende koel kunnen blijven" (NTA 8800-label met oververhittingsrisico
    "laag") kunnen ook tot 2 punten krijgen. Niet geïmplementeerd, want onduidelijk hoeveel punten per wat.
14. **Geldigheid energielabel**: het Bbl rekent tien jaar vanaf de **datum van opname**, niet vanaf de
    registratiedatum (spec, scherm 6). De invoer vraagt dus om de opnamedatum. Of labels van vóór het Bbl
    (NEN 7120, Energie-Index) een andere geldigheid hadden, is niet nagezocht.
15. **Contracten van vóór de Wet betaalbare huur**: art. 12a laat het oude art. 2 gelden. Voor die contracten
    kunnen andere segmentgrenzen gelden (oude liberalisatiegrens). WWSKit waarschuwt, maar rekent dat niet door.
16. **Boven 186 punten**: de tabel loopt tot 250 punten, maar WWSKit geeft dan "vrije sector, geen maximum".
17. **Afronding van de maximale huur na prijsopslag**: niet voorgeschreven. Gekozen: op hele centen (0,5 cent naar boven).
18. **Eisen aan een vertrek** (breedte 1,50 m over 80%, vrije hoogte 2,10 m, raam 0,5 m², ventilatie, stopcontact):
    WWSKit controleert alleen de minimumoppervlakte; de rest moet de gebruiker in de app aangeven. In de bron is
    het stuk "50% van de oppervlakte of over een oppervlakte van 11 m²" slecht opgemaakt.
19. **Oppervlakte type I-parkeerplek in de WOZ-oppervlakte**: bij een gedeelde garage is onduidelijk welke
    oppervlakte meetelt. De invoer neemt de opgegeven oppervlakte over (bedoeld: de eigen plek).
20. **Rubriek 9**: maximum en koeling uit rubriek 3, en rubriek 7, zijn voor gedeelde ruimten niet uitgewerkt.

## C. Vooruitkijken

- Op wetten.overheid.nl staan al wijzigingen aangekondigd per **01-01-2027** voor Bijlage I en de
  Uitvoeringsregeling. Daarvoor komt `wws-zelfstandig-2027.json` erbij; de app kiest het bestand op peildatum.
- Fase 2 kan pas als A3 is ingevuld en de groene build er is, of als je besluit fase 2 alvast te starten.

## D. Fase 2 (schermen 1 t/m 7)

1. **Niet op een echt toestel getest.** De app-code is gecompileerd via GitHub Actions (macOS, Xcode), maar
   niemand heeft hem nog in de simulator of op een iPhone doorgelopen. Graag een eerste rondje in Xcode.
2. **Bouwjaar uit de BAG**: bij meerdere panden neemt de app het oudste bouwjaar. Bij verbouw tot woning kan
   een ander jaar gelden; de gebruiker kan het aanpassen.
3. **COROP-gebied Amsterdam/Utrecht** wordt aan de gebruiker gevraagd (alleen bij kleine woningen uit 2018 t/m
   2022). Automatisch afleiden uit de gemeente kan later met een gemeente-COROP-tabel.
4. **Sanitair**: de vragenlijst ondersteunt maximaal twee badkamers en telt wastafels in andere kamers als één per kamer.
5. **Gedeelde ruimtes en parkeren**: één gedeelde woonruimte, één gedeelde berging en één groep parkeerplekken.
   Complexere situaties (verschillende aantallen adressen per plek) vragen later een uitgebreider scherm.
6. **Privacy**: "Adres opzoeken" stuurt postcode en huisnummer naar PDOK. Dat staat in Info; voor het
   App Store-privacylabel is dat geen gegevensverzameling door de app zelf, maar laat dit nog checken.
7. **Bundel-ID en team**: voorlopig `nl.huurmeter.app` (zie open punt in de spec).

## E. Fase 3 (inmeten met RoomPlan)

1. **Niet op een toestel met LiDAR getest.** De scan is gecompileerd (CI), maar RoomPlan werkt alleen op een
   iPhone Pro met LiDAR. Graag een proefscan van een rechthoekige én een L-vormige kamer, en de uitkomst
   vergelijken met een rolmaat.
2. **Meethoogte**: het WWS meet van muur tot muur op 1,50 m hoogte. RoomPlan geeft de vloerpolygoon; bij rechte
   muren is dat hetzelfde. Plinten, scheve muren of een uitstekende vensterbank kunnen een klein verschil geven.
3. **Schuin dak en schachten** vult de gebruiker zelf in als af te trekken m² (spec §6). De app rekent die
   oppervlakte niet zelf uit de scan.
4. **Meerdere vloervlakken** (bijv. een kamer met een opstap): de app telt alle vloervlakken op en tekent het grootste.
5. **Plattegrond**: één PNG per ruimte (1200 × 1200), bewaard op het toestel voor het dossier van fase 4.
   Deuren zijn als onderbreking in de muur getekend, ramen blauw.
6. **Beleidsboek** (A4) is nog steeds niet geraadpleegd; de meetregels komen uit de toelichting in het Besluit
   (opgenomen als `meetregels` in het regelbestand).
