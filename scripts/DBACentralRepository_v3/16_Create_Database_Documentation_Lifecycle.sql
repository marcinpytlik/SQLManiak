USE [DBACentralRepository];
GO

/*
===============================================================================
16_Create_Database_Documentation_Lifecycle.sql
===============================================================================
*/

IF OBJECT_ID(N'[db].[DatabaseDocumentation]', N'U') IS NULL
BEGIN
    CREATE TABLE [db].[DatabaseDocumentation]
    (
        [DatabaseDocumentationId] bigint IDENTITY(1,1) NOT NULL,
        [InstanceId] bigint NOT NULL,
        [DatabaseName] sysname NOT NULL,
        [PageTitle] nvarchar(512) NULL,
        [ConfluencePageId] nvarchar(100) NULL,
        [ConfluencePageUrl] nvarchar(2000) NULL,
        [ApplicationName] nvarchar(256) NULL,
        [PurposeDescription] nvarchar(max) NULL,
        [TechnicalOwner] nvarchar(256) NULL,
        [BusinessOwner] nvarchar(256) NULL,
        [SupportGroup] nvarchar(256) NULL,
        [Criticality] varchar(20) NULL,
        [RpoMinutes] int NULL,
        [RtoMinutes] int NULL,
        [DataClassification] nvarchar(100) NULL,
        [RetentionDescription] nvarchar(1000) NULL,
        [HaRequirement] nvarchar(1000) NULL,
        [DrRequirement] nvarchar(1000) NULL,
        [RestoreProcedure] nvarchar(max) NULL,
        [OperationalNotes] nvarchar(max) NULL,
        [IsDocumented] bit NOT NULL
            CONSTRAINT [DF_DatabaseDocumentation_IsDocumented] DEFAULT (0),
        [DocumentationStatus] varchar(30) NOT NULL
            CONSTRAINT [DF_DatabaseDocumentation_Status] DEFAULT ('MISSING'),
        [GeneratedAt] datetime2(0) NULL,
        [PublishedAt] datetime2(0) NULL,
        [LastReviewedAt] datetime2(0) NULL,
        [ReviewedBy] nvarchar(256) NULL,
        [ModifiedAt] datetime2(0) NOT NULL
            CONSTRAINT [DF_DatabaseDocumentation_ModifiedAt] DEFAULT (SYSDATETIME()),

        CONSTRAINT [PK_DatabaseDocumentation]
            PRIMARY KEY CLUSTERED ([DatabaseDocumentationId]),

        CONSTRAINT [UQ_DatabaseDocumentation]
            UNIQUE ([InstanceId], [DatabaseName]),

        CONSTRAINT [FK_DatabaseDocumentation_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId]),

        CONSTRAINT [CK_DatabaseDocumentation_Status]
            CHECK
            (
                [DocumentationStatus] IN
                (
                    'MISSING','GENERATED','IN_REVIEW',
                    'APPROVED','OUTDATED','RETIRED'
                )
            )
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes]
    WHERE [object_id] = OBJECT_ID(N'[db].[DatabaseDocumentation]')
      AND [name] = N'IX_DatabaseDocumentation_Status'
)
BEGIN
    CREATE INDEX [IX_DatabaseDocumentation_Status]
        ON [db].[DatabaseDocumentation]
        (
            [DocumentationStatus],
            [InstanceId],
            [DatabaseName]
        )
        INCLUDE
        (
            [ConfluencePageUrl],
            [TechnicalOwner],
            [BusinessOwner],
            [Criticality],
            [LastReviewedAt]
        );
END;
GO


