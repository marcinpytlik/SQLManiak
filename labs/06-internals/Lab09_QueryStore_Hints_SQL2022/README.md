# Lab 09 — Query Store Hints (SQL Server 2022+)

Cel:
- Pokazać **Query Store Hints**: wymuszanie hintów *bez zmiany kodu* (np. `MAXDOP`, `USE HINT ('DISABLE_OPTIMIZER_ROWGOAL')`, `QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_*`).
- Porównać czasy wykonania i IO przed/po zastosowaniu hintów.
- Zarządzać hintami: dodaj, podejrzyj, usuń.

## Wymagania
- SQL Server 2022 (compat 160), Query Store w trybie READ_WRITE.
