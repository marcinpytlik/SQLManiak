/* QSH_Timeline_PerInterval.sql
   Seria czasowa metryk dla @query_id po bucketach Query Store.
   Użyteczne do wykresów (Excel/Grafana): jedna linia = ms / io per interval.
*/
SET NOCOUNT ON;

DECLARE @query_id bigint = 0;      -- TODO: wstaw
DECLARE @from datetime2(0) = NULL; -- opcjonalnie
DECLARE @to   datetime2(0) = NULL; -- opcjonalnie

IF @query_id = 0
BEGIN
    RAISERROR('Ustaw @query_id', 16, 1);
    RETURN;
END

SELECT
    i.start_time,
    i.end_time,
    SUM(rs.count_executions)                         AS execs,
    SUM(rs.total_duration)/1000.0                    AS total_duration_ms,
    SUM(rs.total_cpu_time)/1000.0                    AS total_cpu_ms,
    SUM(rs.total_logical_io_reads)                   AS total_lreads,
    CASE WHEN SUM(rs.count_executions) > 0
         THEN (1.0*SUM(rs.total_duration)/1000.0) / NULLIF(SUM(rs.count_executions),0)
    END                                              AS avg_duration_ms,
    CASE WHEN SUM(rs.count_executions) > 0
         THEN (1.0*SUM(rs.total_cpu_time)/1000.0) / NULLIF(SUM(rs.count_executions),0)
    END                                              AS avg_cpu_ms,
    CASE WHEN SUM(rs.count_executions) > 0
         THEN 1.0*SUM(rs.total_logical_io_reads) / NULLIF(SUM(rs.count_executions),0)
    END                                              AS avg_lreads
FROM sys.query_store_runtime_stats AS rs
JOIN sys.query_store_plan AS p ON p.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval AS i ON i.runtime_stats_interval_id = rs.runtime_stats_interval_id
WHERE p.query_id = @query_id
  AND (@from IS NULL OR i.start_time >= @from)
  AND (@to   IS NULL OR i.end_time   <= @to)
GROUP BY i.start_time, i.end_time
ORDER BY i.start_time;
