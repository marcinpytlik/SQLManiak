USE [DBACentralRepository];
GO

/*
===============================================================================
Plik: 14_Create_Job_Documentation_Lifecycle.sql
Projekt: DBACentralRepository v3

Cel:
    Obsługa cyklu życia dokumentacji jobów SQL Server Agent:

        MISSING
          -> GENERATED
          -> IN_REVIEW
          -> APPROVED
          -> OUTDATED
          -> RETIRED

Ważne:
    - GENERATED oznacza, że powstał lokalny plik HTML.
    - IN_REVIEW oznacza, że istnieje już strona Confluence.
    - APPROVED oznacza kompletną i zatwierdzoną dokumentację.
    - Dopiero APPROVED ustawia IsDocumented = 1.
===============================================================================
*/


/*=============================================================================
  1. Rozszerzenie [audit].[JobDocumentation]
=============================================================================*/
IF COL_LENGTH(N'[audit].[JobDocumentation]', N'GeneratedFilePath') IS NULL
BEGIN
    ALTER TABLE [audit].[JobDocumentation]
        ADD [GeneratedFilePath] nvarchar(2000) NULL;
END;
GO

IF COL_LENGTH(N'[audit].[JobDocumentation]', N'GeneratedAt') IS NULL
BEGIN
    ALTER TABLE [audit].[JobDocumentation]
        ADD [GeneratedAt] datetime2(0) NULL;
END;
GO

IF COL_LENGTH(N'[audit].[JobDocumentation]', N'PublishedAt') IS NULL
BEGIN
    ALTER TABLE [audit].[JobDocumentation]
        ADD [PublishedAt] datetime2(0) NULL;
END;
GO

IF COL_LENGTH(N'[audit].[JobDocumentation]', N'RetiredAt') IS NULL
BEGIN
    ALTER TABLE [audit].[JobDocumentation]
        ADD [RetiredAt] datetime2(0) NULL;
END;
GO

IF COL_LENGTH(N'[audit].[JobDocumentation]', N'LastTechnicalSyncAt') IS NULL
BEGIN
    ALTER TABLE [audit].[JobDocumentation]
        ADD [LastTechnicalSyncAt] datetime2(0) NULL;
END;
GO

IF COL_LENGTH(N'[audit].[JobDocumentation]', N'PageTitle') IS NULL
BEGIN
    ALTER TABLE [audit].[JobDocumentation]
        ADD [PageTitle] nvarchar(512) NULL;
END;
GO

/*=============================================================================
  2. Synchronizacja rejestru dokumentacji z aktualnymi jobami
=============================================================================*/
CREATE OR ALTER PROCEDURE [audit].[usp_SyncJobDocumentationRegistry]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        Dodanie rekordów dla nowych jobów.
        IsDocumented pozostaje 0.
    */
    INSERT INTO [audit].[JobDocumentation]
    (
        [InstanceId],
        [JobId],
        [JobName],
        [IsDocumented],
        [DocumentationStatus],
        [PageTitle],
        [LastTechnicalSyncAt],
        [Notes]
    )
    SELECT
        J.[InstanceId],
        J.[JobId],
        J.[JobName],
        0,
        'MISSING',
        J.[JobName],
        SYSDATETIME(),
        N'Rekord utworzony automatycznie przez usp_SyncJobDocumentationRegistry.'
    FROM [report].[vCurrentJobs] AS J
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [audit].[JobDocumentation] AS D
        WHERE D.[InstanceId] = J.[InstanceId]
          AND D.[JobId] = J.[JobId]
    );

    /*
        Aktualizacja nazwy i znacznika synchronizacji.
        Zmiana nazwy joba nie usuwa informacji uzupełnionych ręcznie.
    */
    UPDATE D
    SET
        D.[JobName] = J.[JobName],
        D.[PageTitle] =
            CASE
                WHEN NULLIF(D.[PageTitle], N'') IS NULL
                    THEN J.[JobName]
                ELSE D.[PageTitle]
            END,
        D.[LastTechnicalSyncAt] = SYSDATETIME(),
        D.[RetiredAt] = NULL,
        D.[DocumentationStatus] =
            CASE
                WHEN D.[DocumentationStatus] = 'RETIRED'
                    THEN
                        CASE
                            WHEN D.[IsDocumented] = 1 THEN 'APPROVED'
                            WHEN NULLIF(D.[ConfluencePageUrl], N'') IS NOT NULL
                                THEN 'IN_REVIEW'
                            WHEN NULLIF(D.[GeneratedFilePath], N'') IS NOT NULL
                                THEN 'GENERATED'
                            ELSE 'MISSING'
                        END
                ELSE D.[DocumentationStatus]
            END
    FROM [audit].[JobDocumentation] AS D
    INNER JOIN [report].[vCurrentJobs] AS J
        ON J.[InstanceId] = D.[InstanceId]
       AND J.[JobId] = D.[JobId];

    /*
        Joby nieobecne w bieżącym katalogu otrzymują RETIRED.
        Dokumentacja nie jest usuwana.
    */
    UPDATE D
    SET
        D.[DocumentationStatus] = 'RETIRED',
        D.[IsDocumented] = 0,
        D.[RetiredAt] = COALESCE(D.[RetiredAt], SYSDATETIME())
    FROM [audit].[JobDocumentation] AS D
    WHERE D.[DocumentationStatus] <> 'RETIRED'
      AND NOT EXISTS
      (
          SELECT 1
          FROM [report].[vCurrentJobs] AS J
          WHERE J.[InstanceId] = D.[InstanceId]
            AND J.[JobId] = D.[JobId]
      );

    SELECT
        SUM(CASE WHEN [DocumentationStatus] = 'MISSING' THEN 1 ELSE 0 END)
            AS [MissingCount],
        SUM(CASE WHEN [DocumentationStatus] = 'GENERATED' THEN 1 ELSE 0 END)
            AS [GeneratedCount],
        SUM(CASE WHEN [DocumentationStatus] = 'IN_REVIEW' THEN 1 ELSE 0 END)
            AS [InReviewCount],
        SUM(CASE WHEN [DocumentationStatus] = 'APPROVED' THEN 1 ELSE 0 END)
            AS [ApprovedCount],
        SUM(CASE WHEN [DocumentationStatus] = 'OUTDATED' THEN 1 ELSE 0 END)
            AS [OutdatedCount],
        SUM(CASE WHEN [DocumentationStatus] = 'RETIRED' THEN 1 ELSE 0 END)
            AS [RetiredCount]
    FROM [audit].[JobDocumentation];
