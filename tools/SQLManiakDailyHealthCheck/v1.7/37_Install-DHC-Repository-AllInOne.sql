/*
 SQLManiak DHC v1.7 - ONE-FILE T-SQL REPOSITORY INSTALLER (SQL Server 2022+)
 Based on validated modular scripts 01/04/08/09/12/14/20/36, same object definitions.
 Run as authorized DBA in SSMS on intended REPOSITORY INSTANCE, with CREATE DATABASE
 and CREATE LOGIN privileges. REVIEW database files, recovery model, encryption,
 backups and service account permissions with the bank's operational standards.
 No automatic recovery-model changes, schedules, alerts, purges, source grants or targets.
 Safe to rerun in principle: no DELETE or DROP; existing passwords are not reset.
 IMPORTANT: copy this file OUTSIDE Git before entering real passwords; NEVER COMMIT
 credential-bearing variants. The literals below are placeholders and MUST be changed.
 DO NOT use on a SQL Server instance that hosts a different DHC Repository by accident.
*/
USE master;
GO
SET NOCOUNT ON;
DECLARE @CollectorPassword nvarchar(128) = N'REPLACE_WITH_UNIQUE_COLLECTOR_PASSWORD_16_PLUS';
DECLARE @GrafanaPassword nvarchar(128) = N'REPLACE_WITH_UNIQUE_GRAFANA_PASSWORD_16_PLUS';
DECLARE @ExpectedServer sysname = N'REPLACE_WITH_EXPECTED_REPOSITORY_SERVER_NAME'; 
-- Set @ExpectedServer to the exact value of SELECT @@SERVERNAME on the intended repository.
-- This protects against accidental installation on a source/production SQL instance.

IF CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) < 16
    THROW 51900,'SQL Server 2022 or newer required for this installer.',1;
IF @ExpectedServer LIKE N'REPLACE_WITH_%' OR @ExpectedServer<>CONVERT(sysname,@@SERVERNAME)
    THROW 51901,'Expected repository @@SERVERNAME does not match. Set @ExpectedServer explicitly.',1;
IF @CollectorPassword LIKE N'REPLACE_WITH_%' OR @GrafanaPassword LIKE N'REPLACE_WITH_%'
    THROW 51902,'Replace both password placeholders in a PRIVATE LOCAL COPY before executing.',1;
IF LEN(@CollectorPassword)<16 OR LEN(@GrafanaPassword)<16 OR @CollectorPassword=@GrafanaPassword
    THROW 51903,'Passwords must each be >=16 characters and different.',1;
IF CHARINDEX(NCHAR(0),@CollectorPassword)>0 OR CHARINDEX(NCHAR(0),@GrafanaPassword)>0
    THROW 51904,'Passwords contain invalid characters.',1;

DECLARE @login sysname,@secret nvarchar(128),@sql nvarchar(max),@type char(1);
DECLARE accounts CURSOR LOCAL FAST_FORWARD FOR
    SELECT name,secret FROM (VALUES
        (CONVERT(sysname,N'dhc_repository_collector'),@CollectorPassword),
        (CONVERT(sysname,N'dhc_grafana_reader'),@GrafanaPassword)
    ) AS p(name,secret);
