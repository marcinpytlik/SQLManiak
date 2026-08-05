USE [DBACentralRepository];
GO

IF OBJECT_ID(N'[job].[JobSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [job].[JobSnapshot]
    (
        JobSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_JobSnapshot PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        JobId uniqueidentifier NOT NULL,
        JobName sysname NOT NULL,
        CategoryName sysname NULL,
        OwnerName sysname NULL,
        Description nvarchar(512) NULL,
        IsEnabled bit NOT NULL,
        StartStepId int NULL,
        DateCreated datetime NULL,
        DateModified datetime NULL,
        NotifyLevelEmail int NULL,
        OperatorName sysname NULL,
        CONSTRAINT FK_JobSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_JobSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes]
    WHERE [object_id] = OBJECT_ID(N'[job].[JobSnapshot]')
      AND [name] = N'IX_JobSnapshot_Current'
)
BEGIN
    CREATE INDEX IX_JobSnapshot_Current ON [job].[JobSnapshot](InstanceId,JobId,CapturedAt DESC);
END;
GO

IF OBJECT_ID(N'[job].[JobStepSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [job].[JobStepSnapshot]
    (
        JobStepSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_JobStepSnapshot PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        JobId uniqueidentifier NOT NULL,
        JobName sysname NOT NULL,
        StepId int NOT NULL,
        StepName sysname NOT NULL,
        Subsystem nvarchar(40) NULL,
        DatabaseName sysname NULL,
        CommandText nvarchar(max) NULL,
        ProxyName sysname NULL,
        RetryAttempts int NULL,
        RetryInterval int NULL,
        OutputFileName nvarchar(4000) NULL,
        OnSuccessAction int NULL,
        OnSuccessStepId int NULL,
        OnFailAction int NULL,
        OnFailStepId int NULL,
        CONSTRAINT FK_JobStepSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_JobStepSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF OBJECT_ID(N'[job].[JobScheduleSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [job].[JobScheduleSnapshot]
    (
        JobScheduleSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_JobScheduleSnapshot PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        JobId uniqueidentifier NOT NULL,
        JobName sysname NOT NULL,
        ScheduleId int NOT NULL,
        ScheduleName sysname NOT NULL,
        IsEnabled bit NOT NULL,
        FreqType int NULL,
        FreqInterval int NULL,
        FreqSubdayType int NULL,
        FreqSubdayInterval int NULL,
        FreqRelativeInterval int NULL,
        FreqRecurrenceFactor int NULL,
        ActiveStartDate int NULL,
        ActiveEndDate int NULL,
        ActiveStartTime int NULL,
        ActiveEndTime int NULL,
        NextRunAt datetime NULL,
        CONSTRAINT FK_JobScheduleSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_JobScheduleSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF OBJECT_ID(N'[job].[JobExecution]', N'U') IS NULL
BEGIN
    CREATE TABLE [job].[JobExecution]
    (
        JobExecutionId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_JobExecution PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        JobId uniqueidentifier NOT NULL,
        JobName sysname NOT NULL,
        RunAt datetime NOT NULL,
        RunStatus int NOT NULL,
        RunStatusDescription nvarchar(30) NULL,
        DurationSeconds int NULL,
        DurationHHMMSS char(8) NULL,
        SqlMessageId int NULL,
        SqlSeverity int NULL,
        RetriesAttempted int NULL,
        MessageText nvarchar(max) NULL,
        CONSTRAINT UQ_JobExecution UNIQUE(InstanceId,JobId,RunAt),
        CONSTRAINT FK_JobExecution_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_JobExecution_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF OBJECT_ID(N'[job].[DatabaseJobReference]', N'U') IS NULL
BEGIN
    CREATE TABLE [job].[DatabaseJobReference]
    (
        DatabaseJobReferenceId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DatabaseJobReference PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        JobId uniqueidentifier NOT NULL,
        JobName sysname NOT NULL,
        StepId int NOT NULL,
        DatabaseName sysname NOT NULL,
        ReferenceType varchar(30) NOT NULL,
        ConfidenceLevel varchar(20) NOT NULL,
        CONSTRAINT FK_DatabaseJobReference_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_DatabaseJobReference_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF OBJECT_ID(N'[job].[OperatorSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [job].[OperatorSnapshot]
    (
        OperatorSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_OperatorSnapshot PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        OperatorId int NOT NULL,
        OperatorName sysname NOT NULL,
        IsEnabled bit NOT NULL,
        EmailAddress nvarchar(512) NULL,
        PagerAddress nvarchar(512) NULL,
        NetsendAddress nvarchar(512) NULL,
        WeekdayPagerStartTime int NULL,
        WeekdayPagerEndTime int NULL,
        SaturdayPagerStartTime int NULL,
        SaturdayPagerEndTime int NULL,
        SundayPagerStartTime int NULL,
        SundayPagerEndTime int NULL,
        PagerDays int NULL,
        CONSTRAINT FK_OperatorSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_OperatorSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF OBJECT_ID(N'[db].[DatabaseSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [db].[DatabaseSnapshot]
    (
        DatabaseSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DatabaseSnapshot PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        DatabaseId int NOT NULL,
        DatabaseName sysname NOT NULL,
        StateDesc nvarchar(60) NULL,
        UserAccessDesc nvarchar(60) NULL,
        RecoveryModelDesc nvarchar(60) NULL,
        CompatibilityLevel tinyint NULL,
        CollationName sysname NULL,
        OwnerName sysname NULL,
        CreateDate datetime NULL,
        PageVerifyOptionDesc nvarchar(60) NULL,
        IsAutoCloseOn bit NULL,
        IsAutoShrinkOn bit NULL,
        IsAutoCreateStatsOn bit NULL,
        IsAutoUpdateStatsOn bit NULL,
        IsAutoUpdateStatsAsyncOn bit NULL,
        IsReadCommittedSnapshotOn bit NULL,
        SnapshotIsolationStateDesc nvarchar(60) NULL,
        IsTrustworthyOn bit NULL,
        IsDbChainingOn bit NULL,
        TargetRecoveryTimeSeconds int NULL,
        IsQueryStoreOn bit NULL,
        IsEncrypted bit NULL,
        DataSizeMB decimal(19,2) NULL,
        LogSizeMB decimal(19,2) NULL,
        TotalSizeMB decimal(19,2) NULL,
        CONSTRAINT FK_DatabaseSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_DatabaseSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes]
    WHERE [object_id] = OBJECT_ID(N'[db].[DatabaseSnapshot]')
      AND [name] = N'IX_DatabaseSnapshot_Current'
)
BEGIN
    CREATE INDEX IX_DatabaseSnapshot_Current ON [db].[DatabaseSnapshot](InstanceId,DatabaseName,CapturedAt DESC);
END;
GO

IF OBJECT_ID(N'[db].[DatabaseFileSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [db].[DatabaseFileSnapshot]
    (
        DatabaseFileSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DatabaseFileSnapshot PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        DatabaseName sysname NOT NULL,
        FileId int NOT NULL,
        LogicalName sysname NOT NULL,
        FileTypeDesc nvarchar(60) NULL,
        FilegroupName sysname NULL,
        PhysicalName nvarchar(4000) NULL,
        SizeMB decimal(19,2) NULL,
        GrowthValue bigint NULL,
        GrowthUnit varchar(20) NULL,
        MaxSizeMB decimal(19,2) NULL,
        IsPercentGrowth bit NULL,
        IsReadOnly bit NULL,
        IsSparse bit NULL,
        CONSTRAINT FK_DatabaseFileSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_DatabaseFileSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF OBJECT_ID(N'[db].[LargestTableSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [db].[LargestTableSnapshot]
    (
        LargestTableSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_LargestTableSnapshot PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        DatabaseName sysname NOT NULL,
        SchemaName sysname NOT NULL,
        TableName sysname NOT NULL,
        [RowCount] bigint NULL,
        ReservedMB decimal(19,2) NULL,
        DataMB decimal(19,2) NULL,
        IndexMB decimal(19,2) NULL,
        CONSTRAINT FK_LargestTableSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_LargestTableSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO
