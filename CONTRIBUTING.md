# Contributing to SQLManiak DBA Library

Dzięki za zainteresowanie rozwojem SQLManiak DBA Library.

Repozytorium jest rozwijane jako praktyczna biblioteka DBA, w której każda nowa treść powinna mieć jasno określoną rolę.

## Model repozytorium

```text
Architecture / ADR
        ↓
Standards
        ↓
Monitoring
        ↓
Troubleshooting
        ↓
Runbooks
        ↓
Existing source of truth
```

Znaczenie warstw:

- **Architecture / ADR** — dlaczego wybraliśmy dany model,
- **Standards** — jak powinno być,
- **Monitoring** — czy nadal tak jest,
- **Troubleshooting** — dlaczego jest źle,
- **Runbooks** — jak bezpiecznie wykonać operację,
- **docs/scripts/tools/labs** — źródła techniczne, implementacje, laboratoria i materiały referencyjne.

## Zanim dodasz nowy materiał

1. Sprawdź [DBA Library Cross-Link Map](docs/DBA-LIBRARY-MAP.md).
2. Sprawdź, czy podobny source of truth już istnieje.
3. Nie kopiuj istniejących skryptów tylko po to, żeby umieścić je w nowym katalogu.
4. Wybierz właściwy typ artefaktu.
5. Użyj odpowiedniego template z [templates/](templates/).

## Typy artefaktów

### Standard

Użyj [STANDARD-TEMPLATE.md](templates/STANDARD-TEMPLATE.md).

Standard opisuje stan oczekiwany, wymagania, wyjątki i walidację.

### Monitoring

Nowy moduł powinien opisywać:

- Signals / Metrics,
- ALERT vs TREND vs DIAGNOSTIC,
- Baseline,
- Correlation,
- Severity,
- Validation,
- Troubleshooting,
- Runbooks,
- Sources of truth.

### Troubleshooting

Użyj [TROUBLESHOOTING-TEMPLATE.md](templates/TROUBLESHOOTING-TEMPLATE.md).

Troubleshooting powinien być symptom-first i prowadzić do root cause.

### Runbook

Użyj [RUNBOOK-TEMPLATE.md](templates/RUNBOOK-TEMPLATE.md).

Runbook musi posiadać:

```text
README.md
PRECHECK.md
RUNBOOK.md
VALIDATION.md
ROLLBACK.md
```

### ADR

Użyj [ADR-TEMPLATE.md](templates/ADR-TEMPLATE.md).

ADR opisuje decyzję, alternatywy, trade-offy i warunki ponownego review.

## Content lifecycle

Obowiązuje lifecycle opisany w [CONTENT-LIFECYCLE.md](docs/CONTENT-LIFECYCLE.md):

- ACTIVE,
- REFERENCE,
- LAB,
- LEGACY,
- ARCHIVED.

Nie oznaczaj starszego materiału jako LEGACY tylko dlatego, że jest stary.

## Branches

Preferowany model:

```text
docs/<topic>
feat/<topic>
fix/<topic>
chore/<topic>
```

Przykłady:

```text
docs/query-store-standard
feat/zabbix-ag-monitoring
fix/broken-runbook-link
chore/dba-library-inventory
```

## Pull Request workflow

1. Utwórz branch z aktualnego `master`.
2. Wprowadź zmianę.
3. Uruchom lokalne walidatory.
4. Zregeneruj inventory, jeśli zmieniła się kanoniczna struktura.
5. Otwórz Pull Request.
6. Poczekaj na wymagane GitHub Actions.
7. Napraw problemy zamiast wyłączać walidację.
8. Merge wykonuj dopiero po zielonych checkach.

## Lokalne validation

```powershell
python tools/dba-library-quality/validate_structure.py
python tools/dba-library-quality/validate_links.py
python tools/dba-library-quality/generate_inventory.py --check
```

Po dodaniu/usunięciu/zmianie nazwy kanonicznego artefaktu:

```powershell
python tools/dba-library-quality/generate_inventory.py
```

## Definition of Done

Przed PR sprawdź [Definition of Done](docs/DEFINITION-OF-DONE.md).

## Source of truth

Preferujemy linkowanie do istniejącego artefaktu zamiast duplikowania zawartości.

Jeżeli istniejący dokument jest poprawny, ale znajduje się w starszej części repo:

```text
classify
→ add canonical entry point
→ cross-link
→ keep source where it belongs
```

## Pull Request size

Preferowane są PR-y o jednym spójnym celu.

Duża zmiana jest akceptowalna, jeżeli stanowi jeden logiczny pakiet, np.:

- kompletny runbook,
- nowy moduł monitoringowy,
- nowa reference architecture.

## Bezpieczeństwo

Nie umieszczaj w repo:

- haseł,
- tokenów,
- connection stringów z sekretami,
- prywatnych certyfikatów/kluczy,
- danych produkcyjnych,
- danych osobowych,
- danych klientów.

Przykłady i laby powinny używać danych demonstracyjnych.

## Release / versioning

Zobacz [Release Policy](docs/RELEASE-POLICY.md).