OPEN accounts;
FETCH NEXT FROM accounts INTO @login,@secret;
WHILE @@FETCH_STATUS=0
BEGIN
    IF EXISTS(SELECT 1 FROM sys.server_principals WHERE name=@login AND type<>'S')
        THROW 51905,'Existing principal with requested name is not a SQL login.',1;
    IF EXISTS(SELECT 1 FROM sys.server_principals WHERE name=@login)
    BEGIN
        IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin',@login),0)<>0
            THROW 51906,'Existing DHC account is sysadmin. Refusing to reuse.',1;
        PRINT CONCAT('Existing SQL login retained without password reset: ',@login);
    END
    ELSE
    BEGIN
        SET @sql=N'CREATE LOGIN '+QUOTENAME(@login)+
          N' WITH PASSWORD = N'''+REPLACE(@secret,N'''',N'''''')+
          N''', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [master];';
        EXEC sys.sp_executesql @sql;
        PRINT CONCAT('Created SQL login: ',@login);
    END
    FETCH NEXT FROM accounts INTO @login,@secret;
END
CLOSE accounts;
DEALLOCATE accounts;
SET @sql=NULL;
SET @secret=NULL;
SET @CollectorPassword=NULL;
SET @GrafanaPassword=NULL;
GO

/* Deploy EXACT modular schema and grants; all below blocks are embedded so
   no external .sql files, SQLCMD mode or PowerShell are required. */

/* ===== BEGIN 01_Repository.sql ===== */
/* SQLManiak DHC v1.7 - central repository, SQL Server 2022+
   Execute ON THE REPOSITORY INSTANCE, with a deployment administrator.
   Creates SQLManiakHealthHistory if missing; additive/idempotent schema.
   No agent jobs or source-instance changes.
*/
USE master;
GO
IF DB_ID(N'SQLManiakHealthHistory') IS NULL CREATE DATABASE SQLManiakHealthHistory;
GO
USE SQLManiakHealthHistory;
GO
IF SCHEMA_ID(N'dhc') IS NULL EXEC(N'CREATE SCHEMA dhc AUTHORIZATION dbo');
GO
IF OBJECT_ID(N'dhc.Run',N'U') IS NULL
CREATE TABLE dhc.Run
(
 RunId uniqueidentifier NOT NULL CONSTRAINT PK_DHCRun PRIMARY KEY,
 ServerInstance nvarchar(256) NOT NULL,
 StartedUTC datetime2(3) NOT NULL CONSTRAINT DF_DHCRun_StartedUTC DEFAULT (SYSUTCDATETIME()),
 FinishedUTC datetime2(3) NULL,
 Status varchar(16) NOT NULL CONSTRAINT CK_DHCRun_Status CHECK (Status IN ('RUNNING','COMPLETE','PARTIAL','FAILED')),
 SourceResultSets int NULL,
 SourceRowCount bigint NULL,
 ErrorText nvarchar(2000) NULL,
 CollectorVersion varchar(16) NOT NULL CONSTRAINT DF_DHCCollectorVersion DEFAULT ('1.7')
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dhc.Run') AND name=N'IX_DHCRun_ServerDate')
 CREATE INDEX IX_DHCRun_ServerDate ON dhc.Run(ServerInstance,StartedUTC DESC) INCLUDE(Status,FinishedUTC);
GO
IF OBJECT_ID(N'dhc.ResultBatch',N'U') IS NULL
CREATE TABLE dhc.ResultBatch
(
 RunId uniqueidentifier NOT NULL,
 ResultIndex int NOT NULL,
 BatchNo int NOT NULL,
 SectionName nvarchar(128) NOT NULL,
 RowCount int NOT NULL,
 ColumnNamesJson nvarchar(max) NOT NULL,
 RowsJson nvarchar(max) NOT NULL,
 CONSTRAINT PK_DHCResultBatch PRIMARY KEY(RunId,ResultIndex,BatchNo),
 CONSTRAINT FK_DHCResultBatch_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId),
 CONSTRAINT CK_DHCResultBatch_RowsJson CHECK (ISJSON(RowsJson)=1),
 CONSTRAINT CK_DHCResultBatch_ColsJson CHECK (ISJSON(ColumnNamesJson)=1)
);
GO
IF OBJECT_ID(N'dhc.Alert',N'U') IS NULL
CREATE TABLE dhc.Alert
(
 AlertId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DHCAlert PRIMARY KEY,
 RunId uniqueidentifier NOT NULL,
 Severity varchar(8) NOT NULL,
 Area nvarchar(64) NOT NULL,
 ObjectName nvarchar(256) NULL,
 Details nvarchar(2000) NOT NULL,
 CONSTRAINT FK_DHCAlert_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dhc.Alert') AND name=N'IX_DHCAlert_Run')
 CREATE INDEX IX_DHCAlert_Run ON dhc.Alert(RunId,Severity);
GO
IF OBJECT_ID(N'dhc.TempDBSnapshot',N'U') IS NULL
CREATE TABLE dhc.TempDBSnapshot
(
 RunId uniqueidentifier NOT NULL CONSTRAINT PK_DHCTempDBSnapshot PRIMARY KEY,
 SampleUTC datetime2(3) NOT NULL,
 TotalDataMB decimal(19,2) NULL,
 UsedDataMB decimal(19,2) NULL,
 FreeDataMB decimal(19,2) NULL,
 DataFreePct decimal(9,2) NULL,
 UserObjectsMB decimal(19,2) NULL,
 InternalObjectsMB decimal(19,2) NULL,
 VersionStoreMB decimal(19,2) NULL,
 VersionStoreShareUsedPct decimal(9,2) NULL,
 TotalLogMB decimal(19,2) NULL,
 UsedLogMB decimal(19,2) NULL,
 LogFreePct decimal(9,2) NULL,
 MinDriveFreePct decimal(9,2) NULL,
 AnyFileCannotGrow bit NULL,
 PercentGrowthFileCount int NULL,
 DataFileCount int NULL,
 LogFileCount int NULL,
 ActiveVersioningTransactions bigint NULL,
 OldestVersioningSeconds bigint NULL,
 TempDBLogReuseWait nvarchar(60) NULL,
 CONSTRAINT FK_DHCTempDBSnapshot_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId)
);
GO
IF OBJECT_ID(N'dhc.TempDBFile',N'U') IS NULL
CREATE TABLE dhc.TempDBFile
(
 RunId uniqueidentifier NOT NULL,
 FileId int NOT NULL,
 FileType nvarchar(12) NULL,
 FileName sysname NULL,
 VolumeMountPoint nvarchar(512) NULL,
 SizeMB decimal(19,2) NULL,
 MaxSizeMB decimal(19,2) NULL,
 GrowthMB decimal(19,2) NULL,
 IsPercentGrowth bit NULL,
 NextGrowthMB decimal(19,2) NULL,
 NextGrowthWillFit bit NULL,
 AvailableVolumeMB decimal(19,2) NULL,
 JsonRow nvarchar(max) NOT NULL,
 CONSTRAINT PK_DHCTempDBFile PRIMARY KEY(RunId,FileId),
 CONSTRAINT FK_DHCTempDBFile_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId)
);
GO
IF OBJECT_ID(N'dhc.TempDBSession',N'U') IS NULL
CREATE TABLE dhc.TempDBSession
(
 RunId uniqueidentifier NOT NULL,
 SessionId smallint NOT NULL,
 RequestId int NOT NULL CONSTRAINT DF_DHCTempDBRequestId DEFAULT(-1),
 LoginName nvarchar(128) NULL,
 SessionAttributedMB decimal(19,2) NULL,
 VersioningSeconds bigint NULL,
 JsonRow nvarchar(max) NOT NULL,
 CONSTRAINT PK_DHCTempDBSession PRIMARY KEY(RunId,SessionId,RequestId),
 CONSTRAINT FK_DHCTempDBSession_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId)
);
GO
CREATE OR ALTER VIEW dhc.vTempDBTrend
AS
SELECT r.ServerInstance,r.StartedUTC,r.Status, t.*
FROM dhc.Run AS r JOIN dhc.TempDBSnapshot AS t ON r.RunId=t.RunId;
GO
CREATE OR ALTER VIEW dhc.vDailyAlerts
AS
SELECT CONVERT(date,r.StartedUTC) AS DayUTC,r.StartedUTC,r.ServerInstance,
       a.Severity,a.Area,a.ObjectName,a.Details