END;
GO

/*=============================================================================
  3. Oznaczenie wygenerowania pliku HTML
=============================================================================*/
CREATE OR ALTER PROCEDURE [audit].[usp_MarkJobDocumentationGenerated]
    @InstanceId bigint,
    @JobId uniqueidentifier,
    @GeneratedFilePath nvarchar(2000),
    @PageTitle nvarchar(512)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE [audit].[JobDocumentation]
    SET
        [GeneratedFilePath] = @GeneratedFilePath,
        [GeneratedAt] = SYSDATETIME(),
        [LastTechnicalSyncAt] = SYSDATETIME(),
        [PageTitle] = @PageTitle,
        [DocumentationStatus] =
            CASE
                WHEN [DocumentationStatus] IN ('APPROVED', 'IN_REVIEW', 'OUTDATED')
                    THEN [DocumentationStatus]
                ELSE 'GENERATED'
            END,
        [IsDocumented] =
            CASE
                WHEN [DocumentationStatus] = 'APPROVED'
                    THEN 1
                ELSE 0
            END
    WHERE [InstanceId] = @InstanceId
      AND [JobId] = @JobId;

    IF @@ROWCOUNT = 0
    BEGIN
        THROW 51001,
              'Nie znaleziono joba w [audit].[JobDocumentation]. Uruchom najpierw usp_SyncJobDocumentationRegistry.',
              1;
    END;
END;
GO

/*=============================================================================
  4. Rejestracja opublikowanej strony Confluence
=============================================================================*/
CREATE OR ALTER PROCEDURE [audit].[usp_RegisterJobConfluencePage]
    @InstanceId bigint,
    @JobId uniqueidentifier,
    @ConfluencePageId nvarchar(100) = NULL,
    @ConfluencePageUrl nvarchar(2000),
    @PageTitle nvarchar(512) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@ConfluencePageUrl)), N'') IS NULL
    BEGIN
        THROW 51002, 'ConfluencePageUrl jest wymagany.', 1;
    END;

    UPDATE [audit].[JobDocumentation]
    SET
        [ConfluencePageId] = @ConfluencePageId,
        [ConfluencePageUrl] = @ConfluencePageUrl,
        [PageTitle] = COALESCE(NULLIF(@PageTitle, N''), [PageTitle], [JobName]),
        [PublishedAt] = COALESCE([PublishedAt], SYSDATETIME()),
        [DocumentationStatus] = 'IN_REVIEW',
        [IsDocumented] = 0,
        [RetiredAt] = NULL
    WHERE [InstanceId] = @InstanceId
      AND [JobId] = @JobId;

    IF @@ROWCOUNT = 0
    BEGIN
        THROW 51003, 'Nie znaleziono joba w rejestrze dokumentacji.', 1;
    END;
