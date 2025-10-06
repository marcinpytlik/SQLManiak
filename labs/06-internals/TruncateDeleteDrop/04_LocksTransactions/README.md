# 04 – DELETE vs TRUNCATE: blokady i transakcje

**Concept:**  
- `DELETE` – locki na wierszach/stronach z możliwą eskalacją do TAB (X). Rollback „cofa wiersze”.  
- `TRUNCATE` – szybkie, ale zakłada `Sch-M` na tabeli (blokuje wszystkich na czas operacji). Rollback „cofa wszystko” jednym ruchem.

## Kolejność
1. `01_prepare.sql` – tworzy i wypełnia `dbo.DemoLocks` w `tempdb`.
2. Otwórz **dwa okna**:
   - Okno A: `02_delete_in_tran.sql` – zostaw otwartą transakcję i podejrzyj blokady.
   - Okno B: `04_locks_query.sql` – podgląd `sys.dm_tran_locks`.
3. Powtórz dla `03_truncate_in_tran.sql` (Okno A) + `04_locks_query.sql` (Okno B).
