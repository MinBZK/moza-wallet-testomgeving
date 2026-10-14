#!/usr/bin/env bash
#
# testpersonen.sh
#
# Zet de fictieve testpersonen uit testpersonen/ in de mock-BRP (versleutelde GBA-V-antwoorden)
# en op de mock-DigiD-pagina ([digid.mock_subjects] in pid_issuer.toml). Draait bij de inrichting
# (inrichten.sh) en bij elke start (start), zodat een gewijzigde testpersoon na een nieuwe uitrol
# meteen geldt, zonder nieuw volume. Bestaande namen voor hetzelfde BSN worden vervangen.

set -euo pipefail

NL_WALLET_DIR="${NL_WALLET_DIR:-/opt/nl-wallet}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
GBA_DIR="${NL_WALLET_DIR}/wallet_core/gba_hc_converter/resources"
PID_TOML="${NL_WALLET_DIR}/wallet_core/wallet_server/pid_issuer/pid_issuer.toml"

echo "Testpersonen in de mock-BRP en op de mock-DigiD-pagina zetten"
mkdir -p "${GBA_DIR}/gba-v-responses" "${GBA_DIR}/encrypted-gba-v-responses"
for xml in "${SCRIPT_DIR}"/testpersonen/*.xml; do
	bsn="$(basename "${xml}" .xml)"
	cp "${xml}" "${GBA_DIR}/gba-v-responses/${bsn}.xml"
	cargo run --quiet --manifest-path "${NL_WALLET_DIR}/wallet_core/Cargo.toml" \
		--bin gba_encrypt -- \
		--basename "${bsn}" \
		--output "${GBA_DIR}/encrypted-gba-v-responses" \
		"${GBA_DIR}/gba-v-responses/${bsn}.xml"
done

python3 - "${PID_TOML}" "${SCRIPT_DIR}/testpersonen" <<'PY2'
import glob, os, re, sys

pad, map_ = sys.argv[1:3]
tekst = open(pad, encoding="utf-8").read()

def waarde(xml, nummer):
    gevonden = re.search(r"<ns2:nummer>" + nummer + r"</ns2:nummer>\s*<ns2:waarde>([^<]*)</ns2:waarde>", xml)
    return gevonden.group(1) if gevonden else ""

kop = "[digid.mock_subjects]\n"
if kop not in tekst:
    sys.exit("Geen [digid.mock_subjects] in " + pad)

for bestand in sorted(glob.glob(os.path.join(map_, "*.xml"))):
    xml = open(bestand, encoding="utf-8").read()
    bsn = waarde(xml, "120")
    # Voornamen (210), voorvoegsel (230) en geslachtsnaam (240), zoals de wallet ze toont.
    naam = " ".join(deel for deel in (waarde(xml, "210"), waarde(xml, "230"), waarde(xml, "240")) if deel)
    regel = f'"{bsn}" = "{naam}"'
    # Een eerdere naam voor dit BSN vervangen, anders bovenaan toevoegen.
    tekst, aantal = re.subn(r'^"' + bsn + r'" = .*$', regel, tekst, flags=re.M)
    if aantal == 0:
        tekst = tekst.replace(kop, kop + regel + "\n", 1)

open(pad, "w", encoding="utf-8").write(tekst)
PY2
