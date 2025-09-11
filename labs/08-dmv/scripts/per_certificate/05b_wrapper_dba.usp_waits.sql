USE AdventureWorks2022;
GO

/* 1) Procedura zamiast widoku */
CREATE OR ALTER PROC dba.usp_waits
AS
BEGIN
  SET NOCOUNT ON;
  WITH w AS (
    SELECT
      wait_type,
      waiting_tasks_count,
      wait_time_ms,
      signal_wait_time_ms,
      wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms,
      CAST(100.0 * wait_time_ms / NULLIF(SUM(wait_time_ms) OVER (), 0) AS decimal(9,4)) AS wait_pct
    FROM sys.dm_os_wait_stats
    WHERE waiting_tasks_count > 0
      AND wait_type NOT IN (
        'SLEEP_TASK','SLEEP_SYSTEMTASK','BROKER_TASK_STOP','BROKER_TO_FLUSH',
        'BROKER_EVENTHANDLER','XE_TIMER_EVENT','XE_DISPATCHER_WAIT',
        'FT_IFTS_SCHEDULER_IDLE_WAIT','BROKER_RECEIVE_WAITFOR','SQLTRACE_BUFFER_FLUSH'
      )
  )
  SELECT * FROM w;
END;
GO

/* 2) Podpis procedury certyfikatem (po każdej zmianie — podpisać ponownie) */
IF EXISTS (
  SELECT 1
  FROM sys.crypt_properties
  WHERE class_desc = 'OBJECT_OR_COLUMN'
    AND major_id   = OBJECT_ID(N'dba.usp_waits')
)
BEGIN
  DROP SIGNATURE FROM OBJECT::dba.usp_waits BY CERTIFICATE dmv_cert;
END;
ADD  SIGNATURE TO   OBJECT::dba.usp_waits BY CERTIFICATE dmv_cert;
GO

/* 3) Uprawnienie dla czytelników (rola „cert”) */
GRANT EXECUTE ON dba.usp_waits TO [role_dmv_cert_readers];
GO
