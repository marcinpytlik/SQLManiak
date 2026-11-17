/* DHC v1.7 Test 24 - safe stale-RUNNING detection.
   RUN ON LAB REPOSITORY ONLY after 14_RunningWatch.sql.
   All synthetic rows are transactionally rolled back.
*/
USE SQLManiakHealthHistory;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @tag nvarchar(36)=CONVERT(nvarchar(36),NEWID());
DECLARE @old nvarchar(256)=N'DHC_TEST_STALE_RUNNING_'+@tag;
DECLARE @recent nvarchar(256)=N'DHC_TEST_RECENT_RUNNING_'+@tag;
DECLARE @ids TABLE (ServerId int NOT NULL,ServerInstance nvarchar(256) NOT NULL);
DECLARE @actual TABLE
(
 ExecutionId uniqueidentifier,ServerId int,ServerInstance nvarchar(256),
 StartedUTC datetime2(3),Status varchar(16),
 AgeSeconds bigint,AgeMinutes bigint,SuspectedStale bit,
 Environment varchar(12),IsEnabled bit,ThresholdMinutes int
);
BEGIN TRY
 BEGIN TRANSACTION;

 INSERT dhc.MonitoredServer
 (ServerInstance,DisplayName,Environment,MonitorGroup,IsEnabled,
  IntervalMinutes,CollectTempDB)
 OUTPUT inserted.ServerId,inserted.ServerInstance INTO @ids
 VALUES
 (@old,N'Test stale RUNNING','LAB',N'DHC_TEST',1,60,0),
 (@recent,N'Test recent RUNNING','LAB',N'DHC_TEST',1,60,0);

 INSERT dhc.ExecutionLog
 (ExecutionId,ServerId,ServerInstance,StartedUTC,Status)
 SELECT NEWID(),ServerId,ServerInstance,
        CASE WHEN ServerInstance=@old THEN DATEADD(MINUTE,-180,SYSUTCDATETIME())
             ELSE DATEADD(MINUTE,-1,SYSUTCDATETIME()) END,
        'RUNNING'
 FROM @ids;

 INSERT @actual EXEC dhc.GetRunningWatch @MinAgeMinutes=60,@IncludeRecent=1;
 SELECT
    CASE WHEN a.ServerInstance=@old THEN 'STALE_180_MIN'
         ELSE 'RECENT_1_MIN' END AS Scenario,
    a.Status,a.AgeMinutes,a.ThresholdMinutes,a.SuspectedStale,
    CASE WHEN a.ServerInstance=@old AND a.SuspectedStale=1 THEN 'PASS'
         WHEN a.ServerInstance=@recent AND a.SuspectedStale=0 THEN 'PASS'
         ELSE 'FAILED' END AS Verdict
 FROM @actual AS a
 WHERE a.ServerInstance IN (@old,@recent)
 ORDER BY Scenario;

 IF (SELECT COUNT(*) FROM @actual WHERE ServerInstance IN (@old,@recent))<>2
    OR EXISTS(SELECT 1 FROM @actual
              WHERE (ServerInstance=@old AND SuspectedStale<>1)
                 OR (ServerInstance=@recent AND SuspectedStale<>0))
    THROW 51052,'Stale RUNNING classification assertion failed.',1;

 DELETE FROM @actual;
 INSERT @actual EXEC dhc.GetRunningWatch @MinAgeMinutes=60,@IncludeRecent=0;
 IF (SELECT COUNT(*) FROM @actual WHERE ServerInstance IN (@old,@recent))<>1
    OR NOT EXISTS(SELECT 1 FROM @actual WHERE ServerInstance=@old AND SuspectedStale=1)
    THROW 51053,'Default filter should return only stale synthetic run.',1;

 ROLLBACK TRANSACTION;
 SELECT 'PASS' AS TestResult,'Synthetic rows rolled back' AS Cleanup;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
SELECT ServerId,ServerInstance,IsEnabled
FROM dhc.MonitoredServer
WHERE Environment='LAB'
ORDER BY ServerInstance;
GO