END;
GO

/*=============================================================================
  5. Zatwierdzenie kompletnej dokumentacji
=============================================================================*/
CREATE OR ALTER PROCEDURE [audit].[usp_ApproveJobDocumentation]
    @InstanceId bigint,
    @JobId uniqueidentifier,
    @TechnicalOwner nvarchar(256),
    @BusinessOwner nvarchar(256) = NULL,
    @Criticality varchar(20),
    @ReviewedBy nvarchar(256),
    @Notes nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@TechnicalOwner)), N'') IS NULL
        THROW 51004, 'TechnicalOwner jest wymagany.', 1;

    IF NULLIF(LTRIM(RTRIM(@Criticality)), '') IS NULL
        THROW 51005, 'Criticality jest wymagane.', 1;

    IF NULLIF(LTRIM(RTRIM(@ReviewedBy)), N'') IS NULL
        THROW 51006, 'ReviewedBy jest wymagany.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [audit].[JobDocumentation]
        WHERE [InstanceId] = @InstanceId
          AND [JobId] = @JobId
          AND NULLIF([ConfluencePageUrl], N'') IS NOT NULL
    )
    BEGIN
        THROW 51007,
              'Nie można zatwierdzić dokumentacji bez adresu strony Confluence.',
              1;
    END;

    UPDATE [audit].[JobDocumentation]
    SET
        [TechnicalOwner] = @TechnicalOwner,
        [BusinessOwner] = @BusinessOwner,
        [Criticality] = UPPER(@Criticality),
        [ReviewedBy] = @ReviewedBy,
        [LastReviewedAt] = SYSDATETIME(),
        [DocumentationStatus] = 'APPROVED',
        [IsDocumented] = 1,
        [Notes] =
            CASE
                WHEN @Notes IS NULL THEN [Notes]
                ELSE @Notes
            END,
        [RetiredAt] = NULL
    WHERE [InstanceId] = @InstanceId
      AND [JobId] = @JobId;
END;
GO

