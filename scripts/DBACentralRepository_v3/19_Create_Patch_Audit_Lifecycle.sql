USE [DBACentralRepository];
GO

/*
    DBACentralRepository v3 - Patch Audit Lifecycle
    ------------------------------------------------
    Rozszerza istniejący schemat [patch]. Nie duplikuje snapshotów, które
    są już przechowywane w schematach [db], [backup], [ha], [maintenance]
    i [config]. PRE/POST wskazują na istniejące dbo.ScanRun.
*/

/* 1. Dodatkowe, patch-specyficzne dane, których dotąd nie przechowywaliśmy. */
IF OBJECT_ID(N'[config].[QueryStoreSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [config].[QueryStoreSnapshot]
    (
        QueryStoreSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_QueryStoreSnapshot PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        DatabaseName sysname NOT NULL,
        DesiredStateDesc nvarchar(60) NULL,
        ActualStateDesc nvarchar(60) NULL,
        CurrentStorageSizeMB bigint NULL,
        MaxStorageSizeMB bigint NULL,
        ReadonlyReason bigint NULL,
        CONSTRAINT FK_QueryStoreSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_QueryStoreSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[config].[QueryStoreSnapshot]')
      AND name = N'IX_QueryStoreSnapshot_Current'
)
BEGIN
    CREATE INDEX IX_QueryStoreSnapshot_Current
        ON [config].[QueryStoreSnapshot](InstanceId, DatabaseName, CapturedAt DESC);
END;
GO

IF OBJECT_ID(N'[patch].[CodeRiskSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [patch].[CodeRiskSnapshot]
    (
        CodeRiskSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CodeRiskSnapshot PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        DatabaseName sysname NOT NULL,
        RiskCode varchar(60) NOT NULL,
        SchemaName sysname NULL,
        ObjectName sysname NULL,
        ObjectTypeDesc nvarchar(60) NULL,
        CONSTRAINT FK_CodeRiskSnapshot_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_CodeRiskSnapshot_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[patch].[CodeRiskSnapshot]')
      AND name = N'IX_CodeRiskSnapshot_Current'
)
BEGIN
    CREATE INDEX IX_CodeRiskSnapshot_Current
        ON [patch].[CodeRiskSnapshot](InstanceId, RiskCode, DatabaseName, CapturedAt DESC);
END;
GO

/* 2. Cykl patchowania: jedna instancja, jedno okno/change, PRE + POST. */
IF OBJECT_ID(N'[patch].[PatchCycle]', N'U') IS NULL
BEGIN
    CREATE TABLE [patch].[PatchCycle]
    (
        PatchCycleId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PatchCycle PRIMARY KEY,
        InstanceId bigint NOT NULL,
        ChangeReference nvarchar(128) NULL,
        TargetVersion nvarchar(128) NULL,
        TargetReleaseName nvarchar(128) NULL,
        PlannedAt datetime2(0) NULL,
        StartedAt datetime2(0) NOT NULL CONSTRAINT DF_PatchCycle_StartedAt DEFAULT(SYSDATETIME()),
        CompletedAt datetime2(0) NULL,
        CycleStatus varchar(30) NOT NULL CONSTRAINT DF_PatchCycle_Status DEFAULT('OPEN'),
        Notes nvarchar(max) NULL,
        CONSTRAINT CK_PatchCycle_Status CHECK (CycleStatus IN ('OPEN','READY','IN_PROGRESS','PASS','WARNING','FAIL','CANCELLED')),
        CONSTRAINT FK_PatchCycle_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[patch].[PatchCycle]')
      AND name = N'IX_PatchCycle_Instance'
)
BEGIN
    CREATE INDEX IX_PatchCycle_Instance
        ON [patch].[PatchCycle](InstanceId, StartedAt DESC);
END;
GO

/* 3. PRE/POST nie kopiują snapshotów - wskazują ScanRunId. */
IF OBJECT_ID(N'[patch].[PatchCyclePhase]', N'U') IS NULL
BEGIN
    CREATE TABLE [patch].[PatchCyclePhase]
    (
        PatchCyclePhaseId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PatchCyclePhase PRIMARY KEY,
        PatchCycleId bigint NOT NULL,
        AuditPhase varchar(10) NOT NULL,
        ScanRunId bigint NOT NULL,
        CapturedAt datetime2(0) NOT NULL,
        ProductVersion nvarchar(128) NULL,
        PhaseStatus varchar(30) NOT NULL CONSTRAINT DF_PatchCyclePhase_Status DEFAULT('PASS'),
        RegisteredAt datetime2(0) NOT NULL CONSTRAINT DF_PatchCyclePhase_RegisteredAt DEFAULT(SYSDATETIME()),
        CONSTRAINT CK_PatchCyclePhase_Phase CHECK (AuditPhase IN ('PRE','POST')),
        CONSTRAINT CK_PatchCyclePhase_Status CHECK (PhaseStatus IN ('PASS','WARNING','FAIL')),
        CONSTRAINT UQ_PatchCyclePhase UNIQUE(PatchCycleId, AuditPhase),
        CONSTRAINT FK_PatchCyclePhase_Cycle FOREIGN KEY(PatchCycleId) REFERENCES [patch].[PatchCycle](PatchCycleId),
        CONSTRAINT FK_PatchCyclePhase_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId)
    );
END;
GO

/* 4. Findingi należą tylko do oceny patchingu. */
IF OBJECT_ID(N'[patch].[PatchFinding]', N'U') IS NULL
BEGIN
    CREATE TABLE [patch].[PatchFinding]
    (
        PatchFindingId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PatchFinding PRIMARY KEY,
        PatchCyclePhaseId bigint NOT NULL,
        Severity varchar(20) NOT NULL,
        CheckCode varchar(80) NOT NULL,
        DatabaseName sysname NULL,
        ObjectName nvarchar(512) NULL,
        ObservedValue nvarchar(4000) NULL,
        FindingMessage nvarchar(max) NOT NULL,
        CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_PatchFinding_CreatedAt DEFAULT(SYSDATETIME()),
        CONSTRAINT CK_PatchFinding_Severity CHECK (Severity IN ('INFO','WARNING','FAIL')),
        CONSTRAINT FK_PatchFinding_Phase FOREIGN KEY(PatchCyclePhaseId) REFERENCES [patch].[PatchCyclePhase](PatchCyclePhaseId)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[patch].[PatchFinding]')
      AND name = N'IX_PatchFinding_Phase'
)
BEGIN
    CREATE INDEX IX_PatchFinding_Phase
        ON [patch].[PatchFinding](PatchCyclePhaseId, Severity, CheckCode);
END;
GO

/* 5. Rozpoczęcie cyklu. */
CREATE OR ALTER PROCEDURE [patch].[usp_StartPatchCycle]
    @ServerInstance nvarchar(256),
    @TargetVersion nvarchar(128) = NULL,
    @TargetReleaseName nvarchar(128) = NULL,
    @ChangeReference nvarchar(128) = NULL,
    @PlannedAt datetime2(0) = NULL,
    @Notes nvarchar(max) = NULL,
    @PatchCycleId bigint OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @InstanceId bigint;

    SELECT @InstanceId = InstanceId
    FROM dbo.Instance
    WHERE ServerInstance = @ServerInstance;

    IF @InstanceId IS NULL
        THROW 51000, 'Instancja nie istnieje w dbo.Instance. Najpierw wykonaj collector.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM patch.PatchCycle
        WHERE InstanceId = @InstanceId
          AND CycleStatus IN ('OPEN','READY','IN_PROGRESS')
    )
        THROW 51001, 'Dla tej instancji istnieje już aktywny cykl patchowania.', 1;

    INSERT patch.PatchCycle
    (
        InstanceId, ChangeReference, TargetVersion, TargetReleaseName,
        PlannedAt, CycleStatus, Notes
    )
    VALUES
    (
        @InstanceId, @ChangeReference, @TargetVersion, @TargetReleaseName,
        @PlannedAt, 'OPEN', @Notes
    );

    SET @PatchCycleId = SCOPE_IDENTITY();
