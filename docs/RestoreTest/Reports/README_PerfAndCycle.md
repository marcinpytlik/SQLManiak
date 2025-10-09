# Restore – Performance & Full Cycle

## Full Cycle (manual sequence)
1. **Cleanup: DemoDB_Test** – usuwa poprzednią bazę testową i pliki.
2. **Restore: FULL+DIFF+LOG (DemoDB_Test)** lub **Restore: Point-in-Time (STOPAT)**.
3. **VerifyOnly: wszystkie .bak w D:\Backup** (opcjonalnie przed/po teście).

## Metryki
- Log trafia do: `msdb.dbo.RestorePerfLog` (tworzy `Scripts/Restore_PerfMetrics.sql`).
- Podsumowanie: `msdb.dbo.v_RestorePerfSummary`.

### Przykładowe zapytania
```sql
SELECT TOP (50) * FROM msdb.dbo.RestorePerfLog ORDER BY test_date DESC;
SELECT * FROM msdb.dbo.v_RestorePerfSummary ORDER BY last_test_date DESC;
```
