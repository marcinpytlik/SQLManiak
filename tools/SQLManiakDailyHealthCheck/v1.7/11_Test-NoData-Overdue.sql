/* DHC v1.7 - tests NO_DATA/OVERDUE, fully rolled back.
   RUN ONLY ON LAB REPOSITORY after 09_MonitoringStatus.sql.
   Does NOT touch the two actual Docker targets.
   Inserts three synthetic inventory entries inside one transaction.
   Does not persist anything (ROLLBACK on success and on error).
*/
USE SQLManiakHealthHistory;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @tag nvarchar(36)=CONVERT(nvarchar(36),NEWID());
DECLARE @fresh nvarchar(256)=N'DHC_TEST_FRESH_'+@tag;
DECLARE @stale nvarchar(256)=N'DHC_TEST_STALE_'+@tag;
DECLARE @disabled nvarchar(256)=N'DHC_TEST_DISABLED_'+@tag;
DECLARE @test TABLE
(
 Scenario varchar(32) NOT NULL,
 ServerInstance nvarchar(256) NOT NULL,
 ExpectedStatus varchar(16) NOT NULL,
 ExpectedOverdue bit NOT NULL
);
INSERT @test(Scenario,ServerInstance,ExpectedStatus,ExpectedOverdue)
VALUES
 ('NO_DATA_FRESH',@fresh,'NO_DATA',0),
 ('NO_DATA_OVERDUE',@stale,'NO_DATA',1),
 ('DISABLED',@disabled,'DISABLED',0);
BEGIN TRY
 BEGIN TRANSACTION;

 INSERT dhc.MonitoredServer
 (ServerInstance,DisplayName,Environment,MonitorGroup,IsEnabled,
  IntervalMinutes,CollectTempDB,CreatedUTC)
 VALUES
 (@fresh,N'Temporary fresh registration','LAB',N'DHC_TEST',1,60,0,SYSUTCDATETIME()),
 (@stale,N'Temporary overdue registration','LAB',N'DHC_TEST',1,60,0,DATEADD(HOUR,-3,SYSUTCDATETIME())),
 (@disabled,N'Temporary disabled registration','LAB',N'DHC_TEST',0,60,0,DATEADD(HOUR,-3,SYSUTCDATETIME()));

 DECLARE @result TABLE
 (
   Scenario varchar(32),
   ServerInstance nvarchar(256),
   ExpectedStatus varchar(16),
   ActualStatus varchar(16),
   ExpectedOverdue bit,
   ActualOverdue bit,
   MinutesSinceAttempt bigint,
   Verdict varchar(8)
 );
 INSERT @result
 SELECT t.Scenario,t.ServerInstance,
        t.ExpectedStatus,s.MonitoringStatus,
        t.ExpectedOverdue,s.IsOverdue,
        s.MinutesSinceAttempt,
        CASE WHEN t.ExpectedStatus=s.MonitoringStatus
                    AND t.ExpectedOverdue=s.IsOverdue
                    AND s.LastExecutionId IS NULL
             THEN 'PASS' ELSE 'FAILED' END
 FROM @test AS t
 LEFT JOIN dhc.vMonitoringStatus AS s
 ON s.ServerInstance=t.ServerInstance;

 SELECT Scenario,ExpectedStatus,ActualStatus,
        ExpectedOverdue,ActualOverdue,MinutesSinceAttempt,Verdict
 FROM @result ORDER BY Scenario;

 IF (SELECT COUNT(*) FROM @result)<>3
    OR EXISTS(SELECT 1 FROM @result WHERE Verdict<>'PASS')
    THROW 51030,'DHC monitoring status test failed. Transaction will be rolled back.',1;

 ROLLBACK TRANSACTION;
 SELECT 'PASS' AS TestResult,'All synthetic rows rolled back' AS Cleanup;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
-- Real inventory must still contain only real entries.
SELECT ServerId,ServerInstance,Environment,IsEnabled
FROM dhc.MonitoredServer
WHERE Environment='LAB'
ORDER BY ServerInstance;
GO