END;
GO

/* 6. Rejestracja PRE/POST i automatyczna ocena istniejących snapshotów. */
CREATE OR ALTER PROCEDURE [patch].[usp_RegisterPatchPhase]
    @PatchCycleId bigint,
    @AuditPhase varchar(10),
    @ScanRunId bigint,
    @MaxFullBackupAgeHours int = 36,
    @MaxDiffBackupAgeHours int = 8,
    @MaxLogBackupAgeMinutes int = 60
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @AuditPhase = UPPER(@AuditPhase);
    IF @AuditPhase NOT IN ('PRE','POST')
        THROW 51010, 'AuditPhase musi mieć wartość PRE albo POST.', 1;

    DECLARE
        @InstanceId bigint,
        @TargetVersion nvarchar(128),
        @CapturedAt datetime2(0),
        @ProductVersion nvarchar(128),
        @PatchCyclePhaseId bigint;

    SELECT
        @InstanceId = InstanceId,
        @TargetVersion = TargetVersion
    FROM patch.PatchCycle
    WHERE PatchCycleId = @PatchCycleId;

    IF @InstanceId IS NULL
        THROW 51011, 'Nie znaleziono PatchCycleId.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM patch.InstanceBuildHistory
        WHERE ScanRunId = @ScanRunId
          AND InstanceId = @InstanceId
    )
        THROW 51012, 'Podany ScanRunId nie zawiera danych patch.InstanceBuildHistory dla tej instancji.', 1;

    SELECT TOP (1)
        @CapturedAt = CapturedAt,
        @ProductVersion = ProductVersion
    FROM patch.InstanceBuildHistory
    WHERE ScanRunId = @ScanRunId
      AND InstanceId = @InstanceId
    ORDER BY InstanceBuildHistoryId DESC;

    IF EXISTS
    (
        SELECT 1 FROM patch.PatchCyclePhase
        WHERE PatchCycleId = @PatchCycleId AND AuditPhase = @AuditPhase
    )
        THROW 51013, 'Ta faza PRE/POST jest już zarejestrowana dla cyklu.', 1;

    INSERT patch.PatchCyclePhase
    (
        PatchCycleId, AuditPhase, ScanRunId, CapturedAt, ProductVersion, PhaseStatus
    )
    VALUES
    (
        @PatchCycleId, @AuditPhase, @ScanRunId, @CapturedAt, @ProductVersion, 'PASS'
    );

    SET @PatchCyclePhaseId = SCOPE_IDENTITY();

    /* Database state */
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, DatabaseName, ObservedValue, FindingMessage)
    SELECT
        @PatchCyclePhaseId, 'FAIL', 'DATABASE_NOT_ONLINE', DatabaseName, StateDesc,
        N'Baza danych nie jest w stanie ONLINE.'
    FROM db.DatabaseSnapshot
    WHERE ScanRunId = @ScanRunId
      AND InstanceId = @InstanceId
      AND ISNULL(StateDesc,'') <> 'ONLINE';

    /* Linked Server MSDASQL */
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, ObjectName, ObservedValue, FindingMessage)
    SELECT
        @PatchCyclePhaseId, 'WARNING', 'MSDASQL_LINKED_SERVER', LinkedServerName, Provider,
        N'Linked Server korzysta z providera MSDASQL. Zweryfikuj działanie kont niebędących sysadmin po aktualizacji.'
    FROM config.LinkedServerSnapshot
    WHERE ScanRunId = @ScanRunId
      AND InstanceId = @InstanceId
      AND Provider = 'MSDASQL';

    /* SESSION_CONTEXT - dane zbiera rozszerzony collector */
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, DatabaseName, ObjectName, ObservedValue, FindingMessage)
    SELECT
        @PatchCyclePhaseId, 'WARNING', RiskCode, DatabaseName,
        QUOTENAME(SchemaName) + N'.' + QUOTENAME(ObjectName), ObjectTypeDesc,
        N'Kod korzysta z SESSION_CONTEXT/sp_set_session_context. Zweryfikuj scenariusze z planami równoległymi.'
    FROM patch.CodeRiskSnapshot
    WHERE ScanRunId = @ScanRunId
      AND InstanceId = @InstanceId
      AND RiskCode = 'SESSION_CONTEXT';

    /* Trace flag 11042 - informacyjnie */
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, ObservedValue, FindingMessage)
    SELECT TOP (1)
        @PatchCyclePhaseId, 'INFO', 'TRACEFLAG_11042_ENABLED', '11042',
        N'Trace flag 11042 jest aktywny na instancji.'
    FROM config.TraceFlagSnapshot
    WHERE ScanRunId = @ScanRunId
      AND InstanceId = @InstanceId
      AND TraceFlag = 11042;

    /* Query Store */
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, DatabaseName, ObservedValue, FindingMessage)
    SELECT
        @PatchCyclePhaseId,
        CASE WHEN ActualStateDesc = 'ERROR' THEN 'FAIL' ELSE 'WARNING' END,
        CASE WHEN ActualStateDesc = 'ERROR' THEN 'QUERY_STORE_ERROR' ELSE 'QUERY_STORE_NOT_READ_WRITE' END,
        DatabaseName,
        CONCAT(ISNULL(ActualStateDesc,N'NULL'), N'; readonly_reason=', ISNULL(CONVERT(nvarchar(30),ReadonlyReason),N'NULL')),
        N'Query Store nie jest w stanie READ_WRITE.'
    FROM config.QueryStoreSnapshot
    WHERE ScanRunId = @ScanRunId
      AND InstanceId = @InstanceId
      AND ISNULL(ActualStateDesc,'') NOT IN ('READ_WRITE','OFF');

    /* AG health */
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, DatabaseName, ObservedValue, FindingMessage)
    SELECT
        @PatchCyclePhaseId,
        CASE WHEN IsSuspended = 1 OR DatabaseStateDesc <> 'ONLINE' THEN 'FAIL' ELSE 'WARNING' END,
        CASE WHEN IsSuspended = 1 THEN 'AG_DATABASE_SUSPENDED' ELSE 'AG_DATABASE_NOT_HEALTHY' END,
        DatabaseName,
        CONCAT(ISNULL(SynchronizationStateDesc,N'NULL'), N' / ', ISNULL(SynchronizationHealthDesc,N'NULL'), N' / ', ISNULL(DatabaseStateDesc,N'NULL')),
        N'Baza w Availability Group wymaga weryfikacji przed/po patchingu.'
    FROM ha.DatabaseReplicaSnapshot
    WHERE ScanRunId = @ScanRunId
      AND InstanceId = @InstanceId
      AND
      (
          IsSuspended = 1
          OR ISNULL(DatabaseStateDesc,'') <> 'ONLINE'
          OR ISNULL(SynchronizationHealthDesc,'') = 'NOT_HEALTHY'
      );

    /* Suspect pages */
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, DatabaseName, ObservedValue, FindingMessage)
    SELECT
        @PatchCyclePhaseId, 'FAIL', 'SUSPECT_PAGE', DatabaseName,
        CONCAT(N'file=',FileId,N'; page=',PageId,N'; event=',EventType,N'; errors=',ISNULL(ErrorCount,0)),
        N'msdb.dbo.suspect_pages zawiera wpis dla bazy.'
    FROM maintenance.SuspectPageSnapshot
    WHERE ScanRunId = @ScanRunId
      AND InstanceId = @InstanceId;

    /* Backup freshness - BackupHistory jest historią deduplikowaną, dlatego oceniamy po czasie CapturedAt, a nie ScanRunId. */
    ;WITH D AS
    (
        SELECT DatabaseName, RecoveryModelDesc
        FROM db.DatabaseSnapshot
        WHERE ScanRunId = @ScanRunId
          AND InstanceId = @InstanceId
          AND DatabaseName NOT IN ('master','model','msdb','tempdb')
          AND StateDesc = 'ONLINE'
    ), B AS
    (
        SELECT
            D.DatabaseName,
            D.RecoveryModelDesc,
            MAX(CASE WHEN H.BackupType='D' AND H.BackupFinishDate <= @CapturedAt THEN H.BackupFinishDate END) LastFull,
            MAX(CASE WHEN H.BackupType='I' AND H.BackupFinishDate <= @CapturedAt THEN H.BackupFinishDate END) LastDiff,
            MAX(CASE WHEN H.BackupType='L' AND H.BackupFinishDate <= @CapturedAt THEN H.BackupFinishDate END) LastLog
        FROM D
        LEFT JOIN backup.BackupHistory H
          ON H.InstanceId = @InstanceId
         AND H.DatabaseName = D.DatabaseName
        GROUP BY D.DatabaseName, D.RecoveryModelDesc
    )
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, DatabaseName, ObservedValue, FindingMessage)
    SELECT
        @PatchCyclePhaseId, 'WARNING', 'BACKUP_FULL_STALE', DatabaseName,
        COALESCE(CONVERT(nvarchar(30),LastFull,126),N'NULL'),
        N'Ostatni FULL backup jest starszy niż dopuszczalny próg lub nie został znaleziony.'
    FROM B
    WHERE LastFull IS NULL OR DATEDIFF(HOUR,LastFull,@CapturedAt) > @MaxFullBackupAgeHours;

    ;WITH D AS
    (
        SELECT DatabaseName, RecoveryModelDesc
        FROM db.DatabaseSnapshot
        WHERE ScanRunId = @ScanRunId
          AND InstanceId = @InstanceId
          AND DatabaseName NOT IN ('master','model','msdb','tempdb')
          AND StateDesc = 'ONLINE'
    ), B AS
    (
        SELECT
            D.DatabaseName,
            D.RecoveryModelDesc,
            MAX(CASE WHEN H.BackupType='I' AND H.BackupFinishDate <= @CapturedAt THEN H.BackupFinishDate END) LastDiff,
            MAX(CASE WHEN H.BackupType='L' AND H.BackupFinishDate <= @CapturedAt THEN H.BackupFinishDate END) LastLog
        FROM D
        LEFT JOIN backup.BackupHistory H
          ON H.InstanceId = @InstanceId
         AND H.DatabaseName = D.DatabaseName
        GROUP BY D.DatabaseName, D.RecoveryModelDesc
    )
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, DatabaseName, ObservedValue, FindingMessage)
    SELECT
        @PatchCyclePhaseId, 'WARNING', 'BACKUP_LOG_STALE', DatabaseName,
        COALESCE(CONVERT(nvarchar(30),LastLog,126),N'NULL'),
        N'Dla bazy FULL/BULK_LOGGED ostatni LOG backup przekracza dopuszczalny próg lub nie został znaleziony.'
    FROM B
    WHERE RecoveryModelDesc IN ('FULL','BULK_LOGGED')
      AND (LastLog IS NULL OR DATEDIFF(MINUTE,LastLog,@CapturedAt) > @MaxLogBackupAgeMinutes);

    /* Dla DIFF ostrzegamy tylko, gdy istnieje historia DIFF i ostatni jest za stary. Brak DIFF może być świadomą polityką. */
    ;WITH D AS
    (
        SELECT DatabaseName
        FROM db.DatabaseSnapshot
        WHERE ScanRunId = @ScanRunId
          AND InstanceId = @InstanceId
          AND DatabaseName NOT IN ('master','model','msdb','tempdb')
          AND StateDesc = 'ONLINE'
    ), B AS
    (
        SELECT D.DatabaseName,
               MAX(CASE WHEN H.BackupType='I' AND H.BackupFinishDate <= @CapturedAt THEN H.BackupFinishDate END) LastDiff
        FROM D
        LEFT JOIN backup.BackupHistory H
          ON H.InstanceId = @InstanceId
         AND H.DatabaseName = D.DatabaseName
        GROUP BY D.DatabaseName
    )
    INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, DatabaseName, ObservedValue, FindingMessage)
    SELECT
        @PatchCyclePhaseId, 'WARNING', 'BACKUP_DIFF_STALE', DatabaseName,
        CONVERT(nvarchar(30),LastDiff,126),
        N'Ostatni DIFF backup przekracza dopuszczalny próg.'
    FROM B
    WHERE LastDiff IS NOT NULL
      AND DATEDIFF(HOUR,LastDiff,@CapturedAt) > @MaxDiffBackupAgeHours;

    /* POST: build musi odpowiadać targetowi, jeśli target podano. */
    IF @AuditPhase = 'POST' AND @TargetVersion IS NOT NULL AND @ProductVersion <> @TargetVersion
    BEGIN
        INSERT patch.PatchFinding(PatchCyclePhaseId, Severity, CheckCode, ObservedValue, FindingMessage)
        VALUES
        (
            @PatchCyclePhaseId, 'FAIL', 'BUILD_MISMATCH', @ProductVersion,
            CONCAT(N'Oczekiwany build: ',@TargetVersion,N'; wykryty build: ',COALESCE(@ProductVersion,N'NULL'),N'.')
        );
    END;

    UPDATE patch.PatchCyclePhase
    SET PhaseStatus =
        CASE
            WHEN EXISTS (SELECT 1 FROM patch.PatchFinding WHERE PatchCyclePhaseId=@PatchCyclePhaseId AND Severity='FAIL') THEN 'FAIL'
            WHEN EXISTS (SELECT 1 FROM patch.PatchFinding WHERE PatchCyclePhaseId=@PatchCyclePhaseId AND Severity='WARNING') THEN 'WARNING'
            ELSE 'PASS'
        END
    WHERE PatchCyclePhaseId = @PatchCyclePhaseId;

    IF @AuditPhase='PRE'
    BEGIN
        UPDATE patch.PatchCycle
        SET CycleStatus = CASE
                WHEN (SELECT PhaseStatus FROM patch.PatchCyclePhase WHERE PatchCyclePhaseId=@PatchCyclePhaseId)='FAIL' THEN 'FAIL'
                ELSE 'READY'
            END
        WHERE PatchCycleId=@PatchCycleId;
    END
    ELSE
    BEGIN
        UPDATE patch.PatchCycle
        SET
            CompletedAt = SYSDATETIME(),
            CycleStatus = (SELECT PhaseStatus FROM patch.PatchCyclePhase WHERE PatchCyclePhaseId=@PatchCyclePhaseId)
        WHERE PatchCycleId=@PatchCycleId;
    END;

    SELECT * FROM patch.PatchCyclePhase WHERE PatchCyclePhaseId=@PatchCyclePhaseId;
    SELECT * FROM patch.PatchFinding WHERE PatchCyclePhaseId=@PatchCyclePhaseId ORDER BY CASE Severity WHEN 'FAIL' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END, CheckCode, DatabaseName;