CREATE OR ALTER PROCEDURE [db].[usp_SyncDatabaseDocumentationRegistry]
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [db].[DatabaseDocumentation]
    (
        [InstanceId],
        [DatabaseName],
        [PageTitle],
        [DocumentationStatus],
        [IsDocumented]
    )
    SELECT
        D.[InstanceId],
        D.[DatabaseName],
        CONCAT(D.[ServerInstance], N' - ', D.[DatabaseName]),
        'MISSING',
        0
    FROM [report].[vCurrentDatabases] AS D
    WHERE D.[DatabaseName] NOT IN
    (
        N'master',N'model',N'msdb',N'tempdb'
    )
      AND NOT EXISTS
      (
          SELECT 1
          FROM [db].[DatabaseDocumentation] AS X
          WHERE X.[InstanceId] = D.[InstanceId]
            AND X.[DatabaseName] = D.[DatabaseName]
      );

    UPDATE DD
    SET
        [DocumentationStatus] = 'RETIRED',
        [IsDocumented] = 0,
        [ModifiedAt] = SYSDATETIME()
    FROM [db].[DatabaseDocumentation] AS DD
    WHERE DD.[DocumentationStatus] <> 'RETIRED'
      AND NOT EXISTS
      (
          SELECT 1
          FROM [report].[vCurrentDatabases] AS D
          WHERE D.[InstanceId] = DD.[InstanceId]
            AND D.[DatabaseName] = DD.[DatabaseName]
      );

    UPDATE DD
    SET
        [DocumentationStatus] = 'MISSING',
        [ModifiedAt] = SYSDATETIME()
    FROM [db].[DatabaseDocumentation] AS DD
    WHERE DD.[DocumentationStatus] = 'RETIRED'
      AND EXISTS
      (
          SELECT 1
          FROM [report].[vCurrentDatabases] AS D
          WHERE D.[InstanceId] = DD.[InstanceId]
            AND D.[DatabaseName] = DD.[DatabaseName]
      );
END;
GO


CREATE OR ALTER PROCEDURE [db].[usp_MarkDatabaseDocumentationGenerated]
    @InstanceId bigint,
    @DatabaseName sysname,
    @PageTitle nvarchar(512)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC [db].[usp_SyncDatabaseDocumentationRegistry];

    UPDATE [db].[DatabaseDocumentation]
    SET
        [PageTitle] = @PageTitle,
        [GeneratedAt] = SYSDATETIME(),
        [DocumentationStatus] =
            CASE
                WHEN [DocumentationStatus] = 'APPROVED'
                    THEN 'APPROVED'
                ELSE 'GENERATED'
            END,
        [ModifiedAt] = SYSDATETIME()
    WHERE [InstanceId] = @InstanceId
      AND [DatabaseName] = @DatabaseName;
END;
GO


CREATE OR ALTER PROCEDURE [db].[usp_RegisterDatabaseConfluencePage]
    @InstanceId bigint,
    @DatabaseName sysname,
    @ConfluencePageId nvarchar(100),
    @ConfluencePageUrl nvarchar(2000),
    @PageTitle nvarchar(512)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC [db].[usp_SyncDatabaseDocumentationRegistry];

    UPDATE [db].[DatabaseDocumentation]
    SET
        [ConfluencePageId] = @ConfluencePageId,
        [ConfluencePageUrl] = @ConfluencePageUrl,
        [PageTitle] = @PageTitle,
        [PublishedAt] = SYSDATETIME(),
        [DocumentationStatus] = 'IN_REVIEW',
        [IsDocumented] = 0,
        [ModifiedAt] = SYSDATETIME()
    WHERE [InstanceId] = @InstanceId
      AND [DatabaseName] = @DatabaseName;
END;
GO


CREATE OR ALTER PROCEDURE [db].[usp_ApproveDatabaseDocumentation]
    @InstanceId bigint,
    @DatabaseName sysname,
    @TechnicalOwner nvarchar(256),
    @BusinessOwner nvarchar(256) = NULL,
    @Criticality varchar(20) = NULL,
    @RpoMinutes int = NULL,
    @RtoMinutes int = NULL,
    @ReviewedBy nvarchar(256)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [db].[DatabaseDocumentation]
        WHERE [InstanceId] = @InstanceId
          AND [DatabaseName] = @DatabaseName
          AND NULLIF([ConfluencePageUrl], N'') IS NOT NULL
    )
    BEGIN
        THROW 51000,
            'Dokumentacja nie ma zarejestrowanej strony Confluence.',
            1;
    END;

    UPDATE [db].[DatabaseDocumentation]
    SET
        [TechnicalOwner] = @TechnicalOwner,
        [BusinessOwner] = COALESCE(@BusinessOwner,[BusinessOwner]),
        [Criticality] = COALESCE(@Criticality,[Criticality]),
        [RpoMinutes] = COALESCE(@RpoMinutes,[RpoMinutes]),
        [RtoMinutes] = COALESCE(@RtoMinutes,[RtoMinutes]),
        [DocumentationStatus] = 'APPROVED',
        [IsDocumented] = 1,
        [LastReviewedAt] = SYSDATETIME(),
        [ReviewedBy] = @ReviewedBy,
        [ModifiedAt] = SYSDATETIME()
    WHERE [InstanceId] = @InstanceId
      AND [DatabaseName] = @DatabaseName;
END;
GO


