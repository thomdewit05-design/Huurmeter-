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

def vraag(pad):
    verzoek = urllib.request.Request("https://api.appstoreconnect.apple.com" + pad,
                                     headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(verzoek, timeout=30) as r:
            return r.status, ""
    except urllib.error.HTTPError as e:
        try:
            fouten = json.loads(e.read()).get("errors", [])
            return e.code, "; ".join(f"{f.get('code')}: {f.get('detail')}" for f in fouten)
        except Exception:
            return e.code, ""

# /v1/apps werkt met elke rol; certificaten, bundel-ID's en profielen (nodig voor automatisch ondertekenen)
# alleen met de rol Admin (of App Manager met toegang tot certificaten).
mislukt = False
for pad, wat in [("/v1/apps?limit=1", "apps"), ("/v1/bundleIds?limit=1", "bundel-ID's"),
                 ("/v1/certificates?limit=1", "certificaten"), ("/v1/profiles?limit=1", "profielen")]:
    status, uitleg = vraag(pad)
    print(f"{wat}: HTTP {status} {uitleg}")
    if status != 200:
        mislukt = True
        print(f"::error title=API-sleutel::Geen toegang tot {wat} (HTTP {status}). {uitleg} "
              "Automatisch ondertekenen vraagt een teamsleutel met de rol Admin.")
if mislukt:
    sys.exit(1)
print("De sleutel heeft toegang tot alles wat Xcode nodig heeft.")
