# Grafana GitOps – DBACentralRepository

## Zasada

GitHub jest źródłem prawdy dla dashboardów Grafany.

Dashboardy znajdują się w:

```text
scripts/DBACentralRepository_v3/grafana/
```

## Workflow

### 1. Walidacja Pull Request

Plik:

```text
.github/workflows/validate-grafana.yml
```

Uruchamia się na GitHub-hosted runnerze `ubuntu-latest`.

Nie korzysta z:
- self-hosted runnera,
- `GRAFANA_TOKEN`,
- lokalnej sieci.

Sprawdza:
- poprawność JSON,
- `apiVersion`,
- `kind = Dashboard`,
- `metadata.name`,
- `spec.title`,
- unikalność nazw i tytułów.

### 2. Deployment

Plik:

```text
.github/workflows/deploy-grafana.yml
```

Uruchamia się po pushu do `master`, jeśli zmieni się dashboard JSON.

Wykonuje się na:

```text
grafana-rpi
```

Dashboardy trafiają do folderu:

```text
DBACentralRepository
```

Workflow dodaje tagi:

```text
DBACentralRepository
ManagedByGitHub
```

### 3. Drift detection

Plik:

```text
.github/workflows/detect-grafana-drift.yml
```

Uruchamia się:
- ręcznie,
- codziennie o 03:17 UTC.

Porównuje desired state z GitHub z aktualnym stanem Grafany.

Jeżeli dashboard został ręcznie zmieniony w Grafanie, workflow kończy się błędem:

```text
DRIFT detected
```

## Zmiana dashboardu

Preferowany proces:

```text
edycja w Grafanie
→ test
→ Export as code / JSON
→ nadpisanie pliku w repo
→ Pull Request
→ walidacja
→ merge do master
→ automatyczny deployment
```

## Rollback

Rollback to powrót do wcześniejszej wersji pliku w Git:

```powershell
git log -- scripts/DBACentralRepository_v3/grafana/
git checkout <commit> -- scripts/DBACentralRepository_v3/grafana/<dashboard>.json
git commit -m "Rollback Grafana dashboard"
git push
```

Po pushu workflow wdroży poprzednią wersję do Grafany.

## Bezpieczeństwo

Repozytorium publiczne nie powinno uruchamiać kodu z Pull Requestów na self-hosted runnerze.

Dlatego:

```text
PR validation → ubuntu-latest
deployment    → self-hosted ARM64
drift check   → self-hosted ARM64
```

`GRAFANA_TOKEN` i `GRAFANA_URL` pozostają w GitHub Repository Secrets.
test
