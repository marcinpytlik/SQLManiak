# TempDB Emergency — PRECHECK

1. Sprawdź rozmiar/free space i autogrowth.
2. Znajdź top consumers.
3. Sprawdź version store i aktywne transakcje.
4. Sprawdź spills/worktables.
5. Sprawdź allocation contention.
6. W FCI sprawdź lokalną ścieżkę TempDB.

## Evidence before
- file sizes/free
- top consumers
- version store
- active transactions
- waits
- growth history

## Stop conditions
- planowany restart bez identyfikacji konsumenta
- planowany shrink podczas aktywnego pressure
- brak miejsca na filesystemie bez planu capacity
