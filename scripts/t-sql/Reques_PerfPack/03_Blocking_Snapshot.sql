/* 03_Blocking_Snapshot.sql
   Uruchom W TRAKCIE problemu (np. gdy API „wisi” i oddaje 202 a praca dzieje się później).
   Skrypt robi serię snapshotów co 5 sekund przez 15 minut i zapisuje je do #temp tabel.

   Wskazówka: podmień @Minutes jeśli chcesz.
*/
DECLARE @SecondsBetweenSamples int = 5;
DECLARE @Minutes int = 15;

IF OBJECT_ID('tempdb..#blocking_snap') IS NOT NULL DROP TABLE #blocking_snap;
CREATE TABLE #blocking_snap
(
    sample_time          datetime2(0) NOT NULL,
    session_id           int          NOT NULL,
    blocking_session_id  int          NULL,
    status               nvarchar(30) NULL,
    wait_type            nvarchar(60) NULL,
    wait_time_ms         int          NULL,
    wait_resource        nvarchar(256) NULL,
    cpu_time_ms          int          NULL,
    total_elapsed_ms     int          NULL,
    reads                bigint       NULL,
    writes               bigint       NULL,
    logical_reads        bigint       NULL,
    open_tran_count      int          NULL,
    tran_isolation_level tinyint      NULL,
    host_name            nvarchar(128) NULL,
    program_name         nvarchar(128) NULL,
    login_name           nvarchar(128) NULL,
    database_name        sysname       NULL,
    statement_text       nvarchar(max) NULL
);

DECLARE @i int = 0, @loops int = (@Minutes*60)/@SecondsBetweenSamples;

WHILE @i < @loops
BEGIN
    INSERT #blocking_snap
    SELECT
        SYSDATETIME(),
        r.session_id,
        r.blocking_session_id,
        r.status,
        r.wait_type,
        r.wait_time,
        r.wait_resource,
        r.cpu_time,
        r.total_elapsed_time,
        r.reads,
        r.writes,
        r.logical_reads,
        r.open_transaction_count,
        s.transaction_isolation_level,
        s.host_name,
        s.program_name,
        s.login_name,
        DB_NAME(r.database_id) AS database_name,
        SUBSTRING(st.text,
                  (r.statement_start_offset/2)+1,
                  CASE r.statement_end_offset
                       WHEN -1 THEN (DATALENGTH(st.text) - r.statement_start_offset)/2 + 1
                       ELSE (r.statement_end_offset - r.statement_start_offset)/2 + 1
                  END) AS statement_text
    FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
    WHERE r.session_id <> @@SPID;

    WAITFOR DELAY TIMEFROMPARTS(0,0,@SecondsBetweenSamples,0,0);
    SET @i += 1;
END;

-- Wyniki: kto blokuje kogo i na czym
SELECT TOP (500)
    sample_time,
    session_id,
    blocking_session_id,
    status,
    wait_type,
    wait_time_ms,
    wait_resource,
    total_elapsed_ms,
    cpu_time_ms,
    database_name,
    host_name,
    program_name,
    login_name,
    LEFT(statement_text, 4000) AS statement_text_4k
FROM #blocking_snap
WHERE blocking_session_id IS NOT NULL
   OR wait_type IS NOT NULL
ORDER BY sample_time DESC, wait_time_ms DESC;

-- „Top wait_type” w oknie próbki
SELECT TOP (50)
    wait_type,
    COUNT(*) AS samples,
    MAX(wait_time_ms) AS max_wait_ms
FROM #blocking_snap
WHERE wait_type IS NOT NULL
GROUP BY wait_type
ORDER BY max_wait_ms DESC, samples DESC;
