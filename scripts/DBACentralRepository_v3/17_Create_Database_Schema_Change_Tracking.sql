USE [DBACentralRepository];
GO

/*
===============================================================================
17_Create_Database_Schema_Change_Tracking.sql
===============================================================================
*/

IF OBJECT_ID(N'[db].[DatabaseSchemaCollectionStatus]',N'U') IS NULL
BEGIN
    CREATE TABLE [db].[DatabaseSchemaCollectionStatus]
    (
        [DatabaseSchemaCollectionStatusId] bigint IDENTITY(1,1) NOT NULL,
        [ScanRunId] bigint NOT NULL,
        [InstanceId] bigint NOT NULL,
        [DatabaseName] sysname NOT NULL,
        [StartedAt] datetime2(0) NOT NULL,
        [CompletedAt] datetime2(0) NULL,
        [CollectionStatus] varchar(30) NOT NULL,
        [ObjectCount] int NULL,
        [ColumnCount] int NULL,
        [ErrorMessage] nvarchar(max) NULL,

        CONSTRAINT [PK_DatabaseSchemaCollectionStatus]
            PRIMARY KEY CLUSTERED ([DatabaseSchemaCollectionStatusId]),

        CONSTRAINT [UQ_DatabaseSchemaCollectionStatus]
            UNIQUE ([ScanRunId],[InstanceId],[DatabaseName]),

        CONSTRAINT [FK_DatabaseSchemaCollectionStatus_ScanRun]
            FOREIGN KEY ([ScanRunId])
            REFERENCES [dbo].[ScanRun] ([ScanRunId]),

        CONSTRAINT [FK_DatabaseSchemaCollectionStatus_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId]),

        CONSTRAINT [CK_DatabaseSchemaCollectionStatus_Status]
            CHECK ([CollectionStatus] IN ('STARTED','SUCCESS','FAILED','SKIPPED'))
    );
END;
GO


IF OBJECT_ID(N'[db].[DatabaseObjectSnapshot]',N'U') IS NULL
BEGIN
    CREATE TABLE [db].[DatabaseObjectSnapshot]
    (
        [DatabaseObjectSnapshotId] bigint IDENTITY(1,1) NOT NULL,
        [ScanRunId] bigint NOT NULL,
        [InstanceId] bigint NOT NULL,
        [CapturedAt] datetime2(0) NOT NULL,
        [DatabaseName] sysname NOT NULL,
        [ObjectId] int NOT NULL,
        [SchemaName] sysname NOT NULL,
        [ObjectName] sysname NOT NULL,
        [ObjectType] char(2) NOT NULL,
        [ObjectTypeDesc] nvarchar(60) NOT NULL,
        [CreateDate] datetime NULL,
        [ModifyDate] datetime NULL,
        [DefinitionHash] varbinary(32) NULL,
        [DefinitionText] nvarchar(max) NULL,

        CONSTRAINT [PK_DatabaseObjectSnapshot]
            PRIMARY KEY CLUSTERED ([DatabaseObjectSnapshotId]),

        CONSTRAINT [FK_DatabaseObjectSnapshot_ScanRun]
            FOREIGN KEY ([ScanRunId])
            REFERENCES [dbo].[ScanRun] ([ScanRunId]),

        CONSTRAINT [FK_DatabaseObjectSnapshot_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId])
    );
END;
GO


