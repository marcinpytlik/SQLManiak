USE [msdb];
GO

IF OBJECT_ID(N'dbo.DBA_BackupDatabaseConfig', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DBA_BackupDatabaseConfig
    (
        DatabaseName   sysname        NOT NULL CONSTRAINT PK_DBA_BackupDatabaseConfig PRIMARY KEY,
        BackupBasePath nvarchar(4000) NOT NULL,
        IsEnabled      bit            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_IsEnabled DEFAULT (1),
        BackupFull     bit            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_BackupFull DEFAULT (1),
        BackupDiff     bit            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_BackupDiff DEFAULT (1),
        BackupLog      bit            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_BackupLog DEFAULT (1),
        Priority       int            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_Priority DEFAULT (100),
        Notes          nvarchar(1000) NULL,
        CreatedAt      datetime2(0)   NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_CreatedAt DEFAULT (SYSDATETIME()),
        UpdatedAt      datetime2(0)   NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_UpdatedAt DEFAULT (SYSDATETIME()),
        CONSTRAINT CK_DBA_BackupDatabaseConfig_BackupBasePath_NotEmpty CHECK (LEN(LTRIM(RTRIM(BackupBasePath))) > 0)
    );
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_DBA_BackupDatabaseConfig_SetUpdatedAt
ON dbo.DBA_BackupDatabaseConfig
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE c
        SET UpdatedAt = SYSDATETIME()
    FROM dbo.DBA_BackupDatabaseConfig AS c
    INNER JOIN inserted AS i
        ON i.DatabaseName = c.DatabaseName;
END;
GO

IF OBJECT_ID(N'dbo.DBA_BackupExecutionLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DBA_BackupExecutionLog
    (
        LogId          bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DBA_BackupExecutionLog PRIMARY KEY,
        ExecutionId    uniqueidentifier     NOT NULL,
        DatabaseName   sysname              NOT NULL,
        BackupType     varchar(10)          NOT NULL,
        BackupBasePath nvarchar(4000)       NULL,
        BackupFile     nvarchar(4000)       NULL,
        StartedAt      datetime2(0)         NOT NULL CONSTRAINT DF_DBA_BackupExecutionLog_StartedAt DEFAULT (SYSDATETIME()),
        FinishedAt     datetime2(0)         NULL,
        Status         varchar(20)          NOT NULL CONSTRAINT DF_DBA_BackupExecutionLog_Status DEFAULT ('STARTED'),
        Message        nvarchar(4000)       NULL
    );

    CREATE INDEX IX_DBA_BackupExecutionLog_ExecutionId
        ON dbo.DBA_BackupExecutionLog(ExecutionId, LogId);

    CREATE INDEX IX_DBA_BackupExecutionLog_DatabaseName_StartedAt
        ON dbo.DBA_BackupExecutionLog(DatabaseName, StartedAt DESC);
END;
GO
