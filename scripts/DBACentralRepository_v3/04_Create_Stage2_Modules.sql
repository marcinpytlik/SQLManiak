USE DBACentralRepository;
GO

CREATE TABLE patch.SqlBuildCatalog
(
    SqlBuildCatalogId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_SqlBuildCatalog PRIMARY KEY,
    MajorVersion int NOT NULL,
    ProductVersion nvarchar(128) NOT NULL CONSTRAINT UQ_SqlBuildCatalog UNIQUE,
    ProductName nvarchar(128) NULL,
    ServicingModel varchar(20) NULL,
    ReleaseType varchar(30) NULL,
    ReleaseName nvarchar(128) NULL,
    ReleaseDate date NULL,
    IsRecommended bit NOT NULL CONSTRAINT DF_SqlBuildCatalog_IsRecommended DEFAULT(0),
    SupportEndDate date NULL,
    SourceUrl nvarchar(2000) NULL
);
GO

CREATE TABLE patch.InstanceBuildHistory
(
    InstanceBuildHistoryId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_InstanceBuildHistory PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    ProductVersion nvarchar(128) NOT NULL,
    ProductLevel nvarchar(128) NULL,
    Edition nvarchar(256) NULL,
    ProductMajorVersion int NULL,
    CONSTRAINT FK_InstanceBuildHistory_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_InstanceBuildHistory_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE patch.PatchAssessment
(
    PatchAssessmentId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PatchAssessment PRIMARY KEY,
    InstanceId bigint NOT NULL,
    AssessedAt datetime2(0) NOT NULL,
    CurrentVersion nvarchar(128) NOT NULL,
    RecommendedVersion nvarchar(128) NULL,
    AssessmentStatus varchar(30) NOT NULL,
    MissingReleaseCount int NULL,
    IsEndOfSupport bit NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT FK_PatchAssessment_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE patch.PatchException
(
    PatchExceptionId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PatchException PRIMARY KEY,
    InstanceId bigint NOT NULL,
    ValidFrom date NOT NULL,
    ValidTo date NULL,
    ApprovedBy nvarchar(256) NULL,
    TicketNumber nvarchar(128) NULL,
    Reason nvarchar(max) NOT NULL,
    IsActive bit NOT NULL CONSTRAINT DF_PatchException_IsActive DEFAULT(1),
    CONSTRAINT FK_PatchException_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE config.ServerConfigurationSnapshot
(
    ServerConfigurationSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServerConfigurationSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    ConfigurationName sysname NOT NULL,
    MinimumValue sql_variant NULL,
    MaximumValue sql_variant NULL,
    ConfigValue sql_variant NULL,
    RunValue sql_variant NULL,
    IsDynamic bit NULL,
    IsAdvanced bit NULL,
    CONSTRAINT FK_ServerConfigurationSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_ServerConfigurationSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE config.TempdbFileSnapshot
(
    TempdbFileSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TempdbFileSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    FileId int NOT NULL,
    LogicalName sysname NOT NULL,
    PhysicalName nvarchar(4000) NOT NULL,
    FileTypeDesc nvarchar(60) NULL,
    SizeMB decimal(19,2) NULL,
    GrowthMB decimal(19,2) NULL,
    IsPercentGrowth bit NULL,
    CONSTRAINT FK_TempdbFileSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_TempdbFileSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE config.TraceFlagSnapshot
(
    TraceFlagSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TraceFlagSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    TraceFlag int NOT NULL,
    IsGlobal bit NOT NULL,
    IsSession bit NOT NULL,
    CONSTRAINT FK_TraceFlagSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_TraceFlagSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE config.LinkedServerSnapshot
(
    LinkedServerSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_LinkedServerSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    LinkedServerName sysname NOT NULL,
    Product nvarchar(128) NULL,
    Provider nvarchar(128) NULL,
    DataSource nvarchar(4000) NULL,
    IsDataAccessEnabled bit NULL,
    IsRpcOutEnabled bit NULL,
    IsRemoteProcTransactionPromotionEnabled bit NULL,
    CONSTRAINT FK_LinkedServerSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_LinkedServerSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE config.ConfigurationBaseline
(
    ConfigurationBaselineId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ConfigurationBaseline PRIMARY KEY,
    BaselineName sysname NOT NULL CONSTRAINT UQ_ConfigurationBaseline UNIQUE,
    EnvironmentCode varchar(20) NULL,
    EditionPattern nvarchar(128) NULL,
    IsEnabled bit NOT NULL CONSTRAINT DF_ConfigurationBaseline_IsEnabled DEFAULT(1)
);
GO

CREATE TABLE config.ConfigurationBaselineItem
(
    ConfigurationBaselineItemId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ConfigurationBaselineItem PRIMARY KEY,
    ConfigurationBaselineId int NOT NULL,
    ConfigurationName sysname NOT NULL,
    ExpectedValue nvarchar(4000) NULL,
    ComparisonOperator varchar(20) NOT NULL,
    Severity varchar(20) NOT NULL,
    CONSTRAINT FK_ConfigurationBaselineItem_Baseline
        FOREIGN KEY(ConfigurationBaselineId)
        REFERENCES config.ConfigurationBaseline(ConfigurationBaselineId)
);
GO

CREATE TABLE security.ServerPrincipalSnapshot
(
    ServerPrincipalSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServerPrincipalSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    PrincipalId int NOT NULL,
    PrincipalName sysname NOT NULL,
    PrincipalTypeDesc nvarchar(60) NULL,
    IsDisabled bit NULL,
    CreateDate datetime NULL,
    ModifyDate datetime NULL,
    DefaultDatabaseName sysname NULL,
    IsPolicyChecked bit NULL,
    IsExpirationChecked bit NULL,
    CONSTRAINT FK_ServerPrincipalSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_ServerPrincipalSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE security.ServerRoleMembershipSnapshot
(
    ServerRoleMembershipSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServerRoleMembershipSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    RoleName sysname NOT NULL,
    MemberName sysname NOT NULL,
    CONSTRAINT FK_ServerRoleMembershipSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_ServerRoleMembershipSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE security.ServerPermissionSnapshot
(
    ServerPermissionSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServerPermissionSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    GranteeName sysname NOT NULL,
    GrantorName sysname NULL,
    PermissionName nvarchar(128) NOT NULL,
    StateDesc nvarchar(60) NULL,
    ClassDesc nvarchar(60) NULL,
    MajorId int NULL,
    CONSTRAINT FK_ServerPermissionSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_ServerPermissionSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE security.ProxySnapshot
(
    ProxySnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProxySnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    ProxyId int NOT NULL,
    ProxyName sysname NOT NULL,
    CredentialName sysname NULL,
    IsEnabled bit NULL,
    Description nvarchar(512) NULL,
    CONSTRAINT FK_ProxySnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_ProxySnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE security.CredentialSnapshot
(
    CredentialSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CredentialSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    CredentialName sysname NOT NULL,
    CredentialIdentity nvarchar(4000) NULL,
    CreateDate datetime NULL,
    ModifyDate datetime NULL,
    CONSTRAINT FK_CredentialSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_CredentialSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE security.DatabaseMailProfileSnapshot
(
    DatabaseMailProfileSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DatabaseMailProfileSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    ProfileId int NOT NULL,
    ProfileName sysname NOT NULL,
    Description nvarchar(512) NULL,
    IsDefaultPublicProfile bit NULL,
    CONSTRAINT FK_DatabaseMailProfileSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_DatabaseMailProfileSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE security.DatabaseMailAccountSnapshot
(
    DatabaseMailAccountSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DatabaseMailAccountSnapshot PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    CapturedAt datetime2(0) NOT NULL,
    AccountId int NOT NULL,
    AccountName sysname NOT NULL,
    EmailAddress nvarchar(512) NULL,
    DisplayName nvarchar(256) NULL,
    ReplyToAddress nvarchar(512) NULL,
    MailServerName nvarchar(512) NULL,
    Port int NULL,
    EnableSsl bit NULL,
    Username nvarchar(256) NULL,
    CONSTRAINT FK_DatabaseMailAccountSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_DatabaseMailAccountSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE security.SecurityFinding
(
    SecurityFindingId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_SecurityFinding PRIMARY KEY,
    InstanceId bigint NOT NULL,
    FindingCode varchar(100) NOT NULL,
    ObjectType varchar(30) NOT NULL,
    ObjectName nvarchar(512) NOT NULL,
    Severity varchar(20) NOT NULL,
    CurrentValue nvarchar(max) NULL,
    ExpectedValue nvarchar(max) NULL,
    Recommendation nvarchar(max) NULL,
    FirstDetectedAt datetime2(0) NOT NULL,
    LastDetectedAt datetime2(0) NOT NULL,
    FindingStatus varchar(30) NOT NULL,
    CONSTRAINT FK_SecurityFinding_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE alert.Rule
(
    RuleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_AlertRule PRIMARY KEY,
    RuleCode varchar(100) NOT NULL CONSTRAINT UQ_AlertRule_Code UNIQUE,
    ModuleName varchar(30) NOT NULL,
    RuleName nvarchar(256) NOT NULL,
    Severity varchar(20) NOT NULL,
    IsEnabled bit NOT NULL CONSTRAINT DF_AlertRule_IsEnabled DEFAULT(1)
);
GO

CREATE TABLE alert.Finding
(
    FindingId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AlertFinding PRIMARY KEY,
    RuleId int NOT NULL,
    InstanceId bigint NOT NULL,
    ObjectType varchar(30) NOT NULL,
    ObjectName nvarchar(512) NOT NULL,
    FirstDetectedAt datetime2(0) NOT NULL,
    LastDetectedAt datetime2(0) NOT NULL,
    FindingStatus varchar(30) NOT NULL,
    Details nvarchar(max) NULL,
    CONSTRAINT FK_AlertFinding_Rule FOREIGN KEY(RuleId) REFERENCES alert.Rule(RuleId),
    CONSTRAINT FK_AlertFinding_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO
