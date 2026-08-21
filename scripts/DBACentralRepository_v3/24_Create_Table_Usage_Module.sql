USE [DBACentralRepository];
GO

/*
===============================================================================
DBACentralRepository v3 - TABLE USAGE module v1.0
===============================================================================
Cel:
  - historyczny snapshot wykorzystania tabel na podstawie
    sys.dm_db_index_usage_stats;
  - dokładne przypisanie dostępu SELECT do loginu/użytkownika na podstawie
    SQL Server Audit;
  - raport technical vs other bez mylenia system_* z kontem technicznym.

Metryki są rozdzielone celowo:
  * UserReadsDelta = seeks + scans + lookups z DMV (obciążenie tabeli ogółem),
  * AccessCount    = liczba audytowanych operacji SELECT per principal/obiekt.

SQL Server Audit nie zawiera logical reads per obiekt, dlatego repozytorium nie
udaje, że potrafi przypisać strony logiczne do konkretnego loginu.
===============================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'perf') IS NULL
    EXEC(N'CREATE SCHEMA [perf] AUTHORIZATION [dbo];');
GO

/*=============================================================================
  01. Konfiguracja monitorowanych baz
=============================================================================*/
IF OBJECT_ID(N'[perf].[TableUsageTarget]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[TableUsageTarget]
    (
        [TableUsageTargetId] bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_TableUsageTarget] PRIMARY KEY,
        [InstanceId]         bigint NOT NULL,
        [DatabaseName]       sysname NOT NULL,
        [IsEnabled]          bit NOT NULL
            CONSTRAINT [DF_perf_TableUsageTarget_IsEnabled] DEFAULT (1),
        [AuditName]          sysname NOT NULL,
        [AuditSpecificationName] sysname NOT NULL,
        [AuditPath]          nvarchar(1000) NOT NULL,
        [AuditReadOverlapMinutes] int NOT NULL
            CONSTRAINT [DF_perf_TableUsageTarget_Overlap] DEFAULT (15),
        [CreatedAt]          datetime2(0) NOT NULL
            CONSTRAINT [DF_perf_TableUsageTarget_CreatedAt] DEFAULT (SYSDATETIME()),
        [ModifiedAt]         datetime2(0) NOT NULL
            CONSTRAINT [DF_perf_TableUsageTarget_ModifiedAt] DEFAULT (SYSDATETIME()),

        CONSTRAINT [FK_perf_TableUsageTarget_Instance]
            FOREIGN KEY ([InstanceId]) REFERENCES [dbo].[Instance]([InstanceId]),
        CONSTRAINT [UX_perf_TableUsageTarget_Instance_Db]
            UNIQUE ([InstanceId],[DatabaseName]),
        CONSTRAINT [CK_perf_TableUsageTarget_Overlap]
            CHECK ([AuditReadOverlapMinutes] BETWEEN 1 AND 1440)
    );
END;
GO

/*=============================================================================
  02. Principale techniczne
=============================================================================*/
IF OBJECT_ID(N'[perf].[TableUsageTechnicalPrincipal]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[TableUsageTechnicalPrincipal]
    (
        [TableUsageTechnicalPrincipalId] bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_TableUsageTechnicalPrincipal] PRIMARY KEY,
        [TableUsageTargetId] bigint NOT NULL,
        [PrincipalPattern]   nvarchar(256) NOT NULL,
        [Description]        nvarchar(500) NULL,
        [IsEnabled]          bit NOT NULL
            CONSTRAINT [DF_perf_TableUsageTechnicalPrincipal_IsEnabled] DEFAULT (1),
        [CreatedAt]          datetime2(0) NOT NULL
            CONSTRAINT [DF_perf_TableUsageTechnicalPrincipal_CreatedAt] DEFAULT (SYSDATETIME()),

        CONSTRAINT [FK_perf_TableUsageTechnicalPrincipal_Target]
            FOREIGN KEY ([TableUsageTargetId])
            REFERENCES [perf].[TableUsageTarget]([TableUsageTargetId])
            ON DELETE CASCADE,
        CONSTRAINT [UX_perf_TableUsageTechnicalPrincipal_Target_Pattern]
            UNIQUE ([TableUsageTargetId],[PrincipalPattern])
    );
END;
GO

