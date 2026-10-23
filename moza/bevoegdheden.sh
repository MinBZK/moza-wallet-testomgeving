#!/usr/bin/env bash
#
# bevoegdheden.sh
#
# Zet de KVK-bevoegdheden uit attestaties/bevoegdheden.json klaar als attestatie van de fictieve
# uitgever "KVK Demo": certificaten (alleen als ze er nog niet zijn), per onderneming een usecase in
# de issuance_server, de gegevens per houder (BSN) in demo_issuer.json en de links voor "bevoegdheid
# toevoegen" in MOZA_JSON. Draait bij de inrichting (inrichten.sh) en bij elke start (start), zodat
# een nieuwe houder of onderneming na een uitrol meteen geldt, zonder nieuw volume. Een houder is een
# BSN, of een object met "bsn" en eventueel een eigen "functie" en "bevoegdheid".

set -euo pipefail

NL_WALLET_DIR="${NL_WALLET_DIR:-/opt/nl-wallet}"
TARGET_DIR="${NL_WALLET_DIR}/scripts/devenv/target"
CRL_URL="${NLW_URL_STATIC:?}/wrpac.crl.der"
MOZA_JSON="${MOZA_JSON:?}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

echo "KVK-bevoegdheid als attestatie inrichten (uitgever KVK Demo)"
ATTESTATIES="${SCRIPT_DIR}/attestaties"
IS_DIR="${NL_WALLET_DIR}/wallet_core/wallet_server/issuance_server"
DEMO_ISSUER_JSON="${NL_WALLET_DIR}/wallet_core/demo/demo_issuer/demo_issuer.json"
KVK_PREFIX="${TARGET_DIR}/demo_issuer/kvk_bevoegdheid"

# Uitgevercertificaat (met organisatiegegevens), statuslijst-certificaat en WRPAC, zoals de
# demo-uitgevers in setup-devenv.sh. Fictief: "KVK Demo" met een verzonnen organisatie-ID.
for type in issuer tsl wrpac; do
	if [[ -z "${NIEUWE_CERTIFICATEN:-}" && -f "${KVK_PREFIX}.${type}.crt.der" ]]; then
		echo "Certificaat ${type} voor KVK Demo bestaat al"
		continue
	fi
	ca="${type}"
	extra=()
	[[ "${type}" == "tsl" ]] && ca="issuer"
	[[ "${type}" == "issuer" ]] && extra=(--issuer-auth-file "${ATTESTATIES}/kvk_issuer_auth.json")
	[[ "${type}" == "wrpac" ]] && extra=(--crl-distribution-point "${CRL_URL}")
	cargo run --quiet --manifest-path "${NL_WALLET_DIR}/wallet_core/Cargo.toml" \
		--bin wallet_ca cert --type "${type}" \
		--ca-key-file "${TARGET_DIR}/ca.${ca}.key.pem" \
		--ca-crt-file "${TARGET_DIR}/ca.${ca}.crt.pem" \
		--common-name "KVK Demo" \
		--organization-name "Kamer van Koophandel (demo)" \
		--organization-id "NTRNL-99876549" \
		--san-uri "https://kvk_bevoegdheid.example.com" \
		"${extra[@]}" \
		--file-prefix "${KVK_PREFIX}.${type}" \
		--force
	openssl x509 -in "${KVK_PREFIX}.${type}.crt.pem" -outform DER -out "${KVK_PREFIX}.${type}.crt.der"
	openssl pkcs8 -topk8 -inform PEM -outform DER -in "${KVK_PREFIX}.${type}.key.pem" -out "${KVK_PREFIX}.${type}.key.der" -nocrypt
done

cp "${ATTESTATIES}/com.example.kvk_bevoegdheid.json" "${IS_DIR}/"

python3 - "${IS_DIR}/issuance_server.toml" "${DEMO_ISSUER_JSON}" "${ATTESTATIES}/bevoegdheden.json" "${KVK_PREFIX}" "${MOZA_JSON}" <<'PY3'
import base64, hashlib, json, os, re, sys
from urllib.parse import urlencode

toml_pad, demo_pad, data_pad, prefix, lokaal_pad = sys.argv[1:6]
VCT = "com.example.kvk_bevoegdheid"
CONFIG_ID = VCT + "_sd_jwt"
PID_BSN = {"credential_type": "urn:eudi:pid:nl:1", "path": ["urn:eudi:pid:nl:1", "bsn"]}
ondernemingen = json.load(open(data_pad, encoding="utf-8"))["ondernemingen"]

def b64(bestand):
    return base64.b64encode(open(bestand, "rb").read()).decode()

def usecase(onderneming):
    return "kvk_bevoegdheid_" + onderneming["id"]

# issuance_server.toml: alle eerdere kvk_bevoegdheid-blokken weg (ook de oude zonder onderneming),
# type-metadata aanmelden, dan per onderneming een eigen uitgifte en één gedeelde credential-configuratie.
tekst = open(toml_pad, encoding="utf-8").read()
for kop in (r"\[\[?disclosure_settings\.kvk_bevoegdheid[a-z_]*[\].]", rf'\[credential_configurations\."{re.escape(CONFIG_ID)}"[\].]'):
    tekst = re.sub(r"\n" + kop + r"(?:(?!\n\[).)*", "", tekst, flags=re.S)

