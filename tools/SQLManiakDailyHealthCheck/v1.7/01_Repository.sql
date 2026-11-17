/* SQLManiak DHC v1.7 - central repository, SQL Server 2022+
   Execute ON THE REPOSITORY INSTANCE, with a deployment administrator.
   Creates SQLManiakHealthHistory if missing; additive/idempotent schema.
   No agent jobs or source-instance changes.
*/
USE master;
GO
IF DB_ID(N'SQLManiakHealthHistory') IS NULL CREATE DATABASE SQLManiakHealthHistory;
GO
USE SQLManiakHealthHistory;
GO
IF SCHEMA_ID(N'dhc') IS NULL EXEC(N'CREATE SCHEMA dhc AUTHORIZATION dbo');
GO
IF OBJECT_ID(N'dhc.Run',N'U') IS NULL
CREATE TABLE dhc.Run
(
 RunId uniqueidentifier NOT NULL CONSTRAINT PK_DHCRun PRIMARY KEY,
 ServerInstance nvarchar(256) NOT NULL,
 StartedUTC datetime2(3) NOT NULL CONSTRAINT DF_DHCRun_StartedUTC DEFAULT (SYSUTCDATETIME()),
 FinishedUTC datetime2(3) NULL,
 Status varchar(16) NOT NULL CONSTRAINT CK_DHCRun_Status CHECK (Status IN ('RUNNING','COMPLETE','PARTIAL','FAILED')),
 SourceResultSets int NULL,
 SourceRowCount bigint NULL,
 ErrorText nvarchar(2000) NULL,
 CollectorVersion varchar(16) NOT NULL CONSTRAINT DF_DHCCollectorVersion DEFAULT ('1.7')
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dhc.Run') AND name=N'IX_DHCRun_ServerDate')
 CREATE INDEX IX_DHCRun_ServerDate ON dhc.Run(ServerInstance,StartedUTC DESC) INCLUDE(Status,FinishedUTC);
GO
IF OBJECT_ID(N'dhc.ResultBatch',N'U') IS NULL
CREATE TABLE dhc.ResultBatch
(
 RunId uniqueidentifier NOT NULL,
 ResultIndex int NOT NULL,
 BatchNo int NOT NULL,
 SectionName nvarchar(128) NOT NULL,
 [RowCount] int NOT NULL,
 ColumnNamesJson nvarchar(max) NOT NULL,
 RowsJson nvarchar(max) NOT NULL,
 CONSTRAINT PK_DHCResultBatch PRIMARY KEY(RunId,ResultIndex,BatchNo),
 CONSTRAINT FK_DHCResultBatch_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId),
 CONSTRAINT CK_DHCResultBatch_RowsJson CHECK (ISJSON(RowsJson)=1),
 CONSTRAINT CK_DHCResultBatch_ColsJson CHECK (ISJSON(ColumnNamesJson)=1)
);
GO
IF OBJECT_ID(N'dhc.Alert',N'U') IS NULL
CREATE TABLE dhc.Alert
(
 AlertId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DHCAlert PRIMARY KEY,
 RunId uniqueidentifier NOT NULL,
 Severity varchar(8) NOT NULL,
 Area nvarchar(64) NOT NULL,
 ObjectName nvarchar(256) NULL,
 Details nvarchar(2000) NOT NULL,
 CONSTRAINT FK_DHCAlert_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dhc.Alert') AND name=N'IX_DHCAlert_Run')
 CREATE INDEX IX_DHCAlert_Run ON dhc.Alert(RunId,Severity);
GO
IF OBJECT_ID(N'dhc.TempDBSnapshot',N'U') IS NULL
CREATE TABLE dhc.TempDBSnapshot
(
 RunId uniqueidentifier NOT NULL CONSTRAINT PK_DHCTempDBSnapshot PRIMARY KEY,
 SampleUTC datetime2(3) NOT NULL,
 TotalDataMB decimal(19,2) NULL,
 UsedDataMB decimal(19,2) NULL,
 FreeDataMB decimal(19,2) NULL,
 DataFreePct decimal(9,2) NULL,
 UserObjectsMB decimal(19,2) NULL,
 InternalObjectsMB decimal(19,2) NULL,
 VersionStoreMB decimal(19,2) NULL,
 VersionStoreShareUsedPct decimal(9,2) NULL,
 TotalLogMB decimal(19,2) NULL,
 UsedLogMB decimal(19,2) NULL,
 LogFreePct decimal(9,2) NULL,
 MinDriveFreePct decimal(9,2) NULL,
 AnyFileCannotGrow bit NULL,
 PercentGrowthFileCount int NULL,
 DataFileCount int NULL,
 LogFileCount int NULL,
 ActiveVersioningTransactions bigint NULL,
 OldestVersioningSeconds bigint NULL,
 TempDBLogReuseWait nvarchar(60) NULL,
 CONSTRAINT FK_DHCTempDBSnapshot_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId)
);
GO
IF OBJECT_ID(N'dhc.TempDBFile',N'U') IS NULL
CREATE TABLE dhc.TempDBFile
(
 RunId uniqueidentifier NOT NULL,
 FileId int NOT NULL,
 FileType nvarchar(12) NULL,
 FileName sysname NULL,
 VolumeMountPoint nvarchar(512) NULL,
 SizeMB decimal(19,2) NULL,
 MaxSizeMB decimal(19,2) NULL,
 GrowthMB decimal(19,2) NULL,
 IsPercentGrowth bit NULL,
 NextGrowthMB decimal(19,2) NULL,
 NextGrowthWillFit bit NULL,
 AvailableVolumeMB decimal(19,2) NULL,
 JsonRow nvarchar(max) NOT NULL,
 CONSTRAINT PK_DHCTempDBFile PRIMARY KEY(RunId,FileId),
 CONSTRAINT FK_DHCTempDBFile_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId)
);
GO
IF OBJECT_ID(N'dhc.TempDBSession',N'U') IS NULL
CREATE TABLE dhc.TempDBSession
(
 RunId uniqueidentifier NOT NULL,
 SessionId smallint NOT NULL,
 RequestId int NOT NULL CONSTRAINT DF_DHCTempDBRequestId DEFAULT(-1),
 LoginName nvarchar(128) NULL,
 SessionAttributedMB decimal(19,2) NULL,
 VersioningSeconds bigint NULL,
 JsonRow nvarchar(max) NOT NULL,
 CONSTRAINT PK_DHCTempDBSession PRIMARY KEY(RunId,SessionId,RequestId),
 CONSTRAINT FK_DHCTempDBSession_Run FOREIGN KEY(RunId) REFERENCES dhc.Run(RunId)
);
GO
CREATE OR ALTER VIEW dhc.vTempDBTrend
AS
SELECT r.ServerInstance,r.StartedUTC,r.Status, t.*
FROM dhc.Run AS r JOIN dhc.TempDBSnapshot AS t ON r.RunId=t.RunId;
GO
CREATE OR ALTER VIEW dhc.vDailyAlerts
AS
SELECT CONVERT(date,r.StartedUTC) AS DayUTC,r.StartedUTC,r.ServerInstance,
       a.Severity,a.Area,a.ObjectName,a.Details
FROM dhc.Run AS r JOIN dhc.Alert AS a ON r.RunId=a.RunId;
GO
/* Optional retention: review before executing! Does not auto-delete. */
CREATE OR ALTER PROCEDURE dhc.PurgeRuns @OlderThanUTC datetime2(3), @DryRun bit=1
AS
BEGIN
 SET NOCOUNT ON;
 IF @DryRun=1
 BEGIN
  SELECT COUNT_BIG(*) AS RunsToDelete FROM dhc.Run WHERE StartedUTC<@OlderThanUTC;
  RETURN;
 END;
 BEGIN TRAN;
 DELETE t FROM dhc.TempDBSession t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE t FROM dhc.TempDBFile t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE t FROM dhc.TempDBSnapshot t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE t FROM dhc.Alert t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE t FROM dhc.ResultBatch t JOIN dhc.Run r ON t.RunId=r.RunId WHERE r.StartedUTC<@OlderThanUTC;
 DELETE FROM dhc.Run WHERE StartedUTC<@OlderThanUTC;
 COMMIT;
END;
GO
