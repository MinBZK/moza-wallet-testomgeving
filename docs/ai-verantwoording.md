# Verantwoording inzet van generatieve AI in de MOZa wallet testomgeving

**Verantwoording in het kader van het Overheidsbreed Standpunt Generatieve AI, getoetst aan het stappenplan uit de bijbehorende handreiking.** Voor een beknopte samenvatting, zie [`DISCLAIMER.md`](../DISCLAIMER.md). Deze verantwoording volgt de opzet van die van [moza-poc-fbs-berichtenbox](https://github.com/MinBZK/moza-poc-fbs-berichtenbox/blob/main/docs/ai-verantwoording.md).

## Beschrijving van het project en de rol van AI

Deze repository zet de lokale ontwikkelomgeving van NL Wallet online op ZAD, als testomgeving voor inloggen op MijnOverheid Zakelijk (MOZa). Zie de [`README.md`](../README.md) voor de opzet.

**Rol van AI.** De containers, scripts, configuratie en workflow zijn grotendeels gegenereerd met de AI-assistent Claude Code (Anthropic), in een dialoog met een ontwikkelaar die de opdrachten gaf, de keuzes maakte (welk ZAD-project, welke hostnamen, wat er wel en niet online mag) en het resultaat beproefde. De NL Wallet-broncode zelf is niet door AI geschreven; die wordt ongewijzigd meegebouwd vanaf een vaste commit.

**Menselijke review.** In deze fase staat de ontwikkeling bewust open: wijzigingen gaan niet regel voor regel door een review. De werking van het geheel wordt beproefd door de omgeving lokaal in een container te draaien, op ZAD uit te rollen en met de testapp op een toestel te gebruiken (onboarding, PID via de mock-DigiD, bevoegdheid, inloggen op MOZa). De mens blijft eindverantwoordelijk; de AI is een hulpmiddel. Zodra de omgeving door meer mensen gebruikt wordt, komen branchbescherming en review erbij.

**Gegevens.** De omgeving verwerkt geen persoonsgegevens. Er wordt uitsluitend gewerkt met fictieve testpersonen, testsleutels, een gesimuleerde HSM en een mock-DigiD.

**Scope-grens.** Deze verantwoording betreft uitsluitend deze testomgeving. Gebruik in een pilot of productie valt buiten de scope en vereist aanvullende toetsing, waaronder een beoordeling tegen de BIO en een DPIA, en de community onboarding bij het NL Wallet-team.

## Verantwoording per stappenplan

Hieronder volgen we het stappenplan uit hoofdstuk 4 van de [Overheidsbrede handreiking verantwoorde inzet van generatieve AI](https://open.overheid.nl/documenten/9c273b71-cebb-4e11-b06f-fa20f7b4b90e/file).

### 1) Doel en toepassingsgebied

*Doel (AI-aspect):* onderzoeken of een ontwikkelaar met generatieve AI een bestaande, complexe open-source-omgeving (NL Wallet) verantwoord en herhaalbaar online kan zetten, met de standaarden en het platform van de Rijksoverheid (ZAD) als kader.

*Toepassingsgebied:* de ontwikkeling van deze testomgeving. Niet in scope: gebruik in pilot of productie.

### 2) Zorg voor de juiste mensen en vaardigheden

De ontwikkelaar is geen NL Wallet-expert; de omgeving is gebouwd door de scripts en documentatie van NL Wallet te volgen en de werking op een toestel te beproeven. Waar de documentatie van het platform tekortschoot, is het gedrag empirisch vastgesteld en in de code vastgelegd. AI wordt ingezet als gereedschap onder menselijke regie.

### 3) Creëer een (generatieve) AI-governance structuur

Het werk gebeurt in opdracht van het Ministerie van Binnenlandse Zaken en Koninkrijksrelaties (BZK). Als beleidsmatige leidraad gelden het [Overheidsbreed standpunt voor de inzet van generatieve AI](https://open.overheid.nl/documenten/bc03ce31-0cf1-4946-9c94-e934a62ebe73/file) en de bijbehorende handreiking.

Concrete maatregelen:

- Met AI gegenereerde bijdragen zijn herkenbaar via de commit-trailer `Co-Authored-By`.
- De ontwikkelaar beproeft elke uitrol op ZAD met de testapp.
- Geheimen staan niet in de repo en niet in de images: sleutels ontstaan bij de eerste start op het volume, de ZAD-key is een repo-secret.
- De governance van het MOZa-project geldt, zie [`GOVERNANCE.md`](../GOVERNANCE.md).

### 4) Kies de juiste toepassing en leverancier

Gebruikt is Claude Code (Anthropic) via een zakelijke omgeving. Er zijn geen persoonsgegevens of geheimen aan het model aangeboden; de omgeving werkt met fictieve gegevens.

### 5) Wees transparant

Deze verantwoording, [`DISCLAIMER.md`](../DISCLAIMER.md) en de `Co-Authored-By`-trailers maken het AI-gebruik zichtbaar. De repository is openbaar onder de EUPL-1.2.

### 6) Toets en evalueer

De omgeving wordt beproefd door hem te gebruiken: onboarding, PID-uitgifte, de KVK-bevoegdheid en inloggen op MOZa. Gevonden gebreken worden in de repo hersteld en in de commitgeschiedenis vastgelegd. Zolang de ontwikkeling open staat, is dit de toets; bij bredere inzet komen review en statuschecks erbij.
