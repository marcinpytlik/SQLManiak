/* TEST 07 - Retention / LSN gap
   WARNING: destructive with respect to CDC history. Run only in the lab.
*/
USE CDC_Lab;
GO

EXEC sys.sp_cdc_help_jobs;
GO

SELECT
    capture_instance,
    sys.fn_cdc_get_min_lsn(capture_instance) AS MinLsn
FROM cdc.change_tables;
GO

SELECT sys.fn_cdc_get_max_lsn() AS MaxLsn;
GO

/*
Test procedure:
1. Stop Debezium Connect.
2. Record the current consumer/connector position if available.
3. Generate some source changes.
4. Temporarily reduce CDC cleanup retention for the lab.
5. Let cleanup remove history older than the consumer position.
6. Start Debezium Connect and observe the failure/recovery behaviour.

Example LAB-ONLY retention change:
*/
EXEC sys.sp_cdc_change_job
    @job_type = N'cleanup',
    @retention = 1;
GO

EXEC sys.sp_cdc_stop_job @job_type = N'cleanup';
EXEC sys.sp_cdc_start_job @job_type = N'cleanup';
GO

WAITFOR DELAY '00:00:10';
GO

SELECT
    capture_instance,
    sys.fn_cdc_get_min_lsn(capture_instance) AS MinLsnAfterCleanup
FROM cdc.change_tables;
GO

/* Restore normal lab retention after the test (3 days = 4320 minutes). */
EXEC sys.sp_cdc_change_job
    @job_type = N'cleanup',
    @retention = 4320;
GO

/*
PASS:
- loss of required CDC history is detectable,
- connector does not silently skip the missing range,
- runbook decision is REINITIALIZE / new snapshot when required,
- cleanup retention is restored after the test.
*/
