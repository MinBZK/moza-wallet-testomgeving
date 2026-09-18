# MOZa wallet testomgeving

Een online NL Wallet-omgeving waartegen een zelfgebouwde NL Wallet-app (Android) kan onboarden, een PID kan ophalen via de mock-DigiD, een KVK-bevoegdheid kan krijgen en kan inloggen bij MOZa. Het is de lokale ontwikkelomgeving van [MinBZK/nl-wallet](https://github.com/MinBZK/nl-wallet) (`scripts/setup-devenv.sh` en `scripts/start-devenv.sh`), in een container op ZAD. De MOZa-kant (inlogkaart, node-server, lokale inrichting) staat in [MinBZK/moza-poc](https://github.com/MinBZK/moza-poc), branch `feat/nl-wallet-inloggen`.

Alleen voor testen met fictieve gegevens. De omgeving gebruikt SoftHSM, een gesimuleerde Play Integrity-controle en testsleutels.

## Opzet

ZAD-project `mwt-ked` (MOZa wallet testomgeving), deployment `nlw`.

| Component | Hostnaam | Wat |
|---|---|---|
| `nlw` | geen (intern) | Kerncontainer: alle services, PostgreSQL, redis, SoftHSM, mock-DigiD (nl-rdo-max), BRP-proxy. Persistent volume op `/data`. |
| `nlw-wp` | nlw-wp.moza-wallet.rijksapp.dev | wallet_provider |
| `nlw-static` | nlw-static.moza-wallet.rijksapp.dev | static_server: wallet-config, WIA-statuslijsten, WRPAC-CRL |
| `nlw-ups` | nlw-ups.moza-wallet.rijksapp.dev | update_policy_server |
| `nlw-pid` | nlw-pid.moza-wallet.rijksapp.dev | pid_issuer, met de mock-DigiD-inlogpagina |
| `nlw-issuance` | nlw-issuance.moza-wallet.rijksapp.dev | issuance_server (KVK-bevoegdheid van "KVK Demo") |
| `nlw-verifier` | nlw-verifier.moza-wallet.rijksapp.dev | verification_server (publieke kant) |

Het subdomein `moza-wallet.rijksapp.dev` moet ZAD-beheer goedkeuren. Tot die tijd serveert het platform op `nlw-<dienst>-nlw-mwt-ked.rig.prd1.gn2.quattro.rijksapps.nl`; de kerncontainer krijgt die vorm dan via `NLW_HOST_PATROON`. Let op: de hostnamen zitten in sleutels, configuratie en de app, dus overstappen op het eigen subdomein betekent opnieuw inrichten (schoon volume) en een nieuwe app-build. `zad-inrichten.sh` maakt de deployment eenmalig aan.

ZAD geeft elk component één hostnaam. De `nlw-*`-componenten zijn daarom kleine nginx-proxy's (`proxy/`) die met de oorspronkelijke Host-header doorsturen naar de kerncontainer (`NLW_KERN`, op ZAD `nlw-nlw:8080`: een Service heet daar `<deployment>-<component>`). De nginx in de kerncontainer kiest op die hostnaam de service (`rootfs/opt/nlw/nginx.conf`).

Binnen het project (bijvoorbeeld vanuit MOZa) geeft `http://nlw-nlw:8080` de interne API van de verification_server, en `http://nlw-nlw:8080/moza.json` de links voor "bevoegdheid toevoegen".

## Bouwen

`.github/workflows/build.yml` checkt NL Wallet uit op de commit in `versies.env`, bouwt de binaries (`bouw-binaries.sh`) en daarna de images, als tags `kern-sha-…` en `proxy-sha-…` in het package `ghcr.io/minbzk/moza-wallet-testomgeving`. Dat package moet openbaar staan (eenmalig instellen in GitHub, Package settings), anders kan ZAD de images niet ophalen; ze bevatten geen geheimen, sleutels ontstaan bij de eerste start. Op `main` rolt de workflow ze uit naar ZAD met het repo-secret `ZAD_API_KEY` van project mwt-ked.

De app op het toestel moet met dezelfde NL Wallet-commit gebouwd zijn. Verander je `NL_WALLET_REF`, bouw dan ook de app opnieuw.

## Eerste start en persistentie

Op een leeg volume draait `rootfs/opt/nlw/sbin/inrichten` één keer:

1. `publiek-maken.py` zet de devenv-templates om van `localhost` naar de publieke https-adressen, en de TLS-pinning in de wallet-config naar de Let's Encrypt-roots;
2. `scripts/setup-devenv.sh` van NL Wallet maakt CA's, certificaten, HSM-sleutels en configuratie. `cargo run` gaat via een shim naar de binaries in het image;
3. de mock-DigiD krijgt zijn sleutels en configuratie;
4. `moza/inrichten.sh` voegt de MOZa-verifier (usecase `moza_inloggen`), de testpersonen uit `moza/testpersonen/` en de KVK-bevoegdheid (`moza/attestaties/`) toe.

Sleutels, HSM-token, database en configuratie horen bij elkaar. Een nieuw volume betekent een nieuwe omgeving: wallets die tegen de oude omgeving geregistreerd zijn, werken dan niet meer. Migraties draaien bij elke start met `up`, nooit met `fresh`.

`moza/inrichten.sh` is afgeleid van `server/nl-wallet/lokaal-inrichten.sh` in MinBZK/moza-poc (branch `feat/nl-wallet-inloggen`). Pas wijzigingen in testpersonen of attestaties op beide plekken toe.

## Bijdragen

De ontwikkeling staat in deze fase bewust open: wijzigingen mogen direct op `main`, zonder verplichte review of statuschecks, zodat aanpassen laagdrempelig blijft. Elke push naar `main` bouwt de images en rolt ze uit naar ZAD (zie Bouwen). Een pull request bouwt alleen. Zodra de omgeving door meer mensen wordt gebruikt, komen branchbescherming en review erbij, zoals in [moza-poc-fbs-berichtenbox](https://github.com/MinBZK/moza-poc-fbs-berichtenbox).

## Licentie

Dit project is gelicenseerd onder de [EUPL-1.2](LICENSE). De NL Wallet-broncode die in de images wordt meegebouwd heeft haar eigen licentie, zie [MinBZK/nl-wallet](https://github.com/MinBZK/nl-wallet).

## AI-verantwoording

De code in deze repo is grotendeels gegenereerd met generatieve AI (Claude Code) en door een ontwikkelaar beproefd door de omgeving lokaal en op ZAD te draaien en met de testapp te gebruiken. Zie [DISCLAIMER.md](DISCLAIMER.md) en [docs/ai-verantwoording.md](docs/ai-verantwoording.md).

## Ondersteuning

Zie [SUPPORT.md](SUPPORT.md).

## Governance

Zie [GOVERNANCE.md](GOVERNANCE.md).
