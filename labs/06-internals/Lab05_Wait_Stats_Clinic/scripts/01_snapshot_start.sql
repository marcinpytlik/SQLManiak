-- scripts/01_snapshot_start.sql
-- START snapshot waitów (nie czyści globalnie, zapisujemy stan do tabeli tempdb)

USE tempdb;
GO
IF OBJECT_ID('tempdb..#waits_start') IS NOT NULL DROP TABLE #waits_start;
SELECT * INTO #waits_start FROM sys.dm_os_wait_stats;
SELECT COUNT(*) AS captured FROM #waits_start;
