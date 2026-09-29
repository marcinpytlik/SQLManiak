# Runbook: Query Store Regression Mitigation

## Cel

Szybka, odwracalna stabilizacja zapytania po potwierdzonej regresji planu.

## Kiedy użyć

- wzrost duration/CPU/reads po zmianie planu
- regresja po compat level/deployment/statistics

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [Query Store troubleshooting](../../troubleshooting/query-store/)
- [Regression lab](../../labs/01-query-store-regression/)
- [QS Compat Report](../../scripts/t-sql/database/QS-Compat-Report/)

> Force Plan i Query Store Hint są mitigacją; po stabilizacji nadal trzeba znaleźć root cause.
