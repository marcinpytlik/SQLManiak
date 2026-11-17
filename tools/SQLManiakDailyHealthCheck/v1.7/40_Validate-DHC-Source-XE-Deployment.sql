/*
 SQLManiak DHC v1.7 - post-install read-only verification (SQL Server 2022+).
 Run on monitored source as a DBA in SSMS, after 38 and 39.
 Uses EXECUTE AS LOGIN. Does not modify server state, databases or XE.
 Empty XE events are not proof that no autogrowth occurred.
*/
USE master;
GO
SET NOCOUNT ON;
DECLARE @ExpectedServer sysname=N'REPLACE_WITH_EXACT_AT_AT_SERVERNAME';
IF @@SERVERNAME<>@ExpectedServer OR @ExpectedServer LIKE N'REPLACE_WITH_%'
    THROW 51950,'Wrong source instance; configure @ExpectedServer.',1;
IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE name=N'dhc_source_collector')
    THROW 51951,'DHC source login missing. Run installer 38.',1;
IF NOT EXISTS(SELECT 1 FROM sys.server_event_sessions WHERE name=N'SQLManiak_Autogrowth')
    THROW 51952,'DHC XE session missing. Run installer 39.',1;

SELECT @@SERVERNAME AS InstanceName,
       CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion')) AS ProductVersion,
       s.name AS SessionName,s.startup_state,
       CASE WHEN r.name IS NULL THEN 'STOPPED' ELSE 'RUNNING' END AS RuntimeState,
       t.name AS TargetName,CONVERT(nvarchar(4000),f.value) AS XelPath,
       e.name AS EventName,e.predicate AS EventPredicate
FROM sys.server_event_sessions s
JOIN sys.server_event_session_events e ON e.event_session_id=s.event_session_id
LEFT JOIN sys.server_event_session_targets t
  ON t.event_session_id=s.event_session_id AND t.name=N'event_file'
LEFT JOIN sys.server_event_session_fields f
  ON f.event_session_id=s.event_session_id
 AND f.object_id=t.target_id AND f.name=N'filename'
LEFT JOIN sys.dm_xe_sessions r ON r.name=s.name
WHERE s.name=N'SQLManiak_Autogrowth';

BEGIN TRY
    EXECUTE AS LOGIN=N'dhc_source_collector';
    SELECT SUSER_SNAME() AS ExecutionLogin,
           HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY DEFINITION') AS CanViewAnyDefinition,
           HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER PERFORMANCE STATE') AS CanViewPerformance,
           HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER SECURITY STATE') AS CanViewSecurity,
           HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY ERROR LOG') AS CanViewErrorLog,
           HAS_PERMS_BY_NAME(NULL,NULL,'ALTER TRACE') AS CanAlterTrace,
           IS_SRVROLEMEMBER('sysadmin') AS IsSysadmin;

    SELECT COUNT_BIG(*) AS VisibleFiles,
           SUM(CASE WHEN database_id > 4 THEN CONVERT(bigint,1)
                    ELSE CONVERT(bigint,0) END) AS UserDatabaseFiles
    FROM sys.master_files;

    DECLARE @FileName nvarchar(4000),@Pattern nvarchar(4000);
    SELECT TOP (1) @FileName=CONVERT(nvarchar(4000),f.value)
    FROM sys.server_event_sessions s
    JOIN sys.server_event_session_targets t
      ON t.event_session_id=s.event_session_id AND t.name=N'event_file'
    JOIN sys.server_event_session_fields f
      ON f.event_session_id=s.event_session_id
     AND f.object_id=t.target_id AND f.name=N'filename'
    WHERE s.name=N'SQLManiak_Autogrowth';
    IF @FileName IS NULL OR RIGHT(LOWER(@FileName),4)<>N'.xel'
        THROW 51953,'XE event_file filename not readable.',1;
    SET @Pattern=LEFT(@FileName,LEN(@FileName)-4)+N'*.xel';

    SELECT object_name,timestamp_utc,CAST(event_data AS xml) AS EventXml
    INTO #XeReadback
    FROM sys.fn_xe_file_target_read_file(@Pattern,NULL,NULL,NULL)
    WHERE object_name=N'database_file_size_change';

    SELECT COUNT_BIG(*) AS RecordedGrowthEvents,
           MIN(timestamp_utc) AS OldestEventUTC,
           MAX(timestamp_utc) AS NewestEventUTC
    FROM #XeReadback;

    REVERT;
END TRY
BEGIN CATCH
    IF ORIGINAL_LOGIN()<>SUSER_SNAME() REVERT;
    THROW;
END CATCH;
GO
