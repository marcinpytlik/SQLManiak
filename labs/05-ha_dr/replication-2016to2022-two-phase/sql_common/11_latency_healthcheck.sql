/*
  Healthcheck replikacji: tracer token latency logger.
  Tworzy msdb.dbo.ReplLatencyLog i procedurę msdb.dbo.usp_ReplLatency_Probe.
*/
USE msdb;
IF OBJECT_ID('dbo.ReplLatencyLog','U') IS NULL
BEGIN
  CREATE TABLE dbo.ReplLatencyLog(
    id int IDENTITY(1,1) PRIMARY KEY,
    log_time datetime2(0) NOT NULL CONSTRAINT DF_ReplLatencyLog_logtime DEFAULT (sysdatetime()),
    publication sysname NOT NULL,
    overall_latency_ms int NULL,
    status_desc nvarchar(60) NULL
  );
END
GO
USE msdb;
IF OBJECT_ID('dbo.usp_ReplLatency_Probe','P') IS NOT NULL DROP PROCEDURE dbo.usp_ReplLatency_Probe;
GO
CREATE PROCEDURE dbo.usp_ReplLatency_Probe @publication sysname AS
BEGIN
  SET NOCOUNT ON;
  EXEC sp_posttracertoken @publication=@publication;
  WAITFOR DELAY '00:00:02';
  DECLARE @t TABLE(overall_latency int);
  INSERT INTO @t EXEC sp_helptracertokenhistory @publication=@publication;
  INSERT INTO msdb.dbo.ReplLatencyLog(publication, overall_latency_ms, status_desc)
  SELECT TOP 1 @publication, overall_latency, CASE WHEN overall_latency IS NULL THEN 'In-Transit' ELSE 'Arrived' END FROM @t;
END
GO