IF OBJECT_ID(N'[db].[DatabaseColumnSnapshot]',N'U') IS NULL
BEGIN
    CREATE TABLE [db].[DatabaseColumnSnapshot]
    (
        [DatabaseColumnSnapshotId] bigint IDENTITY(1,1) NOT NULL,
        [ScanRunId] bigint NOT NULL,
        [InstanceId] bigint NOT NULL,
        [CapturedAt] datetime2(0) NOT NULL,
        [DatabaseName] sysname NOT NULL,
        [ObjectId] int NOT NULL,
        [SchemaName] sysname NOT NULL,
        [ObjectName] sysname NOT NULL,
        [ObjectType] char(2) NOT NULL,
        [ColumnId] int NOT NULL,
        [ColumnName] sysname NOT NULL,
        [DataTypeName] sysname NOT NULL,
        [MaxLength] smallint NOT NULL,
        [PrecisionValue] tinyint NOT NULL,
        [ScaleValue] tinyint NOT NULL,
        [IsNullable] bit NOT NULL,
        [IsIdentity] bit NOT NULL,
        [IsComputed] bit NOT NULL,
        [CollationName] sysname NULL,
        [DefaultDefinition] nvarchar(max) NULL,
        [ComputedDefinition] nvarchar(max) NULL,
        [ColumnSignatureHash] varbinary(32) NOT NULL,

        CONSTRAINT [PK_DatabaseColumnSnapshot]
            PRIMARY KEY CLUSTERED ([DatabaseColumnSnapshotId]),

        CONSTRAINT [FK_DatabaseColumnSnapshot_ScanRun]
            FOREIGN KEY ([ScanRunId])
            REFERENCES [dbo].[ScanRun] ([ScanRunId]),

        CONSTRAINT [FK_DatabaseColumnSnapshot_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId])
    );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes]
    WHERE [object_id] = OBJECT_ID(N'[db].[DatabaseObjectSnapshot]')
      AND [name] = N'IX_DatabaseObjectSnapshot_Compare'
)
BEGIN
    CREATE INDEX [IX_DatabaseObjectSnapshot_Compare]
        ON [db].[DatabaseObjectSnapshot]
        (
            [InstanceId],[DatabaseName],[ScanRunId],
            [SchemaName],[ObjectName],[ObjectType]
        )
        INCLUDE ([DefinitionHash],[ModifyDate]);
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes]
    WHERE [object_id] = OBJECT_ID(N'[db].[DatabaseColumnSnapshot]')
      AND [name] = N'IX_DatabaseColumnSnapshot_Compare'
)
BEGIN
    CREATE INDEX [IX_DatabaseColumnSnapshot_Compare]
        ON [db].[DatabaseColumnSnapshot]
        (
            [InstanceId],[DatabaseName],[ScanRunId],
            [SchemaName],[ObjectName],[ColumnName]
        )
        INCLUDE ([ColumnSignatureHash],[ColumnId]);
END;
GO


CREATE OR ALTER VIEW [report].[vCurrentDatabaseObjects]
AS
WITH LatestSuccessfulScan AS
(
    SELECT
        [InstanceId],
        [DatabaseName],
        MAX([ScanRunId]) AS [ScanRunId]
    FROM [db].[DatabaseSchemaCollectionStatus]
    WHERE [CollectionStatus] = 'SUCCESS'
    GROUP BY [InstanceId],[DatabaseName]
)
SELECT O.*
FROM [db].[DatabaseObjectSnapshot] AS O
INNER JOIN LatestSuccessfulScan AS L
    ON L.[InstanceId] = O.[InstanceId]
   AND L.[DatabaseName] = O.[DatabaseName]
   AND L.[ScanRunId] = O.[ScanRunId];
GO


CREATE OR ALTER VIEW [report].[vCurrentDatabaseColumns]
AS
WITH LatestSuccessfulScan AS
(
    SELECT
        [InstanceId],
        [DatabaseName],
        MAX([ScanRunId]) AS [ScanRunId]
    FROM [db].[DatabaseSchemaCollectionStatus]
    WHERE [CollectionStatus] = 'SUCCESS'
    GROUP BY [InstanceId],[DatabaseName]
)
SELECT C.*
FROM [db].[DatabaseColumnSnapshot] AS C
INNER JOIN LatestSuccessfulScan AS L
    ON L.[InstanceId] = C.[InstanceId]
   AND L.[DatabaseName] = C.[DatabaseName]
   AND L.[ScanRunId] = C.[ScanRunId];
GO


