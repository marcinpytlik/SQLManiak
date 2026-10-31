/* SQLManiak Index Maintenance — audit model, SQL Server 2022+ */
USE [SQLManiakIndexMaintenance];
GO
IF OBJECT_ID(N'im.IndexAssessment',N'U') IS NULL
BEGIN
 CREATE TABLE im.IndexAssessment
 (
  AssessmentId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_IndexAssessment PRIMARY KEY,
  AuditRunId bigint NOT NULL CONSTRAINT FK_IndexAssessment_Run REFERENCES im.AuditRun(AuditRunId),
  ObjectId int NOT NULL,
  IndexId int NOT NULL,
  PartitionNumber int NOT NULL,
  SchemaName sysname NOT NULL,
  TableName sysname NOT NULL,
  IndexName sysname NOT NULL,
  IndexType tinyint NOT NULL,
  PageCount bigint NOT NULL,
  FragmentationPercent float NULL,
  PageDensityPercent float NULL,
  MeasurementMode varchar(10) NOT NULL,
  Classification varchar(32) NOT NULL,
  Priority tinyint NOT NULL,
  Reason nvarchar(500) NOT NULL,
  CapturedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_IndexAssessment_At DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT UQ_IndexAssessment_RunPartition UNIQUE (AuditRunId,ObjectId,IndexId,PartitionNumber),
  CONSTRAINT CK_IndexAssessment_Mode CHECK (MeasurementMode IN ('LIMITED','SAMPLED')),
  CONSTRAINT CK_IndexAssessment_Class CHECK (Classification IN
   ('NO_ACTION','REVIEW','REORGANIZE_CANDIDATE','REBUILD_CANDIDATE'))
 );
 CREATE INDEX IX_IndexAssessment_Class ON im.IndexAssessment(AuditRunId,Priority,Classification)
 INCLUDE (PageCount,FragmentationPercent,PageDensityPercent);
END;
GO
