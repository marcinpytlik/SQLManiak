# SQL Server 2016 to 2022 Migration — VALIDATION

## Kryteria sukcesu

- wszystkie bazy ONLINE/READ_WRITE na destination
- loginy/mapowania działają
- SQL Agent jobs i schedules poprawne
- Query Store działa zgodnie z planem
- backupy/restore test działają na 2022
- smoke tests aplikacji zakończone sukcesem
- monitoring i alerty działają

## Evidence after

Zachowaj:

- postcheck logs
- listę orphaned users
- baseline/Query Store after
- wyniki smoke tests
- RPO/RTO verification

## Zamknięcie

Nie zamykaj zmiany/incydentu tylko dlatego, że pojedynczy krok zakończył się sukcesem. Potwierdź rezultat techniczny oraz wpływ na usługę.
