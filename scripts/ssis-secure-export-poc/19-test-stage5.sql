/*
    POC: Secure export without unconstrained delegation
    Stage 5 - end-to-end queue test

    Expected:
      two requests are created
      worker changes them NEW -> PROCESSING -> DONE
      OutputFile points to \\DC01\SSISLab$
*/

USE [SSIS_Delegation_Lab];
GO

SET NOCOUNT ON;

DECLARE @RequestId1 uniqueidentifier;
DECLARE @RequestId2 uniqueidentifier;
DECLARE @ReportDate date = CONVERT(date, GETDATE());

EXEC dbo.usp_RequestExport
     @CustomerId = 5001,
     @ReportDate = @ReportDate,
     @RequestId = @RequestId1 OUTPUT;

EXEC dbo.usp_RequestExport
     @CustomerId = 5002,
     @ReportDate = @ReportDate,
     @RequestId = @RequestId2 OUTPUT;

SELECT
    N'Created test requests' AS TestStep,
    @RequestId1 AS RequestId1,
    @RequestId2 AS RequestId2;

DECLARE @JobName sysname = N'POC_Secure_Export_Stage5_Worker';
DECLARE @JobId uniqueidentifier;

SELECT @JobId = job_id
FROM msdb.dbo.sysjobs
WHERE name = @JobName;

IF @JobId IS NULL
BEGIN
    THROW 60001, 'Stage 5 worker job was not found.', 1;
END;

/* Start immediately unless the schedule has already started it. */
IF NOT EXISTS
(
    SELECT 1
    FROM msdb.dbo.sysjobactivity AS a
    WHERE a.session_id = (SELECT MAX(session_id) FROM msdb.dbo.syssessions)
      AND a.job_id = @JobId
      AND a.start_execution_date IS NOT NULL
      AND a.stop_execution_date IS NULL
)
BEGIN
    EXEC msdb.dbo.sp_start_job @job_id = @JobId;
END;

DECLARE @Counter int = 0;
DECLARE @MaxLoops int = 60; -- 120 seconds
DECLARE @Done int = 0;

WHILE @Counter < @MaxLoops
BEGIN
    SELECT @Done = COUNT(*)
    FROM dbo.ExportRequest
    WHERE RequestId IN (@RequestId1, @RequestId2)
      AND Status = 'DONE';

    IF @Done = 2
        BREAK;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ExportRequest
        WHERE RequestId IN (@RequestId1, @RequestId2)
          AND Status = 'FAILED'
    )
        BREAK;

    WAITFOR DELAY '00:00:02';
    SET @Counter += 1;
END;

SELECT
    RequestId,
    CustomerId,
    ReportDate,
    RequestedBy,
    RequestedAt,
    Status,
    StartedAt,
    FinishedAt,
    AttemptCount,
    MaxAttempts,
    LastAttemptAt,
    NextAttemptAt,
    OutputFile,
    ErrorMessage,
    WorkerToken
FROM dbo.ExportRequest
WHERE RequestId IN (@RequestId1, @RequestId2)
ORDER BY RequestedAt, RequestId;

SELECT TOP (10)
    h.instance_id,
    h.step_id,
    CASE h.step_id WHEN 0 THEN N'(Job outcome)' ELSE h.step_name END AS StepName,
    h.run_status,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
    h.run_duration,
    h.message
FROM msdb.dbo.sysjobhistory AS h
WHERE h.job_id = @JobId
ORDER BY h.instance_id DESC;

IF EXISTS
(
    SELECT 1
    FROM dbo.ExportRequest
    WHERE RequestId IN (@RequestId1, @RequestId2)
      AND Status <> 'DONE'
)
BEGIN
    THROW 60002, 'Stage 5 test did not complete both requests successfully. Review queue rows and SQL Agent history.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.ExportRequest
    WHERE RequestId IN (@RequestId1, @RequestId2)
      AND (OutputFile IS NULL OR OutputFile NOT LIKE N'\\DC01\SSISLab$\%')
)
BEGIN
    THROW 60003, 'Stage 5 request completed without the expected output path.', 1;
END;

PRINT 'STAGE5_END_TO_END_OK';
PRINT 'Verify both output files on \\DC01\SSISLab$ and confirm WorkerIdentity=SQLLAB\poc-ssis-export.';
GO