metadata = VCT + ".json"
if f'"{metadata}"' not in tekst:
    tekst, n = re.subn(r"type_metadata = \[\n", f'type_metadata = [\n    "{metadata}",\n', tekst, count=1)
    assert n == 1, "type_metadata niet gevonden"

# De TLS-pinning naar de attestation-server van demo_issuer: dezelfde CA als bij housing.
anker = re.search(r'\[disclosure_settings\.housing\.attestation_url_config\]\nbase_url = "https?://([^/]+)/housing/"\ntrust_anchors = (\[[^\]]*\])', tekst)
assert anker, "housing attestation_url_config niet gevonden"
host, trust_anchors = anker.group(1), anker.group(2)
publish_dir = re.search(r'publish_dir = "([^"]*)"', tekst).group(1)

tekst = tekst.rstrip("\n")
for onderneming in ondernemingen:
    u = usecase(onderneming)
    tekst += f"""

[disclosure_settings.{u}]
private_key_type = "software"
private_key = "{b64(prefix + '.wrpac.key.der')}"
certificate = "{b64(prefix + '.wrpac.crt.der')}"

[[disclosure_settings.{u}.dcql_query.credentials]]
id = "pid_bsn"
format = "mso_mdoc"
meta = {{ doctype_value = "urn:eudi:pid:nl:1" }}
claims = [
    {{ path = ["urn:eudi:pid:nl:1", "bsn"], intent_to_retain = true }}
]

[disclosure_settings.{u}.attestation_url_config]
base_url = "https://{host}/{u}/"
trust_anchors = {trust_anchors}"""

tekst += f"""

[credential_configurations."{CONFIG_ID}"]
format = "dc+sd-jwt"
attestation_type = "{VCT}"
valid_days = 365
private_key_type = "software"
private_key = "{b64(prefix + '.issuer.key.der')}"
certificate = "{b64(prefix + '.issuer.crt.der')}"

[credential_configurations."{CONFIG_ID}".status_list]
group_name = "{CONFIG_ID}"
context_path = "/tsl"
publish_dir = "{publish_dir}"
private_key_type = "software"
private_key = "{b64(prefix + '.tsl.key.der')}"
certificate = "{b64(prefix + '.tsl.crt.der')}"
"""
open(toml_pad, "w", encoding="utf-8").write(tekst)

# demo_issuer.json: per onderneming een usecase met de bevoegdheid voor elke houder (BSN). Een
# houder kan een eigen functie en bevoegdheid hebben, bijvoorbeeld een gemachtigde medewerker.
client_id = "x509_hash:" + base64.urlsafe_b64encode(hashlib.sha256(open(prefix + ".wrpac.crt.der", "rb").read()).digest()).decode().rstrip("=")
demo = json.load(open(demo_pad, encoding="utf-8"))
for sleutel in [k for k in demo["usecases"] if k.startswith("kvk_bevoegdheid")]:
    del demo["usecases"][sleutel]
VELDEN = ("kvk_nummer", "handelsnaam", "rechtsvorm", "functie", "bevoegdheid")
def document(onderneming, houder):
    waarden = {**onderneming, **houder}
    return {"format": "dc+sd-jwt", "attestation_type": VCT, "attributes": {k: {"type": "text", "value": waarden[k]} for k in VELDEN}}

for onderneming in ondernemingen:
    houders = [h if isinstance(h, dict) else {"bsn": h} for h in onderneming["houders"]]
    demo["usecases"][usecase(onderneming)] = {
        "client_id": client_id,
        "disclosed": PID_BSN,
        "data": {h["bsn"]: [document(onderneming, h)] for h in houders},
    }
json.dump(demo, open(demo_pad, "w", encoding="utf-8"), indent=2, ensure_ascii=False)

# Links voor "bevoegdheid toevoegen" per onderneming op de MOZa-pagina.
def link(u, sessie):
    request_uri = f"{demo['issuance_server_url'].rstrip('/')}/disclosure/{u}/request_uri?session_type={sessie}"
    return "walletdebuginteraction://wallet.edi.rijksoverheid.nl/disclosure_based_issuance?" + urlencode(
        {"client_id": client_id, "request_uri": request_uri, "request_uri_method": "post"})

config = {}
try:
    config = json.load(open(lokaal_pad, encoding="utf-8"))
except (OSError, ValueError):
    pass
config.pop("bevoegdheid", None)
config["bevoegdheden"] = [
    {"id": o["id"], "handelsnaam": o["handelsnaam"], "kvkNummer": o["kvk_nummer"], "same_device_ul": link(usecase(o), "same_device"), "cross_device_ul": link(usecase(o), "cross_device")}
    for o in ondernemingen
]
json.dump(config, open(lokaal_pad, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY3
