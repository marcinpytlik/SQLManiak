# SQL Server Patching — VALIDATION

## Kryteria sukcesu

- oczekiwany build/version
- bazy ONLINE
- SQL Agent działa
- snapshot jobów odtworzony zgodnie z planem
- monitoring aktywny
- HA/FCI/AG zdrowe
- brak krytycznych błędów w ERRORLOG

## Evidence after

Zachowaj:

- build po patchu
- raport patching window
- lista jobów przywróconych/nieprzywróconych
- ERRORLOG
- smoke tests

## Zamknięcie

Nie zamykaj zmiany/incydentu tylko dlatego, że pojedynczy krok zakończył się sukcesem. Potwierdź rezultat techniczny oraz wpływ na usługę.
