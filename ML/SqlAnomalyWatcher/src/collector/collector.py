from __future__ import annotations

from sqlalchemy import text
from src.ml.db import get_engine


COLLECT_QUERY = """
WITH perf AS
(
    SELECT
        MAX(CASE WHEN counter_name = 'Batch Requests/sec' THEN cntr_value END) AS BatchRequestsPerSec,
        MAX(CASE WHEN counter_name = 'User Connections' THEN cntr_value END) AS UserConnections,
        MAX(CASE WHEN counter_name = 'Page life expectancy' THEN cntr_value END) AS PageLifeExpectancy
    FROM sys.dm_os_performance_counters
    WHERE counter_name IN
    (
        'Batch Requests/sec',
        'User Connections',
        'Page life expectancy'
    )
),
blocking AS
(
    SELECT COUNT(*) AS BlockedSessions
    FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
),
tempdb_usage AS
(
    SELECT
        SUM(user_object_reserved_page_count +
            internal_object_reserved_page_count +
            version_store_reserved_page_count +
            mixed_extent_page_count +
            unallocated_extent_page_count) * 8.0 / 1024.0 AS TempdbUsedMb
    FROM tempdb.sys.dm_db_file_space_usage
),
query_stats AS
(
    SELECT
        AVG(CAST(total_elapsed_time / NULLIF(execution_count, 0) AS decimal(18,2)) / 1000.0) AS AvgQueryDurationMs,
        AVG(CAST(total_logical_reads / NULLIF(execution_count, 0) AS decimal(18,2))) AS AvgLogicalReads
    FROM sys.dm_exec_query_stats
),
waits AS
(
    SELECT
        SUM(signal_wait_time_ms) AS SignalWaitTimeMs
    FROM sys.dm_os_wait_stats
),
cpu_estimate AS
(
    SELECT
        CAST(
            (
                SELECT AVG(CAST(runnable_tasks_count AS decimal(10,2)))
                FROM sys.dm_os_schedulers
                WHERE status = 'VISIBLE ONLINE'
            ) * 10.0
            AS decimal(5,2)
        ) AS CpuPercent
)
SELECT
    SYSDATETIME() AS CaptureTime,
    @@SERVERNAME AS ServerName,
    @@SERVICENAME AS InstanceName,
    c.CpuPercent,
    p.BatchRequestsPerSec,
    p.UserConnections,
    b.BlockedSessions,
    0 AS DeadlocksPerMin,
    q.AvgQueryDurationMs,
    q.AvgLogicalReads,
    t.TempdbUsedMb,
    w.SignalWaitTimeMs,
    p.PageLifeExpectancy
FROM perf p
CROSS JOIN blocking b
CROSS JOIN tempdb_usage t
CROSS JOIN query_stats q
CROSS JOIN waits w
CROSS JOIN cpu_estimate c;
"""

INSERT_QUERY = """
INSERT INTO dbo.TelemetrySnapshot
(
    CaptureTime,
    ServerName,
    InstanceName,
    CpuPercent,
    BatchRequestsPerSec,
    UserConnections,
    BlockedSessions,
    DeadlocksPerMin,
    AvgQueryDurationMs,
    AvgLogicalReads,
    TempdbUsedMb,
    SignalWaitTimeMs,
    PageLifeExpectancy
)
VALUES
(
    :CaptureTime,
    :ServerName,
    :InstanceName,
    :CpuPercent,
    :BatchRequestsPerSec,
    :UserConnections,
    :BlockedSessions,
    :DeadlocksPerMin,
    :AvgQueryDurationMs,
    :AvgLogicalReads,
    :TempdbUsedMb,
    :SignalWaitTimeMs,
    :PageLifeExpectancy
)
"""


def main() -> None:
    engine = get_engine()

    with engine.begin() as conn:
        row = conn.execute(text(COLLECT_QUERY)).mappings().first()

        if row is None:
            raise RuntimeError("Collector query nie zwrócił żadnych danych.")

        conn.execute(text(INSERT_QUERY), dict(row))

        print("Zapisano snapshot:")
        for key, value in row.items():
            print(f"{key}: {value}")


if __name__ == "__main__":
    main()