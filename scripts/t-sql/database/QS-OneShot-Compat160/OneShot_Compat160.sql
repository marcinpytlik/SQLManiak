
/*
    OneShot_Compat160.sql
    Cel: Jednym skryptem
      1) włączyć/ustawić Query Store (READ_WRITE),
      2) (opcjonalnie) zaktualizować statystyki i zrobić prostą konserwację indeksów,
      3) wykonać snapshot "PRZED",
      4) podnieść COMPATIBILITY_LEVEL do 160 (SQL 2022),
      5) wykonać snapshot "PO",
      6) pokazać TOP regresje.
    Uruchamiaj świadomie na PROD (najpierw DEV/QA!).

    WYMAGANIA: SQL Server 2022
*/

/************ 0) PARAMETRY ************/
USE [TwojaBaza]; -- TODO: ZMIEŃ
GO

DECLARE @DoUpdateStats bit = 1;         -- 1 = uruchom sp_updatestats
DECLARE @DoIndexMaint  bit = 0;         -- 1 = lekka konserwacja indeksów (reorganize/rebuild)
DECLARE @CompatTarget  int = 160;       -- docelowy compatibility level
DECLARE @QS_MaxSizeMB  int = 20480;     -- opcjonalny limit Query Store (20 GB)

-- Okna czasowe do snapshotów (dopasuj do ruchu)
DECLARE @BeforeStart datetime2 = DATEADD(minute, -90, SYSUTCDATETIME());
DECLARE @BeforeEnd   datetime2 = DATEADD(minute, -60, SYSUTCDATETIME());
DECLARE @AfterStart  datetime2 = DATEADD(minute, +5, SYSUTCDATETIME());
DECLARE @AfterEnd    datetime2 = DATEADD(minute, +65, SYSUTCDATETIME());

PRINT '== PARAMETRY ==';
PRINT CONCAT('DB: ', DB_NAME(), '  TargetCompat: ', @CompatTarget);
PRINT CONCAT('Before: ', @BeforeStart, ' - ', @BeforeEnd, ' | After: ', @AfterStart, ' - ', @AfterEnd);
PRINT CONCAT('DoUpdateStats=', @DoUpdateStats, ' DoIndexMaint=', @DoIndexMaint);
PRINT '=====================================';

-- Bezpieczeństwo: sprawdź Query Store i compat
DECLARE @CurrentCompat int = (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME());

/************ 1) QUERY STORE: włącz i ustaw ************/
IF (SELECT desired_state_desc FROM sys.database_query_store_options) = 'OFF'
BEGIN
    PRINT 'Włączam Query Store...';
    ALTER DATABASE CURRENT SET QUERY_STORE = ON;
END

-- Wymuś tryb zapisu i podstawowe limity (bez resetu zawartości!)
ALTER DATABASE CURRENT SET QUERY_STORE (OPERATION_MODE = READ_WRITE, MAX_STORAGE_SIZE_MB = @QS_MaxSizeMB);
-- (Opcjonalnie) Agresywniejsze zbieranie:
-- ALTER DATABASE CURRENT SET QUERY_STORE (INTERVAL_LENGTH_MINUTES = 5);

-- Prosty sanity check
PRINT CONCAT('QS state: ', (SELECT actual_state_desc FROM sys.database_query_store_options));

/************ 2) HIGIENA: statystyki i indeksy ************/
IF @DoUpdateStats = 1
BEGIN
    PRINT 'Aktualizuję statystyki (sp_updatestats)...';
    EXEC sp_updatestats;  -- szybkie, niskie ryzyko
END

IF @DoIndexMaint = 1
BEGIN
    PRINT 'Konserwacja indeksów (lekka) — reorganize/rebuild wg fragmentacji...';
    ;WITH fr AS (
        SELECT
            s.[object_id], s.index_id,
            avg_fragmentation_in_percent = CONVERT(decimal(5,2), s.avg_fragmentation_in_percent)
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') s
        WHERE s.index_id > 0
    )
    SELECT * INTO #frag FROM fr;

    DECLARE @obj int, @ix int, @frag decimal(5,2);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT [object_id], index_id, avg_fragmentation_in_percent FROM #frag;
    OPEN c;
    FETCH NEXT FROM c INTO @obj, @ix, @frag;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @sql nvarchar(4000) =
            CASE WHEN @frag BETWEEN 10 AND 30 THEN
                N'ALTER INDEX [' + QUOTENAME(i.name) + N'] ON ' + QUOTENAME(OBJECT_SCHEMA_NAME(@obj)) + N'.' + QUOTENAME(OBJECT_NAME(@obj)) + N' REORGANIZE;'
            WHEN @frag > 30 THEN
                N'ALTER INDEX [' + QUOTENAME(i.name) + N'] ON ' + QUOTENAME(OBJECT_SCHEMA_NAME(@obj)) + N'.' + QUOTENAME(OBJECT_NAME(@obj)) + N' REBUILD WITH (ONLINE = ON);'
            ELSE NULL END
        FROM sys.indexes i WHERE i.[object_id] = @obj AND i.index_id = @ix;

        IF @sql IS NOT NULL
        BEGIN
            PRINT CONCAT('Maint: ', @sql);
            BEGIN TRY
                EXEC sp_executesql @sql;
            END TRY
            BEGIN CATCH
                PRINT CONCAT('WARN: Index maint failed on ', OBJECT_SCHEMA_NAME(@obj), '.', OBJECT_NAME(@obj), ' index_id=', @ix, ' frag=', @frag, ' msg=', ERROR_MESSAGE());
            END CATCH
        END

        FETCH NEXT FROM c INTO @obj, @ix, @frag;
    END
    CLOSE c; DEALLOCATE c;
    DROP TABLE #frag;
END

/************ 3) OBIEKTY: tabela snapshotów + proc ************/
IF OBJECT_ID('dbo.QS_Snapshot','U') IS NULL
BEGIN
    CREATE TABLE dbo.QS_Snapshot
    (
        snapshot_id     int IDENTITY(1,1) PRIMARY KEY,
        label           sysname        NOT NULL,  -- 'BEFORE' / 'AFTER'
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

IF OBJECT_ID('dbo.QS_TakeSnapshot','P') IS NOT NULL
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
            SUM(r.total_duration) / 1000                                    AS total_duration_ms,
            SUM(r.total_cpu_time) / 1000                                    AS total_cpu_ms,
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

IF OBJECT_ID('dbo.v_QS_Compare','V') IS NOT NULL
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

/************ 4) SNAPSHOT BEFORE ************/
PRINT 'Robię snapshot BEFORE...';
EXEC dbo.QS_TakeSnapshot @Label='BEFORE', @StartTime=@BeforeStart, @EndTime=@BeforeEnd;

/************ 5) ZMIANA COMPATIBILITY_LEVEL ************/
IF @CurrentCompat = @CompatTarget
BEGIN
    PRINT CONCAT('Compat już ustawiony na ', @CompatTarget, ' — pomijam ALTER DATABASE.');
END
ELSE
BEGIN
    PRINT CONCAT('ALTER DATABASE SET COMPATIBILITY_LEVEL = ', @CompatTarget, ' ...');
    DECLARE @sql nvarchar(200) = N'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + N' SET COMPATIBILITY_LEVEL = ' + CAST(@CompatTarget as nvarchar(10)) + N';';
    EXEC (@sql);
END

/************ 6) SNAPSHOT AFTER ************/
PRINT 'Robię snapshot AFTER...';
EXEC dbo.QS_TakeSnapshot @Label='AFTER', @StartTime=@AfterStart, @EndTime=@AfterEnd;

/************ 7) RAPORTY ************/
PRINT '== TOP regresje (czas wykonania, % wzrost) ==';
SELECT TOP (50)
    query_hash,
    LEFT(REPLACE(REPLACE(query_text, CHAR(13), ' '), CHAR(10), ' '), 3000) AS sample_text,
    before_execs, before_avg_duration_ms, after_execs, after_avg_duration_ms,
    delta_avg_duration_ms, pct_change_duration
FROM dbo.v_QS_Compare
WHERE before_execs IS NOT NULL AND after_execs IS NOT NULL AND pct_change_duration IS NOT NULL
ORDER BY pct_change_duration DESC;

PRINT '== TOP wzrost CPU (ms) ==';
SELECT TOP (50)
    query_hash,
    LEFT(REPLACE(REPLACE(query_text, CHAR(13), ' '), CHAR(10), ' '), 3000) AS sample_text,
    before_avg_cpu_ms, after_avg_cpu_ms, delta_avg_cpu_ms, pct_change_cpu
FROM dbo.v_QS_Compare
WHERE before_execs IS NOT NULL AND after_execs IS NOT NULL AND pct_change_cpu IS NOT NULL
ORDER BY delta_avg_cpu_ms DESC;

PRINT '== TOP wzrost odczytów logicznych ==';
SELECT TOP (50)
    query_hash,
    LEFT(REPLACE(REPLACE(query_text, CHAR(13), ' '), CHAR(10), ' '), 3000) AS sample_text,
    before_avg_lreads, after_avg_lreads, delta_avg_lreads, pct_change_lreads
FROM dbo.v_QS_Compare
WHERE before_execs IS NOT NULL AND after_execs IS NOT NULL AND pct_change_lreads IS NOT NULL
ORDER BY delta_avg_lreads DESC;

PRINT 'Koniec. Pamiętaj o obserwacji i ewentualnym plan forcing w razie regresji.';
