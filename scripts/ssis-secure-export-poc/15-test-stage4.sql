/*
    POC: Secure export without unconstrained delegation
    Stage 4 - run and verify the SQL Agent CmdExec job

    Expected:
      job outcome = Succeeded
      file appears on \\DC01\SSISLab$
*/

USE [msdb];
GO

SET NOCOUNT ON;

DECLARE @JobName sysname = N'POC_Secure_Export_Stage4';
DECLARE @JobId uniqueidentifier;
DECLARE @SessionId int;
DECLARE @Counter int = 0;
DECLARE @MaxLoops int = 60; -- 60 x 2 seconds = 120 seconds
DECLARE @IsRunning bit = 0;
DECLARE @RunStatus int;
DECLARE @RunStatusText nvarchar(30);

SELECT @JobId = job_id
FROM dbo.sysjobs
WHERE name = @JobName;

IF @JobId IS NULL
BEGIN
    THROW 58001, 'Stage 4 SQL Agent job was not found.', 1;
END;

SELECT @SessionId = MAX(session_id)
FROM dbo.syssessions;

IF EXISTS
(
    SELECT 1
    FROM dbo.sysjobactivity
    WHERE session_id = @SessionId
      AND job_id = @JobId
      AND start_execution_date IS NOT NULL
      AND stop_execution_date IS NULL
)
BEGIN
    THROW 58002, 'Stage 4 SQL Agent job is already running.', 1;
END;

EXEC dbo.sp_start_job @job_id = @JobId;

WHILE @Counter < 10
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM dbo.sysjobactivity
        WHERE session_id = @SessionId
          AND job_id = @JobId
          AND start_execution_date IS NOT NULL
          AND stop_execution_date IS NULL
    )
        BREAK;

    WAITFOR DELAY '00:00:01';
    SET @Counter += 1;
END;

SET @Counter = 0;

WHILE @Counter < @MaxLoops
BEGIN
    SET @IsRunning = 0;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.sysjobactivity
        WHERE session_id = @SessionId
          AND job_id = @JobId
          AND start_execution_date IS NOT NULL
          AND stop_execution_date IS NULL
    )
    BEGIN
        SET @IsRunning = 1;
    END;

    IF @IsRunning = 0
        BREAK;

    WAITFOR DELAY '00:00:02';
    SET @Counter += 1;
END;

IF @IsRunning = 1
BEGIN
    THROW 58003, 'Stage 4 job did not finish within 120 seconds.', 1;
END;

SELECT TOP (1)
    @RunStatus = h.run_status
FROM dbo.sysjobhistory AS h
WHERE h.job_id = @JobId
  AND h.step_id = 0
ORDER BY h.instance_id DESC;

SET @RunStatusText =
    CASE @RunStatus
        WHEN 0 THEN N'Failed'
        WHEN 1 THEN N'Succeeded'
        WHEN 2 THEN N'Retry'
        WHEN 3 THEN N'Canceled'
        WHEN 4 THEN N'In Progress'
        ELSE N'Unknown'
    END;

SELECT
    @JobName AS JobName,
    @RunStatus AS RunStatus,
    @RunStatusText AS JobOutcome;

SELECT TOP (10)
    h.instance_id,
    CASE h.step_id WHEN 0 THEN N'(Job outcome)' ELSE h.step_name END AS StepName,
    h.run_status,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
    h.run_duration,
    h.message
FROM dbo.sysjobhistory AS h
WHERE h.job_id = @JobId
ORDER BY h.instance_id DESC;

IF ISNULL(@RunStatus, -1) <> 1
BEGIN
    THROW 58004, 'Stage 4 job did not finish successfully. Review SQL Agent job history.', 1;
END;

PRINT 'STAGE4_JOB_TEST_OK';
PRINT 'Verify that a new cmdexec-proxy-test-*.txt file exists on \\DC01\SSISLab$.';
PRINT 'Verify inside the file: WindowsIdentity=SQLLAB\poc-ssis-export.';
GO
