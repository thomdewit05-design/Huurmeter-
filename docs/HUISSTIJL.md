# Huisstijl: richting C "Vriendelijk"

Gekozen door Thom op 15-11-2026. Ontwerpcanvas met de drie richtingen: zie het artifact "Huurmeter huisstijl".

**Gevoel:** toegankelijk en optimistisch: je staat sterker dan je denkt. Persoonlijk, niet kinderachtig.

## Logo

Een dak met een vinkje: "klopt mijn huur?". Bestanden: [`huisstijl/logo.svg`](huisstijl/logo.svg) (op bosgroen vlak,
ook het app-icoon) en [`huisstijl/logo-los.svg`](huisstijl/logo-los.svg) (eenkleurig, zonder vlak). In de app: `Logo()`
in `Huurmeter/Huisstijl/Huisstijl.swift`.

- Dak in limoen, vinkje in wit, op bosgroen. Eenkleurig: alles bosgroen.
- Vrije ruimte rondom: minstens de lijndikte van het dak.
- Niet uitrekken, draaien of in andere kleuren zetten. Geen logo of naam van de Huurcommissie of de overheid ernaast.

## Kleuren

| Naam | Hex | Gebruik | Donkere modus |
|------|-----|---------|---------------|
| Bosgroen | `#17402E` | hoofdkleur, koppen, knoppen, accent (tint) | `#C6F06B` |
| Limoen | `#C6F06B` | accentvlakken (segment, labels). **Nooit als tekst op wit.** | `#3D5A1E` |
| Salie | `#F3F6EF` | achtergrond van schermen | `#0F1712` |
| Wit | `#FFFFFF` | kaarten | `#1A2620` |
| Signaal | `#B42318` op `#FDE7E4` | "te veel huur" | `#FF8A80` op `#3A1714` |
| Gedempt | `#3F4D44` | bijschriften | `#B7C4BB` |

Tekstkleuren halen minstens 4,5:1 contrast op hun achtergrond.

## Letters

- **App:** SF Pro Rounded (de afgeronde systeemletter van iOS), zodat alles meeschaalt met de tekstgrootte
  van de gebruiker en er geen lettertypebestand in de app hoeft. Puntentotaal: Large Title, Heavy, bosgroen.
- **Woordmerk, App Store-beelden, website:** Plus Jakarta Sans ExtraBold (Google Fonts, Open Font License).

## Vormen

Ruime, zachte hoeken: kaarten 20–28 pt, knoppen 18 pt, labels als pil. Geen schaduwen of verlopen.
