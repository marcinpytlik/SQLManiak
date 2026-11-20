/*
 SQLManiak Index Maintenance v0.2 — optional historical measurements.
 Historical data are aggregate observations (not per-partition assessments).
 Never infer a rebuild solely from a drop in fragmentation.
*/
USE [SQLManiakIndexMaintenance];
GO
IF OBJECT_ID(N'im.IndexHistory',N'U') IS NULL
BEGIN
 CREATE TABLE im.IndexHistory
 (
  HistoryId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_im_IndexHistory PRIMARY KEY,
  SourceName nvarchar(128) NOT NULL,
  MeasuredAt datetime2(3) NOT NULL,
  ServerName nvarchar(256) NOT NULL,
  DatabaseName sysname NOT NULL,
  TableName nvarchar(256) NOT NULL,
  IndexName sysname NOT NULL,
  AvgFragmentationPct float NULL,
  TotalPageCount bigint NOT NULL,
  PartitionCount int NULL,
  ImportedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_im_IndexHistory_Imported DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT CK_im_IndexHistory_Pages CHECK(TotalPageCount>=0),
  CONSTRAINT CK_im_IndexHistory_Partitions CHECK(PartitionCount IS NULL OR PartitionCount>=0),
  CONSTRAINT CK_im_IndexHistory_Frag CHECK(AvgFragmentationPct IS NULL OR AvgFragmentationPct BETWEEN 0 AND 100)
 );
 CREATE INDEX IX_im_IndexHistory_Trend
 ON im.IndexHistory(ServerName,DatabaseName,TableName,IndexName,MeasuredAt)
 INCLUDE(AvgFragmentationPct,TotalPageCount,PartitionCount);
END;
GO
CREATE OR ALTER VIEW im.IndexHistoryDaily
AS
 WITH Daily AS
 (
  SELECT SourceName,ServerName,DatabaseName,TableName,IndexName,
    CONVERT(date,MeasuredAt) AS MeasurementDate,
    COUNT_BIG(*) AS SamplesInDay,
    AVG(AvgFragmentationPct) AS AvgFragmentationPct,
    MAX(TotalPageCount) AS MaxPageCount,
    MAX(PartitionCount) AS MaxPartitionCount
  FROM im.IndexHistory
  GROUP BY SourceName,ServerName,DatabaseName,TableName,IndexName,CONVERT(date,MeasuredAt)
 )
 SELECT SourceName,ServerName,DatabaseName,TableName,IndexName,MeasurementDate,
   SamplesInDay,AvgFragmentationPct,MaxPageCount,MaxPartitionCount,
   LAG(AvgFragmentationPct) OVER(
    PARTITION BY SourceName,ServerName,DatabaseName,TableName,IndexName
    ORDER BY MeasurementDate) AS PreviousFragmentationPct,
   LAG(MeasurementDate) OVER(
    PARTITION BY SourceName,ServerName,DatabaseName,TableName,IndexName
    ORDER BY MeasurementDate) AS PreviousMeasurementDate
 FROM Daily;
GO
/* Multiple measurements in one day are averaged: validate source granularity first.
   Changing table names, index names and schema ambiguity may invalidate trends. */
