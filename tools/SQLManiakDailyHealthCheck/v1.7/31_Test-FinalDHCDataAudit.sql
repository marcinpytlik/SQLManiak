/* SQLManiak DHC v1.7 - Test 38: read-only cross-host integrity audit.
 Execute on 127.0.0.1,15433 (SQLManiakHealthHistory). No DHC run and no UPDATE.
 Explicit RunIds are successful Test 36 / Test 37 collection runs.
 Different hosts may legitimately report different section and row counts.
*/
USE SQLManiakHealthHistory;
GO
SET NOCOUNT ON;
DECLARE @T table(TargetLabel varchar(12) PRIMARY KEY,ServerInstance nvarchar(256),RunId uniqueidentifier);
INSERT @T VALUES
('Target 1',N'127.0.0.1,15434','ec7e29a0-dffd-4702-9e4d-ac3705c61d9b'),
('Target 2',N'127.0.0.1,15435','c8ad74a0-d721-4124-878e-75dee31baa15');

IF (SELECT COUNT(*) FROM @T t JOIN dhc.Run r ON r.RunId=t.RunId
 WHERE r.ServerInstance=t.ServerInstance AND r.Status='COMPLETE')<>2
 THROW 51380,'Expected the two exact COMPLETE LAB RunIds; cannot audit another pair.',1;

PRINT '01 | RUN SUMMARY AND PERSISTED DATA';
SELECT t.TargetLabel,t.ServerInstance,r.RunId,r.Status,r.CollectorVersion,
 r.StartedUTC,r.FinishedUTC,DATEDIFF_BIG(MILLISECOND,r.StartedUTC,r.FinishedUTC) AS DurationMs,
 r.SourceResultSets,r.SourceRowCount,r.ErrorText,
 (SELECT COUNT_BIG(*) FROM dhc.ResultBatch b WHERE b.RunId=t.RunId) AS PersistedBatches,
 (SELECT SUM(CONVERT(bigint,b.RowCount)) FROM dhc.ResultBatch b WHERE b.RunId=t.RunId) AS PersistedBatchRows,
 (SELECT COUNT(DISTINCT b.ResultIndex) FROM dhc.ResultBatch b WHERE b.RunId=t.RunId) AS DistinctResultIndexes,
 (SELECT COUNT_BIG(*) FROM dhc.Alert a WHERE a.RunId=t.RunId) AS Alerts,
 (SELECT COUNT_BIG(*) FROM dhc.TempDBSnapshot x WHERE x.RunId=t.RunId) AS TempDBSnapshots
FROM @T t JOIN dhc.Run r ON r.RunId=t.RunId ORDER BY t.TargetLabel;

PRINT '02 | EXACT EXECUTIONLOG LINKAGE';
SELECT t.TargetLabel,e.ExecutionId,e.ServerInstance,e.Status AS ExecutionStatus,
 e.StartedUTC,e.FinishedUTC,e.RunId,e.RowsStored,e.ErrorText
FROM @T t LEFT JOIN dhc.ExecutionLog e ON e.RunId=t.RunId
 AND e.ServerInstance=t.ServerInstance
ORDER BY t.TargetLabel,e.StartedUTC DESC;

PRINT '03 | SECTION COVERAGE BY NAME (missing != automatically failed)';
;WITH S AS (
 SELECT t.TargetLabel,b.SectionName,COUNT_BIG(*) AS Batches,
 COUNT(DISTINCT b.ResultIndex) AS ResultIndexes,SUM(CONVERT(bigint,b.RowCount)) AS StoredRows
 FROM @T t JOIN dhc.ResultBatch b ON b.RunId=t.RunId
 GROUP BY t.TargetLabel,b.SectionName
)
SELECT COALESCE(x.SectionName,y.SectionName) AS SectionName,
 ISNULL(x.Batches,0) AS T1Batches,ISNULL(y.Batches,0) AS T2Batches,
 ISNULL(x.ResultIndexes,0) AS T1Indexes,ISNULL(y.ResultIndexes,0) AS T2Indexes,
 ISNULL(x.StoredRows,0) AS T1Rows,ISNULL(y.StoredRows,0) AS T2Rows,
 CASE WHEN x.SectionName IS NULL THEN 'ONLY_TARGET_2'
      WHEN y.SectionName IS NULL THEN 'ONLY_TARGET_1'
      ELSE 'BOTH' END AS Coverage
FROM (SELECT * FROM S WHERE TargetLabel='Target 1') x
FULL JOIN (SELECT * FROM S WHERE TargetLabel='Target 2') y ON y.SectionName=x.SectionName
ORDER BY Coverage,SectionName;

