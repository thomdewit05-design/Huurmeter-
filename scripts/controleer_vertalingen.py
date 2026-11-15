#!/usr/bin/env python3
"""Leest de door Xcode geëxporteerde Engelse XLIFF en meldt teksten zonder Engelse vertaling.

Gebruik: python3 scripts/controleer_vertalingen.py <pad naar en.xliff>
Meldt ontbrekende vertalingen als GitHub-waarschuwing; faalt niet, zodat een nieuwe tekst de build niet blokkeert.
"""
import sys
import xml.etree.ElementTree as ET

ns = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
boom = ET.parse(sys.argv[1])
ontbreekt = []
for unit in boom.iterfind(".//x:trans-unit", ns):
    bron = unit.findtext("x:source", default="", namespaces=ns)
    doel = unit.find("x:target", ns)
    bestand = unit.get("id", "")
    if doel is None or (doel.get("state") in ("new", "needs-translation")) or not (doel.text or "").strip():
        ontbreekt.append((bron, bestand))
for bron, sleutel in ontbreekt:
    print(f"::warning title=Engelse vertaling ontbreekt::{bron!r}")
print(f"{len(ontbreekt)} tekst(en) zonder Engelse vertaling.")
