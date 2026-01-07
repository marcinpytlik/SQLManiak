# Nazwatabeli – PerfPack (SQL Server 2022)

Cel: szybka analiza incydentu spowolnienia (np. 15:00–15:25) dla zapytań dotykających tabeli `Nazwatabeli`.

## Jak używać (VS Code)
1. Otwórz folder w VS Code.
2. Połącz się z SQL Server (rozszerzenie `mssql`).
3. Uruchamiaj skrypty w kolejności:
   - `01_QueryStore_FindQueries.sql`
   - `02_PlanCache_Fallback.sql` (jeśli Query Store nie ma danych / jest wyłączony)
   - `03_Blocking_Snapshot.sql` (odpal w trakcie problemu)
   - `04_XE_LongRunning_and_Blocking.sql` (ustaw na przyszłość)
   - `05_Table_Health_Indexes_Stats.sql`

## Co zbierać do ticketu (minimum)
- Query Store: `query_id`, `plan_id`, `query_hash`, `query_plan_hash`
- Plan cache (fallback): `plan_handle`, `sql_handle`
- Blocking: `blocking_session_id`, `wait_type`, `wait_resource`, `transaction_isolation_level`
- Baza: `log_reuse_wait_desc`, `VLF count`, `STATS_DATE()` dla kluczowych statystyk
- IO/log: top waits (delta), latencje plików, stan tempdb

> Uwaga: w skryptach są zmienne @From/@To – ustaw konkretną datę incydentu.
