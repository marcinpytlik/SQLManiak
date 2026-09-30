# Standard: Query Store

## Purpose

Zapewnić historyczne źródło danych o planach, runtime statistics i regresjach zapytań dla baz produkcyjnych.

## Scope

Bazy produkcyjne oraz inne bazy, w których wymagane jest porównywanie planów i zachowania workloadu w czasie.

## Requirements

### Required

- Query Store jest włączony dla baz produkcyjnych, chyba że istnieje zatwierdzony wyjątek.
- Oczekiwany stan operacyjny to `READ_WRITE`.
- Stan `READ_ONLY` jest monitorowany i wyjaśniany.
- Rozmiar, retencja i capture mode są dobrane do aktywności bazy.
- Przed zmianą compatibility level zbierany jest baseline Query Store.
- Force Plan i Query Store Hints są dokumentowane.
- Forced plans są okresowo przeglądane.
- Query Store nie jest czyszczony bez analizy i uzasadnienia.

### Recommended

Obecne materiały repo używają jako punktów odniesienia:

```text
retention: 30–90 dni dla typowego OLTP
interval: 15–60 min
max storage: zależnie od bazy, przykładowo 1000–5000 MB
```

To wartości orientacyjne, nie uniwersalne progi.

Dla SQL Server i scenariuszy, które to wspierają, warto przechwytywać Query Store wait statistics, jeśli są potrzebne diagnostycznie.

### Not allowed

- Wymuszanie planu wyłącznie dlatego, że historycznie miał najniższe `avg_duration`.
- Traktowanie forcingu jako permanentnego rozwiązania bez RCA.
- Czyszczenie Query Store podczas incydentu bez zachowania evidence.
- Pozostawianie `READ_ONLY` bez wyjaśnienia przyczyny.
- Porównywanie nieporównywalnych okien workloadu jako dowodu regresji.

## Default configuration

Standard wymaga świadomej konfiguracji:

```text
QUERY_STORE = ON
OPERATION_MODE = READ_WRITE
capture mode = dobrany do workloadu
retention = dobrana do potrzeb diagnostycznych
storage limit = dobrany do aktywności bazy
```

## Exceptions

Wyjątek musi wskazywać:

- bazę,
- przyczynę wyłączenia/ograniczenia Query Store,
- ownera,
- termin ponownego przeglądu,
- alternatywne źródło historii performance.

## Validation

- `actual_state_desc`,
- `desired_state_desc`,
- `current_storage_size_mb`,
- `max_storage_size_mb`,
- capture mode,
- forced plans / force failures,
- historia regresji.

## Ownership

DBA / właściciel platformy performance.

## Review cycle

- miesięcznie,
- po upgrade/migracji,
- przed i po compatibility level change,
- po incydencie plan regression.

## References

- [Query Store Checklist](../../labs/QueryStore/checklists/QueryStore-Checklist.md)
- [Query Store Troubleshooting](../../troubleshooting/query-store/)
- [Query Store Regression Runbook](../../runbooks/query-store-regression-mitigation/)
