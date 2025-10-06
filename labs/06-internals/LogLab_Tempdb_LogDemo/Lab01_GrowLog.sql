/* Lab 01 — Jak napompować LOG (duża transakcja) */
USE LogLab;
CHECKPOINT;

BEGIN TRAN;
;WITH N AS(
  SELECT 1 n UNION ALL SELECT 1
), Tally AS(
  SELECT TOP (200000) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS i
  FROM N a,N b,N c,N d,N e,N f
)
INSERT dbo.BigT DEFAULT VALUES
OPTION (MAXDOP 1);

/* Nie kończ transakcji – podejrzyj rozmiary: */
SELECT total_log_size_mb, active_log_size_mb, log_truncation_holdup_reason
FROM sys.dm_db_log_stats(DB_ID());

COMMIT;

SELECT total_log_size_mb, active_log_size_mb, log_truncation_holdup_reason
FROM sys.dm_db_log_stats(DB_ID());
