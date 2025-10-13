
# 03 – SPID < 50

**Idea:** SPID mniejsze niż 50 to wewnętrzne procesy systemowe: LOG WRITER, LAZY WRITER, RESOURCE MONITOR itd.

## Podgląd
```sql
SELECT s.session_id, s.login_name, s.status, r.command, r.wait_type, r.cpu_time, r.total_elapsed_time
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r ON s.session_id = r.session_id
WHERE s.session_id < 50
ORDER BY s.session_id;
```

## Ciekawostka
- Nie „zabijaj” tych sesji. To wbudowane usługi silnika.
- Zdarza się zobaczyć GHOST CLEANUP, CHECKPOINT, DB STARTUP/SHUTDOWN.