END;
GO

/* 7. Widok historii. */
CREATE OR ALTER VIEW [patch].[vPatchCycleHistory]
AS
SELECT
    C.PatchCycleId,
    I.ServerInstance,
    E.EnvironmentCode,
    C.ChangeReference,
    C.TargetVersion,
    C.TargetReleaseName,
    C.PlannedAt,
    C.StartedAt,
    C.CompletedAt,
    PRE.ScanRunId AS PreScanRunId,
    PRE.CapturedAt AS PreCapturedAt,
    PRE.ProductVersion AS PreVersion,
    PRE.PhaseStatus AS PreStatus,
    POST.ScanRunId AS PostScanRunId,
    POST.CapturedAt AS PostCapturedAt,
    POST.ProductVersion AS PostVersion,
    POST.PhaseStatus AS PostStatus,
    C.CycleStatus,
    C.Notes
FROM patch.PatchCycle C
JOIN dbo.Instance I ON I.InstanceId=C.InstanceId
LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId
LEFT JOIN patch.PatchCyclePhase PRE ON PRE.PatchCycleId=C.PatchCycleId AND PRE.AuditPhase='PRE'
LEFT JOIN patch.PatchCyclePhase POST ON POST.PatchCycleId=C.PatchCycleId AND POST.AuditPhase='POST';
GO

