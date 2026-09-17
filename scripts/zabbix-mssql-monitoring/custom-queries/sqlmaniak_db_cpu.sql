SET NOCOUNT ON;

/* Based directly on SQL-CPU-07 from the monitoring workbook.
   total_worker_time is microseconds; output is milliseconds. */
;WITH Q AS
(
    SELECT
        CONVERT(int, pa.value) AS database_id,
        qs.total_worker_time
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) AS pa
    WHERE pa.attribute = N'dbid'
),
DBCPU AS
(
    SELECT
        database_id,
        SUM(total_worker_time) / 1000.0 AS cpu_time_ms_total
    FROM Q
    WHERE database_id > 4
    GROUP BY database_id
)
SELECT
    DB_NAME(database_id) AS db,
    CAST(cpu_time_ms_total AS bigint) AS cpu_time_ms_total
FROM DBCPU
WHERE DB_NAME(database_id) IS NOT NULL
ORDER BY cpu_time_ms_total DESC;
