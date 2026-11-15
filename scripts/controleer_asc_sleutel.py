#!/usr/bin/env python3
"""Controleert de App Store Connect API-sleutel zonder geheimen te tonen.

Leest ASC_KEY_ID, ASC_ISSUER_ID en het pad naar AuthKey.p8, maakt een token en vraagt /v1/apps op.
Meldt alleen vormkenmerken (lengte, kop/voet aanwezig) en het antwoord van Apple.
"""
import json, os, re, sys, time, urllib.request, urllib.error
import jwt  # PyJWT

key_id = os.environ.get("ASC_KEY_ID", "").strip()
issuer = os.environ.get("ASC_ISSUER_ID", "").strip()
pad = sys.argv[1]
p8 = open(pad).read()

problemen = []
if not re.fullmatch(r"[A-Z0-9]{10}", key_id):
    problemen.append(f"ASC_KEY_ID heeft niet de vorm van een Key ID (10 hoofdletters/cijfers); lengte nu {len(key_id)}.")
if not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", issuer):
    problemen.append(f"ASC_ISSUER_ID is geen UUID (vorm xxxxxxxx-xxxx-...); lengte nu {len(issuer)}. "
                     "Let op: bij een 'individuele sleutel' is er geen Issuer ID; gebruik een teamsleutel.")
if "-----BEGIN PRIVATE KEY-----" not in p8 or "-----END PRIVATE KEY-----" not in p8:
    problemen.append("ASC_KEY_P8 mist de regel -----BEGIN PRIVATE KEY----- of -----END PRIVATE KEY-----.")
regels = [r for r in p8.strip().splitlines() if r.strip()]
print(f"p8: {len(regels)} regels, {len(p8)} tekens.")
for p in problemen:
    print(f"::error title=API-sleutel::{p}")
if problemen:
    sys.exit(1)

try:
    token = jwt.encode({"iss": issuer, "iat": int(time.time()), "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"},
                       p8, algorithm="ES256", headers={"kid": key_id, "typ": "JWT"})
except Exception as e:
    print(f"::error title=API-sleutel::Het .p8-bestand is niet te lezen als privésleutel ({type(e).__name__}). Plak de volledige inhoud opnieuw.")
    sys.exit(1)

verzoek = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/apps?limit=1",
                                 headers={"Authorization": f"Bearer {token}"})
try:
    with urllib.request.urlopen(verzoek, timeout=30) as r:
        print(f"Apple antwoordt {r.status}: de sleutel werkt.")
except urllib.error.HTTPError as e:
    try:
        fouten = json.loads(e.read()).get("errors", [])
        uitleg = "; ".join(f"{f.get('code')}: {f.get('detail')}" for f in fouten)
    except Exception:
        uitleg = ""
    print(f"::error title=API-sleutel::Apple weigert de sleutel (HTTP {e.code}). {uitleg} "
          "Controleer of Key ID en Issuer ID bij deze sleutel horen, of de sleutel actief is en de rol Admin heeft.")
    sys.exit(1)