FROM dhc.Run AS r JOIN dhc.Alert AS a ON r.RunId=a.RunId;
GO
/* Optional retention: review before executing! Does not auto-delete. */
CREATE OR ALTER PROCEDURE dhc.PurgeRuns @OlderThanUTC datetime2(3), @DryRun bit=1
AS
BEGIN
 SET NOCOUNT ON;
 IF @DryRun=1
 BEGIN
  SELECT COUNT_BIG(*) AS RunsToDelete FROM dhc.Run WHERE StartedUTC<@OlderThanUTC;
  RETURN;
 END;
 BEGIN TRAN;
 DELETE t FROM dhc.TempDBSession t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE t FROM dhc.TempDBFile t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE t FROM dhc.TempDBSnapshot t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE t FROM dhc.Alert t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE t FROM dhc.ResultBatch t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE FROM dhc.Run WHERE StartedUTC<@OlderThanUTC;
 COMMIT;
END;
GO
/* ===== END 01_Repository.sql ===== */


/* ===== BEGIN 04_MonitoredServers.sql ===== */
/* SQLManiak DHC v1.7 - monitored SQL Server instances inventory.
   Run on SQL Repository (port 15433 in the Docker lab).
   Safe to rerun; no existing DHC history or configuration is altered.
   Does NOT create credentials or schedule the collector.
*/
USE SQLManiakHealthHistory;
GO
IF SCHEMA_ID(N'dhc') IS NULL
    THROW 51001, 'Schema dhc is missing. Run 01_Repository.sql first.', 1;
GO

IF OBJECT_ID(N'dhc.MonitoredServer', N'U') IS NULL
BEGIN
    CREATE TABLE dhc.MonitoredServer
    (
        ServerId int IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_DHCMonitoredServer PRIMARY KEY,
        ServerInstance nvarchar(256) NOT NULL,
        DisplayName nvarchar(256) NULL,
        Environment varchar(12) NOT NULL,
        MonitorGroup nvarchar(80) NULL,
        IsEnabled bit NOT NULL
            CONSTRAINT DF_DHCMonitoredServer_IsEnabled DEFAULT (0),
        IntervalMinutes int NOT NULL
            CONSTRAINT DF_DHCMonitoredServer_IntervalMinutes DEFAULT (1440),
        CollectTempDB bit NOT NULL
            CONSTRAINT DF_DHCMonitoredServer_CollectTempDB DEFAULT (1),
        Notes nvarchar(1000) NULL,
        CreatedUTC datetime2(3) NOT NULL
            CONSTRAINT DF_DHCMonitoredServer_CreatedUTC DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_DHCMonitoredServer_ServerInstance UNIQUE (ServerInstance),
        CONSTRAINT CK_DHCMonitoredServer_Instance_NotBlank CHECK (LEN(LTRIM(RTRIM(ServerInstance))) > 0),
        CONSTRAINT CK_DHCMonitoredServer_Environment
            CHECK (Environment IN ('PROD','TEST','DEV','LAB','DR')),
        CONSTRAINT CK_DHCMonitoredServer_IntervalMinutes
            CHECK (IntervalMinutes BETWEEN 1 AND 10080)
    );
END;
GO

-- The inventory is configuration, not history: intentionally no foreign key
-- from dhc.Run.ServerInstance, so historical runs remain when inventory changes.
SELECT ServerId, ServerInstance, DisplayName, Environment, MonitorGroup,
       IsEnabled, IntervalMinutes, CollectTempDB, Notes, CreatedUTC
FROM dhc.MonitoredServer
ORDER BY Environment, ServerInstance;
GO

