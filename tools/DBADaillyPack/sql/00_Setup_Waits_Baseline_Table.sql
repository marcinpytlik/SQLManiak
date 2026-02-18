/* Creates table for wait stats baseline snapshots (idempotent). */
USE master;
GO
IF OBJECT_ID('dbo.WaitStatsBaseline','U') IS NULL
BEGIN
    CREATE TABLE dbo.WaitStatsBaseline
    (
        BaselineId      bigint IDENTITY(1,1) PRIMARY KEY,
        CapturedAtUtc   datetime2(0) NOT NULL CONSTRAINT DF_WaitStatsBaseline_CapturedAt DEFAULT (SYSUTCDATETIME()),
        CapturedBy      sysname      NOT NULL CONSTRAINT DF_WaitStatsBaseline_CapturedBy DEFAULT (ORIGINAL_LOGIN()),
        WaitType        nvarchar(120) NOT NULL,
        WaitingTasksCount bigint NOT NULL,
        WaitTimeMs      bigint NOT NULL,
        SignalWaitTimeMs bigint NOT NULL
    );

    CREATE INDEX IX_WaitStatsBaseline_CapturedAt ON dbo.WaitStatsBaseline(CapturedAtUtc);
    CREATE INDEX IX_WaitStatsBaseline_WaitType ON dbo.WaitStatsBaseline(WaitType);
END
GO
