# Runbook — Piecemeal Restore (VLDB)
**Cel:** Szybkie uruchomienie krytycznych filegroup i dogrywanie reszty w tle.

## Założenia
- Backupy FULL/Diff/Log dla poszczególnych filegroup.
- Baza: `VLDB`. Krytyczne FG: `PRIMARY`, `FG_HOT`.

## Krok po kroku
1. **NDB**: Utwórz bazę w stanie NORECOVERY z `PRIMARY` (kopie z najnowszych backupów).
2. Przywróć `FG_HOT` (FULL → DIFF → LOGi) w **NORECOVERY**.
3. Wykonaj `RESTORE DATABASE VLDB WITH RECOVERY` — baza startuje, `FG_WARM/COLD/ARCHIVE` pozostają **offline**.
4. Dogrywaj pozostałe FG: `RESTORE DATABASE VLDB FILEGROUP = 'FG_WARM' ... WITH RECOVERY`.
5. Po zakończeniu odtworzeń: sprawdź `sys.database_files`, `sys.filegroups`, `sys.dm_db_file_space_usage`.

## Testy
- `DBCC CHECKDB('VLDB') WITH PHYSICAL_ONLY` po pierwszym etapie, pełny po zakończeniu.
- Integracyjne testy aplikacji na tabelach z `PRIMARY`/`FG_HOT`.
