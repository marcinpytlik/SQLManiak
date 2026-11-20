USE [DBACentralRepositoryv4];
GO
IF OBJECT_ID(N'patch.PatchGroup', N'U') IS NULL
CREATE TABLE patch.PatchGroup (
    PatchGroupId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_PatchGroup PRIMARY KEY,
    GroupCode varchar(30) NOT NULL CONSTRAINT UQ_v4_PatchGroup UNIQUE,
    Description nvarchar(300) NULL,
    RequiresApproval bit NOT NULL CONSTRAINT DF_v4_Group_Approval DEFAULT (1)
);
GO
IF NOT EXISTS(SELECT 1 FROM patch.PatchGroup WHERE GroupCode='FRIDAY')
INSERT patch.PatchGroup(GroupCode,Description) VALUES ('FRIDAY',N'Piątkowe okno aktualizacji');
IF NOT EXISTS(SELECT 1 FROM patch.PatchGroup WHERE GroupCode='SUNDAY')
INSERT patch.PatchGroup(GroupCode,Description) VALUES ('SUNDAY',N'Niedzielne okno aktualizacji');
IF NOT EXISTS(SELECT 1 FROM patch.PatchGroup WHERE GroupCode='MANUAL')
INSERT patch.PatchGroup(GroupCode,Description) VALUES ('MANUAL',N'Wyłącznie ręcznie zatwierdzane');
IF NOT EXISTS(SELECT 1 FROM patch.PatchGroup WHERE GroupCode='EXCLUDED')
INSERT patch.PatchGroup(GroupCode,Description) VALUES ('EXCLUDED',N'Wyłączone z automatycznego planowania');
GO
/* Window is defined in UTC with explicit timestamps per occurrence; no invented local hours. */
IF OBJECT_ID(N'patch.MaintenanceWindow', N'U') IS NULL
CREATE TABLE patch.MaintenanceWindow (
    WindowId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_Window PRIMARY KEY,
    PatchGroupId int NOT NULL REFERENCES patch.PatchGroup(PatchGroupId),
    StartsUtc datetime2(0) NOT NULL,
    EndsUtc datetime2(0) NOT NULL,
    TimeZoneId sysname NOT NULL CONSTRAINT DF_v4_Window_TZ DEFAULT (N'Central European Standard Time'),
    ChangeReference nvarchar(128) NULL,
    Status varchar(20) NOT NULL CONSTRAINT DF_v4_Window_Status DEFAULT ('DRAFT'),
    CONSTRAINT CK_v4_Window_Range CHECK (StartsUtc<EndsUtc),
    CONSTRAINT CK_v4_Window_Status CHECK(Status IN ('DRAFT','APPROVED','CANCELLED','CLOSED'))
);
GO
/* FCI assignment is scoped to ClusterName; standalone to InstanceId.
   Validation ensures exactly one target type. */
