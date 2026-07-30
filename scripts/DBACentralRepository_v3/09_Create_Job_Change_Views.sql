USE [DBACentralRepository];
GO

/*
===============================================================================
Plik: 11_Create_Job_Change_Views.sql
Projekt: DBACentralRepository v3
Cel:
    Utworzenie widoków raportowych dla sekcji Confluence:
    "Zmiany i cykl życia jobów SQL Server Agent".

Źródło:
    [audit].[JobChange]

Założenia:
    - tabela [audit].[JobChange] istnieje,
    - tabela [dbo].[Instance] istnieje,
    - tabela [dbo].[Environment] istnieje,
    - widok [report].[vCurrentJobs] istnieje.

Zgodność:
    - SQL Server 2016 SP1+ / 2019 / 2022.
===============================================================================
*/


/*=============================================================================
  1. Wszystkie wykryte zmiany jobów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChanges]
AS
SELECT
    C.[JobChangeId],
    C.[ScanRunId],
    C.[InstanceId],
    I.[ServerInstance],
    E.[EnvironmentCode],
    C.[DetectedAt],
    C.[JobId],
    C.[JobName],
    C.[ChangeType],
    C.[ObjectType],
    C.[ObjectName],
    C.[PropertyName],
    C.[OldValue],
    C.[NewValue],
    C.[IsAuthorized],
    C.[TicketNumber],

    CASE
        WHEN C.[IsAuthorized] = 1
            THEN N'AUTHORIZED'
        WHEN C.[IsAuthorized] = 0
            THEN N'UNAUTHORIZED'
        ELSE N'NOT_REVIEWED'
    END AS [AuthorizationStatus],

    CASE
        WHEN UPPER(ISNULL(C.[ChangeType], N'')) IN
             (
                 N'ADDED',
                 N'CREATE',
                 N'CREATED',
                 N'NEW'
             )
            THEN N'ADDED'

        WHEN UPPER(ISNULL(C.[ChangeType], N'')) IN
             (
                 N'REMOVED',
                 N'DELETED',
                 N'DROP',
                 N'DROPPED'
             )
            THEN N'REMOVED'

        WHEN UPPER(ISNULL(C.[ChangeType], N'')) IN
             (
                 N'MODIFIED',
                 N'CHANGED',
                 N'UPDATED'
             )
            THEN N'MODIFIED'

        ELSE N'OTHER'
    END AS [NormalizedChangeType],

    CASE
        WHEN UPPER(ISNULL(C.[PropertyName], N'')) LIKE N'%OWNER%'
            THEN N'OWNER'

        WHEN UPPER(ISNULL(C.[PropertyName], N'')) IN
             (
                 N'ISENABLED',
                 N'ENABLED',
                 N'STATUS'
             )
            THEN N'STATUS'

        WHEN UPPER(ISNULL(C.[ObjectType], N'')) IN
             (
                 N'JOB_STEP',
                 N'STEP'
             )
            THEN N'STEP'

        WHEN UPPER(ISNULL(C.[PropertyName], N'')) LIKE N'%COMMAND%'
            THEN N'COMMAND'

        WHEN UPPER(ISNULL(C.[ObjectType], N'')) IN
             (
                 N'JOB_SCHEDULE',
                 N'SCHEDULE'
             )
            THEN N'SCHEDULE'

        WHEN UPPER(ISNULL(C.[PropertyName], N'')) LIKE N'%SCHEDULE%'
            THEN N'SCHEDULE'

        WHEN UPPER(ISNULL(C.[PropertyName], N'')) LIKE N'%OPERATOR%'
            THEN N'OPERATOR'

        WHEN UPPER(ISNULL(C.[PropertyName], N'')) LIKE N'%NOTIFY%'
          OR UPPER(ISNULL(C.[PropertyName], N'')) LIKE N'%NOTIFICATION%'
            THEN N'NOTIFICATION'

        WHEN UPPER(ISNULL(C.[PropertyName], N'')) LIKE N'%PROXY%'
            THEN N'PROXY'

        WHEN UPPER(ISNULL(C.[PropertyName], N'')) LIKE N'%CATEGORY%'
            THEN N'CATEGORY'

        WHEN UPPER(ISNULL(C.[PropertyName], N'')) LIKE N'%DESCRIPTION%'
            THEN N'DESCRIPTION'

        ELSE N'OTHER'
    END AS [ChangeArea]
FROM [audit].[JobChange] AS C
INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = C.[InstanceId]
LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId];
GO

/*=============================================================================
  2. Nowe joby
=============================================================================*/
CREATE OR ALTER VIEW [report].[vNewJobs]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [NormalizedChangeType] = N'ADDED'
  AND UPPER(ISNULL([ObjectType], N'')) IN
      (
          N'JOB',
          N'SQL_AGENT_JOB'
      );
