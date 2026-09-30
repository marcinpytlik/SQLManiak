# DBA Library — Definition of Done

Definition of Done określa minimalny poziom jakości dla zmian w kanonicznych warstwach SQLManiak DBA Library.

## Wszystkie zmiany

- [ ] Zmiana ma jeden jasno określony cel.
- [ ] Nie duplikuje istniejącego source of truth bez uzasadnienia.
- [ ] Linki wewnętrzne są poprawne.
- [ ] Nazewnictwo jest zgodne z istniejącą strukturą.
- [ ] Nie zawiera sekretów ani danych produkcyjnych.
- [ ] Powiązane warstwy są cross-linkowane, jeśli ma to sens.
- [ ] CI przechodzi.

## Standard

- [ ] Purpose.
- [ ] Scope.
- [ ] Required.
- [ ] Recommended.
- [ ] Not allowed.
- [ ] Default configuration.
- [ ] Exceptions.
- [ ] Validation.
- [ ] Ownership.
- [ ] Review cycle.
- [ ] References.
- [ ] Link do Monitoring / Troubleshooting / Runbook, jeśli istnieje.

## Monitoring

- [ ] Purpose.
- [ ] Signals / Metrics.
- [ ] ALERT vs TREND vs DIAGNOSTIC.
- [ ] Baseline.
- [ ] Correlation.
- [ ] Severity.
- [ ] Validation.
- [ ] Troubleshooting.
- [ ] Runbooks.
- [ ] Sources of truth.
- [ ] Nie wprowadzono arbitralnych progów bez uzasadnienia.

## Troubleshooting

- [ ] Problem/symptom jest jasno nazwany.
- [ ] Pierwsze kroki diagnostyczne są bezpieczne.
- [ ] Wskazane jest evidence do zebrania.
- [ ] Hipotezy są rozdzielone od potwierdzonej diagnozy.
- [ ] Resolution nie ukrywa root cause.
- [ ] Validation opisuje, jak potwierdzić poprawę.
- [ ] Prevention istnieje tam, gdzie ma sens.
- [ ] Linki do source scripts/tools istnieją zamiast kopiowania kodu.

## Runbook

- [ ] README.md.
- [ ] PRECHECK.md.
- [ ] RUNBOOK.md.
- [ ] VALIDATION.md.
- [ ] ROLLBACK.md.
- [ ] Prerequisites i uprawnienia są określone.
- [ ] Stop conditions są jasne.
- [ ] Operacja posiada validation.
- [ ] Rollback/failback jest opisany albo jawnie oznaczony jako niemożliwy.
- [ ] Destrukcyjne kroki wymagają świadomej decyzji operatora.

## ADR

- [ ] Context.
- [ ] Decision drivers.
- [ ] Considered options.
- [ ] Decision.
- [ ] Consequences.
- [ ] Positive.
- [ ] Negative / Trade-offs.
- [ ] Validation.
- [ ] Revisit when.
- [ ] References.
- [ ] Status jest określony.
- [ ] ADR nie duplikuje runbooka.

## Reference / Legacy cleanup

- [ ] Status treści został określony.
- [ ] Canonical entry point istnieje, jeśli materiał nie jest kanoniczny.
- [ ] LEGACY ma wskazanego następcę.
- [ ] Nie usunięto materiału tylko dlatego, że jest stary.
- [ ] Linki prowadzące do artefaktu zostały sprawdzone.

## Inventory

Jeżeli zmiana dodaje, usuwa albo zmienia nazwę kanonicznego artefaktu:

```powershell
python tools/dba-library-quality/generate_inventory.py
```

Następnie:

```powershell
python tools/dba-library-quality/generate_inventory.py --check
```