CREATE OR ALTER VIEW [report].[vDatabaseSchemaChanges]
AS
WITH SuccessfulScans AS
(
    SELECT
        S.[InstanceId],
        S.[DatabaseName],
        S.[ScanRunId],
        ROW_NUMBER() OVER
        (
            PARTITION BY S.[InstanceId],S.[DatabaseName]
            ORDER BY S.[ScanRunId] DESC
        ) AS [ScanRank]
    FROM [db].[DatabaseSchemaCollectionStatus] AS S
    WHERE S.[CollectionStatus] = 'SUCCESS'
),
Pairs AS
(
    SELECT
        C.[InstanceId],
        C.[DatabaseName],
        C.[ScanRunId] AS [CurrentScanRunId],
        P.[ScanRunId] AS [PreviousScanRunId]
    FROM SuccessfulScans AS C
    INNER JOIN SuccessfulScans AS P
        ON P.[InstanceId] = C.[InstanceId]
       AND P.[DatabaseName] = C.[DatabaseName]
       AND P.[ScanRank] = 2
    WHERE C.[ScanRank] = 1
),
ObjectKeys AS
(
    SELECT
        P.[InstanceId],P.[DatabaseName],
        P.[CurrentScanRunId],P.[PreviousScanRunId],
        O.[SchemaName],O.[ObjectName],O.[ObjectType]
    FROM Pairs AS P
    INNER JOIN [db].[DatabaseObjectSnapshot] AS O
        ON O.[InstanceId] = P.[InstanceId]
       AND O.[DatabaseName] = P.[DatabaseName]
       AND O.[ScanRunId] = P.[CurrentScanRunId]

    UNION

    SELECT
        P.[InstanceId],P.[DatabaseName],
        P.[CurrentScanRunId],P.[PreviousScanRunId],
        O.[SchemaName],O.[ObjectName],O.[ObjectType]
    FROM Pairs AS P
    INNER JOIN [db].[DatabaseObjectSnapshot] AS O
        ON O.[InstanceId] = P.[InstanceId]
       AND O.[DatabaseName] = P.[DatabaseName]
       AND O.[ScanRunId] = P.[PreviousScanRunId]
),
ObjectChanges AS
(
    SELECT
        K.[InstanceId],
        K.[DatabaseName],
        K.[CurrentScanRunId],
        K.[PreviousScanRunId],
        N'OBJECT' AS [EntityType],
        K.[SchemaName],
        K.[ObjectName],
        CAST(NULL AS sysname) AS [ChildName],
        CASE
            WHEN OldO.[DatabaseObjectSnapshotId] IS NULL
                THEN N'OBJECT_ADDED'
            WHEN NewO.[DatabaseObjectSnapshotId] IS NULL
                THEN N'OBJECT_REMOVED'
            ELSE N'OBJECT_DEFINITION_CHANGED'
        END AS [ChangeType],
        COALESCE(NewO.[ObjectTypeDesc],OldO.[ObjectTypeDesc])
            AS [ObjectTypeDesc],
        CONVERT(nvarchar(max),OldO.[DefinitionHash],1) AS [OldValue],
        CONVERT(nvarchar(max),NewO.[DefinitionHash],1) AS [NewValue]
    FROM ObjectKeys AS K
    LEFT JOIN [db].[DatabaseObjectSnapshot] AS NewO
        ON NewO.[InstanceId] = K.[InstanceId]
       AND NewO.[DatabaseName] = K.[DatabaseName]
       AND NewO.[ScanRunId] = K.[CurrentScanRunId]
       AND NewO.[SchemaName] = K.[SchemaName]
       AND NewO.[ObjectName] = K.[ObjectName]
       AND NewO.[ObjectType] = K.[ObjectType]
    LEFT JOIN [db].[DatabaseObjectSnapshot] AS OldO
        ON OldO.[InstanceId] = K.[InstanceId]
       AND OldO.[DatabaseName] = K.[DatabaseName]
       AND OldO.[ScanRunId] = K.[PreviousScanRunId]
       AND OldO.[SchemaName] = K.[SchemaName]
       AND OldO.[ObjectName] = K.[ObjectName]
       AND OldO.[ObjectType] = K.[ObjectType]
    WHERE OldO.[DatabaseObjectSnapshotId] IS NULL
       OR NewO.[DatabaseObjectSnapshotId] IS NULL
       OR ISNULL(NewO.[DefinitionHash],0x0)
          <> ISNULL(OldO.[DefinitionHash],0x0)
),
ColumnKeys AS
(
    SELECT
        P.[InstanceId],P.[DatabaseName],
        P.[CurrentScanRunId],P.[PreviousScanRunId],
        C.[SchemaName],C.[ObjectName],C.[ColumnName]
    FROM Pairs AS P
    INNER JOIN [db].[DatabaseColumnSnapshot] AS C
        ON C.[InstanceId] = P.[InstanceId]
       AND C.[DatabaseName] = P.[DatabaseName]
       AND C.[ScanRunId] = P.[CurrentScanRunId]

    UNION

    SELECT
        P.[InstanceId],P.[DatabaseName],
        P.[CurrentScanRunId],P.[PreviousScanRunId],
        C.[SchemaName],C.[ObjectName],C.[ColumnName]
    FROM Pairs AS P
    INNER JOIN [db].[DatabaseColumnSnapshot] AS C
        ON C.[InstanceId] = P.[InstanceId]
       AND C.[DatabaseName] = P.[DatabaseName]
       AND C.[ScanRunId] = P.[PreviousScanRunId]
),
ColumnChanges AS
(
    SELECT
        K.[InstanceId],
        K.[DatabaseName],
        K.[CurrentScanRunId],
        K.[PreviousScanRunId],
        N'COLUMN' AS [EntityType],
        K.[SchemaName],
        K.[ObjectName],
        K.[ColumnName] AS [ChildName],
        CASE
            WHEN OldC.[DatabaseColumnSnapshotId] IS NULL
                THEN N'COLUMN_ADDED'
            WHEN NewC.[DatabaseColumnSnapshotId] IS NULL
                THEN N'COLUMN_REMOVED'
            ELSE N'COLUMN_CHANGED'
        END AS [ChangeType],
        COALESCE(NewC.[ObjectType],OldC.[ObjectType])
            AS [ObjectTypeDesc],
        CONCAT
        (
            OldC.[DataTypeName],N'; length=',OldC.[MaxLength],
            N'; precision=',OldC.[PrecisionValue],
            N'; scale=',OldC.[ScaleValue],
            N'; nullable=',OldC.[IsNullable]
        ) AS [OldValue],
        CONCAT
        (
            NewC.[DataTypeName],N'; length=',NewC.[MaxLength],
            N'; precision=',NewC.[PrecisionValue],
            N'; scale=',NewC.[ScaleValue],
            N'; nullable=',NewC.[IsNullable]
        ) AS [NewValue]
    FROM ColumnKeys AS K
    LEFT JOIN [db].[DatabaseColumnSnapshot] AS NewC
        ON NewC.[InstanceId] = K.[InstanceId]
       AND NewC.[DatabaseName] = K.[DatabaseName]
       AND NewC.[ScanRunId] = K.[CurrentScanRunId]
       AND NewC.[SchemaName] = K.[SchemaName]
       AND NewC.[ObjectName] = K.[ObjectName]
       AND NewC.[ColumnName] = K.[ColumnName]
    LEFT JOIN [db].[DatabaseColumnSnapshot] AS OldC
        ON OldC.[InstanceId] = K.[InstanceId]
       AND OldC.[DatabaseName] = K.[DatabaseName]
       AND OldC.[ScanRunId] = K.[PreviousScanRunId]
       AND OldC.[SchemaName] = K.[SchemaName]
       AND OldC.[ObjectName] = K.[ObjectName]
       AND OldC.[ColumnName] = K.[ColumnName]
    WHERE OldC.[DatabaseColumnSnapshotId] IS NULL
       OR NewC.[DatabaseColumnSnapshotId] IS NULL
       OR NewC.[ColumnSignatureHash] <> OldC.[ColumnSignatureHash]
)
SELECT * FROM ObjectChanges
UNION ALL
SELECT * FROM ColumnChanges;
GO


CREATE OR ALTER VIEW [report].[vDatabaseSchemaChangeSummary]
AS
SELECT
    I.[ServerInstance],
    E.[EnvironmentCode],
    C.[DatabaseName],
    C.[ChangeType],
    COUNT_BIG(*) AS [ChangeCount],
    MAX(C.[CurrentScanRunId]) AS [CurrentScanRunId],
    MAX(C.[PreviousScanRunId]) AS [PreviousScanRunId]
FROM [report].[vDatabaseSchemaChanges] AS C
INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = C.[InstanceId]
LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId]
GROUP BY
    I.[ServerInstance],
    E.[EnvironmentCode],
    C.[DatabaseName],
    C.[ChangeType];
GO


CREATE OR ALTER VIEW [report].[vDatabaseSchemaCollectionStatus]
AS
SELECT
    I.[ServerInstance],
    E.[EnvironmentCode],
    S.*
FROM [db].[DatabaseSchemaCollectionStatus] AS S
INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = S.[InstanceId]
LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId];
GO
