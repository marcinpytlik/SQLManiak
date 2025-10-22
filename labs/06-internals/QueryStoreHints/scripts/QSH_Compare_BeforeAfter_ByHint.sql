/* QSH_Compare_BeforeAfter_ByHint.sql
   Porównanie metryk Query Store *przed* i *po* nałożeniu ostatniego hinta dla danego query_id.
   - automatycznie pobiera @change_time z sys.query_store_query_hints.last_modified (ostatni wpis, is_enabled = 1)
   - liczy SUM/AVG z sys.query_store_runtime_stats po bucketach, z joinem do intervals
*/
SET NOCOUNT ON;

DECLARE @query_id bigint = 0;               -- TODO: wstaw query_id
DECLARE @from datetime2(0) = NULL;          -- opcjonalnie
DECLARE @to   datetime2(0) = NULL;          -- opcjonalnie

IF @query_id = 0
BEGIN
    RAISERROR('Ustaw @query_id', 16, 1);
    RETURN;
END

DECLARE @change_time datetime2(7) =
(
    SELECT TOP (1) qsqh.last_modified
    FROM sys.query_store_query_hints AS qsqh
    WHERE qsqh.query_id = @query_id
      AND qsqh.is_enabled = 1
    ORDER BY qsqh.last_modified DESC
);

IF @change_time IS NULL
BEGIN
    PRINT 'Brak aktywnego hinta – używam całego zakresu jako "Before".';
    SET @change_time = '9999-12-31T23:59:59.9'; -- wszystko traktuj jako Before
END
ELSE
BEGIN
    PRINT 'Wykryto czas zmiany (last_modified): ' + CONVERT(varchar(33), @change_time, 126);
END

;WITH RS AS
(
    SELECT
        i.start_time, i.end_time,
        rs.count_executions,
        rs.avg_duration/1000.0     AS avg_duration_ms,
        rs.total_duration/1000.0   AS total_duration_ms,
        rs.avg_cpu_time/1000.0     AS avg_cpu_ms,
        rs.total_cpu_time/1000.0   AS total_cpu_ms,
        rs.avg_logical_io_reads    AS avg_lreads,
        rs.total_logical_io_reads  AS total_lreads
    FROM sys.query_store_runtime_stats AS rs
    JOIN sys.query_store_plan AS p ON p.plan_id = rs.plan_id
    JOIN sys.query_store_runtime_stats_interval AS i ON i.runtime_stats_interval_id = rs.runtime_stats_interval_id
    WHERE p.query_id = @query_id
      AND (@from IS NULL OR i.start_time >= @from)
      AND (@to   IS NULL OR i.end_time   <= @to)
)
SELECT TOP (1)
    SUM(CASE WHEN end_time <  @change_time THEN count_executions ELSE 0 END) AS execs_before,
    SUM(CASE WHEN end_time >= @change_time THEN count_executions ELSE 0 END) AS execs_after,
    SUM(CASE WHEN end_time <  @change_time THEN total_duration_ms ELSE 0 END) AS total_duration_ms_before,
    SUM(CASE WHEN end_time >= @change_time THEN total_duration_ms ELSE 0 END) AS total_duration_ms_after,
    SUM(CASE WHEN end_time <  @change_time THEN total_cpu_ms ELSE 0 END) AS total_cpu_ms_before,
    SUM(CASE WHEN end_time >= @change_time THEN total_cpu_ms ELSE 0 END) AS total_cpu_ms_after,
    SUM(CASE WHEN end_time <  @change_time THEN total_lreads ELSE 0 END) AS total_lreads_before,
    SUM(CASE WHEN end_time >= @change_time THEN total_lreads ELSE 0 END) AS total_lreads_after,
    CASE WHEN SUM(CASE WHEN end_time <  @change_time THEN count_executions ELSE 0 END) > 0
         THEN 1.0 * SUM(CASE WHEN end_time <  @change_time THEN total_duration_ms ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN end_time <  @change_time THEN count_executions ELSE 0 END),0)
    END AS avg_duration_ms_before,
    CASE WHEN SUM(CASE WHEN end_time >= @change_time THEN count_executions ELSE 0 END) > 0
         THEN 1.0 * SUM(CASE WHEN end_time >= @change_time THEN total_duration_ms ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN end_time >= @change_time THEN count_executions ELSE 0 END),0)
    END AS avg_duration_ms_after
FROM RS;