/*=============================================================================
  03. Snapshot cumulative DMV per tabela
=============================================================================*/
IF OBJECT_ID(N'[perf].[TableUsageSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[TableUsageSnapshot]
    (
        [TableUsageSnapshotId] bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_TableUsageSnapshot] PRIMARY KEY,
        [TableUsageTargetId] bigint NOT NULL,
        [InstanceId]        bigint NOT NULL,
        [CapturedAt]        datetime2(0) NOT NULL, -- UTC (collector timestamp)
        [DatabaseId]        int NOT NULL,
        [DatabaseName]      sysname NOT NULL,
        [ObjectId]          int NOT NULL,
        [SchemaName]        sysname NOT NULL,
        [TableName]         sysname NOT NULL,
        [UserSeeks]         bigint NOT NULL,
        [UserScans]         bigint NOT NULL,
        [UserLookups]       bigint NOT NULL,
        [UserUpdates]       bigint NOT NULL,
        [LastUserSeek]      datetime NULL,
        [LastUserScan]      datetime NULL,
        [LastUserLookup]    datetime NULL,
        [LastUserUpdate]    datetime NULL,

        CONSTRAINT [FK_perf_TableUsageSnapshot_Target]
            FOREIGN KEY ([TableUsageTargetId])
            REFERENCES [perf].[TableUsageTarget]([TableUsageTargetId])
            ON DELETE CASCADE,
        CONSTRAINT [FK_perf_TableUsageSnapshot_Instance]
            FOREIGN KEY ([InstanceId]) REFERENCES [dbo].[Instance]([InstanceId])
    );

    CREATE UNIQUE INDEX [UX_perf_TableUsageSnapshot_Target_Time_Object]
        ON [perf].[TableUsageSnapshot]
        ([TableUsageTargetId],[CapturedAt],[ObjectId]);

    CREATE INDEX [IX_perf_TableUsageSnapshot_History]
        ON [perf].[TableUsageSnapshot]
        ([TableUsageTargetId],[ObjectId],[CapturedAt] DESC)
        INCLUDE ([SchemaName],[TableName],[UserSeeks],[UserScans],[UserLookups],[UserUpdates]);
END;
GO

/*=============================================================================
  04. Agregaty SQL Audit - bucket 5 minut
=============================================================================*/
IF OBJECT_ID(N'[perf].[TableAccessAggregate]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[TableAccessAggregate]
    (
        [TableAccessAggregateId] bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_TableAccessAggregate] PRIMARY KEY,
        [TableUsageTargetId] bigint NOT NULL,
        [InstanceId]        bigint NOT NULL,
        [BucketStartUtc]    datetime2(0) NOT NULL,
        [DatabaseName]      sysname NOT NULL,
        [SchemaName]        sysname NOT NULL,
        [ObjectName]        sysname NOT NULL,
        [ObjectId]          int NULL,
        [ServerPrincipalName] nvarchar(256) NULL,
        [SessionServerPrincipalName] nvarchar(256) NULL,
        [DatabasePrincipalName] nvarchar(256) NULL,
        [ApplicationName]   nvarchar(128) NULL,
        [HostName]          nvarchar(128) NULL,
        [AccessCount]       bigint NOT NULL,
        [FailedCount]       bigint NOT NULL,
        [ImportedAt]        datetime2(0) NOT NULL
            CONSTRAINT [DF_perf_TableAccessAggregate_ImportedAt] DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT [FK_perf_TableAccessAggregate_Target]
            FOREIGN KEY ([TableUsageTargetId])
            REFERENCES [perf].[TableUsageTarget]([TableUsageTargetId])
            ON DELETE CASCADE,
        CONSTRAINT [FK_perf_TableAccessAggregate_Instance]
            FOREIGN KEY ([InstanceId]) REFERENCES [dbo].[Instance]([InstanceId])
    );

    CREATE INDEX [IX_perf_TableAccessAggregate_Report]
        ON [perf].[TableAccessAggregate]
        ([TableUsageTargetId],[BucketStartUtc],[SchemaName],[ObjectName])
        INCLUDE ([ServerPrincipalName],[AccessCount],[FailedCount],[ApplicationName],[HostName]);
END;
GO

