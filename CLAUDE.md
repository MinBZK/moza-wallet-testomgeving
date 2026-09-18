# CLAUDE.md - Projectcontext voor AI-assistentie

## Project

MOZa wallet testomgeving: de lokale ontwikkelomgeving van [NL Wallet](https://github.com/MinBZK/nl-wallet) als container op ZAD (project `mwt-ked`, deployment `nlw`), zodat een zelfgebouwde NL Wallet-app kan inloggen op MijnOverheid Zakelijk. Zie `README.md` voor de opzet; `DISCLAIMER.md` en `docs/ai-verantwoording.md` voor de kaders rond AI-gebruik.

## Taal

Communicatie, commentaar en documentatie in het Nederlands. Code en technische termen in het Engels waar gangbaar; namen van NL Wallet-onderdelen (wallet_provider, pid_issuer, WRPAC, PID) blijven zoals NL Wallet ze noemt. Geen gedachtestreepje (em-dash) in tekst; gebruik een gewoon streepje of een komma.

## Structuur

- `Containerfile`, `rootfs/`: de kerncontainer. `rootfs/opt/nlw/sbin/start` is het entrypoint, `inrichten` de eenmalige inrichting, `omgeving` de gedeelde variabelen, `supervisord.conf` de procesbewaking, `nginx.conf` de routering op hostnaam.
- `proxy/`: het nginx-image dat per publieke hostnaam als ZAD-component draait.
- `moza/`: wat MOZa toevoegt aan de NL Wallet-devenv (verifier, testpersonen, KVK-bevoegdheid). `moza/inrichten.sh` hoort gelijk te blijven aan `server/nl-wallet/lokaal-inrichten.sh` in MinBZK/moza-poc.
- `bouw-binaries.sh`, `versies.env`: welke NL Wallet-commit en welke binaries de workflow bouwt.
- `zad-inrichten.sh`: de eenmalige inrichting van het ZAD-project, als documentatie van wat er met de hand is gedaan.

## Wat je moet weten voordat je iets verandert

- De publieke hostnamen zitten in sleutels, certificaten en de getekende wallet-config op het volume. Veranderen ze, dan wist `start` het volume en richt hij opnieuw in; wallets die tegen de oude omgeving geregistreerd waren werken dan niet meer en de app moet opnieuw gebouwd worden.
- Migraties draaien met `up`, nooit met `fresh`: dat wist geregistreerde wallets en statuslijsten.
- De app op het toestel moet met dezelfde NL Wallet-commit gebouwd zijn als de servers (`versies.env`).
- ZAD draait containers onder een willekeurige uid met gid 0; schrijfbare mappen zijn groep-schrijfbaar en `start` voegt een passwd-regel toe.
- Een Service heet op ZAD `<deployment>-<component>`; de nginx-resolver kent geen zoekdomeinen, dus de proxy vult `NLW_KERN` aan tot een volledige naam.
- Commits via de GitHub-API hebben geen uitvoerbit; roep scripts met `bash` aan of zet het bit in het Containerfile.

## Werkwijze

- De ontwikkeling staat in deze fase open: wijzigingen mogen direct op `main`. Elke push naar `main` bouwt en rolt uit naar ZAD; test grotere wijzigingen eerst lokaal (het Containerfile bouwt ook op Apple Silicon, met dummy-binaries voor de Rust-services).
- Commitberichten volgen de emoji-conventie van moza-poc (➕ Added, ✏️ Modified, ❌ Deleted, 🧼 Hygiene, 🐛 Bugfix, 🔁 Renamed) en eindigen bij AI-bijdragen met een `Co-Authored-By`-trailer.
- Geheimen horen niet in de repo: de ZAD-key staat als repo-secret `ZAD_API_KEY`, sleutels van de omgeving ontstaan bij de eerste start op het volume.