GO

/*=============================================================================
  3. Usunięte joby
=============================================================================*/
CREATE OR ALTER VIEW [report].[vRemovedJobs]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [NormalizedChangeType] = N'REMOVED'
  AND UPPER(ISNULL([ObjectType], N'')) IN
      (
          N'JOB',
          N'SQL_AGENT_JOB'
      );
GO

/*=============================================================================
  4. Zmodyfikowane joby
=============================================================================*/
CREATE OR ALTER VIEW [report].[vModifiedJobs]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [NormalizedChangeType] = N'MODIFIED';
GO

/*=============================================================================
  5. Zmiany właścicieli jobów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobOwnerChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'OWNER';
GO

/*=============================================================================
  6. Zmiany statusu aktywności jobów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobStatusChanges]
AS
SELECT
    *,
    CASE
        WHEN UPPER(ISNULL([NewValue], N'')) IN
             (
                 N'1',
                 N'TRUE',
                 N'ENABLED',
                 N'ACTIVE'
             )
            THEN N'ENABLED'

        WHEN UPPER(ISNULL([NewValue], N'')) IN
             (
                 N'0',
                 N'FALSE',
                 N'DISABLED',
                 N'INACTIVE'
             )
            THEN N'DISABLED'

        ELSE N'UNKNOWN'
    END AS [NewStatus]
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'STATUS';
GO

/*=============================================================================
  7. Joby włączone
=============================================================================*/
CREATE OR ALTER VIEW [report].[vEnabledJobChanges]
AS
SELECT *
FROM [report].[vJobStatusChanges]
WHERE [NewStatus] = N'ENABLED';
GO

/*=============================================================================
  8. Joby wyłączone
=============================================================================*/
CREATE OR ALTER VIEW [report].[vDisabledJobChanges]
AS
SELECT *
FROM [report].[vJobStatusChanges]
WHERE [NewStatus] = N'DISABLED';
GO

