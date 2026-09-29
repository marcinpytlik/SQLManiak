# Query Store Regression Mitigation — PRECHECK

## Sprawdzenia
1. Sprawdź Query Store state.
2. Zdefiniuj BEFORE i INCIDENT.
3. Znajdź query_id i plan_id.
4. Porównaj execution count, duration, CPU, reads i waits.
5. Potwierdź plan regression, a nie tylko wzrost workloadu.

## Evidence before
- query_id
- plan_id
- runtime stats
- plans
- incident window

## Stop conditions
- brak known-good plan
- brak reprezentatywnych danych
- problem nie jest plan regression
