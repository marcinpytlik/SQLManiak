# Troubleshooting: Query Performance

## Symptoms

- pojedyncze zapytanie nagle działa wolniej,
- wzrost czasu odpowiedzi w konkretnym przedziale,
- regresja planu,
- duże CPU lub logical reads dla wybranych zapytań,
- różne czasy wykonania tego samego zapytania.

## First checks

1. Query Store.
2. Plan cache jako fallback.
3. Blocking w czasie problemu.
4. Execution plan.
5. Statystyki i indeksy.
6. I/O, waits i TempDB.
7. Parametry i możliwy parameter sniffing.

## Existing sources of truth

### Request PerfPack

- [README](../../scripts/t-sql/Reques_PerfPack/README.md)
- [01_QueryStore_FindQueries.sql](../../scripts/t-sql/Reques_PerfPack/01_QueryStore_FindQueries.sql)
- [02_PlanCache_Fallback.sql](../../scripts/t-sql/Reques_PerfPack/02_PlanCache_Fallback.sql)
- [03_Blocking_Snapshot.sql](../../scripts/t-sql/Reques_PerfPack/03_Blocking_Snapshot.sql)
- [04_XE_LongRunning_and_Blocking.sql](../../scripts/t-sql/Reques_PerfPack/04_XE_LongRunning_and_Blocking.sql)
- [05_Table_Health_Indexes_Stats.sql](../../scripts/t-sql/Reques_PerfPack/05_Table_Health_Indexes_Stats.sql)

### Additional diagnostics

- [Query Store PBM notes](../../scripts/PBM_QueryStore.md)
- [DBA Daily Pack](../../tools/DBADaillyPack/)

## Evidence to collect

- query_id,
- plan_id,
- query_hash,
- query_plan_hash,
- execution count,
- duration,
- CPU,
- logical reads,
- waits,
- plan XML,
- statistics date,
- blocking context,
- exact incident window.

## Validation

Porównuj **przed i po**:

- duration,
- CPU,
- logical reads,
- execution plan,
- wait profile,
- concurrency impact.

Nie oceniaj poprawy tylko na podstawie jednego szybkiego wykonania.