/* Example: insert the local Docker target ONCE, if desired.
   Disabled by default; enable only after configuring a scheduler.

IF NOT EXISTS (
    SELECT 1 FROM dhc.MonitoredServer
    WHERE ServerInstance = N'127.0.0.1,15434'
)
BEGIN
    INSERT dhc.MonitoredServer
        (ServerInstance, DisplayName, Environment, MonitorGroup,
         IsEnabled, IntervalMinutes, CollectTempDB, Notes)
    VALUES
        (N'127.0.0.1,15434', N'DHC Docker Target', 'LAB', N'Docker',
         0, 1440, 1, N'Local SQL Server 2022 test instance');
END;

-- Example production registration (replace values with real endpoints).
-- Keep IsEnabled = 0 until tested with a least-privilege collector identity.
-- INSERT dhc.MonitoredServer(ServerInstance, DisplayName, Environment, MonitorGroup, IsEnabled)
-- VALUES (N'FCI-VNN\INST', N'Production SQL FCI', 'PROD', N'Cluster-01', 0);

-- Enable monitoring for a verified endpoint (no schedule is installed here).
-- UPDATE dhc.MonitoredServer SET IsEnabled = 1
-- WHERE ServerInstance = N'FCI-VNN\INST';
*/
/* ===== END 04_MonitoredServers.sql ===== */


/* ===== BEGIN 08_ExecutionLog.sql ===== */
/* SQLManiak DHC v1.7 - durable multi-server runner execution history.
   Run on Repository (SQLManiakHealthHistory) AFTER 04_MonitoredServers.sql.
   Additive and idempotent; no existing DHC data is removed.
   Never log passwords, credentials, or connection strings.
*/
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.MonitoredServer', N'U') IS NULL
    THROW 51010, 'Run 04_MonitoredServers.sql before 08_ExecutionLog.sql.', 1;
GO
IF OBJECT_ID(N'dhc.ExecutionLog', N'U') IS NULL
BEGIN
 CREATE TABLE dhc.ExecutionLog
 (
    ExecutionId uniqueidentifier NOT NULL CONSTRAINT PK_DHCExecutionLog PRIMARY KEY,
    ServerId int NOT NULL,
    ServerInstance nvarchar(256) NOT NULL,
    StartedUTC datetime2(3) NOT NULL,
    FinishedUTC datetime2(3) NULL,
    Status varchar(16) NOT NULL,
    RunId uniqueidentifier NULL,
    RowsStored bigint NULL,
    ErrorText nvarchar(4000) NULL,
    RunnerVersion varchar(16) NOT NULL
        CONSTRAINT DF_DHCExecutionLog_RunnerVersion DEFAULT ('1.7'),
    CONSTRAINT CK_DHCExecutionLog_Status
        CHECK (Status IN ('RUNNING','COMPLETE','PARTIAL','FAILED')),
    CONSTRAINT CK_DHCExecutionLog_Finish
        CHECK (
            (Status='RUNNING' AND FinishedUTC IS NULL)
            OR (Status<>'RUNNING' AND FinishedUTC IS NOT NULL)
        ),
    CONSTRAINT CK_DHCExecutionLog_RunId
        CHECK ((Status IN ('RUNNING','FAILED') AND RunId IS NULL)
            OR (Status IN ('COMPLETE','PARTIAL') AND RunId IS NOT NULL))
 );
END;
GO
IF NOT EXISTS
(
 SELECT 1 FROM sys.indexes
 WHERE object_id=OBJECT_ID(N'dhc.ExecutionLog')
   AND name=N'IX_DHCExecutionLog_ServerStarted'
)
 CREATE INDEX IX_DHCExecutionLog_ServerStarted
 ON dhc.ExecutionLog(ServerInstance,StartedUTC DESC)
 INCLUDE(Status,FinishedUTC,RunId,RowsStored);
GO
IF NOT EXISTS
(
 SELECT 1 FROM sys.indexes
 WHERE object_id=OBJECT_ID(N'dhc.ExecutionLog')
   AND name=N'IX_DHCExecutionLog_StatusStarted'
)
 CREATE INDEX IX_DHCExecutionLog_StatusStarted
 ON dhc.ExecutionLog(Status,StartedUTC DESC)
 INCLUDE(ServerId,ServerInstance,FinishedUTC);
GO
SELECT TOP(20) ExecutionId,ServerId,ServerInstance,StartedUTC,FinishedUTC,
               Status,RunId,RowsStored,ErrorText
FROM dhc.ExecutionLog
ORDER BY StartedUTC DESC;
GO
/* ===== END 08_ExecutionLog.sql ===== */


/* ===== BEGIN 09_MonitoringStatus.sql ===== */
/* SQLManiak DHC v1.7 - monitoring of the monitoring.
   Install on Repository after 04_MonitoredServers.sql and 08_ExecutionLog.sql.
   Read-only views; safe to rerun and do not schedule or alter monitored targets.

   NO_DATA: no execution attempt has ever been logged for this endpoint.
   IsOverdue: enabled instance with no attempt by registration+IntervalMinutes,
              or no new attempt by last StartedUTC+IntervalMinutes.
   Note: IsOverdue measures ATTEMPT cadence, not successful measurements.
   LastCompleteUTC tracks last COMPLETE, independently of last attempt.
*/
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.MonitoredServer',N'U') IS NULL
 OR OBJECT_ID(N'dhc.ExecutionLog',N'U') IS NULL
    THROW 51020, 'Deploy 04_MonitoredServers.sql and 08_ExecutionLog.sql first.', 1;
