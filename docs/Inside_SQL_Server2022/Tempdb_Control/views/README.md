# T-SQL Views — kontrola rozrostu i długich transakcji

## 🧠 Konwencje
- Widoki w bazie **DBA** agregują logi z jobów (`LongTransactions`, `StorageSignals`, `TempdbHealth`).
- Widoki **Query Store** uruchamiaj **w kontekście każdej bazy użytkownika** (QS jest per-database).

---

## 1) Widoki w bazie DBA

> Uruchom w bazie `DBA`.

```sql
USE DBA;
GO

-- 1.1 Najnowsze długie transakcje (z logu)
CREATE OR ALTER VIEW dbo.vLongTransactions AS
SELECT
    l.LoggedAt,
    l.MinutesOpen,
    l.SessionID,
    l.TransactionID,
    l.DatabaseName,
    l.LoginName,
    l.HostName,
    l.ProgramName,
    l.WaitType,
    l.BlockingSession,
    LEFT(l.StatementText, 4000) AS StatementSample
FROM dbo.LongTransactionsLog AS l;
GO

-- 1.2 Najstarsza transakcja w ostatnich N minutach (domyślnie 60) – do szybkiego podglądu
CREATE OR ALTER VIEW dbo.vOldestTransaction_60m AS
SELECT TOP(1) *
FROM dbo.vLongTransactions
WHERE LoggedAt > DATEADD(MINUTE, -60, SYSUTCDATETIME())
ORDER BY MinutesOpen DESC, LoggedAt DESC;
GO

-- 1.3 Autogrow z ostatniej godziny (licznik per baza)
CREATE OR ALTER VIEW dbo.vAutogrowLastHour AS
WITH last1h AS (
  SELECT DatabaseName, COUNT(*) AS events
  FROM dbo.FileGrowthLog
  WHERE EventTime > DATEADD(HOUR, -1, SYSUTCDATETIME())
  GROUP BY DatabaseName
)
SELECT * FROM last1h
ORDER BY events DESC;
GO

-- 1.4 Autogrow: seria godzinowa z ostatnich 24h (przydatne do trendu)
CREATE OR ALTER VIEW dbo.vAutogrowHourly_24h AS
WITH bucket AS (
  SELECT
    DATEADD(HOUR, DATEDIFF(HOUR, 0, EventTime), 0) AS hour_bucket,
    DatabaseName
  FROM dbo.FileGrowthLog
  WHERE EventTime > DATEADD(HOUR, -24, SYSUTCDATETIME())
)
SELECT hour_bucket, DatabaseName, COUNT(*) AS events
FROM bucket
GROUP BY hour_bucket, DatabaseName
ORDER BY hour_bucket DESC, events DESC;
GO

-- 1.5 Version Store – średnia z ostatnich 15 minut (GB) per baza
CREATE OR ALTER VIEW dbo.vVersionStore15min AS
SELECT
    DatabaseId,
    DatabaseName,
    CAST(AVG(VersionStoreKB)/1024.0/1024.0 AS DECIMAL(18,2)) AS VS_GB_15min_avg
FROM dbo.VersionStoreUsageLog
WHERE CollectedAt > DATEADD(MINUTE, -15, SYSUTCDATETIME())
GROUP BY DatabaseId, DatabaseName
ORDER BY VS_GB_15min_avg DESC;
GO

-- 1.6 Version Store – ostatni odczyt (GB)
CREATE OR ALTER VIEW dbo.vVersionStoreLatest AS
WITH x AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY DatabaseId ORDER BY CollectedAt DESC) AS rn
  FROM dbo.VersionStoreUsageLog
)
SELECT
  DatabaseId, DatabaseName,
  CAST(VersionStoreKB/1024.0/1024.0 AS DECIMAL(18,2)) AS VS_GB_latest,
  CollectedAt
FROM x
WHERE rn = 1
ORDER BY VS_GB_latest DESC;
GO

-- 1.7 Rozmiary plików wszystkich baz (DATA/LOG) – snapshot z sys.master_files
CREATE OR ALTER VIEW dbo.vDbFileSizes AS
SELECT
    DB_NAME(mf.database_id) AS DatabaseName,
    mf.type_desc            AS FileType,
    mf.name                 AS FileLogicalName,
    mf.physical_name,
    CAST(mf.size*8.0/1024.0 AS DECIMAL(18,2)) AS SizeMB,
    mf.max_size,
    mf.is_percent_growth,
    mf.growth
FROM sys.master_files AS mf
ORDER BY DatabaseName, FileType;
GO

-- 1.8 Najcięższe typy oczekiwań (od startu instancji) – do sanity check
CREATE OR ALTER VIEW dbo.vWaitsTop AS
SELECT TOP(50)
    wait_type,
    wait_time_ms,
    signal_wait_time_ms,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE 'SLEEP%' AND wait_type NOT LIKE 'XE_TIMER%'
ORDER BY wait_time_ms DESC;
GO
```

---

## 2) Widoki Query Store (uruchamiaj w każdej bazie z QS)

> Uruchom w **docelowej bazie użytkownika**, np. `USE YourDb;`.  
> Wymagane: Query Store włączony:  
> `ALTER DATABASE CURRENT SET QUERY_STORE = ON;`

```sql
-- 2.1 Top Duration – ostatnie 7 dni (sumaryczny czas wykonania)
CREATE OR ALTER VIEW dbo.vQS_TopDuration_7d AS
WITH rs AS (
  SELECT
    qsq.query_id,
    qsp.plan_id,
    SUM(rs.runtime_stats_total_duration) AS total_duration_us,
    SUM(rs.count_executions) AS exec_count,
    MAX(rs.last_execution_time) AS last_exec_time
  FROM sys.query_store_runtime_stats AS rs
  JOIN sys.query_store_plan           AS qsp ON qsp.plan_id  = rs.plan_id
  JOIN sys.query_store_query          AS qsq ON qsq.query_id = qsp.query_id
  WHERE rs.last_execution_time > DATEADD(DAY, -7, SYSUTCDATETIME())
  GROUP BY qsq.query_id, qsp.plan_id
),
t AS (
  SELECT
    rs.query_id, rs.plan_id,
    rs.total_duration_us/1000.0 AS total_duration_ms,
    rs.exec_count,
    rs.last_exec_time
  FROM rs
)
SELECT TOP(50)
  t.total_duration_ms,
  t.exec_count,
  t.last_exec_time,
  t.query_id, t.plan_id,
  LEFT(qt.query_sql_text, 4000) AS query_text
FROM t
JOIN sys.query_store_query_text AS qt
  ON qt.query_text_id = (SELECT query_text_id FROM sys.query_store_query WHERE query_id = t.query_id)
ORDER BY total_duration_ms DESC;
GO

-- 2.2 Top CPU – ostatnie 7 dni
CREATE OR ALTER VIEW dbo.vQS_TopCPU_7d AS
WITH rs AS (
  SELECT
    qsq.query_id, qsp.plan_id,
    SUM(rs.runtime_stats_cpu_time) AS cpu_us,
    SUM(rs.count_executions) AS exec_count,
    MAX(rs.last_execution_time) AS last_exec_time
  FROM sys.query_store_runtime_stats AS rs
  JOIN sys.query_store_plan  AS qsp ON qsp.plan_id  = rs.plan_id
  JOIN sys.query_store_query AS qsq ON qsq.query_id = qsp.query_id
  WHERE rs.last_execution_time > DATEADD(DAY, -7, SYSUTCDATETIME())
  GROUP BY qsq.query_id, qsp.plan_id
)
SELECT TOP(50)
  (cpu_us/1000.0) AS cpu_ms,
  exec_count,
  last_exec_time,
  query_id, plan_id,
  LEFT(qt.query_sql_text, 4000) AS query_text
FROM rs
JOIN sys.query_store_query_text AS qt
  ON qt.query_text_id = (SELECT query_text_id FROM sys.query_store_query WHERE query_id = rs.query_id)
ORDER BY cpu_ms DESC;
GO

-- 2.3 Regressive queries – pogorszenie czasu średniego (7d vs poprzednie 7d)
CREATE OR ALTER VIEW dbo.vQS_Regressions AS
WITH base AS (
  SELECT
    qsq.query_id, qsp.plan_id,
    CASE WHEN rs.first_execution_time >= DATEADD(DAY,-7,SYSUTCDATETIME()) THEN 'new'
         WHEN rs.last_execution_time  >= DATEADD(DAY,-7,SYSUTCDATETIME()) THEN 'recent'
         ELSE 'old' END AS bucket,
    SUM(rs.runtime_stats_total_duration) AS dur_us,
    SUM(rs.count_executions) AS execs
  FROM sys.query_store_runtime_stats rs
  JOIN sys.query_store_plan  qsp ON qsp.plan_id  = rs.plan_id
  JOIN sys.query_store_query qsq ON qsq.query_id = qsp.query_id
  GROUP BY qsq.query_id, qsp.plan_id,
    CASE WHEN rs.first_execution_time >= DATEADD(DAY,-7,SYSUTCDATETIME()) THEN 'new'
         WHEN rs.last_execution_time  >= DATEADD(DAY,-7,SYSUTCDATETIME()) THEN 'recent'
         ELSE 'old' END
),
agg AS (
  SELECT query_id,
         SUM(CASE WHEN bucket='recent' THEN dur_us END) / NULLIF(SUM(CASE WHEN bucket='recent' THEN execs END),0) AS recent_avg_us,
         SUM(CASE WHEN bucket='old'    THEN dur_us END) / NULLIF(SUM(CASE WHEN bucket='old'    THEN execs END),0) AS old_avg_us
  FROM base
  GROUP BY query_id
)
SELECT TOP(50)
  a.query_id,
  (a.recent_avg_us/1000.0) AS recent_avg_ms,
  (a.old_avg_us/1000.0)    AS old_avg_ms,
  ((a.recent_avg_us - a.old_avg_us)/NULLIF(a.old_avg_us,0))*100.0 AS regression_pct,
  LEFT(qt.query_sql_text, 4000) AS query_text
FROM agg a
JOIN sys.query_store_query AS qsq ON qsq.query_id = a.query_id
JOIN sys.query_store_query_text AS qt ON qt.query_text_id = qsq.query_text_id
WHERE a.old_avg_us IS NOT NULL AND a.recent_avg_us IS NOT NULL
  AND a.recent_avg_us > a.old_avg_us * 1.3     -- >30% gorzej
ORDER BY regression_pct DESC;
GO

-- 2.4 Plan variants – ile planów dla zapytania (podejrzenie PSP/param sniffing)
CREATE OR ALTER VIEW dbo.vQS_PlanVariants AS
SELECT
  qsq.query_id,
  COUNT(DISTINCT qsp.plan_id) AS plan_variants,
  MIN(qsp.last_compile_start_time) AS first_seen,
  MAX(qsp.last_execution_time)     AS last_seen,
  LEFT(qt.query_sql_text, 4000)    AS query_text
FROM sys.query_store_query AS qsq
JOIN sys.query_store_plan  AS qsp ON qsp.query_id = qsq.query_id
JOIN sys.query_store_query_text AS qt ON qt.query_text_id = qsq.query_text_id
GROUP BY qsq.query_id, qt.query_sql_text
HAVING COUNT(DISTINCT qsp.plan_id) >= 2
ORDER BY plan_variants DESC, last_seen DESC;
GO

-- 2.5 PSP heuristic – zmienność czasu/wierszy między planami
CREATE OR ALTER VIEW dbo.vQS_ParameterSensitivity AS
WITH rs AS (
  SELECT
    qsq.query_id, qsp.plan_id,
    SUM(rs.runtime_stats_total_duration) AS dur_us,
    SUM(rs.count_executions) AS execs,
    SUM(rs.runtime_stats_rowcount) AS rows_total
  FROM sys.query_store_runtime_stats AS rs
  JOIN sys.query_store_plan  AS qsp ON qsp.plan_id  = rs.plan_id
  JOIN sys.query_store_query AS qsq ON qsq.query_id = qsp.query_id
  WHERE rs.last_execution_time > DATEADD(DAY,-7,SYSUTCDATETIME())
  GROUP BY qsq.query_id, qsp.plan_id
),
perq AS (
  SELECT query_id,
         COUNT(*) AS plans,
         AVG(CASE WHEN execs>0 THEN dur_us/execs END) AS avg_us_per_exec,
         MIN(CASE WHEN execs>0 THEN dur_us/execs END) AS min_us_per_exec,
         MAX(CASE WHEN execs>0 THEN dur_us/execs END) AS max_us_per_exec,
         AVG(CASE WHEN execs>0 THEN rows_total/execs END) AS avg_rows_per_exec,
         MIN(CASE WHEN execs>0 THEN rows_total/execs END) AS min_rows_per_exec,
         MAX(CASE WHEN execs>0 THEN rows_total/execs END) AS max_rows_per_exec
  FROM rs
  GROUP BY query_id
)
SELECT TOP(50)
  p.query_id,
  p.plans AS plan_variants_7d,
  (p.max_us_per_exec/1000.0) AS max_ms_per_exec,
  (p.min_us_per_exec/1000.0) AS min_ms_per_exec,
  CASE WHEN p.min_us_per_exec>0 THEN (p.max_us_per_exec/p.min_us_per_exec) END AS exec_time_ratio,
  p.avg_rows_per_exec, p.min_rows_per_exec, p.max_rows_per_exec,
  LEFT(qt.query_sql_text, 4000) AS query_text
FROM perq p
JOIN sys.query_store_query AS qsq ON qsq.query_id = p.query_id
JOIN sys.query_store_query_text AS qt ON qt.query_text_id = qsq.query_text_id
WHERE p.plans >= 2
  AND p.min_us_per_exec IS NOT NULL
  AND p.max_us_per_exec > p.min_us_per_exec * 4
ORDER BY exec_time_ratio DESC, max_ms_per_exec DESC;
GO
```

