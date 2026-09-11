/* SQLManiak - CDC POC | 06_CDC_Retention.sql */
USE CDC_Lab;
GO

-- Show current CDC job configuration.
EXEC sys.sp_cdc_help_jobs;
GO

-- Example: keep CDC data for 24 hours (1440 minutes).
-- Change this value for your lab scenario if needed.
EXEC sys.sp_cdc_change_job
    @job_type = N'cleanup',
    @retention = 1440;
GO

-- Example: capture job tuning for a lab.
EXEC sys.sp_cdc_change_job
    @job_type = N'capture',
    @maxtrans = 500,
    @maxscans = 10,
    @pollinginterval = 5;
GO

-- Restart capture job so changed capture parameters take effect.
EXEC sys.sp_cdc_stop_job @job_type = N'capture';
EXEC sys.sp_cdc_start_job @job_type = N'capture';
GO

EXEC sys.sp_cdc_help_jobs;
GO

-- Oldest/newest LSN currently available per capture instance.
SELECT
    N'dbo_Customer' AS CaptureInstance,
    sys.fn_cdc_get_min_lsn(N'dbo_Customer') AS MinLSN,
    sys.fn_cdc_get_max_lsn() AS MaxLSN
UNION ALL
SELECT
    N'dbo_CustomerOrder',
    sys.fn_cdc_get_min_lsn(N'dbo_CustomerOrder'),
    sys.fn_cdc_get_max_lsn();
GO