/* 8. Porównanie PRE/POST - używa istniejących snapshotów. */
CREATE OR ALTER PROCEDURE [patch].[usp_ComparePatchCycle]
    @PatchCycleId bigint
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InstanceId bigint, @PreScanRunId bigint, @PostScanRunId bigint;

    SELECT @InstanceId=InstanceId FROM patch.PatchCycle WHERE PatchCycleId=@PatchCycleId;
    SELECT @PreScanRunId=ScanRunId FROM patch.PatchCyclePhase WHERE PatchCycleId=@PatchCycleId AND AuditPhase='PRE';
    SELECT @PostScanRunId=ScanRunId FROM patch.PatchCyclePhase WHERE PatchCycleId=@PatchCycleId AND AuditPhase='POST';

    IF @InstanceId IS NULL THROW 51020, 'Nie znaleziono PatchCycleId.', 1;
    IF @PreScanRunId IS NULL THROW 51021, 'Brak fazy PRE.', 1;
    IF @PostScanRunId IS NULL THROW 51022, 'Brak fazy POST.', 1;

    SELECT * FROM patch.vPatchCycleHistory WHERE PatchCycleId=@PatchCycleId;

    SELECT
        COALESCE(PRE.DatabaseName,POST.DatabaseName) DatabaseName,
        PRE.StateDesc PreState,
        POST.StateDesc PostState,
        PRE.RecoveryModelDesc PreRecoveryModel,
        POST.RecoveryModelDesc PostRecoveryModel,
        PRE.CompatibilityLevel PreCompatibilityLevel,
        POST.CompatibilityLevel PostCompatibilityLevel,
        PRE.IsQueryStoreOn PreIsQueryStoreOn,
        POST.IsQueryStoreOn PostIsQueryStoreOn,
        CASE
            WHEN PRE.DatabaseName IS NULL THEN 'ADDED'
            WHEN POST.DatabaseName IS NULL THEN 'REMOVED'
            WHEN ISNULL(PRE.StateDesc,'')<>ISNULL(POST.StateDesc,'')
              OR ISNULL(PRE.RecoveryModelDesc,'')<>ISNULL(POST.RecoveryModelDesc,'')
              OR ISNULL(PRE.CompatibilityLevel,-1)<>ISNULL(POST.CompatibilityLevel,-1)
              OR ISNULL(PRE.IsQueryStoreOn,0)<>ISNULL(POST.IsQueryStoreOn,0) THEN 'CHANGED'
            ELSE 'SAME'
        END ComparisonStatus
    FROM (SELECT * FROM db.DatabaseSnapshot WHERE ScanRunId=@PreScanRunId AND InstanceId=@InstanceId) PRE
    FULL OUTER JOIN (SELECT * FROM db.DatabaseSnapshot WHERE ScanRunId=@PostScanRunId AND InstanceId=@InstanceId) POST
      ON POST.DatabaseName=PRE.DatabaseName
    ORDER BY DatabaseName;

    SELECT
        COALESCE(PRE.DatabaseName,POST.DatabaseName) DatabaseName,
        PRE.SynchronizationStateDesc PreSyncState,
        POST.SynchronizationStateDesc PostSyncState,
        PRE.SynchronizationHealthDesc PreSyncHealth,
        POST.SynchronizationHealthDesc PostSyncHealth,
        PRE.IsSuspended PreIsSuspended,
        POST.IsSuspended PostIsSuspended,
        PRE.LogSendQueueKB PreLogSendQueueKB,
        POST.LogSendQueueKB PostLogSendQueueKB,
        PRE.RedoQueueKB PreRedoQueueKB,
        POST.RedoQueueKB PostRedoQueueKB
    FROM (SELECT * FROM ha.DatabaseReplicaSnapshot WHERE ScanRunId=@PreScanRunId AND InstanceId=@InstanceId) PRE
    FULL OUTER JOIN (SELECT * FROM ha.DatabaseReplicaSnapshot WHERE ScanRunId=@PostScanRunId AND InstanceId=@InstanceId) POST
      ON POST.GroupName=PRE.GroupName AND POST.DatabaseName=PRE.DatabaseName
    ORDER BY DatabaseName;

    SELECT
        COALESCE(PRE.DatabaseName,POST.DatabaseName) DatabaseName,
        PRE.ActualStateDesc PreActualState,
        POST.ActualStateDesc PostActualState,
        PRE.CurrentStorageSizeMB PreStorageMB,
        POST.CurrentStorageSizeMB PostStorageMB,
        PRE.ReadonlyReason PreReadonlyReason,
        POST.ReadonlyReason PostReadonlyReason
    FROM (SELECT * FROM config.QueryStoreSnapshot WHERE ScanRunId=@PreScanRunId AND InstanceId=@InstanceId) PRE
    FULL OUTER JOIN (SELECT * FROM config.QueryStoreSnapshot WHERE ScanRunId=@PostScanRunId AND InstanceId=@InstanceId) POST
      ON POST.DatabaseName=PRE.DatabaseName
    ORDER BY DatabaseName;

    SELECT
        P.AuditPhase, F.Severity, F.CheckCode, F.DatabaseName, F.ObjectName, F.ObservedValue, F.FindingMessage
    FROM patch.PatchFinding F
    JOIN patch.PatchCyclePhase P ON P.PatchCyclePhaseId=F.PatchCyclePhaseId
    WHERE P.PatchCycleId=@PatchCycleId
    ORDER BY CASE P.AuditPhase WHEN 'PRE' THEN 1 ELSE 2 END,
             CASE F.Severity WHEN 'FAIL' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
             F.CheckCode, F.DatabaseName;
END;
GO

/* 9. Szybki status aktywnych/ostatnich cykli. */
CREATE OR ALTER PROCEDURE [patch].[usp_LatestPatchStatus]
    @Top int = 100
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top) *
    FROM patch.vPatchCycleHistory
    ORDER BY StartedAt DESC, ServerInstance;
END;
GO
