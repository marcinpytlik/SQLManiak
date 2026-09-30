# DBA Library Quality

Narzędzia jakości dla kanonicznych warstw SQLManiak DBA Library.

## Validate structure

```powershell
python tools/dba-library-quality/validate_structure.py
```

Sprawdza:

- wymagane sekcje Standards,
- wymagane sekcje Monitoring,
- obecność podstawowej sekcji Symptoms w Troubleshooting,
- komplet plików runbooka:
  - README.md,
  - PRECHECK.md,
  - RUNBOOK.md,
  - VALIDATION.md,
  - ROLLBACK.md,
- wymagane sekcje ADR.

## Validate links

```powershell
python tools/dba-library-quality/validate_links.py
```

Sprawdza wewnętrzne linki Markdown w kanonicznych warstwach DBA Library oraz głównych dokumentach governance.

Celowo nie waliduje całego historycznego repo. Starsze katalogi są obejmowane kontrolą stopniowo zgodnie z Content Lifecycle i Strangler approach.

## Generate inventory

```powershell
python tools/dba-library-quality/generate_inventory.py
```

Generuje:

```text
docs/DBA-LIBRARY-INVENTORY.md
```

CI używa:

```powershell
python tools/dba-library-quality/generate_inventory.py --check
```

i blokuje PR, jeżeli inventory nie odpowiada aktualnej strukturze.

## CI

Workflow:

```text
.github/workflows/validate-dba-library.yml
```

Uruchamia się dla PR do `master`, jeśli zmieniają się kanoniczne warstwy DBA Library, governance, quality tooling albo root README.

Pipeline:

```text
Validate structure
        ↓
Validate internal links
        ↓
Validate generated inventory
```

Nie zastępuje istniejącego checka:

```text
Validate dashboard JSON
```

Oba mechanizmy są niezależne.