IF OBJECT_ID(N'patch.TargetAssignment', N'U') IS NULL
CREATE TABLE patch.TargetAssignment (
    AssignmentId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_Assignment PRIMARY KEY,
    PatchGroupId int NOT NULL REFERENCES patch.PatchGroup(PatchGroupId),
    InstanceId bigint NULL REFERENCES inventory.Instance(InstanceId),
    ClusterName sysname NULL,
    EffectiveFrom date NOT NULL CONSTRAINT DF_v4_Assignment_From DEFAULT CONVERT(date,SYSUTCDATETIME()),
    EffectiveTo date NULL,
    Notes nvarchar(1000) NULL,
    CONSTRAINT CK_v4_Assignment_Target CHECK
      ((InstanceId IS NOT NULL AND ClusterName IS NULL) OR
       (InstanceId IS NULL AND ClusterName IS NOT NULL)),
    CONSTRAINT CK_v4_Assignment_Range CHECK(EffectiveTo IS NULL OR EffectiveTo>=EffectiveFrom)
);
GO
IF OBJECT_ID(N'patch.PatchOperation', N'U') IS NULL
CREATE TABLE patch.PatchOperation (
    OperationId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_Operation PRIMARY KEY,
    WindowId bigint NOT NULL REFERENCES patch.MaintenanceWindow(WindowId),
    InstanceId bigint NOT NULL REFERENCES inventory.Instance(InstanceId),
    TargetBuild nvarchar(64) NOT NULL,
    ChangeReference nvarchar(128) NOT NULL,
    Status varchar(24) NOT NULL CONSTRAINT DF_v4_Operation_Status DEFAULT ('DRAFT'),
    PreScanRunId bigint NULL REFERENCES inventory.ScanRun(ScanRunId),
    PostScanRunId bigint NULL REFERENCES inventory.ScanRun(ScanRunId),
    ApprovedBy nvarchar(256) NULL,
    ApprovedUtc datetime2(0) NULL,
    StartedUtc datetime2(0) NULL,
    FinishedUtc datetime2(0) NULL,
    CONSTRAINT UQ_v4_Operation_WindowInstance UNIQUE(WindowId,InstanceId),
    CONSTRAINT CK_v4_Operation_Status CHECK(Status IN
      ('DRAFT','PRECHECK','READY','APPROVED','RUNNING','PASS','WARNING','FAILED','CANCELLED')),
    CONSTRAINT CK_v4_Operation_Approval CHECK
      ((ApprovedBy IS NULL AND ApprovedUtc IS NULL) OR
       (ApprovedBy IS NOT NULL AND ApprovedUtc IS NOT NULL)),
    CONSTRAINT CK_v4_Operation_Scans CHECK
      (PreScanRunId IS NULL OR PostScanRunId IS NULL OR PreScanRunId<>PostScanRunId)
);
GO
IF OBJECT_ID(N'patch.PatchEvent', N'U') IS NULL
CREATE TABLE patch.PatchEvent (
    PatchEventId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_PatchEvent PRIMARY KEY,
    OperationId bigint NOT NULL REFERENCES patch.PatchOperation(OperationId),
    EventUtc datetime2(0) NOT NULL CONSTRAINT DF_v4_Event_Utc DEFAULT SYSUTCDATETIME(),
    EventType varchar(40) NOT NULL,
    Phase varchar(20) NULL,
    Outcome varchar(20) NOT NULL,
    Actor nvarchar(256) NULL,
    Message nvarchar(max) NULL,
    CONSTRAINT CK_v4_Event_Outcome CHECK(Outcome IN ('INFO','PASS','WARN','FAIL'))
);
GO
/* Audit trail for an approval action (does not perform patching). */
CREATE OR ALTER PROCEDURE patch.usp_ApproveOperation
 @OperationId bigint, @Approver nvarchar(256)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@Approver)),N'') IS NULL
     THROW 52001,'Approver is required.',1;
 BEGIN TRANSACTION;
 UPDATE patch.PatchOperation WITH (UPDLOCK)
 SET Status='APPROVED',ApprovedBy=@Approver,ApprovedUtc=SYSUTCDATETIME()
 WHERE OperationId=@OperationId AND Status='READY' AND PreScanRunId IS NOT NULL
   AND EXISTS (
    SELECT 1 FROM inventory.ScanRun s
    WHERE s.ScanRunId=patch.PatchOperation.PreScanRunId
      AND s.InstanceId=patch.PatchOperation.InstanceId
      AND s.ScanType='PRE' AND s.ScanStatus='COMPLETE')
   AND EXISTS (
    SELECT 1 FROM patch.MaintenanceWindow w
    WHERE w.WindowId=patch.PatchOperation.WindowId AND w.Status='APPROVED');
 IF @@ROWCOUNT<>1
 BEGIN
   ROLLBACK;
   THROW 52002,'Operation not ready, PRE scan incomplete, or window not approved.',1;
 END;
 INSERT patch.PatchEvent(OperationId,EventType,Outcome,Actor,Message)
 VALUES(@OperationId,'APPROVAL','PASS',@Approver,N'Operation approved; no patch executed.');
 COMMIT;
END;
GO
