USE SQLManiakHealthHistory;
GO
-- History reuses dhc.ResultBatch; no duplicate storage or new retention dependencies.
CREATE OR ALTER VIEW dhc.vLinkedServerHistory AS
SELECT r.RunId,r.ServerInstance,r.StartedUTC,r.Status AS RunStatus,b.SectionName,b.BatchNo,
 j.[key] AS RowOrdinal,j.value AS SampleJson
FROM dhc.Run r JOIN dhc.ResultBatch b ON b.RunId=r.RunId
CROSS APPLY OPENJSON(b.RowsJson) j
WHERE b.SectionName IN ('LINKED_SERVER_CONFIGURATION','LINKED_SERVER_LOGIN_MAPPING','LINKED_SERVER_METADATA_STATUS','LINKED_SERVER_CONNECTIVITY','LINKED_SERVER_AUTH_EVENTS');
GO
CREATE OR ALTER VIEW dhc.vLinkedServerProbe AS
SELECT RunId,ServerInstance,StartedUTC,RunStatus,
 JSON_VALUE(SampleJson,'$.LinkedServer') AS LinkedServer,
 JSON_VALUE(SampleJson,'$.ProbeStatus') AS ProbeStatus,
 TRY_CONVERT(bigint,JSON_VALUE(SampleJson,'$.DurationMs')) AS DurationMs,
 JSON_VALUE(SampleJson,'$.CollectorLogin') AS CollectorLogin,
 JSON_VALUE(SampleJson,'$.RemoteLogin') AS RemoteLogin,
 JSON_VALUE(SampleJson,'$.RemoteAuthScheme') AS RemoteAuthScheme,
 TRY_CONVERT(int,JSON_VALUE(SampleJson,'$.ErrorNumber')) AS ErrorNumber,
 JSON_VALUE(SampleJson,'$.Details') AS Details
FROM dhc.vLinkedServerHistory WHERE SectionName='LINKED_SERVER_CONNECTIVITY';
GO

-- Observed transitions only; skipped probes break continuity.
CREATE OR ALTER VIEW dhc.vLinkedServerStateChanges AS
WITH samples AS (
 SELECT *,LAG(ProbeStatus) OVER(PARTITION BY ServerInstance,LinkedServer,CollectorLogin ORDER BY StartedUTC,RunId) AS PreviousStatus,
 LAG(StartedUTC) OVER(PARTITION BY ServerInstance,LinkedServer,CollectorLogin ORDER BY StartedUTC,RunId) AS PreviousSampleUTC
 FROM dhc.vLinkedServerProbe
)
SELECT *,CASE WHEN ProbeStatus='SKIPPED' THEN 'SKIPPED'
 WHEN PreviousStatus='PASS' AND ProbeStatus='FAILED' THEN 'OUTAGE'
 WHEN PreviousStatus='FAILED' AND ProbeStatus='FAILED' THEN 'ONGOING OUTAGE'
 WHEN PreviousStatus='FAILED' AND ProbeStatus='PASS' THEN 'RECOVERY'
 WHEN PreviousStatus='PASS' AND ProbeStatus='PASS' THEN 'HEALTHY'
 ELSE 'INITIAL / UNKNOWN' END AS StateChange
FROM samples;
GO
