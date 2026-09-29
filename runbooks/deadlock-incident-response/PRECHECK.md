# Deadlock Incident Response — PRECHECK

1. Ustal dokładne okno czasu.
2. Pobierz xml_deadlock_report z system_health.
3. Zidentyfikuj victim i wszystkie processes.
4. Zapisz resources, lock modes, isolation levels i SQL.
5. Sprawdź plany i access order.

## Evidence before
- deadlock graph XML
- query text/plans
- process metadata
- frequency/business impact

## Stop conditions
- brak graph i próba diagnozy tylko z current DMVs
- planowana jest szeroka zmiana isolation/MAXDOP bez evidence
