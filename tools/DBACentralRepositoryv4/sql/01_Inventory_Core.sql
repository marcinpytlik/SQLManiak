USE [DBACentralRepositoryv4];
GO
/* Registry: one logical SQL instance may belong to multiple hosts (FCI). */
IF OBJECT_ID(N'inventory.Instance', N'U') IS NULL
CREATE TABLE inventory.Instance (
    InstanceId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_Instance PRIMARY KEY,
    ServerInstance nvarchar(256) NOT NULL,
    EnvironmentCode varchar(20) NOT NULL,
    WorkloadCriticality varchar(20) NOT NULL CONSTRAINT DF_v4_Instance_Criticality DEFAULT ('UNCLASSIFIED'),
    Architecture varchar(20) NOT NULL CONSTRAINT DF_v4_Instance_Architecture DEFAULT ('UNKNOWN'),
    ClusterName sysname NULL,
    IsEnabled bit NOT NULL CONSTRAINT DF_v4_Instance_Enabled DEFAULT(1),
    CreatedUtc datetime2(0) NOT NULL CONSTRAINT DF_v4_Instance_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_v4_Instance_Name UNIQUE(ServerInstance),
    CONSTRAINT CK_v4_Instance_Architecture CHECK (Architecture IN ('STANDALONE','FCI','AG','UNKNOWN'))
);
GO
IF OBJECT_ID(N'inventory.Host', N'U') IS NULL
CREATE TABLE inventory.Host (
    HostId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_Host PRIMARY KEY,
    HostName sysname NOT NULL CONSTRAINT UQ_v4_Host_Name UNIQUE,
    ClusterName sysname NULL,
    IsEnabled bit NOT NULL CONSTRAINT DF_v4_Host_Enabled DEFAULT(1)
);
GO
IF OBJECT_ID(N'inventory.InstanceHost', N'U') IS NULL
CREATE TABLE inventory.InstanceHost (
    InstanceId bigint NOT NULL REFERENCES inventory.Instance(InstanceId),
    HostId bigint NOT NULL REFERENCES inventory.Host(HostId),
    IsPreferredOwner bit NOT NULL CONSTRAINT DF_v4_IH_Preferred DEFAULT(0),
    IsCurrentOwner bit NOT NULL CONSTRAINT DF_v4_IH_Current DEFAULT(0),
    LastObservedUtc datetime2(0) NULL,
    CONSTRAINT PK_v4_InstanceHost PRIMARY KEY(InstanceId,HostId)
);
GO
/* Scan execution, partial failures retained for diagnosis. */
IF OBJECT_ID(N'inventory.ScanRun', N'U') IS NULL
CREATE TABLE inventory.ScanRun (
    ScanRunId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_ScanRun PRIMARY KEY,
    InstanceId bigint NOT NULL REFERENCES inventory.Instance(InstanceId),
    ScanType varchar(20) NOT NULL,
    StartedUtc datetime2(0) NOT NULL CONSTRAINT DF_v4_Scan_Start DEFAULT SYSUTCDATETIME(),
    FinishedUtc datetime2(0) NULL,
    ScanStatus varchar(20) NOT NULL CONSTRAINT DF_v4_Scan_Status DEFAULT ('RUNNING'),
    CollectorVersion nvarchar(64) NULL,
    ErrorMessage nvarchar(4000) NULL,
    CONSTRAINT CK_v4_Scan_Type CHECK (ScanType IN ('FULL','DELTA','PRE','POST')),
    CONSTRAINT CK_v4_Scan_Status CHECK (ScanStatus IN ('RUNNING','COMPLETE','PARTIAL','FAILED'))
);
GO
/* Inventory categories: typed domain + JSON payload to allow nonbreaking collector evolution.
   Full normalized domain tables are future migration work; category snapshots must not contain secrets. */
IF OBJECT_ID(N'inventory.InventorySnapshot', N'U') IS NULL
CREATE TABLE inventory.InventorySnapshot (
    InventorySnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_Snapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL REFERENCES inventory.ScanRun(ScanRunId),
    Category varchar(32) NOT NULL,
    EntityKey nvarchar(900) NOT NULL,
    CapturedUtc datetime2(0) NOT NULL CONSTRAINT DF_v4_Snapshot_Captured DEFAULT SYSUTCDATETIME(),
    DataJson nvarchar(max) NOT NULL,
    CONSTRAINT UQ_v4_Snapshot_Row UNIQUE(ScanRunId,Category,EntityKey),
    CONSTRAINT CK_v4_Snapshot_Category CHECK (Category IN
      ('INSTANCE','CONFIGURATION','DATABASE','DATABASE_FILE','TEMPDB','OBJECT','INDEX','STATISTICS',
       'SQL_AGENT_JOB','SQL_AGENT_STEP','SQL_AGENT_SCHEDULE','LOGIN','SERVER_ROLE','SERVER_PERMISSION',
       'DATABASE_USER','DATABASE_ROLE','DATABASE_PERMISSION','LINKED_SERVER','CREDENTIAL_METADATA',
       'HA_CLUSTER','HA_REPLICA','HA_DATABASE','BACKUP_POLICY','VOLUME','SERVICE')),
    CONSTRAINT CK_v4_Snapshot_Json CHECK (ISJSON(DataJson)=1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'inventory.InventorySnapshot') AND name=N'IX_v4_Snapshot_Cat')
CREATE INDEX IX_v4_Snapshot_Cat ON inventory.InventorySnapshot(Category, CapturedUtc DESC) INCLUDE(ScanRunId);
GO
/* Record collector errors without claiming an incomplete scan is complete. */
IF OBJECT_ID(N'inventory.ScanFinding', N'U') IS NULL
CREATE TABLE inventory.ScanFinding (
    ScanFindingId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_ScanFinding PRIMARY KEY,
    ScanRunId bigint NOT NULL REFERENCES inventory.ScanRun(ScanRunId),
    Category varchar(32) NOT NULL,
    Severity varchar(10) NOT NULL,
    Message nvarchar(4000) NOT NULL,
    CreatedUtc datetime2(0) NOT NULL CONSTRAINT DF_v4_Finding_Utc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_v4_Finding_Severity CHECK (Severity IN ('INFO','WARN','ERROR'))
);
GO
