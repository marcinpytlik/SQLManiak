
/*
    QS_Compat_Report.sql
    Raport Query Store PRZED/PO zmianie COMPATIBILITY_LEVEL (130 -> 160).
    Autor: marcin + Duduś
    Wymagania: SQL Server 2022, Query Store ON (READ_WRITE).
*/

-- ===== 0) KONFIGURACJA =======================================================
USE [TwojaBaza]; -- TODO: ZMIEŃ NA NAZWĘ BAZY
GO

-- Okna czasowe - dopasuj do swoich "przed" i "po"
DECLARE @BeforeStart datetime2 = '2025-09-26 08:00:00';
DECLARE @BeforeEnd   datetime2 = '2025-09-26 10:00:00';
DECLARE @AfterStart  datetime2 = '2025-09-26 10:15:00';
DECLARE @AfterEnd    datetime2 = '2025-09-26 12:15:00';

-- Upewnij się, że Query Store zbiera dane
ALTER DATABASE CURRENT SET QUERY_STORE = ON;
ALTER DATABASE CURRENT SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
-- (opcjonalnie) zwiększ limit rozmiaru:
-- ALTER DATABASE CURRENT SET QUERY_STORE (MAX_STORAGE_SIZE_MB = 20480);


-- ===== 1) OBIEKTY POMOCNICZE =================================================

-- 1.1) Tabela na snapshoty (agregaty per query_hash)
IF OBJECT_ID('dbo.QS_Snapshot', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.QS_Snapshot
    (
        snapshot_id     int IDENTITY(1,1) PRIMARY KEY,
        label           sysname        NOT NULL,   -- 'BEFORE' / 'AFTER'
        captured_at     datetime2      NOT NULL DEFAULT SYSUTCDATETIME(),
        query_hash      bigint         NOT NULL,
        query_text      nvarchar(max)  NULL,
        total_execs     bigint         NOT NULL,
        total_duration_ms    bigint    NOT NULL,
        avg_duration_ms      decimal(18,3) NOT NULL,
        total_cpu_ms         bigint    NOT NULL,
        avg_cpu_ms           decimal(18,3) NOT NULL,
        total_logical_reads  bigint    NOT NULL,
        avg_logical_reads    decimal(18,3) NOT NULL,
        total_logical_writes bigint    NOT NULL,
        avg_logical_writes   decimal(18,3) NOT NULL
    );
END
GO

-- 1.2) Procedura: snapshot z danego okna czasu
IF OBJECT_ID('dbo.QS_TakeSnapshot', 'P') IS NOT NULL
    DROP PROCEDURE dbo.QS_TakeSnapshot;
GO
CREATE PROCEDURE dbo.QS_TakeSnapshot
(
      @Label sysname
    , @StartTime datetime2
    , @EndTime   datetime2
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH rs AS
    (
        SELECT
            q.query_hash,
            qt.query_sql_text,
            SUM(r.execution_count)                                          AS total_execs,
            SUM(r.total_duration) / 1000                                    AS total_duration_ms, -- mikrosek. -> ms
            SUM(r.total_cpu_time) / 1000                                    AS total_cpu_ms,      -- mikrosek. -> ms
            SUM(r.total_logical_reads)                                      AS total_logical_reads,
            SUM(r.total_logical_writes)                                     AS total_logical_writes
        FROM sys.query_store_runtime_stats r
        JOIN sys.query_store_plan         p  ON p.plan_id  = r.plan_id
        JOIN sys.query_store_query        q  ON q.query_id = p.query_id
        JOIN sys.query_store_query_text   qt ON qt.query_text_id = q.query_text_id
        JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id = r.runtime_stats_interval_id
        WHERE i.start_time >= @StartTime
          AND i.end_time   <= @EndTime
        GROUP BY q.query_hash, qt.query_sql_text
    )
    INSERT dbo.QS_Snapshot
    (
        label, query_hash, query_text,
        total_execs, total_duration_ms, avg_duration_ms,
        total_cpu_ms,  avg_cpu_ms,
        total_logical_reads, avg_logical_reads,
        total_logical_writes, avg_logical_writes
    )
    SELECT
        @Label,
        query_hash,
        query_sql_text,
        total_execs,
        total_duration_ms,
        CASE WHEN total_execs > 0 THEN CAST(1.0 * total_duration_ms / total_execs AS decimal(18,3)) ELSE 0 END,
        total_cpu_ms,
        CASE WHEN total_execs > 0 THEN CAST(1.0 * total_cpu_ms / total_execs       AS decimal(18,3)) ELSE 0 END,
        total_logical_reads,
        CASE WHEN total_execs > 0 THEN CAST(1.0 * total_logical_reads / total_execs AS decimal(18,3)) ELSE 0 END,
        total_logical_writes,
        CASE WHEN total_execs > 0 THEN CAST(1.0 * total_logical_writes / total_execs AS decimal(18,3)) ELSE 0 END;
END
GO

-- 1.3) Widok porównawczy BEFORE vs AFTER (po query_hash)
IF OBJECT_ID('dbo.v_QS_Compare', 'V') IS NOT NULL
    DROP VIEW dbo.v_QS_Compare;
GO
CREATE VIEW dbo.v_QS_Compare
AS
SELECT
    COALESCE(b.query_hash, a.query_hash)              AS query_hash,
    COALESCE(a.query_text,  b.query_text)             AS query_text,

    b.total_execs          AS before_execs,
    b.avg_duration_ms      AS before_avg_duration_ms,
    b.avg_cpu_ms           AS before_avg_cpu_ms,
    b.avg_logical_reads    AS before_avg_lreads,
    b.avg_logical_writes   AS before_avg_lwrites,

    a.total_execs          AS after_execs,
    a.avg_duration_ms      AS after_avg_duration_ms,
    a.avg_cpu_ms           AS after_avg_cpu_ms,
    a.avg_logical_reads    AS after_avg_lreads,
    a.avg_logical_writes   AS after_avg_lwrites,

    (a.avg_duration_ms - b.avg_duration_ms)           AS delta_avg_duration_ms,
    (a.avg_cpu_ms      - b.avg_cpu_ms)                AS delta_avg_cpu_ms,
    (a.avg_logical_reads - b.avg_logical_reads)       AS delta_avg_lreads,
    (a.avg_logical_writes - b.avg_logical_writes)     AS delta_avg_lwrites,

    CASE WHEN b.avg_duration_ms > 0
         THEN (a.avg_duration_ms - b.avg_duration_ms) / NULLIF(b.avg_duration_ms,0.0) * 100
         ELSE NULL END                                AS pct_change_duration,
    CASE WHEN b.avg_cpu_ms > 0
         THEN (a.avg_cpu_ms - b.avg_cpu_ms) / NULLIF(b.avg_cpu_ms,0.0) * 100
         ELSE NULL END                                AS pct_change_cpu,
    CASE WHEN b.avg_logical_reads > 0
         THEN (a.avg_logical_reads - b.avg_logical_reads) / NULLIF(b.avg_logical_reads,0.0) * 100
         ELSE NULL END                                AS pct_change_lreads
FROM (SELECT * FROM dbo.QS_Snapshot WHERE label = 'AFTER') a
FULL OUTER JOIN (SELECT * FROM dbo.QS_Snapshot WHERE label = 'BEFORE') b
  ON a.query_hash = b.query_hash;
GO


-- ===== 2) SNAPSHOTY ==========================================================
-- Uruchom tuż PRZED zmianą compat level:
-- EXEC dbo.QS_TakeSnapshot @Label = 'BEFORE', @StartTime = @BeforeStart, @EndTime = @BeforeEnd;
-- Uruchom PO zmianie compat level:
-- EXEC dbo.QS_TakeSnapshot @Label = 'AFTER',  @StartTime = @AfterStart,  @EndTime  = @AfterEnd;


-- ===== 3) RAPORTY REGRESJI ===================================================

-- 3.1) Największy % wzrost średniego czasu wykonania
SELECT TOP (50)
    query_hash,
    LEFT(REPLACE(REPLACE(query_text, CHAR(13), ' '), CHAR(10), ' '), 4000) AS sample_text,
    before_execs, before_avg_duration_ms, after_execs, after_avg_duration_ms,
    delta_avg_duration_ms,
    pct_change_duration
FROM dbo.v_QS_Compare
WHERE before_execs IS NOT NULL AND after_execs IS NOT NULL
  AND pct_change_duration IS NOT NULL
ORDER BY pct_change_duration DESC;

-- 3.2) Największy absolutny wzrost CPU
SELECT TOP (50)
    query_hash,
    LEFT(REPLACE(REPLACE(query_text, CHAR(13), ' '), CHAR(10), ' '), 4000) AS sample_text,
    before_avg_cpu_ms, after_avg_cpu_ms, delta_avg_cpu_ms, pct_change_cpu
FROM dbo.v_QS_Compare
WHERE before_execs IS NOT NULL AND after_execs IS NOT NULL
  AND pct_change_cpu IS NOT NULL
ORDER BY delta_avg_cpu_ms DESC;

-- 3.3) Największy wzrost odczytów logicznych
SELECT TOP (50)
    query_hash,
    LEFT(REPLACE(REPLACE(query_text, CHAR(13), ' '), CHAR(10), ' '), 4000) AS sample_text,
    before_avg_lreads, after_avg_lreads, delta_avg_lreads, pct_change_lreads
FROM dbo.v_QS_Compare
WHERE before_execs IS NOT NULL AND after_execs IS NOT NULL
  AND pct_change_lreads IS NOT NULL
ORDER BY delta_avg_lreads DESC;


-- ===== 4) DIAGNOZA PLANÓW I FORCING =========================================

-- 4.1) Plany dla konkretnego query_hash
DECLARE @QueryHash bigint = 0x0000000000000000; -- TODO: podaj własny hash
SELECT TOP (50)
      q.query_id, p.plan_id, p.last_execution_time, p.is_forced_plan,
      TRY_CONVERT(xml, p.query_plan) AS query_plan_xml
FROM sys.query_store_query q
JOIN sys.query_store_plan  p ON p.query_id = q.query_id
WHERE q.query_hash = @QueryHash
ORDER BY p.last_execution_time DESC;

-- 4.2) Najlepszy plan z okna BEFORE (po avg duration)
DECLARE @BestBeforePlanId int;

WITH rs AS
(
    SELECT
        p.plan_id,
        SUM(r.execution_count)                                  AS execs,
        SUM(r.total_duration)/1000.0 / NULLIF(SUM(r.execution_count),0) AS avg_ms
    FROM sys.query_store_plan p
    JOIN sys.query_store_query q  ON q.query_id = p.query_id
    JOIN sys.query_store_runtime_stats r ON r.plan_id = p.plan_id
    JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id = r.runtime_stats_interval_id
    WHERE q.query_hash = @QueryHash
      AND i.start_time >= @BeforeStart AND i.end_time <= @BeforeEnd
    GROUP BY p.plan_id
)
SELECT TOP (1) @BestBeforePlanId = plan_id
FROM rs
WHERE execs > 0
ORDER BY avg_ms ASC;

SELECT BestBeforePlanId = @BestBeforePlanId;

-- 4.3) (Opcjonalnie) Wymuszenie najlepszego „starego” planu
-- EXEC sys.sp_query_store_force_plan @query_id = <id>, @plan_id = @BestBeforePlanId;
-- Cofnięcie forcingu:
-- EXEC sys.sp_query_store_unforce_plan @query_id = <id>, @plan_id = <id>;


-- ===== 5) DODATKOWE ZESTAWIENIA =============================================

-- 5.1) Zapytania obecne PRZED, brak PO
SELECT b.query_hash, LEFT(REPLACE(REPLACE(b.query_text, CHAR(13), ' '), CHAR(10), ' '), 4000) AS text_before
FROM dbo.QS_Snapshot b
LEFT JOIN dbo.QS_Snapshot a ON a.label='AFTER' AND a.query_hash=b.query_hash
WHERE b.label='BEFORE' AND a.query_hash IS NULL;

-- 5.2) Zapytania nowe PO, nieobecne PRZED
SELECT a.query_hash, LEFT(REPLACE(REPLACE(a.query_text, CHAR(13), ' '), CHAR(10), ' '), 4000) AS text_after
FROM dbo.QS_Snapshot a
LEFT JOIN dbo.QS_Snapshot b ON b.label='BEFORE' AND b.query_hash=a.query_hash
WHERE a.label='AFTER' AND b.query_hash IS NULL;

-- 5.3) Sprzątanie (opcjonalnie)
-- TRUNCATE TABLE dbo.QS_Snapshot;