/*=============================================================================
  05. Konfiguracja targetu
=============================================================================*/
CREATE OR ALTER PROCEDURE [perf].[usp_ConfigureTableUsageTarget]
    @ServerInstance nvarchar(256),
    @DatabaseName sysname,
    @AuditPath nvarchar(1000),
    @AuditName sysname = NULL,
    @AuditSpecificationName sysname = NULL,
    @AuditReadOverlapMinutes int = 15,
    @IsEnabled bit = 1,
    @TableUsageTargetId bigint = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InstanceId bigint;

    SELECT @InstanceId = I.InstanceId
    FROM dbo.Instance AS I
    WHERE I.ServerInstance = @ServerInstance;

    IF @InstanceId IS NULL
        THROW 51040, 'ServerInstance not found in dbo.Instance.', 1;

    IF NULLIF(LTRIM(RTRIM(@AuditPath)),N'') IS NULL
        THROW 51041, 'AuditPath is required.', 1;

    IF @AuditName IS NULL
        SET @AuditName = CONVERT(sysname,N'DBACR_TableAccess_' + REPLACE(REPLACE(@DatabaseName,N']',N''),N' ',N'_'));

    IF @AuditSpecificationName IS NULL
        SET @AuditSpecificationName = CONVERT(sysname,N'DBACR_TableAccessSpec_' + REPLACE(REPLACE(@DatabaseName,N']',N''),N' ',N'_'));

    MERGE [perf].[TableUsageTarget] AS T
    USING (SELECT @InstanceId AS InstanceId, @DatabaseName AS DatabaseName) AS S
      ON T.InstanceId = S.InstanceId
     AND T.DatabaseName = S.DatabaseName
    WHEN MATCHED THEN
        UPDATE SET
            AuditPath = @AuditPath,
            AuditName = @AuditName,
            AuditSpecificationName = @AuditSpecificationName,
            AuditReadOverlapMinutes = @AuditReadOverlapMinutes,
            IsEnabled = @IsEnabled,
            ModifiedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (InstanceId,DatabaseName,IsEnabled,AuditName,AuditSpecificationName,AuditPath,AuditReadOverlapMinutes)
        VALUES (@InstanceId,@DatabaseName,@IsEnabled,@AuditName,@AuditSpecificationName,@AuditPath,@AuditReadOverlapMinutes);

    SELECT @TableUsageTargetId = TableUsageTargetId
    FROM [perf].[TableUsageTarget]
    WHERE InstanceId=@InstanceId AND DatabaseName=@DatabaseName;

    SELECT @TableUsageTargetId AS TableUsageTargetId;
END;
GO

CREATE OR ALTER PROCEDURE [perf].[usp_AddTableUsageTechnicalPrincipal]
    @TableUsageTargetId bigint,
    @PrincipalPattern nvarchar(256),
    @Description nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM perf.TableUsageTarget WHERE TableUsageTargetId=@TableUsageTargetId)
        THROW 51042, 'TableUsageTargetId not found.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM perf.TableUsageTechnicalPrincipal
        WHERE TableUsageTargetId=@TableUsageTargetId
          AND PrincipalPattern=@PrincipalPattern
    )
    BEGIN
        INSERT perf.TableUsageTechnicalPrincipal
            (TableUsageTargetId,PrincipalPattern,Description)
        VALUES
            (@TableUsageTargetId,@PrincipalPattern,@Description);
    END;
END;
GO

/*=============================================================================
  06. Raport technical vs other + DMV delta
=============================================================================*/
CREATE OR ALTER PROCEDURE [perf].[usp_GetTableUsageByPrincipal]
    @ServerInstance nvarchar(256),
    @DatabaseName sysname,
    @From datetime2(0),
    @To datetime2(0),
    @Top int = 100
