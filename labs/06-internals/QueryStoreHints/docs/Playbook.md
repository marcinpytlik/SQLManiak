# Playbook – Query Store Hints (SQL Server 2022)

## 1) Upewnij się, że Query Store działa
```sql
SELECT current_storage_size_mb, desired_state_desc, actual_state_desc, readonly_reason
FROM sys.database_query_store_options;
```
Jeśli `actual_state_desc <> READ_WRITE` – włącz:
```sql
ALTER DATABASE CURRENT SET QUERY_STORE = ON;
ALTER DATABASE CURRENT SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
```

## 2) Znajdź `query_id`
- Tekstowo: `scripts/QSH_Find_Query_ByText.sql`
- Po planie lub hash: rozwiń zapytanie w tym skrypcie.

## 3) Oceń problem
- Live: `sys.dm_exec_query_memory_grants`, spill w `sys.dm_exec_query_stats` (spills_*), waity (`RESOURCE_SEMAPHORE`)
- Historycznie: Query Store runtime stats (czas/CPU/reads przed/po).

## 4) Nałóż hint
- `QSH_Set_Hint_MAX_GRANT.sql` – ogranicz grant (np. 5%)
- `QSH_Set_Hint_DISABLE_PS.sql` – wyłącz sniffing (tymczasowo)
- `QSH_Set_Hint_Compat150.sql` – zachowanie optymalizatora 2019

## 5) Zweryfikuj
- `QSH_Report_Hints.sql` – czy hint jest aktywny
- Porównaj runtime stats w Query Store (przed/po)

## 6) Cofnij
- `QSH_Remove_Hints_ForQuery.sql` – usuń dla jednego `query_id`
- `QSH_Remove_All_Hints.sql` – usuń hurtowo (ostrożnie)

## Tipy
- Zacznij od **MAX_GRANT_PERCENT** niewielkiego (np. 5–10%). Mierz efekty.
- Jeśli hint „nie działa”, upewnij się, że celujesz w **właściwy `query_id`** i były **nowe przebiegi**.