PRINT '04 | CORE ASSERTIONS (PASS vs REVIEW)';
SELECT t.TargetLabel,t.RunId,
 CASE WHEN r.FinishedUTC>=r.StartedUTC AND r.ErrorText IS NULL THEN 'PASS' ELSE 'REVIEW' END AS TopLevelComplete,
 CASE WHEN EXISTS(SELECT 1 FROM dhc.ResultBatch b WHERE b.RunId=t.RunId) THEN 'PASS' ELSE 'REVIEW' END AS HasBatches,
 CASE WHEN EXISTS(SELECT 1 FROM dhc.ExecutionLog e WHERE e.RunId=t.RunId
       AND e.ServerInstance=t.ServerInstance AND e.Status='COMPLETE' AND e.ErrorText IS NULL)
       THEN 'PASS' ELSE 'REVIEW' END AS LinkedExecution,
 CASE WHEN NOT EXISTS(SELECT 1 FROM dhc.ResultBatch b WHERE b.RunId=t.RunId AND
       (b.RowCount<0 OR ISJSON(b.RowsJson)<>1 OR ISJSON(b.ColumnNamesJson)<>1))
       THEN 'PASS' ELSE 'REVIEW' END AS BatchPayloadValidity,
 CASE WHEN EXISTS(SELECT 1 FROM dhc.TempDBSnapshot s WHERE s.RunId=t.RunId)
       THEN 'PASS' ELSE 'REVIEW' END AS HasTempDBSnapshot,
 CASE WHEN NOT EXISTS(SELECT 1 FROM dhc.Alert a WHERE a.RunId=t.RunId AND
       (a.Details LIKE N'%permission%denied%' OR a.Details LIKE N'%permission%required%'
        OR a.Details LIKE N'%EXECUTE permission%' OR a.Details LIKE N'%SELECT permission%'
        OR a.Details LIKE N'%VIEW SERVER%' OR a.Details LIKE N'%not authorized%'
        OR a.Details LIKE N'%brak uprawnie%'))
       THEN 'PASS' ELSE 'REVIEW' END AS NoRecognizedPermissionErrors
FROM @T t JOIN dhc.Run r ON r.RunId=t.RunId ORDER BY t.TargetLabel;

PRINT '05 | ALERTS BY SEVERITY / AREA';
SELECT t.TargetLabel,a.Severity,a.Area,COUNT_BIG(*) AS Alerts
FROM @T t JOIN dhc.Alert a ON a.RunId=t.RunId
GROUP BY t.TargetLabel,a.Severity,a.Area
ORDER BY t.TargetLabel,a.Severity,a.Area;

PRINT '06 | ALL ALERT DETAILS';
SELECT t.TargetLabel,a.AlertId,a.Severity,a.Area,a.ObjectName,a.Details
FROM @T t JOIN dhc.Alert a ON a.RunId=t.RunId
ORDER BY t.TargetLabel,a.AlertId;

PRINT '07 | TEMPDB PERSISTED DETAIL';
SELECT t.TargetLabel,
 (SELECT COUNT_BIG(*) FROM dhc.TempDBSnapshot s WHERE s.RunId=t.RunId) AS Snapshots,
 (SELECT COUNT_BIG(*) FROM dhc.TempDBFile f WHERE f.RunId=t.RunId) AS Files,
 (SELECT COUNT_BIG(*) FROM dhc.TempDBSession s WHERE s.RunId=t.RunId) AS Sessions,
 (SELECT TOP(1) s.TotalDataMB FROM dhc.TempDBSnapshot s WHERE s.RunId=t.RunId) AS TotalDataMB,
 (SELECT TOP(1) s.VersionStoreMB FROM dhc.TempDBSnapshot s WHERE s.RunId=t.RunId) AS VersionStoreMB
FROM @T t ORDER BY t.TargetLabel;

PRINT '08 | MONITORED SERVER CONFIGURATION / CURRENT STATUS';
SELECT t.TargetLabel,s.ServerInstance,s.Environment,s.MonitorGroup,
 s.IsEnabled,s.IntervalMinutes,s.CollectTempDB,
 CASE WHEN s.IsEnabled=1 AND s.Environment='LAB'
       AND s.IntervalMinutes=1440 AND s.CollectTempDB=1 THEN 'PASS'
       ELSE 'REVIEW' END AS BaselineConfig,
 v.MonitoringStatus,v.IsOverdue,v.LastAttemptUTC,v.LastCompleteUTC,v.LastRunId,v.LastErrorText
FROM @T t LEFT JOIN dhc.MonitoredServer s ON s.ServerInstance=t.ServerInstance
LEFT JOIN dhc.vMonitoringStatus v ON v.ServerInstance=t.ServerInstance
ORDER BY t.TargetLabel;

PRINT '09 | INTERPRETATION NOTES';
SELECT N'The two RunIds are fixed Test 36 and Test 37 runs. No new collection is executed.' AS Note
UNION ALL SELECT N'Host differences in sections and rows are evidence to review, not automatic failures.'
UNION ALL SELECT N'Permission pattern matching is heuristic. Review all alert details.'
UNION ALL SELECT N'SourceResultSets and persisted batch count are different concepts; do not assert equality.'
UNION ALL SELECT N'Test checks persisted structure; it does not prove each diagnostic section is semantically correct.';
GO