/*=============================================================================
  9. Zmiany kroków jobów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobStepChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'STEP'
   OR UPPER(ISNULL([ObjectType], N'')) IN
      (
          N'JOB_STEP',
          N'STEP'
      );
GO

/*=============================================================================
  10. Zmiany komend w krokach jobów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobCommandChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'COMMAND'
   OR
   (
       UPPER(ISNULL([ObjectType], N'')) IN
       (
           N'JOB_STEP',
           N'STEP'
       )
       AND UPPER(ISNULL([PropertyName], N'')) LIKE N'%COMMAND%'
   );
GO

/*=============================================================================
  11. Zmiany harmonogramów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobScheduleChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'SCHEDULE'
   OR UPPER(ISNULL([ObjectType], N'')) IN
      (
          N'JOB_SCHEDULE',
          N'SCHEDULE'
      );
GO

/*=============================================================================
  12. Zmiany operatorów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobOperatorChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'OPERATOR';
GO

/*=============================================================================
  13. Zmiany konfiguracji powiadomień
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobNotificationChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'NOTIFICATION';
GO

/*=============================================================================
  14. Zmiany proxy
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobProxyChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'PROXY';
GO

/*=============================================================================
  15. Zmiany kategorii
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobCategoryChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'CATEGORY';
GO

/*=============================================================================
  16. Zmiany opisów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobDescriptionChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [ChangeArea] = N'DESCRIPTION';
GO

/*=============================================================================
  17. Zmiany autoryzowane
=============================================================================*/
CREATE OR ALTER VIEW [report].[vAuthorizedJobChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [AuthorizationStatus] = N'AUTHORIZED';
GO

/*=============================================================================
  18. Zmiany nieautoryzowane
=============================================================================*/
CREATE OR ALTER VIEW [report].[vUnauthorizedJobChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [AuthorizationStatus] = N'UNAUTHORIZED';
GO

/*=============================================================================
  19. Zmiany niezweryfikowane
=============================================================================*/
CREATE OR ALTER VIEW [report].[vUnreviewedJobChanges]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [AuthorizationStatus] = N'NOT_REVIEWED';
GO

/*=============================================================================
  20. Zmiany bez numeru zgłoszenia
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChangesWithoutTicket]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE NULLIF(LTRIM(RTRIM([TicketNumber])), N'') IS NULL;
GO

/*=============================================================================
  21. Zmiany z numerem zgłoszenia
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChangesWithTicket]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE NULLIF(LTRIM(RTRIM([TicketNumber])), N'') IS NOT NULL;
GO

/*=============================================================================
  22. Zmiany z ostatnich 24 godzin
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChangesLast24Hours]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [DetectedAt] >= DATEADD(hour, -24, SYSDATETIME());
GO

/*=============================================================================
  23. Zmiany z ostatnich 7 dni
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChangesLast7Days]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [DetectedAt] >= DATEADD(day, -7, SYSDATETIME());
GO

/*=============================================================================
  24. Zmiany z ostatnich 30 dni
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChangesLast30Days]
AS
SELECT *
FROM [report].[vJobChanges]
WHERE [DetectedAt] >= DATEADD(day, -30, SYSDATETIME());
GO

/*=============================================================================
  25. Zmiany krytyczne operacyjnie
=============================================================================*/
CREATE OR ALTER VIEW [report].[vCriticalJobChanges]
AS
SELECT
    *,
    CASE
        WHEN [NormalizedChangeType] = N'REMOVED'
            THEN N'CRITICAL'

        WHEN [ChangeArea] = N'OWNER'
            THEN N'HIGH'

        WHEN [ChangeArea] = N'COMMAND'
            THEN N'HIGH'

        WHEN [ChangeArea] = N'SCHEDULE'
            THEN N'HIGH'

        WHEN [ChangeArea] = N'PROXY'
            THEN N'HIGH'

        WHEN [ChangeArea] = N'NOTIFICATION'
            THEN N'MEDIUM'

        WHEN [ChangeArea] = N'STATUS'
            THEN N'MEDIUM'

        ELSE N'LOW'
    END AS [ChangeSeverity]
FROM [report].[vJobChanges]
WHERE
       [NormalizedChangeType] = N'REMOVED'
    OR [ChangeArea] IN
       (
           N'OWNER',
           N'COMMAND',
           N'SCHEDULE',
           N'PROXY',
           N'NOTIFICATION',
           N'STATUS'
       );
GO

/*=============================================================================
  26. Zmiany dotyczące jobów aktualnie aktywnych
=============================================================================*/
CREATE OR ALTER VIEW [report].[vActiveJobChanges]
AS
SELECT
    C.*,
    J.[IsEnabled] AS [CurrentIsEnabled],
    J.[OwnerName] AS [CurrentOwnerName],
    J.[OperatorName] AS [CurrentOperatorName],
    J.[DateModified] AS [CurrentDateModified]
FROM [report].[vJobChanges] AS C
INNER JOIN [report].[vCurrentJobs] AS J
    ON J.[InstanceId] = C.[InstanceId]
   AND J.[JobId] = C.[JobId];
GO

/*=============================================================================
  27. Ostatnia zmiana każdego joba
=============================================================================*/
CREATE OR ALTER VIEW [report].[vLatestJobChange]
AS
WITH X AS
(
    SELECT
        C.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY C.[InstanceId], C.[JobId]
            ORDER BY C.[DetectedAt] DESC, C.[JobChangeId] DESC
        ) AS [rn]
    FROM [report].[vJobChanges] AS C
)
SELECT *
FROM X
WHERE [rn] = 1;
GO

/*=============================================================================
  28. Joby wielokrotnie zmieniane
=============================================================================*/
CREATE OR ALTER VIEW [report].[vFrequentlyChangedJobs]
AS
SELECT
    [InstanceId],
    [ServerInstance],
    [EnvironmentCode],
    [JobId],
    [JobName],
    COUNT(*) AS [ChangeCount],
    MIN([DetectedAt]) AS [FirstChangeAt],
    MAX([DetectedAt]) AS [LastChangeAt],
    SUM
    (
        CASE
            WHEN [AuthorizationStatus] = N'UNAUTHORIZED'
                THEN 1
            ELSE 0
        END
    ) AS [UnauthorizedChangeCount],
    SUM
    (
        CASE
            WHEN [AuthorizationStatus] = N'NOT_REVIEWED'
                THEN 1
            ELSE 0
        END
    ) AS [UnreviewedChangeCount]
FROM [report].[vJobChanges]
WHERE [DetectedAt] >= DATEADD(day, -30, SYSDATETIME())
GROUP BY
    [InstanceId],
    [ServerInstance],
    [EnvironmentCode],
    [JobId],
    [JobName]
HAVING COUNT(*) > 1;
GO

/*=============================================================================
  29. Podsumowanie zmian według rodzaju
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChangeSummary]
AS
SELECT
    [EnvironmentCode],
    [ServerInstance],
    [NormalizedChangeType],
    [ChangeArea],
    [AuthorizationStatus],
    COUNT(*) AS [ChangeCount],
    MIN([DetectedAt]) AS [FirstDetectedAt],
    MAX([DetectedAt]) AS [LastDetectedAt]
FROM [report].[vJobChanges]
GROUP BY
    [EnvironmentCode],
    [ServerInstance],
    [NormalizedChangeType],
    [ChangeArea],
    [AuthorizationStatus];
GO

/*=============================================================================
  30. Dzienne podsumowanie zmian
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChangeDailySummary]
AS
SELECT
    CONVERT(date, [DetectedAt]) AS [ChangeDate],
    [EnvironmentCode],
    [ServerInstance],
    [NormalizedChangeType],
    [ChangeArea],
    COUNT(*) AS [ChangeCount],
    SUM
    (
        CASE
            WHEN [AuthorizationStatus] = N'AUTHORIZED'
                THEN 1
            ELSE 0
        END
    ) AS [AuthorizedCount],
    SUM
    (
        CASE
            WHEN [AuthorizationStatus] = N'UNAUTHORIZED'
                THEN 1
            ELSE 0
        END
    ) AS [UnauthorizedCount],
    SUM
    (
        CASE
            WHEN [AuthorizationStatus] = N'NOT_REVIEWED'
                THEN 1
            ELSE 0
        END
    ) AS [NotReviewedCount]
FROM [report].[vJobChanges]
GROUP BY
    CONVERT(date, [DetectedAt]),
    [EnvironmentCode],
    [ServerInstance],
    [NormalizedChangeType],
    [ChangeArea];
GO

/*=============================================================================
  31. Podsumowanie zmian według instancji
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChangeByInstance]
AS
SELECT
    [InstanceId],
    [ServerInstance],
    [EnvironmentCode],
    COUNT(*) AS [TotalChangeCount],
    SUM(CASE WHEN [NormalizedChangeType] = N'ADDED' THEN 1 ELSE 0 END) AS [AddedCount],
    SUM(CASE WHEN [NormalizedChangeType] = N'REMOVED' THEN 1 ELSE 0 END) AS [RemovedCount],
    SUM(CASE WHEN [NormalizedChangeType] = N'MODIFIED' THEN 1 ELSE 0 END) AS [ModifiedCount],
    SUM(CASE WHEN [AuthorizationStatus] = N'AUTHORIZED' THEN 1 ELSE 0 END) AS [AuthorizedCount],
    SUM(CASE WHEN [AuthorizationStatus] = N'UNAUTHORIZED' THEN 1 ELSE 0 END) AS [UnauthorizedCount],
    SUM(CASE WHEN [AuthorizationStatus] = N'NOT_REVIEWED' THEN 1 ELSE 0 END) AS [NotReviewedCount],
    MIN([DetectedAt]) AS [FirstDetectedAt],
    MAX([DetectedAt]) AS [LastDetectedAt]
FROM [report].[vJobChanges]
GROUP BY
    [InstanceId],
    [ServerInstance],
    [EnvironmentCode];
GO

/*=============================================================================
  32. Dashboard zmian
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobChangeDashboard]
AS
SELECT
    COUNT(*) AS [TotalChanges],
    SUM(CASE WHEN [DetectedAt] >= DATEADD(hour, -24, SYSDATETIME()) THEN 1 ELSE 0 END) AS [ChangesLast24Hours],
    SUM(CASE WHEN [DetectedAt] >= DATEADD(day, -7, SYSDATETIME()) THEN 1 ELSE 0 END) AS [ChangesLast7Days],
    SUM(CASE WHEN [DetectedAt] >= DATEADD(day, -30, SYSDATETIME()) THEN 1 ELSE 0 END) AS [ChangesLast30Days],
    SUM(CASE WHEN [NormalizedChangeType] = N'ADDED' THEN 1 ELSE 0 END) AS [AddedJobsAndObjects],
    SUM(CASE WHEN [NormalizedChangeType] = N'REMOVED' THEN 1 ELSE 0 END) AS [RemovedJobsAndObjects],
    SUM(CASE WHEN [NormalizedChangeType] = N'MODIFIED' THEN 1 ELSE 0 END) AS [ModifiedJobsAndObjects],
    SUM(CASE WHEN [AuthorizationStatus] = N'UNAUTHORIZED' THEN 1 ELSE 0 END) AS [UnauthorizedChanges],
    SUM(CASE WHEN [AuthorizationStatus] = N'NOT_REVIEWED' THEN 1 ELSE 0 END) AS [UnreviewedChanges],
    MAX([DetectedAt]) AS [LastDetectedChangeAt]
FROM [report].[vJobChanges];
GO

/*=============================================================================
  33. Extended properties
=============================================================================*/
IF OBJECT_ID(N'[dbo].[usp_SetDescription]', N'P') IS NOT NULL
BEGIN
    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobChanges',
        @ObjectType = 'VIEW',
        @Description = N'Pełny rejestr wykrytych zmian jobów SQL Server Agent.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vNewJobs',
        @ObjectType = 'VIEW',
        @Description = N'Nowe joby wykryte pomiędzy skanami.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vRemovedJobs',
        @ObjectType = 'VIEW',
        @Description = N'Joby usunięte pomiędzy skanami.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobOwnerChanges',
        @ObjectType = 'VIEW',
        @Description = N'Zmiany właścicieli jobów.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobCommandChanges',
        @ObjectType = 'VIEW',
        @Description = N'Zmiany komend wykonywanych w krokach jobów.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobScheduleChanges',
        @ObjectType = 'VIEW',
        @Description = N'Zmiany harmonogramów jobów.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vUnauthorizedJobChanges',
        @ObjectType = 'VIEW',
        @Description = N'Zmiany oznaczone jako nieautoryzowane.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vUnreviewedJobChanges',
        @ObjectType = 'VIEW',
        @Description = N'Zmiany, które nie zostały jeszcze sklasyfikowane jako autoryzowane lub nieautoryzowane.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobChangeSummary',
        @ObjectType = 'VIEW',
        @Description = N'Podsumowanie zmian według instancji, obszaru i statusu autoryzacji.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobChangeDashboard',
        @ObjectType = 'VIEW',
        @Description = N'Jednowierszowe podsumowanie zmian jobów do dashboardu Confluence.';
END;
GO

/*=============================================================================
  34. Zapytania kontrolne po instalacji
=============================================================================*/
SELECT *
FROM [report].[vJobChangeDashboard];
GO

SELECT
    [EnvironmentCode],
    [ServerInstance],
    [NormalizedChangeType],
    [ChangeArea],
    [AuthorizationStatus],
    [ChangeCount],
    [FirstDetectedAt],
    [LastDetectedAt]
FROM [report].[vJobChangeSummary]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [ChangeCount] DESC;
GO

SELECT TOP (100)
    [DetectedAt],
    [ServerInstance],
    [EnvironmentCode],
    [JobName],
    [NormalizedChangeType],
    [ChangeArea],
    [PropertyName],
    [OldValue],
    [NewValue],
    [AuthorizationStatus],
    [TicketNumber]
FROM [report].[vJobChanges]
ORDER BY
    [DetectedAt] DESC,
    [JobChangeId] DESC;
GO
