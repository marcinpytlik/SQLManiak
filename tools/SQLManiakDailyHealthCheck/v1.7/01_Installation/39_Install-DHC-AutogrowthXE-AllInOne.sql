/*
 SQLManiak DHC v1.7 - SOURCE XE AUTOGROWTH INSTALLER (SQL Server 2022+).
 Run as authorized DBA ON EACH MONITORED INSTANCE AFTER installer 38.
 Creates SQLManiak_Autogrowth XE event_file session; no Repository changes.
 Captures ONLY automatic positive database_file_size_change events.
 Uses SQL Server ERRORLOG directory by default; override @XelFileName only
 after validating folder existence, SQL Server service filesystem rights,
 disk capacity, antivirus exclusions and FCI failover behavior.
 No password or credential in this script. No DROP or event replay.
 Existing session is NOT recreated; inspect mismatches before production.
 Set @ExpectedServer to exact @@SERVERNAME. Run in SSMS (normal mode).
*/
USE master;
GO
SET NOCOUNT ON;

DECLARE @ExpectedServer sysname = N'REPLACE_WITH_EXACT_AT_AT_SERVERNAME';
DECLARE @XelFileName nvarchar(4000) = NULL; -- e.g. N'D:\\SQLXE\\SQLManiak_Autogrowth.xel'; NULL => ERRORLOG directory
DECLARE @MaxFileSizeMB int = 32;
DECLARE @MaxRolloverFiles int = 8;
DECLARE @StartNow bit = 1;
DECLARE @StartupState bit = 1; -- production: ON, LAB may set 0

IF CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) < 16
    THROW 51930, 'SQL Server 2022+ required; review 2016/2019 separately.', 1;
IF @ExpectedServer IS NULL OR @ExpectedServer LIKE N'REPLACE_WITH_%'
   OR @ExpectedServer <> CONVERT(sysname,@@SERVERNAME)
    THROW 51931, 'Wrong source instance: set @ExpectedServer to exact @@SERVERNAME.', 1;
IF @MaxFileSizeMB NOT BETWEEN 5 AND 1024 OR @MaxRolloverFiles NOT BETWEEN 2 AND 32
    THROW 51932, 'Invalid XE event_file retention parameters.', 1;
IF @StartNow IS NULL OR @StartupState IS NULL
    THROW 51933, 'StartNow/StartupState must be 0 or 1.', 1;

IF @XelFileName IS NULL
BEGIN
    DECLARE @ErrorLog nvarchar(4000) =
        CONVERT(nvarchar(4000),SERVERPROPERTY('ErrorLogFileName'));
    IF @ErrorLog IS NULL OR LEN(@ErrorLog) < 5
        THROW 51934, 'Cannot determine ERRORLOG path; set @XelFileName explicitly.', 1;
    DECLARE @Slash int = CHARINDEX(N'/',REVERSE(@ErrorLog));
    DECLARE @Backslash int = CHARINDEX(N'\',REVERSE(@ErrorLog));
    DECLARE @LastSeparator int =
        CASE WHEN @Slash=0 THEN @Backslash
             WHEN @Backslash=0 THEN @Slash
             WHEN @Slash < @Backslash THEN @Slash ELSE @Backslash END;
    IF @LastSeparator=0
        THROW 51935, 'Cannot determine ERRORLOG directory; set @XelFileName.', 1;
    SET @XelFileName = LEFT(@ErrorLog,LEN(@ErrorLog)-@LastSeparator+1)
                        + N'SQLManiak_Autogrowth.xel';
END;
IF RIGHT(LOWER(@XelFileName),4) <> N'.xel'
   OR CHARINDEX(N'*',@XelFileName)>0 OR CHARINDEX(N'?',@XelFileName)>0
    THROW 51936, 'XEL filename must be absolute *.xel without wildcard characters.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name=N'SQLManiak_Autogrowth')
BEGIN
    DECLARE @Sql nvarchar(max) =
        N'CREATE EVENT SESSION [SQLManiak_Autogrowth] ON SERVER
          ADD EVENT sqlserver.database_file_size_change
          (WHERE ([is_automatic]=(1) AND [size_change_kb]>(0)))
          ADD TARGET package0.event_file
          (SET filename=N''' + REPLACE(@XelFileName,N'''',N'''''') +
        N''', max_file_size=(' + CONVERT(nvarchar(10),@MaxFileSizeMB) +
        N'), max_rollover_files=(' + CONVERT(nvarchar(10),@MaxRolloverFiles) +
        N')) WITH (MAX_MEMORY=4 MB,
                   EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
                   MAX_DISPATCH_LATENCY=5 SECONDS,
                   TRACK_CAUSALITY=OFF,
                   STARTUP_STATE=' + CASE WHEN @StartupState=1 THEN N'ON' ELSE N'OFF' END + N');';
    EXEC sys.sp_executesql @Sql;
    PRINT 'Created SQLManiak_Autogrowth XE session.';
END
ELSE
BEGIN
    PRINT 'Existing SQLManiak_Autogrowth retained; verify target path, retention and predicate.';
    -- Do not silently reconfigure/drop an existing event session.
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.server_event_session_events e
    JOIN sys.server_event_sessions s ON s.event_session_id=e.event_session_id
    WHERE s.name=N'SQLManiak_Autogrowth'
      AND e.name=N'database_file_size_change'
      AND CONVERT(nvarchar(max),e.predicate) LIKE N'%is_automatic%'
      AND CONVERT(nvarchar(max),e.predicate) LIKE N'%size_change_kb%'
)
    THROW 51937, 'Existing XE session has unexpected event/predicate; review manually.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.server_event_sessions s
    JOIN sys.server_event_session_targets t
      ON t.event_session_id=s.event_session_id
     AND t.name=N'event_file'
    JOIN sys.server_event_session_fields f
      ON f.event_session_id=s.event_session_id
     AND f.object_id=t.target_id AND f.name=N'filename'
    WHERE s.name=N'SQLManiak_Autogrowth'
)
    THROW 51938, 'XE event_file target/filename missing; review existing session.', 1;

IF @StartNow=1 AND NOT EXISTS
    (SELECT 1 FROM sys.dm_xe_sessions WHERE name=N'SQLManiak_Autogrowth')
    ALTER EVENT SESSION [SQLManiak_Autogrowth] ON SERVER STATE=START;

-- No changes to startup_state if session already existed; verify this explicitly.
SELECT
    @@SERVERNAME AS SourceInstance,
    s.name AS SessionName,
    s.startup_state AS StartupState,
    CASE WHEN r.name IS NULL THEN 'STOPPED' ELSE 'RUNNING' END AS RuntimeState,
    e.name AS EventName,
    e.predicate AS EventPredicate,
    f.value AS ConfiguredXelPath
FROM sys.server_event_sessions s
JOIN sys.server_event_session_events e ON e.event_session_id=s.event_session_id
LEFT JOIN sys.dm_xe_sessions r ON r.name=s.name
LEFT JOIN sys.server_event_session_targets t
  ON t.event_session_id=s.event_session_id AND t.name=N'event_file'
LEFT JOIN sys.server_event_session_fields f
  ON f.event_session_id=s.event_session_id
 AND f.object_id=t.target_id AND f.name=N'filename'
WHERE s.name=N'SQLManiak_Autogrowth';

PRINT 'Verify startup_state, actual XE path, security, 24h retention and FCI failover behavior.';
GO