GO
CREATE OR ALTER VIEW dhc.vMonitoringStatus
AS
SELECT
    s.ServerId,
    s.ServerInstance,
    s.DisplayName,
    s.Environment,
    s.MonitorGroup,
    s.IsEnabled,
    s.IntervalMinutes,
    s.CollectTempDB,
    s.CreatedUTC,
    l.ExecutionId AS LastExecutionId,
    l.StartedUTC AS LastAttemptUTC,
    l.FinishedUTC AS LastAttemptFinishedUTC,
    l.Status AS LastExecutionStatus,
    l.RunId AS LastRunId,
    l.RowsStored AS LastRowsStored,
    l.ErrorText AS LastErrorText,
    good.StartedUTC AS LastCompleteUTC,
    good.RunId AS LastCompleteRunId,
    calc.MinutesSinceAttempt,
    calc.MinutesSinceComplete,
    CONVERT(bit, CASE
       WHEN s.IsEnabled = 0 THEN 0
       WHEN calc.MinutesSinceAttempt > CONVERT(bigint,s.IntervalMinutes) THEN 1
       ELSE 0 END) AS IsOverdue,
    CASE
       WHEN s.IsEnabled = 0 THEN 'DISABLED'
       WHEN l.ExecutionId IS NULL THEN 'NO_DATA'
       WHEN l.Status = 'FAILED' THEN 'FAILED'
       WHEN l.Status = 'PARTIAL' THEN 'PARTIAL'
       WHEN l.Status = 'RUNNING' THEN 'RUNNING'
       WHEN l.Status = 'COMPLETE' THEN 'COMPLETE'
       ELSE 'UNKNOWN'
    END AS MonitoringStatus
FROM dhc.MonitoredServer AS s
OUTER APPLY (
    SELECT TOP (1)
        e.ExecutionId,e.StartedUTC,e.FinishedUTC,e.Status,
        e.RunId,e.RowsStored,e.ErrorText
    FROM dhc.ExecutionLog AS e
    WHERE e.ServerInstance = s.ServerInstance
    ORDER BY e.StartedUTC DESC,e.ExecutionId DESC
) AS l
OUTER APPLY (
    SELECT TOP (1) e.StartedUTC,e.RunId
    FROM dhc.ExecutionLog AS e
    WHERE e.ServerInstance=s.ServerInstance AND e.Status='COMPLETE'
    ORDER BY e.StartedUTC DESC,e.ExecutionId DESC
) AS good
CROSS APPLY (
    SELECT
       DATEDIFF_BIG(MINUTE,COALESCE(l.StartedUTC,s.CreatedUTC),SYSUTCDATETIME()) AS MinutesSinceAttempt,
       CASE WHEN good.StartedUTC IS NULL THEN NULL
            ELSE DATEDIFF_BIG(MINUTE,good.StartedUTC,SYSUTCDATETIME()) END AS MinutesSinceComplete
) AS calc;
GO
CREATE OR ALTER VIEW dhc.vMonitoringSummary
AS
SELECT
    Environment,
    COUNT_BIG(*) AS TotalServers,
    SUM(CONVERT(bigint,IsEnabled)) AS EnabledServers,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='COMPLETE' AND IsOverdue=0 THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS CurrentComplete,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='FAILED' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Failed,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='PARTIAL' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Partial,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='NO_DATA' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS NoData,
    SUM(CASE WHEN IsEnabled=1 AND IsOverdue=1 THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Overdue,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='RUNNING' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Running
FROM dhc.vMonitoringStatus
GROUP BY Environment;
GO
SELECT ServerId,ServerInstance,Environment,MonitoringStatus,
       IsOverdue,LastAttemptUTC,LastCompleteUTC,MinutesSinceAttempt,
       MinutesSinceComplete,LastErrorText
FROM dhc.vMonitoringStatus
ORDER BY Environment,MonitorGroup,ServerInstance;
GO
SELECT * FROM dhc.vMonitoringSummary ORDER BY Environment;
GO
/* ===== END 09_MonitoringStatus.sql ===== */


/* ===== BEGIN 12_TryStartExecution.sql ===== */
/* DHC v1.7: atomic, due-aware execution claim.
   Run on SQLManiakHealthHistory AFTER 08_ExecutionLog.sql.
   Adds no scheduler or SQL Agent job. Existing history is preserved.
*/
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.MonitoredServer',N'U') IS NULL
 OR OBJECT_ID(N'dhc.ExecutionLog',N'U') IS NULL
    THROW 51040, 'Install inventory and ExecutionLog first (04 and 08).', 1;
GO
CREATE OR ALTER PROCEDURE dhc.TryStartExecution
    @ServerId int,
    @ExecutionId uniqueidentifier,
    @Force bit=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Decision varchar(16)='NOT_FOUND',
            @LastStartedUTC datetime2(3)=NULL,
            @LastStatus varchar(16)=NULL,
            @ServerInstance nvarchar(256)=NULL,
            @IntervalMinutes int=NULL,
            @IsEnabled bit=NULL,
            @Resource nvarchar(255)=CONCAT(N'DHC_MONITOR_',CONVERT(nvarchar(12),@ServerId)),
            @LockResult int,
            @Now datetime2(3)=SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @LockResult=sys.sp_getapplock
             @Resource=@Resource,
             @LockMode='Exclusive',
             @LockOwner='Transaction',
             @LockTimeout=10000,
             @DbPrincipal='public';
        IF @LockResult < 0
            THROW 51041, 'Could not acquire the per-server scheduling lock.',1;

        SELECT @ServerInstance=ServerInstance,
               @IntervalMinutes=IntervalMinutes,
               @IsEnabled=IsEnabled
        FROM dhc.MonitoredServer WITH (UPDLOCK, HOLDLOCK)
        WHERE ServerId=@ServerId;

        IF @ServerInstance IS NULL
            SET @Decision='NOT_FOUND';
        ELSE IF @IsEnabled=0
            SET @Decision='DISABLED';
        ELSE
        BEGIN
            SELECT TOP (1)
                @LastStartedUTC=StartedUTC,
                @LastStatus=Status
            FROM dhc.ExecutionLog
            WHERE ServerInstance=@ServerInstance
            ORDER BY StartedUTC DESC, ExecutionId DESC;

            IF @LastStatus='RUNNING'
                SET @Decision='RUNNING';
            ELSE IF @Force=0
                 AND @LastStartedUTC IS NOT NULL
                 AND DATEADD(MINUTE,@IntervalMinutes,@LastStartedUTC)>@Now
                SET @Decision='NOT_DUE';
            ELSE
            BEGIN
                INSERT dhc.ExecutionLog
                    (ExecutionId,ServerId,ServerInstance,StartedUTC,Status)
                VALUES
                    (@ExecutionId,@ServerId,@ServerInstance,@Now,'RUNNING');
                SET @Decision='CLAIMED';
            END
        END;

        COMMIT TRANSACTION;
        SELECT @Decision AS Decision,
               @ServerInstance AS ServerInstance,
               @LastStatus AS PreviousStatus,
               @LastStartedUTC AS PreviousAttemptUTC,
               @Now AS EvaluatedUTC;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- This query does NOT create an execution attempt.
SELECT s.ServerId,s.ServerInstance,s.IntervalMinutes,s.IsEnabled,
       v.MonitoringStatus,v.LastAttemptUTC,v.IsOverdue
FROM dhc.MonitoredServer AS s
LEFT JOIN dhc.vMonitoringStatus AS v ON v.ServerId=s.ServerId
ORDER BY s.ServerId;
GO
/* ===== END 12_TryStartExecution.sql ===== */


/* ===== BEGIN 14_RunningWatch.sql ===== */
/* SQLManiak DHC v1.7 - stale RUNNING diagnostic, read-only.
   Deploy on SQLManiakHealthHistory after 08_ExecutionLog.sql.
   A long-running attempt is SUSPECTED, not proven orphaned.
   No UPDATE/DELETE/unlock or automatic restart.
*/
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.ExecutionLog',N'U') IS NULL
    THROW 51050,'Install 08_ExecutionLog.sql first.',1;
GO
CREATE OR ALTER PROCEDURE dhc.GetRunningWatch
    @MinAgeMinutes int=60,
    @IncludeRecent bit=0
AS
BEGIN
 SET NOCOUNT ON;
 IF @MinAgeMinutes NOT BETWEEN 1 AND 10080
    THROW 51051,'MinAgeMinutes must be between 1 and 10080.',1;

 DECLARE @Now datetime2(3)=SYSUTCDATETIME();
 SELECT
    e.ExecutionId,e.ServerId,e.ServerInstance,
    e.StartedUTC,e.Status,
    DATEDIFF_BIG(SECOND,e.StartedUTC,@Now) AS AgeSeconds,
    DATEDIFF_BIG(MINUTE,e.StartedUTC,@Now) AS AgeMinutes,
    CONVERT(bit,CASE WHEN e.StartedUTC<=DATEADD(MINUTE,-@MinAgeMinutes,@Now)
                     THEN 1 ELSE 0 END) AS SuspectedStale,
    s.Environment,s.IsEnabled,
    @MinAgeMinutes AS ThresholdMinutes
 FROM dhc.ExecutionLog AS e
 LEFT JOIN dhc.MonitoredServer AS s ON s.ServerId=e.ServerId
 WHERE e.Status='RUNNING'
   AND (@IncludeRecent=1 OR e.StartedUTC<=DATEADD(MINUTE,-@MinAgeMinutes,@Now))
 ORDER BY e.StartedUTC,e.ExecutionId;
END;
GO
EXEC dhc.GetRunningWatch @MinAgeMinutes=60, @IncludeRecent=1;
GO
/* ===== END 14_RunningWatch.sql ===== */


/* ===== BEGIN 20_RepositoryLeastPrivilege.sql ===== */
/* SQLManiak DHC v1.7 - repository least-privilege ROLE only.
   Run on LAB Repository after 01,04,08,09,12,14.
   Does NOT create SQL logins or attach users automatically.
   Grants to exact objects; does not grant db_owner/db_datawriter/sysadmin.
   Review for production before use.
*/
USE SQLManiakHealthHistory;
GO
SET NOCOUNT ON;
IF SCHEMA_ID(N'dhc') IS NULL
    THROW 51100,'Missing dhc schema. Deploy DHC repository first.',1;
IF OBJECT_ID(N'dhc.TryStartExecution',N'P') IS NULL
    THROW 51101,'Missing due-aware claim procedure (12).',1;
IF OBJECT_ID(N'dhc.MonitoredServer',N'U') IS NULL
 OR OBJECT_ID(N'dhc.ExecutionLog',N'U') IS NULL
 OR OBJECT_ID(N'dhc.Run',N'U') IS NULL
 OR OBJECT_ID(N'dhc.ResultBatch',N'U') IS NULL
 OR OBJECT_ID(N'dhc.Alert',N'U') IS NULL
 OR OBJECT_ID(N'dhc.TempDBSnapshot',N'U') IS NULL
 OR OBJECT_ID(N'dhc.TempDBFile',N'U') IS NULL
 OR OBJECT_ID(N'dhc.TempDBSession',N'U') IS NULL
    THROW 51102,'Missing one or more DHC repository tables.',1;
GO
IF DATABASE_PRINCIPAL_ID(N'dhc_collector') IS NULL
    CREATE ROLE dhc_collector AUTHORIZATION dbo;
GO
-- Inventory + preview scheduling reads.
GRANT SELECT ON OBJECT::dhc.MonitoredServer TO dhc_collector;
GRANT SELECT ON OBJECT::dhc.ExecutionLog TO dhc_collector;
GRANT EXECUTE ON OBJECT::dhc.TryStartExecution TO dhc_collector;

-- Record the non-atomic runner completion/failure in ExecutionLog.
GRANT INSERT, UPDATE ON OBJECT::dhc.ExecutionLog TO dhc_collector;

-- One collection transaction: write Run and its detail/alert tables.
GRANT INSERT, UPDATE ON OBJECT::dhc.Run TO dhc_collector;
-- UPDATE ... WHERE RunId=@RunId requires SELECT permission on predicate column.
-- Column-only grant avoids exposing other fields of dhc.Run.
GRANT SELECT ON OBJECT::dhc.Run (RunId) TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.ResultBatch TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.Alert TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.TempDBSnapshot TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.TempDBFile TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.TempDBSession TO dhc_collector;
GO
-- Role grants audit: should NOT show CONTROL, ALTER, DELETE, db_owner.
SELECT
    dp.name AS RoleName,
    o.name AS ObjectName,
    p.permission_name AS PermissionName,
    p.state_desc AS PermissionState
FROM sys.database_permissions AS p
JOIN sys.database_principals AS dp ON p.grantee_principal_id=dp.principal_id
LEFT JOIN sys.objects AS o ON p.major_id=o.object_id
WHERE dp.name=N'dhc_collector'
ORDER BY o.name,p.permission_name;
GO
/* ACCOUNT PROVISIONING (MANUAL / NOT EXECUTED):
   1. In Docker LAB only, create dedicated server SQL login with a strong
      independently generated secret kept outside Git and the chat.
   2. Map that login to a user in SQLManiakHealthHistory.
   3. ALTER ROLE dhc_collector ADD MEMBER [YOUR_LAB_DHC_USER];
   4. Use its credential for repository DPAPI config in a NEW private folder.
   5. Do not reuse sa and do not grant server-wide roles or db_owner.
   Exact source-server permissions are outside scope: v1.5 original is
   local and may invoke privileged diagnostic stored procedures.
*/
/* ===== END 20_RepositoryLeastPrivilege.sql ===== */


/* ===== BEGIN 36_GrafanaPortalReader.sql ===== */
/*
 SQLManiak DHC Portal MVP - read-only Grafana access.
 Execute on Repository as deployment administrator.
 Expects an EXISTING SQL login (create it separately using a secure password).
 Replace exact login below. Never reuse the collector login.
 No broad schema SELECT and no write permissions.
*/
USE SQLManiakHealthHistory;
GO
SET NOCOUNT ON;
DECLARE @Login sysname=N'dhc_grafana_reader';
IF SCHEMA_ID(N'dhc') IS NULL OR OBJECT_ID(N'dhc.vMonitoringStatus',N'V') IS NULL
    THROW 51600,'Install DHC Repository first.',1;
IF SUSER_ID(@Login) IS NULL
    THROW 51601,'SQL login dhc_grafana_reader is missing; create it securely first.',1;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name=N'dhc_portal_reader' AND type<>'R')
    THROW 51602,'Principal dhc_portal_reader exists with incompatible type.',1;
