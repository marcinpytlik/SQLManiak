USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_top_waits_categories
    @top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    WITH w AS (
        SELECT
            wait_type,
            waiting_tasks_count,
            wait_time_ms,
            signal_wait_time_ms,
            wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms
        FROM sys.dm_os_wait_stats
        WHERE waiting_tasks_count > 0
          AND wait_type NOT IN (
            'SLEEP_TASK','SLEEP_SYSTEMTASK','BROKER_TASK_STOP','BROKER_TO_FLUSH',
            'BROKER_EVENTHANDLER','XE_TIMER_EVENT','XE_DISPATCHER_WAIT',
            'FT_IFTS_SCHEDULER_IDLE_WAIT','BROKER_RECEIVE_WAITFOR','SQLTRACE_BUFFER_FLUSH'
          )
    ),
    c AS (
        SELECT *,
        CASE
          WHEN wait_type LIKE 'LCK_%'                         THEN 'LOCKS'
          WHEN wait_type LIKE 'LATCH_%'                       THEN 'LATCH'
          WHEN wait_type LIKE 'PAGELATCH_%'                   THEN 'LATCH_PAGE'
          WHEN wait_type LIKE 'PAGEIOLATCH_%'                 THEN 'IO_PAGEIOLATCH'
          WHEN wait_type IN ('WRITELOG','LOGMGR_RESERVE_APPEND','LOG_RATE_GOVERNOR') THEN 'LOG'
          WHEN wait_type IN ('IO_COMPLETION','ASYNC_IO_COMPLETION') THEN 'IO_OTHER'
          WHEN wait_type IN ('ASYNC_NETWORK_IO','NET_WAITFOR_PACKET') THEN 'NETWORK'
          WHEN wait_type = 'RESOURCE_SEMAPHORE'               THEN 'MEMORY'
          WHEN wait_type IN ('SOS_SCHEDULER_YIELD','THREADPOOL') THEN 'CPU/SCHEDULER'
          WHEN wait_type LIKE 'HADR_%'                        THEN 'HADR/ALWAYS ON'
          WHEN wait_type LIKE 'CXCONSUMER' OR wait_type LIKE 'CXPACKET' THEN 'PARALLELISM'
          ELSE 'OTHER'
        END AS wait_category
        FROM w
    )
    SELECT TOP (@top)
        wait_category,
        SUM(waiting_tasks_count)       AS tasks,
        SUM(wait_time_ms)              AS wait_ms,
        SUM(signal_wait_time_ms)       AS signal_ms,
        SUM(resource_wait_time_ms)     AS resource_ms,
        CAST(100.0 * SUM(wait_time_ms) / NULLIF(SUM(SUM(wait_time_ms)) OVER (), 0) AS decimal(6,2)) AS pct
    FROM c
    GROUP BY wait_category
    ORDER BY wait_ms DESC;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_top_waits_categories'))
        DROP SIGNATURE FROM OBJECT::dba.usp_top_waits_categories BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_top_waits_categories BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_top_waits_categories TO [role_dmv_cert_readers];
GO