---

## 3) Widoki – Tempdb Health (DBA)

> Uruchom w bazie `DBA`.

```sql
USE DBA;
GO

-- 3.1 Ostatni pomiar (ostatni wiersz z logu)
CREATE OR ALTER VIEW dbo.vTempdbHealthLast AS
WITH x AS (
  SELECT *,
         ROW_NUMBER() OVER (ORDER BY LoggedAtUtc DESC) AS rn
  FROM dbo.TempdbHealthLog
)
SELECT
  LoggedAtUtc,
  VersionStoreGB,
  TempdbTotalGB,
  TempdbFreeGB,
  DiskFreeGB,
  DrivesCsv,
  ThresholdVS_GB,
  ThresholdDisk_GB,
  IsVSExceeded,
  IsDiskExceeded,
  Note
FROM x
WHERE rn = 1;
GO

-- 3.2 Alerty z ostatnich 24h (przekroczenia progów)
CREATE OR ALTER VIEW dbo.vTempdbHealthAlerts24h AS
SELECT
  LoggedAtUtc,
  VersionStoreGB,
  ThresholdVS_GB,
  DiskFreeGB,
  ThresholdDisk_GB,
  IsVSExceeded,
  IsDiskExceeded,
  DrivesCsv,
  Note
FROM dbo.TempdbHealthLog
WHERE LoggedAtUtc >= DATEADD(HOUR,-24,SYSUTCDATETIME())
  AND (IsVSExceeded = 1 OR IsDiskExceeded = 1)
ORDER BY LoggedAtUtc DESC;
GO

-- 3.3 Trend godzinowy z 24h (agregacja do godzin)
CREATE OR ALTER VIEW dbo.vTempdbHealthHourly_24h AS
WITH b AS (
  SELECT
    DATEADD(HOUR, DATEDIFF(HOUR, 0, LoggedAtUtc), 0) AS hour_bucket,
    VersionStoreGB,
    TempdbTotalGB,
    TempdbFreeGB,
    DiskFreeGB
  FROM dbo.TempdbHealthLog
  WHERE LoggedAtUtc >= DATEADD(HOUR,-24,SYSUTCDATETIME())
)
SELECT
  hour_bucket,
  CAST(AVG(VersionStoreGB) AS DECIMAL(18,2)) AS VS_GB_avg,
  CAST(MAX(VersionStoreGB) AS DECIMAL(18,2)) AS VS_GB_max,
  CAST(AVG(TempdbTotalGB)  AS DECIMAL(18,2)) AS TempdbTotal_GB_avg,
  CAST(AVG(TempdbFreeGB)   AS DECIMAL(18,2)) AS TempdbFree_GB_avg,
  CAST(MIN(DiskFreeGB)     AS DECIMAL(18,2)) AS DiskFree_GB_min
FROM b
GROUP BY hour_bucket
ORDER BY hour_bucket DESC;
GO
```

### Szybkie zapytania

```sql
-- W DBA:
SELECT * FROM DBA.dbo.vAutogrowLastHour;
SELECT * FROM DBA.dbo.vVersionStore15min;
SELECT TOP(20) * FROM DBA.dbo.vLongTransactions ORDER BY LoggedAt DESC;

-- Tempdb Health:
SELECT * FROM DBA.dbo.vTempdbHealthLast;
SELECT * FROM DBA.dbo.vTempdbHealthAlerts24h;
SELECT * FROM DBA.dbo.vTempdbHealthHourly_24h ORDER BY hour_bucket;

-- W bazie user (Query Store):
SELECT TOP(20) * FROM dbo.vQS_TopDuration_7d;
SELECT TOP(20) * FROM dbo.vQS_Regressions;
SELECT TOP(20) * FROM dbo.vQS_ParameterSensitivity;
```
