# DBCC CHECKDB / Corruption Recovery — PRECHECK

## Sprawdzenia
1. Zapisz pełny output CHECKDB i numery błędów.
2. Sprawdź msdb.dbo.suspect_pages.
3. Sprawdź SQL ERRORLOG i Windows/storage events.
4. Zweryfikuj backup chain i restore test.
5. Oceń, czy właściwy jest full/file/page restore.

## Evidence before
- CHECKDB output
- suspect_pages
- ERRORLOG
- storage events
- backup chain

## Stop conditions
- brak wiedzy o zakresie corruption
- backup chain niezweryfikowany
- plan zakłada data-loss repair bez akceptacji
