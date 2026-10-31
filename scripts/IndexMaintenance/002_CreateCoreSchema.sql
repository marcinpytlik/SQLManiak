/* SQLManiak Index Maintenance — podstawowe obiekty ewidencyjne. */
USE [SQLManiakIndexMaintenance];
GO
IF SCHEMA_ID(N'im') IS NULL EXEC(N'CREATE SCHEMA [im] AUTHORIZATION [dbo];');
GO
IF OBJECT_ID(N'im.ManagedInstance', N'U') IS NULL
BEGIN
    CREATE TABLE im.ManagedInstance
    (
        InstanceId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ManagedInstance PRIMARY KEY,
        InstanceName nvarchar(256) NOT NULL CONSTRAINT UQ_ManagedInstance UNIQUE,
        IsEnabled bit NOT NULL CONSTRAINT DF_ManagedInstance_Enabled DEFAULT (0),
        CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_ManagedInstance_Created DEFAULT (SYSUTCDATETIME())
    );
END;
GO
IF OBJECT_ID(N'im.ManagedDatabase', N'U') IS NULL
BEGIN
    CREATE TABLE im.ManagedDatabase
    (
        DatabaseId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ManagedDatabase PRIMARY KEY,
        InstanceId bigint NOT NULL CONSTRAINT FK_ManagedDatabase_Instance REFERENCES im.ManagedInstance(InstanceId),
        DatabaseName sysname NOT NULL,
        IsEnabled bit NOT NULL CONSTRAINT DF_ManagedDatabase_Enabled DEFAULT (0),
        CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_ManagedDatabase_Created DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_ManagedDatabase_Name UNIQUE (InstanceId, DatabaseName)
    );
END;
GO
IF OBJECT_ID(N'im.AuditRun', N'U') IS NULL
BEGIN
    CREATE TABLE im.AuditRun
    (
        AuditRunId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditRun PRIMARY KEY,
        DatabaseId bigint NOT NULL CONSTRAINT FK_AuditRun_Database REFERENCES im.ManagedDatabase(DatabaseId),
        StartedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_AuditRun_Start DEFAULT (SYSUTCDATETIME()),
        CompletedAtUtc datetime2(3) NULL,
        Status varchar(16) NOT NULL CONSTRAINT DF_AuditRun_Status DEFAULT ('Pending'),
        ErrorMessage nvarchar(4000) NULL,
        CONSTRAINT CK_AuditRun_Status CHECK (Status IN ('Pending','Running','Completed','Failed','Cancelled')),
        CONSTRAINT CK_AuditRun_Time CHECK (CompletedAtUtc IS NULL OR CompletedAtUtc >= StartedAtUtc)
    );
    CREATE INDEX IX_AuditRun_DatabaseStarted ON im.AuditRun(DatabaseId, StartedAtUtc DESC);
END;
GO
