# Log Shipping DR Failover — VALIDATION

## Kryteria sukcesu

- baza DR jest ONLINE
- osiągnięty punkt danych spełnia zaakceptowane RPO
- aplikacja łączy się do DR
- podstawowe transakcje działają
- czas przełączenia mieści się w RTO lub odchylenie jest udokumentowane

## Evidence after

Zachowaj:

- ostatni odtworzony log
- timestamp RECOVERY
- RPO/RTO achieved
- smoke tests

## Zamknięcie

Nie zamykaj zmiany/incydentu tylko dlatego, że pojedynczy krok zakończył się sukcesem. Potwierdź rezultat techniczny oraz wpływ na usługę.