IF DATABASE_PRINCIPAL_ID(N'dhc_portal_reader') IS NULL
    EXEC(N'CREATE ROLE [dhc_portal_reader] AUTHORIZATION [dbo];');
IF DATABASE_PRINCIPAL_ID(@Login) IS NULL
    EXEC(N'CREATE USER [dhc_grafana_reader] FOR LOGIN [dhc_grafana_reader];');
GO
GRANT SELECT ON OBJECT::dhc.MonitoredServer TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.ExecutionLog TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.Run TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.Alert TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.vMonitoringStatus TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.vMonitoringSummary TO [dhc_portal_reader];
-- Instance Details: normalized TempDB trends and per-file growth inventory.
GRANT SELECT ON OBJECT::dhc.vTempDBTrend TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.TempDBSnapshot TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.TempDBFile TO [dhc_portal_reader];
GO
IF NOT EXISTS
(
 SELECT 1 FROM sys.database_role_members rm
 JOIN sys.database_principals r ON r.principal_id=rm.role_principal_id
 JOIN sys.database_principals u ON u.principal_id=rm.member_principal_id
 WHERE r.name=N'dhc_portal_reader' AND u.name=N'dhc_grafana_reader'
)
 ALTER ROLE [dhc_portal_reader] ADD MEMBER [dhc_grafana_reader];