/*=============================================================================
  6. Oznaczenie dokumentacji jako nieaktualnej
=============================================================================*/
CREATE OR ALTER PROCEDURE [audit].[usp_MarkJobDocumentationOutdated]
    @InstanceId bigint,
    @JobId uniqueidentifier,
    @Reason nvarchar(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [audit].[JobDocumentation]
    SET
        [DocumentationStatus] = 'OUTDATED',
        [IsDocumented] = 0,
        [Notes] =
            CASE
                WHEN NULLIF(@Reason, N'') IS NULL
                    THEN [Notes]
                WHEN NULLIF([Notes], N'') IS NULL
                    THEN @Reason
                ELSE CONCAT([Notes], CHAR(13), CHAR(10), @Reason)
            END
    WHERE [InstanceId] = @InstanceId
      AND [JobId] = @JobId;

    IF @@ROWCOUNT = 0
        THROW 51008, 'Nie znaleziono joba w rejestrze dokumentacji.', 1;
END;
GO

/*=============================================================================
  7. Widok rejestru stron dokumentacyjnych
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobDocumentationPages]
AS
SELECT
    J.[InstanceId],
    J.[ServerInstance],
    J.[EnvironmentCode],
    J.[JobId],
    J.[JobName],
    J.[CategoryName],
    J.[OwnerName],
    J.[Description],
    J.[IsEnabled],
    J.[DateCreated],
    J.[DateModified],
    J.[OperatorName],
    J.[NotifyLevelEmail],
    J.[StepCount],
    J.[ScheduleCount],
    J.[ExecutionMode],

    D.[JobDocumentationId],
    D.[PageTitle],
    D.[GeneratedFilePath],
    D.[GeneratedAt],
    D.[ConfluencePageId],
    D.[ConfluencePageUrl],
    D.[PublishedAt],
    D.[TechnicalOwner],
    D.[BusinessOwner],
    D.[Criticality],
    D.[IsDocumented],
    D.[DocumentationStatus],
    D.[LastReviewedAt],
    D.[ReviewedBy],
    D.[LastTechnicalSyncAt],
    D.[RetiredAt],
    D.[Notes],

    CASE
        WHEN D.[JobDocumentationId] IS NULL
            THEN 'MISSING'
        WHEN D.[DocumentationStatus] = 'RETIRED'
            THEN 'RETIRED'
        WHEN D.[IsDocumented] = 1
         AND D.[DocumentationStatus] = 'APPROVED'
         AND NULLIF(D.[ConfluencePageUrl], N'') IS NOT NULL
            THEN 'APPROVED'
        WHEN D.[DocumentationStatus] = 'OUTDATED'
            THEN 'OUTDATED'
        WHEN NULLIF(D.[ConfluencePageUrl], N'') IS NOT NULL
            THEN 'IN_REVIEW'
        WHEN NULLIF(D.[GeneratedFilePath], N'') IS NOT NULL
            THEN 'GENERATED'
        ELSE 'MISSING'
    END AS [EffectiveDocumentationStatus]
FROM [report].[vJobInventory] AS J
LEFT JOIN [audit].[JobDocumentation] AS D
    ON D.[InstanceId] = J.[InstanceId]
   AND D.[JobId] = J.[JobId];
GO

/*=============================================================================
  8. Widok danych technicznych do generatora stron
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobDocumentationExport]
AS
SELECT
    P.*,
    C.[CategoryCode] AS [FunctionalCategoryCode],
    C.[CategoryName] AS [FunctionalCategoryName]
FROM [report].[vJobDocumentationPages] AS P
LEFT JOIN [report].[vJobCategoryMembership] AS C
    ON C.[InstanceId] = P.[InstanceId]
   AND C.[JobId] = P.[JobId];
GO

/*=============================================================================
  9. Podsumowanie cyklu życia dokumentacji
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobDocumentationLifecycleSummary]
AS
SELECT
    [EnvironmentCode],
    [ServerInstance],
    [EffectiveDocumentationStatus],
    COUNT(*) AS [JobCount]
FROM [report].[vJobDocumentationPages]
GROUP BY
    [EnvironmentCode],
    [ServerInstance],
    [EffectiveDocumentationStatus];
GO

/*=============================================================================
  10. Reguła JOB_NOT_DOCUMENTED — zaostrzenie kryterium
=============================================================================*/
/*
    Oryginalny audyt sprawdza:
        IsDocumented = 1
        oraz ConfluencePageUrl nie jest pusty.

    Po wdrożeniu cyklu życia zalecamy dodatkowo wymagać:
        DocumentationStatus = 'APPROVED'

    Poniższa procedura pomocnicza pokazuje joby, które nadal powinny
    otrzymywać finding JOB_NOT_DOCUMENTED.
*/
CREATE OR ALTER VIEW [report].[vJobsStillNotDocumented]
AS
SELECT
    P.*
FROM [report].[vJobDocumentationPages] AS P
WHERE
       P.[IsDocumented] = 0
    OR P.[DocumentationStatus] <> 'APPROVED'
    OR NULLIF(P.[ConfluencePageUrl], N'') IS NULL;
GO

/*=============================================================================
  11. Opisy obiektów
=============================================================================*/
IF OBJECT_ID(N'[dbo].[usp_SetDescription]', N'P') IS NOT NULL
BEGIN
    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'audit',
        @ObjectName = N'usp_SyncJobDocumentationRegistry',
        @ObjectType = 'PROCEDURE',
        @Description = N'Synchronizuje rejestr dokumentacji z aktualnymi jobami i oznacza usunięte joby jako RETIRED.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'audit',
        @ObjectName = N'usp_MarkJobDocumentationGenerated',
        @ObjectType = 'PROCEDURE',
        @Description = N'Rejestruje lokalny plik HTML i nadaje dokumentacji status GENERATED.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'audit',
        @ObjectName = N'usp_RegisterJobConfluencePage',
        @ObjectType = 'PROCEDURE',
        @Description = N'Rejestruje stronę Confluence i nadaje dokumentacji status IN_REVIEW.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'audit',
        @ObjectName = N'usp_ApproveJobDocumentation',
        @ObjectType = 'PROCEDURE',
        @Description = N'Zatwierdza kompletną dokumentację joba i ustawia IsDocumented=1.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobDocumentationPages',
        @ObjectType = 'VIEW',
        @Description = N'Rejestr stron dokumentujących poszczególne joby SQL Server Agent.';
END;
GO

/*=============================================================================
  12. Pierwsza synchronizacja i test
=============================================================================*/
EXEC [audit].[usp_SyncJobDocumentationRegistry];
GO

SELECT
    [EnvironmentCode],
    [ServerInstance],
    [EffectiveDocumentationStatus],
    [JobCount]
FROM [report].[vJobDocumentationLifecycleSummary]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [EffectiveDocumentationStatus];
GO
