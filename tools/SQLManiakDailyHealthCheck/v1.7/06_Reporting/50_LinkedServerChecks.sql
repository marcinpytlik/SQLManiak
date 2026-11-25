USE SQLManiakHealthHistory;
-- Read-only verification; empty inventory is valid.
SELECT TOP(100) r.ServerInstance,r.StartedUTC,b.SectionName,b.RowCount,b.ResultIndex
FROM dhc.Run r JOIN dhc.ResultBatch b ON b.RunId=r.RunId
WHERE b.SectionName LIKE 'LINKED[_]SERVER[_]%' ORDER BY r.StartedUTC DESC,b.ResultIndex;
SELECT TOP(100) * FROM dhc.vLinkedServerProbe ORDER BY StartedUTC DESC;
SELECT TOP(100) * FROM dhc.vLinkedServerHistory ORDER BY StartedUTC DESC;
