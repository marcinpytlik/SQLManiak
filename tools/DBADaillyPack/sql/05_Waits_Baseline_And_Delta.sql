/* Waits: capture baseline + show delta vs previous baseline
   First run: execute sql/00_Setup_Waits_Baseline_Table.sql once.
*/
SET NOCOUNT ON;

DECLARE @now datetime2(0) = SYSUTCDATETIME();

-- Capture baseline
INSERT INTO master.dbo.WaitStatsBaseline (CapturedAtUtc, CapturedBy, WaitType, WaitingTasksCount, WaitTimeMs, SignalWaitTimeMs)
SELECT
    @now,
    ORIGINAL_LOGIN(),
    ws.wait_type,
    ws.waiting_tasks_count,
    ws.wait_time_ms,
    ws.signal_wait_time_ms
FROM sys.dm_os_wait_stats ws
WHERE ws.wait_type NOT LIKE 'SLEEP%'
  AND ws.wait_type NOT IN ('CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','XE_TIMER_EVENT','XE_DISPATCHER_WAIT','FT_IFTS_SCHEDULER_IDLE_WAIT','BROKER_TO_FLUSH','BROKER_TASK_STOP','BROKER_EVENTHANDLER','SQLTRACE_BUFFER_FLUSH','CHECKPOINT_QUEUE','REQUEST_FOR_DEADLOCK_SEARCH','LOGMGR_QUEUE','ONDEMAND_TASK_QUEUE','DIRTY_PAGE_POLL','SP_SERVER_DIAGNOSTICS_SLEEP');

DECLARE @newId bigint = SCOPE_IDENTITY();

-- Find previous capture time
DECLARE @prevTime datetime2(0) =
(
    SELECT MAX(CapturedAtUtc)
    FROM master.dbo.WaitStatsBaseline
    WHERE CapturedAtUtc < @now
);

IF @prevTime IS NULL
BEGIN
    PRINT 'No previous baseline found. Captured first baseline only.';
    RETURN;
END

;WITH prev AS
(
    SELECT WaitType, WaitingTasksCount, WaitTimeMs, SignalWaitTimeMs
    FROM master.dbo.WaitStatsBaseline
    WHERE CapturedAtUtc = @prevTime
),
curr AS
(
    SELECT WaitType, WaitingTasksCount, WaitTimeMs, SignalWaitTimeMs
    FROM master.dbo.WaitStatsBaseline
    WHERE CapturedAtUtc = @now
),
d AS
(
    SELECT
        c.WaitType,
        (c.WaitingTasksCount - p.WaitingTasksCount) AS DeltaWaitingTasks,
        (c.WaitTimeMs - p.WaitTimeMs) AS DeltaWaitMs,
        (c.SignalWaitTimeMs - p.SignalWaitTimeMs) AS DeltaSignalWaitMs
    FROM curr c
    JOIN prev p ON p.WaitType = c.WaitType
)
SELECT TOP (30)
    WaitType,
    DeltaWaitingTasks,
    DeltaWaitMs,
    DeltaSignalWaitMs,
    CASE WHEN DeltaWaitingTasks = 0 THEN NULL ELSE 1.0 * DeltaWaitMs / NULLIF(DeltaWaitingTasks,0) END AS AvgWaitMsPerTask
FROM d
WHERE DeltaWaitMs > 0
ORDER BY DeltaWaitMs DESC;
