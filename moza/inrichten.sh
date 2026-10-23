#!/usr/bin/env bash
#
# inrichten.sh
#
# Richt de NL Wallet-testomgeving in als verifier voor MOZa: een WRPAC-certificaat voor "MijnOverheid Zakelijk",
# een usecase `moza_inloggen` in de verification_server en de MOZa-origin in
# allow_origins. Daarnaast komen de fictieve testpersonen uit testpersonen/ in de
# mock-BRP en op de mock-DigiD-pagina, zodat MOZa eigen testgebruikers heeft die
# niet ook in de pre-prod-wallet staan.
#
# Afgeleid van server/nl-wallet/lokaal-inrichten.sh in MinBZK/moza-poc (branch feat/nl-wallet-inloggen), maar voor de
# container: de NL Wallet-checkout staat in /opt/nl-wallet, `cargo run` gaat via de shim naar de
# binaries in het image, de CRL staat op het publieke adres van de static_server en de services
# starten niet opnieuw (dat doet supervisord pas na de inrichting). De links voor "bevoegdheid
# toevoegen" komen in MOZA_JSON, dat de kerncontainer intern serveert op /moza.json.

set -euo pipefail

NL_WALLET_DIR="${NL_WALLET_DIR:-/opt/nl-wallet}"
MOZA_ORIGIN="${MOZA_ORIGIN:?}"
USECASE="${NL_WALLET_USECASE:-moza_inloggen}"

# Lokaal en fictief. Voor de pre-prod-omgeving komen naam, organisatie-ID en CA
# uit de community onboarding van NL Wallet.
RP_NAAM="MijnOverheid Zakelijk"
RP_ORGANISATIE="Ministerie van Binnenlandse Zaken en Koninkrijksrelaties"
RP_ORGANISATIE_ID="NTRNL-00000000"
RP_SAN="https://proef.moza.rijksapp.dev"

TARGET_DIR="${NL_WALLET_DIR}/scripts/devenv/target"
VS_TOML="${NL_WALLET_DIR}/wallet_core/wallet_server/verification_server/verification_server.toml"
CERT_PREFIX="${TARGET_DIR}/demo_relying_party/${USECASE}"
CRL_URL="${NLW_URL_STATIC:?}/wrpac.crl.der"
MOZA_JSON="${MOZA_JSON:?}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
GBA_DIR="${NL_WALLET_DIR}/wallet_core/gba_hc_converter/resources"
PID_TOML="${NL_WALLET_DIR}/wallet_core/wallet_server/pid_issuer/pid_issuer.toml"

for bestand in "${TARGET_DIR}/ca.wrpac.key.pem" "${TARGET_DIR}/ca.wrpac.crt.pem" "${VS_TOML}" "${PID_TOML}"; do
	if [[ ! -f "${bestand}" ]]; then
		echo "Niet gevonden: ${bestand}" >&2
		echo "Draai eerst scripts/setup-devenv.sh in ${NL_WALLET_DIR}." >&2
		exit 1
	fi
done

# Certificaten alleen maken als ze er nog niet zijn (of met NIEUWE_CERTIFICATEN=1). Een nieuw
# certificaat geeft een nieuwe client_id, en dan kloppen links in een al geopende pagina niet meer.
if [[ -n "${NIEUWE_CERTIFICATEN:-}" || ! -f "${CERT_PREFIX}.crt.der" ]]; then
	echo "WRPAC-certificaat maken voor ${RP_NAAM}"
	cargo run --quiet --manifest-path "${NL_WALLET_DIR}/wallet_core/Cargo.toml" \
		--bin wallet_ca cert --type wrpac \
		--ca-key-file "${TARGET_DIR}/ca.wrpac.key.pem" \
		--ca-crt-file "${TARGET_DIR}/ca.wrpac.crt.pem" \
		--common-name "${RP_NAAM}" \
		--organization-name "${RP_ORGANISATIE}" \
		--organization-id "${RP_ORGANISATIE_ID}" \
		--crl-distribution-point "${CRL_URL}" \
		--san-uri "${RP_SAN}" \
		--file-prefix "${CERT_PREFIX}" \
		--force

	openssl x509 -in "${CERT_PREFIX}.crt.pem" -outform DER -out "${CERT_PREFIX}.crt.der"
	openssl pkcs8 -topk8 -inform PEM -outform DER -in "${CERT_PREFIX}.key.pem" -out "${CERT_PREFIX}.key.der" -nocrypt
else
	echo "WRPAC-certificaat voor ${RP_NAAM} bestaat al"
fi

echo "Usecase ${USECASE} en origin ${MOZA_ORIGIN} in de verification_server zetten"
python3 - "${VS_TOML}" "${USECASE}" "${MOZA_ORIGIN}" "${CERT_PREFIX}" <<'PY'
import base64, re, sys

pad, usecase, origin, prefix = sys.argv[1:5]
tekst = open(pad, encoding="utf-8").read()

# Een eerdere run weghalen: de sectie loopt tot de volgende [kop] of het einde.
tekst = re.sub(r"\n\[usecases\." + re.escape(usecase) + r"\]\n(?:(?!\n\[).)*", "", tekst, flags=re.S)

def b64(bestand):
    return base64.b64encode(open(bestand, "rb").read()).decode()

tekst = tekst.rstrip("\n") + (
    f"\n\n[usecases.{usecase}]\n"
    f'certificate = "{b64(prefix + ".crt.der")}"\n'
    f'private_key = "{b64(prefix + ".key.der")}"\n'
    'private_key_type = "software"\n'
)

def voeg_origin_toe(match):
    origins = re.findall(r'"([^"]*)"', match.group(1))
    if origin not in origins:
        origins.append(origin)
    return "allow_origins = [" + ", ".join(f'"{o}"' for o in origins) + "]"

tekst, aantal = re.subn(r"^allow_origins = \[(.*?)\]", voeg_origin_toe, tekst, count=1, flags=re.M)
if aantal == 0:
    tekst = f'allow_origins = ["{origin}"]\n' + tekst

open(pad, "w", encoding="utf-8").write(tekst)
PY

bash "${SCRIPT_DIR}/testpersonen.sh"

bash "${SCRIPT_DIR}/bevoegdheden.sh"

echo "MOZa-inrichting klaar"