CREATE OR ALTER PROCEDURE [db].[usp_MarkDatabaseDocumentationOutdated]
    @InstanceId bigint,
    @DatabaseName sysname,
    @Reason nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [db].[DatabaseDocumentation]
    SET
        [DocumentationStatus] = 'OUTDATED',
        [IsDocumented] = 0,
        [OperationalNotes] =
            CONCAT
            (
                COALESCE([OperationalNotes] + CHAR(13) + CHAR(10),N''),
                CONVERT(nvarchar(19),SYSDATETIME(),120),
                N' - ',
                COALESCE(@Reason,N'Wykryto zmianę struktury.')
            ),
        [ModifiedAt] = SYSDATETIME()
    WHERE [InstanceId] = @InstanceId
      AND [DatabaseName] = @DatabaseName
      AND [DocumentationStatus] <> 'RETIRED';
END;
GO


CREATE OR ALTER VIEW [report].[vDatabaseDocumentationPages]
AS
SELECT
    D.[ServerInstance],
    D.[EnvironmentCode],
    D.[InstanceId],
    D.[DatabaseId],
    D.[DatabaseName],
    D.[StateDesc],
    D.[UserAccessDesc],
    D.[RecoveryModelDesc],
    D.[CompatibilityLevel],
    D.[CollationName],
    D.[OwnerName],
    D.[CreateDate],
    D.[PageVerifyOptionDesc],
    D.[IsAutoCloseOn],
    D.[IsAutoShrinkOn],
    D.[IsAutoCreateStatsOn],
    D.[IsAutoUpdateStatsOn],
    D.[IsAutoUpdateStatsAsyncOn],
    D.[IsReadCommittedSnapshotOn],
    D.[SnapshotIsolationStateDesc],
    D.[IsTrustworthyOn],
    D.[IsDbChainingOn],
    D.[TargetRecoveryTimeSeconds],
    D.[IsQueryStoreOn],
    D.[IsEncrypted],
    D.[DataSizeMB],
    D.[LogSizeMB],
    D.[TotalSizeMB],
    DD.[DatabaseDocumentationId],
    COALESCE
    (
        NULLIF(DD.[PageTitle],N''),
        CONCAT(D.[ServerInstance],N' - ',D.[DatabaseName])
    ) AS [PageTitle],
    DD.[ConfluencePageId],
    DD.[ConfluencePageUrl],
    DD.[ApplicationName],
    DD.[PurposeDescription],
    DD.[TechnicalOwner],
    DD.[BusinessOwner],
    DD.[SupportGroup],
    DD.[Criticality],
    DD.[RpoMinutes],
    DD.[RtoMinutes],
    DD.[DataClassification],
    DD.[RetentionDescription],
    DD.[HaRequirement],
    DD.[DrRequirement],
    DD.[RestoreProcedure],
    DD.[OperationalNotes],
    ISNULL(DD.[IsDocumented],0) AS [IsDocumented],
    COALESCE(DD.[DocumentationStatus],'MISSING')
        AS [DocumentationStatus],
    DD.[GeneratedAt],
    DD.[PublishedAt],
    DD.[LastReviewedAt],
    DD.[ReviewedBy]
FROM [report].[vCurrentDatabases] AS D
LEFT JOIN [db].[DatabaseDocumentation] AS DD
    ON DD.[InstanceId] = D.[InstanceId]
   AND DD.[DatabaseName] = D.[DatabaseName];
GO


CREATE OR ALTER VIEW [report].[vDatabasesStillNotDocumented]
AS
SELECT *
FROM [report].[vDatabaseDocumentationPages]
WHERE [DatabaseName] NOT IN
(
    N'master',N'model',N'msdb',N'tempdb'
)
  AND
  (
      [IsDocumented] = 0
      OR [DocumentationStatus] <> 'APPROVED'
      OR NULLIF([ConfluencePageUrl],N'') IS NULL
  );
GO


CREATE OR ALTER VIEW [report].[vDatabaseDocumentationLifecycleSummary]
AS
SELECT
    [EnvironmentCode],
    [DocumentationStatus],
    COUNT_BIG(*) AS [DatabaseCount]
FROM [report].[vDatabaseDocumentationPages]
WHERE [DatabaseName] NOT IN
(
    N'master',N'model',N'msdb',N'tempdb'
)
GROUP BY
    [EnvironmentCode],
    [DocumentationStatus];
GO

EXEC [db].[usp_SyncDatabaseDocumentationRegistry];
GO
