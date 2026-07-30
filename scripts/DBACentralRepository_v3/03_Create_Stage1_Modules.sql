USE DBACentralRepository;
GO

CREATE TABLE backup.BackupHistory
(
    BackupHistoryId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_BackupHistory PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    DatabaseName sysname NOT NULL,
    BackupSetId int NOT NULL,
    BackupType char(1) NOT NULL,
    BackupTypeDescription nvarchar(30) NULL,
    IsCopyOnly bit NOT NULL,
    BackupStartDate datetime NOT NULL,
    BackupFinishDate datetime NOT NULL,
    DurationSeconds int NULL,
    BackupSizeMB decimal(19,2) NULL,
    CompressedBackupSizeMB decimal(19,2) NULL,
    CompressionRatio decimal(19,4) NULL,
    HasBackupChecksums bit NULL,
    IsDamaged bit NULL,
    RecoveryModel nvarchar(60) NULL,
    FirstLsn numeric(25,0) NULL,
    LastLsn numeric(25,0) NULL,
    DatabaseBackupLsn numeric(25,0) NULL,
    CheckpointLsn numeric(25,0) NULL,
    CONSTRAINT UQ_BackupHistory UNIQUE(InstanceId,BackupSetId),
    CONSTRAINT FK_BackupHistory_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_BackupHistory_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE backup.BackupFile
(
    BackupFileId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_BackupFile PRIMARY KEY,
    BackupHistoryId bigint NOT NULL,
    LogicalDeviceName nvarchar(128) NULL,
    PhysicalDeviceName nvarchar(4000) NULL,
    DeviceType int NULL,
    FamilySequenceNumber int NULL,
    Mirror int NULL,
    CONSTRAINT FK_BackupFile_History FOREIGN KEY(BackupHistoryId) REFERENCES backup.BackupHistory(BackupHistoryId)
);
GO

CREATE TABLE backup.BackupPolicy
(
    BackupPolicyId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_BackupPolicy PRIMARY KEY,
    EnvironmentCode varchar(20) NULL,
    DatabasePattern nvarchar(256) NOT NULL,
    FullMaxAgeHours int NULL,
    DiffMaxAgeHours int NULL,
    LogMaxAgeMinutes int NULL,
    RequireChecksum bit NOT NULL CONSTRAINT DF_BackupPolicy_Checksum DEFAULT(1),
    RequireRestoreTestDays int NULL,
    IsEnabled bit NOT NULL CONSTRAINT DF_BackupPolicy_IsEnabled DEFAULT(1)
);
GO

CREATE TABLE backup.RestoreTest
(
    RestoreTestId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_RestoreTest PRIMARY KEY,
    InstanceId bigint NOT NULL,
    SourceDatabaseName sysname NOT NULL,
    TargetServerInstance nvarchar(256) NOT NULL,
    TargetDatabaseName sysname NOT NULL,
    TestStartedAt datetime2(0) NOT NULL,
    TestFinishedAt datetime2(0) NULL,
    DurationSeconds int NULL,
    CheckDbResult varchar(30) NULL,
    RestoreResult varchar(30) NOT NULL,
    BackupFinishDate datetime NULL,
    PerformedBy nvarchar(256) NULL,
    TicketNumber nvarchar(128) NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT FK_RestoreTest_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE capacity.VolumeSnapshot
(
    VolumeSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_VolumeSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    VolumeMountPoint nvarchar(512) NOT NULL,
    LogicalVolumeName nvarchar(512) NULL,
    FileSystemType nvarchar(60) NULL,
    TotalGB decimal(19,2) NULL,
    AvailableGB decimal(19,2) NULL,
    FreePercent decimal(9,2) NULL,
    CONSTRAINT FK_VolumeSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_VolumeSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE capacity.DatabaseGrowthDaily
(
    DatabaseGrowthDailyId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DatabaseGrowthDaily PRIMARY KEY,
    InstanceId bigint NOT NULL,
    DatabaseName sysname NOT NULL,
    CaptureDate date NOT NULL,
    DataSizeMB decimal(19,2) NULL,
    LogSizeMB decimal(19,2) NULL,
    TotalSizeMB decimal(19,2) NULL,
    DataGrowthMB decimal(19,2) NULL,
    LogGrowthMB decimal(19,2) NULL,
    CONSTRAINT UQ_DatabaseGrowthDaily UNIQUE(InstanceId,DatabaseName,CaptureDate),
    CONSTRAINT FK_DatabaseGrowthDaily_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE capacity.FileGrowthEvent
(
    FileGrowthEventId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FileGrowthEvent PRIMARY KEY,
    InstanceId bigint NOT NULL,
    DatabaseName sysname NOT NULL,
    LogicalFileName sysname NOT NULL,
    EventAt datetime2(0) NOT NULL,
    GrowthMB decimal(19,2) NULL,
    DurationMilliseconds bigint NULL,
    SourceName varchar(30) NULL,
    CONSTRAINT FK_FileGrowthEvent_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE ha.AvailabilityGroupSnapshot
(
    AvailabilityGroupSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AvailabilityGroupSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    GroupId uniqueidentifier NOT NULL,
    GroupName sysname NOT NULL,
    PrimaryReplica nvarchar(256) NULL,
    AutomatedBackupPreferenceDesc nvarchar(60) NULL,
    FailureConditionLevel int NULL,
    HealthCheckTimeout int NULL,
    CONSTRAINT FK_AvailabilityGroupSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_AvailabilityGroupSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE ha.ReplicaSnapshot
(
    ReplicaSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReplicaSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    GroupName sysname NOT NULL,
    ReplicaServerName nvarchar(256) NOT NULL,
    RoleDesc nvarchar(60) NULL,
    ConnectedStateDesc nvarchar(60) NULL,
    OperationalStateDesc nvarchar(60) NULL,
    RecoveryHealthDesc nvarchar(60) NULL,
    SynchronizationHealthDesc nvarchar(60) NULL,
    AvailabilityModeDesc nvarchar(60) NULL,
    FailoverModeDesc nvarchar(60) NULL,
    SecondaryRoleAllowConnectionsDesc nvarchar(60) NULL,
    CONSTRAINT FK_ReplicaSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_ReplicaSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE ha.DatabaseReplicaSnapshot
(
    DatabaseReplicaSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DatabaseReplicaSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    GroupName sysname NOT NULL,
    DatabaseName sysname NOT NULL,
    IsLocal bit NULL,
    IsPrimaryReplica bit NULL,
    SynchronizationStateDesc nvarchar(60) NULL,
    SynchronizationHealthDesc nvarchar(60) NULL,
    DatabaseStateDesc nvarchar(60) NULL,
    IsSuspended bit NULL,
    SuspendReasonDesc nvarchar(60) NULL,
    LogSendQueueKB bigint NULL,
    RedoQueueKB bigint NULL,
    LogSendRateKBs bigint NULL,
    RedoRateKBs bigint NULL,
    LastCommitTime datetime NULL,
    CONSTRAINT FK_DatabaseReplicaSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_DatabaseReplicaSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE ha.FailoverHistory
(
    FailoverHistoryId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FailoverHistory PRIMARY KEY,
    InstanceId bigint NOT NULL,
    GroupName sysname NOT NULL,
    DetectedAt datetime2(0) NOT NULL,
    PreviousPrimary nvarchar(256) NULL,
    NewPrimary nvarchar(256) NULL,
    DetectionSource varchar(30) NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT FK_FailoverHistory_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE maintenance.CheckDbExecution
(
    CheckDbExecutionId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CheckDbExecution PRIMARY KEY,
    InstanceId bigint NOT NULL,
    DatabaseName sysname NOT NULL,
    CheckStartedAt datetime2(0) NOT NULL,
    CheckFinishedAt datetime2(0) NULL,
    DurationSeconds int NULL,
    ResultStatus varchar(30) NOT NULL,
    ErrorCount int NULL,
    CommandText nvarchar(max) NULL,
    SourceJobName sysname NULL,
    MessageText nvarchar(max) NULL,
    CONSTRAINT FK_CheckDbExecution_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE maintenance.SuspectPageSnapshot
(
    SuspectPageSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_SuspectPageSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    DatabaseId int NOT NULL,
    DatabaseName sysname NULL,
    FileId int NOT NULL,
    PageId bigint NOT NULL,
    EventType int NOT NULL,
    ErrorCount int NULL,
    LastUpdateDate datetime NULL,
    CONSTRAINT FK_SuspectPageSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_SuspectPageSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE maintenance.IndexMaintenanceExecution
(
    IndexMaintenanceExecutionId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_IndexMaintenanceExecution PRIMARY KEY,
    InstanceId bigint NOT NULL,
    DatabaseName sysname NOT NULL,
    SchemaName sysname NULL,
    TableName sysname NULL,
    IndexName sysname NULL,
    OperationType varchar(30) NOT NULL,
    StartedAt datetime2(0) NOT NULL,
    FinishedAt datetime2(0) NULL,
    DurationSeconds int NULL,
    ResultStatus varchar(30) NULL,
    SourceJobName sysname NULL,
    CommandText nvarchar(max) NULL,
    CONSTRAINT FK_IndexMaintenanceExecution_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO
