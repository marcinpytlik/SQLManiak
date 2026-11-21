USE [DBACentralRepositoryv4];
GO
/*
 v4.2 retention planning: REPORT ONLY, no deletes.
 Includes dependent child rows and rough storage impact estimates.
 Example: EXEC inventory.usp_RetentionPreview @KeepDays=90;
*/
CREATE OR ALTER PROCEDURE inventory.usp_RetentionPreview
 @KeepDays int=90
AS
BEGIN
 SET NOCOUNT ON;
 IF @KeepDays<1 OR @KeepDays>3650 THROW 54120,'KeepDays must be 1..3650.',1;
 DECLARE @Cutoff datetime2(0)=DATEADD(DAY,-@KeepDays,SYSUTCDATETIME());
 ;WITH Expired AS(
   SELECT ScanRunId,InstanceId,ScanStatus FROM inventory.ScanRun
   WHERE StartedUtc<@Cutoff AND ScanStatus<>'RUNNING'
 )
 SELECT @Cutoff AS CutoffUtc,
  COUNT_BIG(*) AS CandidateScanRuns,
  (SELECT COUNT_BIG(*) FROM inventory.InventorySnapshot s JOIN Expired e ON s.ScanRunId=e.ScanRunId) AS CandidateSnapshots,
  (SELECT COUNT_BIG(*) FROM inventory.ScanCategory c JOIN Expired e ON c.ScanRunId=e.ScanRunId) AS CandidateCategories,
  (SELECT COUNT_BIG(*) FROM inventory.ScanFinding f JOIN Expired e ON f.ScanRunId=e.ScanRunId) AS CandidateFindings,
  (SELECT COUNT_BIG(*) FROM inventory.ChangeEvent c JOIN Expired e ON c.ScanRunId=e.ScanRunId OR c.PreviousScanRunId=e.ScanRunId) AS CandidateChangeEvents
 FROM Expired;
 SELECT TOP(100) s.ScanRunId,i.ServerInstance,s.StartedUtc,s.ScanStatus
 FROM inventory.ScanRun s
 JOIN inventory.Instance i ON i.InstanceId=s.InstanceId
 WHERE s.StartedUtc<@Cutoff AND s.ScanStatus<>'RUNNING'
 ORDER BY s.StartedUtc,s.ScanRunId;
END;
GO