GO
SELECT r.name AS RoleName,u.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id=rm.role_principal_id
JOIN sys.database_principals u ON u.principal_id=rm.member_principal_id
WHERE r.name=N'dhc_portal_reader';
GO
/* Audit separately: do not grant db_datareader, dhc_collector, db_owner, sysadmin.
   Connect AS dhc_grafana_reader to verify Grafana Portal MVP and Instance Details panel queries in Grafana.
   The portal account may read diagnostic alerts, which can include sensitive
   object names and error text. Limit Grafana access accordingly.
*/
/* ===== END 36_GrafanaPortalReader.sql ===== */

/*
 FINAL: separate collector and Grafana database role memberships.
 Existing database users MUST map to their intended SQL login SID; fail otherwise.
*/
USE SQLManiakHealthHistory;
GO
SET NOCOUNT ON;
IF DATABASE_PRINCIPAL_ID(N'dhc_collector') IS NULL
 OR DATABASE_PRINCIPAL_ID(N'dhc_portal_reader') IS NULL
    THROW 51910,'Required DHC roles missing. Recheck previous installer batches.',1;
IF EXISTS (
    SELECT 1 FROM sys.database_principals
    WHERE name=N'dhc_repository_collector'
      AND (type<>'S' OR sid<>SUSER_SID(N'dhc_repository_collector'))
)
    THROW 51911,'Existing collector database user maps to another login.',1;
IF EXISTS (
    SELECT 1 FROM sys.database_principals
    WHERE name=N'dhc_grafana_reader'
      AND (type<>'S' OR sid<>SUSER_SID(N'dhc_grafana_reader'))
)
    THROW 51912,'Existing Grafana database user maps to another login.',1;
IF DATABASE_PRINCIPAL_ID(N'dhc_repository_collector') IS NULL
    CREATE USER [dhc_repository_collector] FOR LOGIN [dhc_repository_collector];
IF DATABASE_PRINCIPAL_ID(N'dhc_grafana_reader') IS NULL
    CREATE USER [dhc_grafana_reader] FOR LOGIN [dhc_grafana_reader];

IF NOT EXISTS (
 SELECT 1 FROM sys.database_role_members m
 JOIN sys.database_principals r ON m.role_principal_id=r.principal_id
 JOIN sys.database_principals u ON m.member_principal_id=u.principal_id
 WHERE r.name=N'dhc_collector' AND u.name=N'dhc_repository_collector'
)
 ALTER ROLE [dhc_collector] ADD MEMBER [dhc_repository_collector];

IF NOT EXISTS (
 SELECT 1 FROM sys.database_role_members m
 JOIN sys.database_principals r ON m.role_principal_id=r.principal_id
 JOIN sys.database_principals u ON m.member_principal_id=u.principal_id
 WHERE r.name=N'dhc_portal_reader' AND u.name=N'dhc_grafana_reader'
)
 ALTER ROLE [dhc_portal_reader] ADD MEMBER [dhc_grafana_reader];

SELECT @@SERVERNAME AS RepositorySqlInstance,DB_NAME() AS RepositoryDatabase,
       r.name AS DatabaseRole,u.name AS DatabaseUser
FROM sys.database_role_members m
JOIN sys.database_principals r ON m.role_principal_id=r.principal_id
JOIN sys.database_principals u ON m.member_principal_id=u.principal_id
WHERE (r.name=N'dhc_collector' AND u.name=N'dhc_repository_collector')
   OR (r.name=N'dhc_portal_reader' AND u.name=N'dhc_grafana_reader')
ORDER BY r.name;

SELECT o.name AS RequiredObject,o.type_desc
FROM sys.objects o
WHERE SCHEMA_NAME(o.schema_id)=N'dhc'
ORDER BY o.type_desc,o.name;
PRINT 'DHC REPOSITORY SQL INSTALLER FINISHED. Validate role memberships, backups, access and source registration separately.';
GO