AS
BEGIN
    SET NOCOUNT ON;

    IF @To <= @From
        THROW 51043, '@To must be greater than @From.', 1;

    IF @Top IS NULL OR @Top < 1 SET @Top = 100;

    DECLARE @TargetId bigint;

    SELECT @TargetId=T.TableUsageTargetId
    FROM perf.TableUsageTarget AS T
    JOIN dbo.Instance AS I ON I.InstanceId=T.InstanceId
    WHERE I.ServerInstance=@ServerInstance
      AND T.DatabaseName=@DatabaseName;

    IF @TargetId IS NULL
        THROW 51044, 'Table usage target not configured.', 1;

    ;WITH A AS
    (
        SELECT
            X.SchemaName,
            X.ObjectName AS TableName,
            SUM(X.AccessCount) AS AccessCount,
            SUM(CASE WHEN P.IsTechnical=1 THEN X.AccessCount ELSE 0 END) AS TechnicalAccessCount,
            SUM(CASE WHEN P.IsTechnical=0 THEN X.AccessCount ELSE 0 END) AS OtherAccessCount,
            COUNT(DISTINCT NULLIF(X.ServerPrincipalName,N'')) AS DistinctPrincipals
        FROM perf.TableAccessAggregate AS X
        OUTER APPLY
        (
            SELECT CONVERT(bit,CASE WHEN EXISTS
            (
                SELECT 1
                FROM perf.TableUsageTechnicalPrincipal AS TP
                WHERE TP.TableUsageTargetId=X.TableUsageTargetId
                  AND TP.IsEnabled=1
                  AND COALESCE(X.ServerPrincipalName,X.SessionServerPrincipalName,N'') LIKE TP.PrincipalPattern
            ) THEN 1 ELSE 0 END) AS IsTechnical
        ) AS P
        WHERE X.TableUsageTargetId=@TargetId
          AND X.BucketStartUtc >= @From
          AND X.BucketStartUtc < @To
        GROUP BY X.SchemaName,X.ObjectName
    ),
    S AS
    (
        SELECT
            TS.*,
            ROW_NUMBER() OVER(PARTITION BY TS.ObjectId ORDER BY TS.CapturedAt ASC) AS rnFirst,
            ROW_NUMBER() OVER(PARTITION BY TS.ObjectId ORDER BY TS.CapturedAt DESC) AS rnLast
        FROM perf.TableUsageSnapshot AS TS
        WHERE TS.TableUsageTargetId=@TargetId
          AND TS.CapturedAt >= @From
          AND TS.CapturedAt <= @To
    ),
    D AS
    (
        SELECT
            COALESCE(L.SchemaName,F.SchemaName) AS SchemaName,
            COALESCE(L.TableName,F.TableName) AS TableName,
            CASE WHEN L.UserSeeks+L.UserScans+L.UserLookups >= F.UserSeeks+F.UserScans+F.UserLookups
                 THEN (L.UserSeeks+L.UserScans+L.UserLookups) - (F.UserSeeks+F.UserScans+F.UserLookups)
                 ELSE (L.UserSeeks+L.UserScans+L.UserLookups) END AS UserReadsDelta,
            CASE WHEN L.UserUpdates >= F.UserUpdates
                 THEN L.UserUpdates-F.UserUpdates ELSE L.UserUpdates END AS UserUpdatesDelta
        FROM (SELECT * FROM S WHERE rnLast=1) AS L
        FULL OUTER JOIN (SELECT * FROM S WHERE rnFirst=1) AS F
          ON F.ObjectId=L.ObjectId
    )
    SELECT TOP (@Top)
        SchemaName = COALESCE(A.SchemaName,D.SchemaName),
        TableName = COALESCE(A.TableName,D.TableName),
        AccessCount = ISNULL(A.AccessCount,0),
        TechnicalAccessCount = ISNULL(A.TechnicalAccessCount,0),
        OtherAccessCount = ISNULL(A.OtherAccessCount,0),
        TechnicalPercent = CONVERT(decimal(9,2),
            CASE WHEN ISNULL(A.AccessCount,0)=0 THEN 0
                 ELSE 100.0*A.TechnicalAccessCount/A.AccessCount END),
        DistinctPrincipals = ISNULL(A.DistinctPrincipals,0),
        UserReadsDelta = ISNULL(D.UserReadsDelta,0),
        UserUpdatesDelta = ISNULL(D.UserUpdatesDelta,0)
    FROM A
    FULL OUTER JOIN D
      ON D.SchemaName=A.SchemaName
     AND D.TableName=A.TableName
    ORDER BY ISNULL(D.UserReadsDelta,0) DESC, ISNULL(A.AccessCount,0) DESC;
END;
GO

/*=============================================================================
  07. Widok dzienny dla Grafany / raportów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vTableUsageDaily]
AS
SELECT
    I.ServerInstance,
    T.DatabaseName,
    CONVERT(date,A.BucketStartUtc) AS UsageDateUtc,
    A.SchemaName,
    A.ObjectName AS TableName,
    SUM(A.AccessCount) AS AccessCount,
    SUM(CASE WHEN C.IsTechnical=1 THEN A.AccessCount ELSE 0 END) AS TechnicalAccessCount,
    SUM(CASE WHEN C.IsTechnical=0 THEN A.AccessCount ELSE 0 END) AS OtherAccessCount
FROM perf.TableAccessAggregate AS A
JOIN perf.TableUsageTarget AS T ON T.TableUsageTargetId=A.TableUsageTargetId
JOIN dbo.Instance AS I ON I.InstanceId=A.InstanceId
CROSS APPLY
(
    SELECT CONVERT(bit,CASE WHEN EXISTS
    (
        SELECT 1
        FROM perf.TableUsageTechnicalPrincipal AS TP
        WHERE TP.TableUsageTargetId=A.TableUsageTargetId
          AND TP.IsEnabled=1
          AND COALESCE(A.ServerPrincipalName,A.SessionServerPrincipalName,N'') LIKE TP.PrincipalPattern
    ) THEN 1 ELSE 0 END) AS IsTechnical
) AS C
GROUP BY
    I.ServerInstance,T.DatabaseName,CONVERT(date,A.BucketStartUtc),A.SchemaName,A.ObjectName;
GO

/*=============================================================================
  08. Retencja modułu
=============================================================================*/
CREATE OR ALTER PROCEDURE [perf].[usp_PurgeTableUsageHistory]
    @RetentionDays int = 180
AS
BEGIN
    SET NOCOUNT ON;
    IF @RetentionDays < 1
        THROW 51045, 'RetentionDays must be >= 1.', 1;

    DECLARE @Cutoff datetime2(0)=DATEADD(day,-@RetentionDays,SYSUTCDATETIME());

    DELETE FROM perf.TableAccessAggregate WHERE BucketStartUtc < @Cutoff;
    DELETE FROM perf.TableUsageSnapshot WHERE CapturedAt < @Cutoff;
END;
GO
