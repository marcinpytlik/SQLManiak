
# 09 – Log Truncation

**Problem:** Plik logu nie maleje mimo SHRINK.

## Szybka diagnostyka
```sql
USE tempdb;
GO
DBCC SQLPERF(LOGSPACE);
SELECT name, recovery_model_desc, log_reuse_wait, log_reuse_wait_desc
FROM sys.databases
WHERE name = 'tempdb';
```

**Typowe przyczyny:**
- aktywna transakcja (w tym długi snapshot/RCSI),
- brak CHECKPOINT,
- brak backupu logu (FULL/BULK_LOGGED),
- replikacja, CDC, AlwaysOn AG (HADR).

## Procedura
1) Znajdź blokera:
```sql
SELECT session_id, open_transaction_count FROM sys.dm_exec_sessions WHERE is_user_process = 1;
DBCC OPENTRAN;
```
2) Wymuś CHECKPOINT / backup logu (pełne modele).  
3) Dopiero potem `DBCC SHRINKFILE(log, <target MB>)`.

**Wniosek:** SHRINK to kosmetyka po **truncation**. Nie zamiast.
