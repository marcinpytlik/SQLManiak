-- scripts/03_snapshot_end_and_delta.sql
USE tempdb;
GO
IF OBJECT_ID('tempdb..#waits_end') IS NOT NULL DROP TABLE #waits_end;
SELECT * INTO #waits_end FROM sys.dm_os_wait_stats;

-- Filtruj „benign” waity
WITH benign AS (
    SELECT wait_type FROM (VALUES
        ('SLEEP_TASK'),('LAZYWRITER_SLEEP'),('BROKER_TO_FLUSH'),
        ('BROKER_TASK_STOP'),('SQLTRACE_BUFFER_FLUSH'),('XE_TIMER_EVENT'),
        ('XE_DISPATCHER_WAIT'),('CLR_AUTO_EVENT'),('CLR_MANUAL_EVENT'),
        ('REQUEST_FOR_DEADLOCK_SEARCH'),('LOGMGR_QUEUE'),('FT_IFTS_SCHEDULER_IDLE_WAIT'),
        ('BROKER_EVENTHANDLER'),('BAD_PAGE_PROCESS'),('DBMIRROR_EVENTS_QUEUE'),
        ('DISPATCHER_QUEUE_SEMAPHORE'),('DBMIRROR_DBM_MUTEX'),
        ('RESOURCE_QUEUE'),('HADR_FILESTREAM_IOMGR_IOCOMPLETION'),
        ('CHECKPOINT_QUEUE'),('FT_IFTSHC_MUTEX'),('XE_DISPATCHER_JOIN'),
        ('SLEEP_SYSTEMTASK'),('HADR_TIMER_TASK'),('HADR_WORK_QUEUE'),
        ('WAITFOR'),('WAIT_XTP_HOST_WAIT'),('HADR_CLUSAPI_CALL'),
        ('DIRTY_PAGE_POLL'),('HADR_LOGCAPTURE_WAIT'),('HADR_LOGCOMPRESSION_WORKER'),
        ('HADR_SYNCHRONIZING_THROTTLE'),('HADR_WORKPOOL_QUEUE'),
        ('QDS_SHUTDOWN_QUEUE'),('QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP'),
        ('QDS_CLEANUP_STALE_QUERIES_TASK_WORKER_SLEEP'),('BROKER_RECEIVE_WAITFOR')
    ) AS b(wait_type)
),
d AS (
    SELECT e.wait_type,
           e.wait_time_ms - s.wait_time_ms AS wait_time_ms,
           e.waiting_tasks_count - s.waiting_tasks_count AS waiting_tasks_count,
           e.signal_wait_time_ms - s.signal_wait_time_ms AS signal_wait_time_ms
    FROM #waits_end e
    JOIN #waits_start s ON s.wait_type = e.wait_type
    WHERE (e.wait_time_ms - s.wait_time_ms) > 0
      AND e.wait_type NOT IN (SELECT wait_type FROM benign)
)
SELECT TOP (50)
    d.wait_type, d.wait_time_ms, d.signal_wait_time_ms, d.waiting_tasks_count,
    CASE 
        WHEN d.wait_type LIKE 'PAGEIOLATCH%' OR d.wait_type IN ('IO_COMPLETION','WRITELOG') THEN 'IO'
        WHEN d.wait_type LIKE 'LCK_%' THEN 'Locks'
        WHEN d.wait_type IN ('CXPACKET','CXCONSUMER','EXCHANGE') THEN 'Parallelism'
        WHEN d.wait_type IN ('SOS_SCHEDULER_YIELD') THEN 'CPU'
        WHEN d.wait_type LIKE 'PAGELATCH%' THEN 'Memory/Latches'
        WHEN d.wait_type LIKE 'ASYNC_NETWORK_IO' THEN 'Network'
        ELSE 'Other'
    END AS category
FROM d
ORDER BY d.wait_time_ms DESC;
