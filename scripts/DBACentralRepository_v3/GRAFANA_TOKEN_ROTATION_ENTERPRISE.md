# Grafana GitOps Enterprise v2.0 – Token Rotation

## Cel

Zero-downtime rotation dla:

- `GRAFANA_TOKEN` – token deploymentu dashboardów,
- `GRAFANA_ROTATION_ADMIN_TOKEN` – token używany do rotacji.

Polityka:

```text
TTL: 90 dni
Reminder: 35 dni do wygaśnięcia
Auto-rotation: 30 dni do wygaśnięcia
Overlap: nowy token jest testowany i zapisany w GitHub Secrets przed usunięciem starego
```

## Sekrety GitHub

W `Settings -> Secrets and variables -> Actions -> Secrets`:

```text
GRAFANA_URL
GRAFANA_TOKEN
GRAFANA_ROTATION_ADMIN_TOKEN
GH_SECRETS_TOKEN
```

### GRAFANA_TOKEN

Service Account:

```text
github-dashboard-deployer
```

Rola:

```text
Editor
```

### GRAFANA_ROTATION_ADMIN_TOKEN

Utwórz osobny Service Account:

```text
github-token-rotator
```

Preferowane uprawnienia:

```text
serviceaccounts:read
serviceaccounts:write
```

dla kont:

```text
github-dashboard-deployer
github-token-rotator
```

Jeżeli używana edycja Grafana OSS nie pozwala nadać tak granularnych RBAC permissions,
użyj roli `Admin` wyłącznie dla tego Service Account.

Bootstrap token rotatora może mieć nazwę:

```text
github-token-rotator-bootstrap
```

Po pierwszej automatycznej rotacji zostanie zastąpiony tokenem:

```text
sqlmaniak-rotator-auto-YYYYMMDDTHHMMSSZ
```

## GH_SECRETS_TOKEN

Fine-grained GitHub Personal Access Token ograniczony do repozytorium:

```text
marcinpytlik/SQLManiak
```

Minimalne uprawnienie repozytorium:

```text
Secrets: Read and write
Metadata: Read
```

Token służy wyłącznie do:

```text
gh secret set GRAFANA_TOKEN
gh secret set GRAFANA_ROTATION_ADMIN_TOKEN
```

Nie używaj classic PAT, jeśli fine-grained PAT jest dostępny.

## GitHub Variables

W `Settings -> Secrets and variables -> Actions -> Variables`:

```text
GRAFANA_DEPLOY_SERVICE_ACCOUNT_ID
GRAFANA_ROTATION_SERVICE_ACCOUNT_ID
GRAFANA_TOKEN_TTL_DAYS
GRAFANA_ROTATE_WHEN_DAYS_LEFT
GRAFANA_REMIND_WHEN_DAYS_LEFT
GRAFANA_LEGACY_DEPLOY_TOKEN_NAME
GRAFANA_LEGACY_ROTATOR_TOKEN_NAME
```

Rekomendowane wartości:

```text
GRAFANA_DEPLOY_SERVICE_ACCOUNT_ID=2
GRAFANA_ROTATION_SERVICE_ACCOUNT_ID=<ID github-token-rotator>
GRAFANA_TOKEN_TTL_DAYS=90
GRAFANA_ROTATE_WHEN_DAYS_LEFT=30
GRAFANA_REMIND_WHEN_DAYS_LEFT=35
GRAFANA_LEGACY_DEPLOY_TOKEN_NAME=github-actions-sqlmaniak
GRAFANA_LEGACY_ROTATOR_TOKEN_NAME=github-token-rotator-bootstrap
```

Po pierwszej udanej rotacji wartości `GRAFANA_LEGACY_*` można wyczyścić.

## Jednorazowy prerequisite na Raspberry Pi

Workflow używa GitHub CLI do bezpiecznego zaszyfrowania i aktualizacji GitHub Secrets.

```bash
sudo apt update
sudo apt install -y gh
gh --version
```

Runner nie loguje się interaktywnie do `gh`.
Workflow ustawia:

```text
GH_TOKEN=${GH_SECRETS_TOKEN}
```

## ETAP 1 – ręczna rotacja zero-downtime

Wejdź:

```text
Actions
-> Rotate Grafana tokens
-> Run workflow
```

Ustaw:

```text
force_rotation = true
```

Workflow wykonuje:

```text
1. tworzy nowy GRAFANA_TOKEN z TTL 90 dni
2. testuje nowy token
3. aktualizuje GitHub Secret GRAFANA_TOKEN
4. usuwa poprzednie managed tokeny
5. tworzy nowy token rotatora
6. testuje uprawnienia rotatora
7. aktualizuje GRAFANA_ROTATION_ADMIN_TOKEN
8. usuwa poprzednie managed tokeny rotatora
```

Jeżeli krok przed aktualizacją GitHub Secret zakończy się błędem, nowo utworzony token jest usuwany,
a stary token pozostaje aktywny.

## ETAP 2 – reminder

Workflow:

```text
Grafana token rotation reminder
```

Uruchamia się w poniedziałek o:

```text
04:17 UTC
```

Jeżeli token ma <= 35 dni życia, tworzy issue:

```text
[Grafana] Deployment token rotation approaching
```

Jeżeli sytuacja wróci do normy, otwarte issue jest automatycznie zamykane.

## ETAP 3 – automatyczna rotacja

Workflow:

```text
Rotate Grafana tokens
```

uruchamia się w niedzielę o:

```text
03:47 UTC
```

Jeżeli token ma więcej niż 30 dni życia:

```text
no rotation required
```

Jeżeli ma <= 30 dni życia:

```text
automatic zero-downtime rotation
```

Token bez TTL albo brak managed tokenu powoduje rotację przy najbliższym przebiegu.

## Emergency recovery

Jeżeli `GRAFANA_TOKEN` przestanie działać:

1. Uruchom `Rotate Grafana tokens` z `force_rotation=true`.
2. Jeżeli rotator działa, nowy deployment token zostanie wygenerowany i zapisany w GitHub Secrets.
3. Uruchom `Test Grafana connection`.
4. Uruchom `Deploy Grafana dashboards`.
5. Uruchom `Detect Grafana dashboard drift`.

Jeżeli nie działa również rotator:

1. Zaloguj się do Grafany kontem administratora.
2. Utwórz tymczasowy token dla `github-token-rotator`.
3. Podmień `GRAFANA_ROTATION_ADMIN_TOKEN` w GitHub Secrets.
4. Uruchom wymuszoną rotację.
5. Usuń tymczasowy bootstrap token.

## Branch protection

Dla `master` ustaw:

```text
Require a pull request before merging
Require status checks to pass
Require branches to be up to date before merging
Do not allow bypassing the above settings
```

Jako required check ustaw:

```text
Validate dashboard JSON
```

Workflow uruchamiany z Pull Request nie korzysta z self-hosted runnera ani sekretów Grafany.

## Root of trust

`GH_SECRETS_TOKEN` jest jedynym bootstrap credentialem, którego ten mechanizm nie może sam sobie
bezpiecznie odtworzyć z Grafany. Powinien być:

- fine-grained,
- ograniczony tylko do `SQLManiak`,
- z permission `Secrets: write`,
- z własnym terminem wygaśnięcia,
- rotowany zgodnie z polityką GitHub organizacji/konta.

W bardziej rozbudowanym środowisku można zastąpić go GitHub App installation token.
