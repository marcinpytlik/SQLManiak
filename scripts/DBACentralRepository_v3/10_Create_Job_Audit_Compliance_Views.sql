USE [DBACentralRepository];
GO

/*
===============================================================================
Plik: 12_Create_Job_Audit_Compliance_Views.sql
Projekt: DBACentralRepository v3

Cel:
    Utworzenie widoków raportowych dla sekcji Confluence:
    "09. Audyt i zgodność".

Zakres:
    - bieżący audyt zgodności,
    - właściciele jobów,
    - proxy i credentials,
    - harmonogramy,
    - operatorzy i powiadomienia,
    - joby wyłączone,
    - dokumentacja,
    - wyjątki,
    - findingi krytyczne,
    - podsumowania i dashboard.

Założenia:
    Istnieją:
    - [audit].[ComplianceRun]
    - [audit].[ComplianceFinding]
    - [audit].[ComplianceRule]
    - [audit].[ComplianceException]
    - [audit].[JobDocumentation]
    - [dbo].[Instance]
    - [dbo].[Environment]
    - [report].[vCurrentJobs]

Zgodność:
    SQL Server 2016 SP1+ / 2019 / 2022.
===============================================================================
*/


/*=============================================================================
  1. Ostatnie poprawne uruchomienie audytu dla każdego ScanRunId
=============================================================================*/
CREATE OR ALTER VIEW [report].[vLatestSuccessfulComplianceRunPerScan]
AS
WITH X AS
(
    SELECT
        CR.[ComplianceRunId],
        CR.[ScanRunId],
        CR.[StartedAt],
        CR.[FinishedAt],
        CR.[Status],
        CR.[FindingCount],
        CR.[ErrorMessage],
        ROW_NUMBER() OVER
        (
            PARTITION BY CR.[ScanRunId]
            ORDER BY CR.[ComplianceRunId] DESC
        ) AS [rn]
    FROM [audit].[ComplianceRun] AS CR
    WHERE CR.[Status] = 'SUCCESS'
)
SELECT
    [ComplianceRunId],
    [ScanRunId],
    [StartedAt],
    [FinishedAt],
    [Status],
    [FindingCount],
    [ErrorMessage]
FROM X
WHERE [rn] = 1;
GO

/*=============================================================================
  2. Ostatnie poprawne uruchomienie audytu globalnie
=============================================================================*/
CREATE OR ALTER VIEW [report].[vLatestSuccessfulComplianceRun]
AS
SELECT TOP (1)
    CR.[ComplianceRunId],
    CR.[ScanRunId],
    CR.[StartedAt],
    CR.[FinishedAt],
    CR.[Status],
    CR.[FindingCount],
    CR.[ErrorMessage]
FROM [audit].[ComplianceRun] AS CR
WHERE CR.[Status] = 'SUCCESS'
ORDER BY
    CR.[ComplianceRunId] DESC;
GO

/*=============================================================================
  3. Pełna historia findingów zgodności
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceFindingHistory]
AS
SELECT
    F.[ComplianceFindingId],
    F.[ComplianceRunId],
    F.[ScanRunId],
    F.[RuleCode],
    R.[RuleName],
    R.[Description] AS [RuleDescription],
    F.[InstanceId],
    I.[ServerInstance],
    E.[EnvironmentCode],
    F.[ObjectType],
    F.[ObjectKey],
    F.[ObjectName],
    F.[Severity],
    F.[CurrentValue],
    F.[ExpectedValue],
    F.[Recommendation],
    F.[FindingStatus],
    F.[IsExcepted],
    F.[ComplianceExceptionId],
    F.[FirstDetectedAt],
    F.[LastDetectedAt],
    F.[ResolvedAt],
    F.[Details],

    CASE
        WHEN F.[IsExcepted] = 1
            THEN N'EXCEPTION'
        WHEN F.[ResolvedAt] IS NOT NULL
          OR F.[FindingStatus] = N'RESOLVED'
            THEN N'RESOLVED'
        ELSE N'OPEN'
    END AS [EffectiveFindingStatus],

    CASE F.[Severity]
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH'     THEN 2
        WHEN 'MEDIUM'   THEN 3
        WHEN 'LOW'      THEN 4
        ELSE 5
    END AS [SeverityOrder]
FROM [audit].[ComplianceFinding] AS F
INNER JOIN [audit].[ComplianceRule] AS R
    ON R.[RuleCode] = F.[RuleCode]
INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = F.[InstanceId]
LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId];
GO

/*=============================================================================
  4. Findingi z ostatniego poprawnego audytu
=============================================================================*/
CREATE OR ALTER VIEW [report].[vCurrentJobComplianceFindings]
AS
SELECT
    H.*
FROM [report].[vJobComplianceFindingHistory] AS H
INNER JOIN [report].[vLatestSuccessfulComplianceRun] AS LR
    ON LR.[ComplianceRunId] = H.[ComplianceRunId];
GO

/*=============================================================================
  5. Otwarte findingi z ostatniego audytu
=============================================================================*/
CREATE OR ALTER VIEW [report].[vOpenJobComplianceFindings]
AS
SELECT *
FROM [report].[vCurrentJobComplianceFindings]
WHERE [EffectiveFindingStatus] = N'OPEN';
GO

/*=============================================================================
  6. Findingi objęte wyjątkiem
=============================================================================*/
CREATE OR ALTER VIEW [report].[vExceptedJobComplianceFindings]
AS
SELECT *
FROM [report].[vCurrentJobComplianceFindings]
WHERE [EffectiveFindingStatus] = N'EXCEPTION';
GO

/*=============================================================================
  7. Findingi krytyczne i wysokie
=============================================================================*/
CREATE OR ALTER VIEW [report].[vCriticalJobComplianceFindings]
AS
SELECT *
FROM [report].[vOpenJobComplianceFindings]
WHERE [Severity] IN
(
    'CRITICAL',
    'HIGH'
);
GO

/*=============================================================================
  8. Audyt właścicieli jobów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobOwnerComplianceAudit]
AS
SELECT *
FROM [report].[vCurrentJobComplianceFindings]
WHERE [RuleCode] IN
(
    'JOB_OWNER_MISSING',
    'JOB_OWNER_DISABLED',
    'JOB_OWNER_NOT_STANDARD'
);
GO

/*=============================================================================
  9. Audyt proxy i credentials
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobProxyComplianceAudit]
AS
SELECT *
FROM [report].[vCurrentJobComplianceFindings]
WHERE [RuleCode] IN
(
    'JOB_PROXY_MISSING',
    'JOB_PROXY_DISABLED',
    'JOB_PROXY_WITHOUT_CREDENTIAL'
);
GO

/*=============================================================================
  10. Audyt harmonogramów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobScheduleComplianceAudit]
AS
SELECT *
FROM [report].[vCurrentJobComplianceFindings]
WHERE [RuleCode] IN
(
    'JOB_NO_SCHEDULE',
    'JOB_SCHEDULE_DISABLED',
    'JOB_SCHEDULE_EXPIRED'
);
GO

/*=============================================================================
  11. Audyt operatorów i powiadomień
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobNotificationComplianceAudit]
AS
SELECT *
FROM [report].[vCurrentJobComplianceFindings]
WHERE [RuleCode] IN
(
    'JOB_NO_NOTIFICATION',
    'JOB_OPERATOR_INVALID'
);
GO

/*=============================================================================
  12. Audyt jobów wyłączonych
=============================================================================*/
CREATE OR ALTER VIEW [report].[vDisabledJobComplianceAudit]
AS
SELECT *
FROM [report].[vCurrentJobComplianceFindings]
WHERE [RuleCode] = 'JOB_DISABLED_WITHOUT_EXCEPTION';
GO

/*=============================================================================
  13. Audyt dokumentacji jobów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobDocumentationComplianceAudit]
AS
SELECT *
FROM [report].[vCurrentJobComplianceFindings]
WHERE [RuleCode] IN
(
    'JOB_NOT_DOCUMENTED',
    'JOB_DOCUMENTATION_OUTDATED'
);
GO

/*=============================================================================
  14. Rejestr dokumentacji jobów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobDocumentationRegistry]
AS
SELECT
    J.[InstanceId],
    J.[ServerInstance],
    J.[EnvironmentCode],
    J.[JobId],
    J.[JobName],
    J.[OwnerName],
    J.[IsEnabled],

    D.[JobDocumentationId],
    D.[ConfluencePageId],
    D.[ConfluencePageUrl],
    D.[TechnicalOwner],
    D.[BusinessOwner],
    D.[Criticality],
    D.[IsDocumented],
    D.[DocumentationStatus],
    D.[LastReviewedAt],
    D.[ReviewedBy],
    D.[Notes],

    CASE
        WHEN D.[JobDocumentationId] IS NULL
            THEN N'MISSING'

        WHEN D.[IsDocumented] = 0
          OR NULLIF(LTRIM(RTRIM(D.[ConfluencePageUrl])), N'') IS NULL
            THEN N'INCOMPLETE'

        WHEN D.[LastReviewedAt] IS NULL
            THEN N'NOT_REVIEWED'

        WHEN D.[LastReviewedAt] < DATEADD(month, -12, SYSDATETIME())
            THEN N'OUTDATED'

        ELSE N'OK'
    END AS [AuditStatus]
FROM [report].[vCurrentJobs] AS J
LEFT JOIN [audit].[JobDocumentation] AS D
    ON D.[InstanceId] = J.[InstanceId]
   AND D.[JobId] = J.[JobId];
GO

/*=============================================================================
  15. Joby bez dokumentacji
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobsMissingDocumentation]
AS
SELECT *
FROM [report].[vJobDocumentationRegistry]
WHERE [AuditStatus] IN
(
    N'MISSING',
    N'INCOMPLETE'
);
GO

/*=============================================================================
  16. Dokumentacja bez przeglądu
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobDocumentationNotReviewed]
AS
SELECT *
FROM [report].[vJobDocumentationRegistry]
WHERE [AuditStatus] = N'NOT_REVIEWED';
GO

/*=============================================================================
  17. Dokumentacja nieaktualna
=============================================================================*/
CREATE OR ALTER VIEW [report].[vOutdatedJobDocumentation]
AS
SELECT *
FROM [report].[vJobDocumentationRegistry]
WHERE [AuditStatus] = N'OUTDATED';
GO

/*=============================================================================
  18. Kompletna dokumentacja
=============================================================================*/
CREATE OR ALTER VIEW [report].[vCompliantJobDocumentation]
AS
SELECT *
FROM [report].[vJobDocumentationRegistry]
WHERE [AuditStatus] = N'OK';
GO

/*=============================================================================
  19. Wszystkie wyjątki zgodności
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceExceptions]
AS
SELECT
    X.[ComplianceExceptionId],
    X.[RuleCode],
    R.[RuleName],
    R.[Severity],
    X.[InstanceId],
    I.[ServerInstance],
    E.[EnvironmentCode],
    X.[ObjectType],
    X.[ObjectName],
    X.[Reason],
    X.[ApprovedBy],
    X.[TicketNumber],
    X.[ValidFrom],
    X.[ValidTo],
    X.[IsActive],

    CASE
        WHEN X.[IsActive] = 0
            THEN N'INACTIVE'

        WHEN X.[ValidFrom] > SYSDATETIME()
            THEN N'NOT_YET_VALID'

        WHEN X.[ValidTo] IS NOT NULL
         AND X.[ValidTo] < SYSDATETIME()
            THEN N'EXPIRED'

        ELSE N'ACTIVE'
    END AS [ExceptionStatus],

    CASE
        WHEN X.[ValidTo] IS NULL
            THEN NULL
        ELSE DATEDIFF(day, SYSDATETIME(), X.[ValidTo])
    END AS [DaysToExpire]
FROM [audit].[ComplianceException] AS X
INNER JOIN [audit].[ComplianceRule] AS R
    ON R.[RuleCode] = X.[RuleCode]
INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = X.[InstanceId]
LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId];
GO

/*=============================================================================
  20. Aktywne wyjątki
=============================================================================*/
CREATE OR ALTER VIEW [report].[vActiveJobComplianceExceptions]
AS
SELECT *
FROM [report].[vJobComplianceExceptions]
WHERE [ExceptionStatus] = N'ACTIVE';
GO

/*=============================================================================
  21. Wygasłe wyjątki
=============================================================================*/
CREATE OR ALTER VIEW [report].[vExpiredJobComplianceExceptions]
AS
SELECT *
FROM [report].[vJobComplianceExceptions]
WHERE [ExceptionStatus] = N'EXPIRED';
GO

/*=============================================================================
  22. Wyjątki wygasające w ciągu 30 dni
=============================================================================*/
CREATE OR ALTER VIEW [report].[vExpiringJobComplianceExceptions]
AS
SELECT *
FROM [report].[vJobComplianceExceptions]
WHERE [ExceptionStatus] = N'ACTIVE'
  AND [DaysToExpire] BETWEEN 0 AND 30;
GO

/*=============================================================================
  23. Wyjątki bez numeru zgłoszenia
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceExceptionsWithoutTicket]
AS
SELECT *
FROM [report].[vJobComplianceExceptions]
WHERE NULLIF(LTRIM(RTRIM([TicketNumber])), N'') IS NULL;
GO

/*=============================================================================
  24. Reguły audytu
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceRules]
AS
SELECT
    R.[ComplianceRuleId],
    R.[RuleCode],
    R.[ModuleName],
    R.[RuleName],
    R.[Description],
    R.[Severity],
    R.[Recommendation],
    R.[IsEnabled],

    CASE R.[Severity]
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH'     THEN 2
        WHEN 'MEDIUM'   THEN 3
        WHEN 'LOW'      THEN 4
        ELSE 5
    END AS [SeverityOrder]
FROM [audit].[ComplianceRule] AS R;
GO

/*=============================================================================
  25. Wyłączone reguły audytu
=============================================================================*/
CREATE OR ALTER VIEW [report].[vDisabledJobComplianceRules]
AS
SELECT *
FROM [report].[vJobComplianceRules]
WHERE [IsEnabled] = 0;
GO

/*=============================================================================
  26. Podsumowanie findingów według reguły
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceByRule]
AS
SELECT
    F.[RuleCode],
    F.[RuleName],
    F.[RuleDescription],
    F.[Severity],
    F.[Recommendation],
    COUNT(*) AS [FindingCount],
    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [OpenCount],
    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'EXCEPTION'
                THEN 1
            ELSE 0
        END
    ) AS [ExceptionCount],
    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'RESOLVED'
                THEN 1
            ELSE 0
        END
    ) AS [ResolvedCount],
    MIN(F.[FirstDetectedAt]) AS [FirstDetectedAt],
    MAX(F.[LastDetectedAt]) AS [LastDetectedAt]
FROM [report].[vCurrentJobComplianceFindings] AS F
GROUP BY
    F.[RuleCode],
    F.[RuleName],
    F.[RuleDescription],
    F.[Severity],
    F.[Recommendation];
GO

/*=============================================================================
  27. Podsumowanie findingów według ważności
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceBySeverity]
AS
SELECT
    F.[Severity],
    F.[SeverityOrder],
    COUNT(*) AS [FindingCount],
    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [OpenCount],
    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'EXCEPTION'
                THEN 1
            ELSE 0
        END
    ) AS [ExceptionCount],
    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'RESOLVED'
                THEN 1
            ELSE 0
        END
    ) AS [ResolvedCount]
FROM [report].[vCurrentJobComplianceFindings] AS F
GROUP BY
    F.[Severity],
    F.[SeverityOrder];
GO

/*=============================================================================
  28. Podsumowanie findingów według instancji
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceByInstance]
AS
SELECT
    F.[InstanceId],
    F.[ServerInstance],
    F.[EnvironmentCode],
    COUNT(*) AS [FindingCount],

    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [OpenCount],

    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'EXCEPTION'
                THEN 1
            ELSE 0
        END
    ) AS [ExceptionCount],

    SUM
    (
        CASE
            WHEN F.[Severity] = 'CRITICAL'
             AND F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [CriticalOpenCount],

    SUM
    (
        CASE
            WHEN F.[Severity] = 'HIGH'
             AND F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [HighOpenCount],

    SUM
    (
        CASE
            WHEN F.[Severity] = 'MEDIUM'
             AND F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [MediumOpenCount],

    SUM
    (
        CASE
            WHEN F.[Severity] = 'LOW'
             AND F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [LowOpenCount],

    COUNT(DISTINCT F.[ObjectName]) AS [AffectedObjectCount],
    MAX(F.[LastDetectedAt]) AS [LastDetectedAt]
FROM [report].[vCurrentJobComplianceFindings] AS F
GROUP BY
    F.[InstanceId],
    F.[ServerInstance],
    F.[EnvironmentCode];
GO

/*=============================================================================
  29. Podsumowanie findingów według joba
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceByJob]
AS
SELECT
    F.[InstanceId],
    F.[ServerInstance],
    F.[EnvironmentCode],
    F.[ObjectKey],
    F.[ObjectName] AS [JobName],
    COUNT(*) AS [FindingCount],

    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [OpenCount],

    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'EXCEPTION'
                THEN 1
            ELSE 0
        END
    ) AS [ExceptionCount],

    MIN(F.[SeverityOrder]) AS [HighestSeverityOrder],

    CASE MIN(F.[SeverityOrder])
        WHEN 1 THEN 'CRITICAL'
        WHEN 2 THEN 'HIGH'
        WHEN 3 THEN 'MEDIUM'
        WHEN 4 THEN 'LOW'
        ELSE 'INFO'
    END AS [HighestSeverity],

    MIN(F.[FirstDetectedAt]) AS [FirstDetectedAt],
    MAX(F.[LastDetectedAt]) AS [LastDetectedAt]
FROM [report].[vCurrentJobComplianceFindings] AS F
GROUP BY
    F.[InstanceId],
    F.[ServerInstance],
    F.[EnvironmentCode],
    F.[ObjectKey],
    F.[ObjectName];
GO

/*=============================================================================
  30. Joby z największą liczbą findingów
=============================================================================*/
CREATE OR ALTER VIEW [report].[vMostNonCompliantJobs]
AS
SELECT
    *
FROM [report].[vJobComplianceByJob]
WHERE [OpenCount] > 0;
GO

/*=============================================================================
  31. Historia uruchomień audytu
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceRunHistory]
AS
SELECT
    CR.[ComplianceRunId],
    CR.[ScanRunId],
    SR.[ScanType],
    SR.[ScanStartedAt],
    SR.[ScanFinishedAt],
    CR.[StartedAt] AS [AuditStartedAt],
    CR.[FinishedAt] AS [AuditFinishedAt],
    CR.[Status],
    CR.[FindingCount],
    CR.[ErrorMessage],

    DATEDIFF
    (
        second,
        CR.[StartedAt],
        CR.[FinishedAt]
    ) AS [DurationSeconds]
FROM [audit].[ComplianceRun] AS CR
LEFT JOIN [dbo].[ScanRun] AS SR
    ON SR.[ScanRunId] = CR.[ScanRunId];
GO

/*=============================================================================
  32. Nieudane uruchomienia audytu
=============================================================================*/
CREATE OR ALTER VIEW [report].[vFailedJobComplianceRuns]
AS
SELECT *
FROM [report].[vJobComplianceRunHistory]
WHERE [Status] = 'FAILED';
GO

/*=============================================================================
  33. Dashboard zgodności
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceDashboard]
AS
SELECT
    LR.[ComplianceRunId],
    LR.[ScanRunId],
    LR.[StartedAt],
    LR.[FinishedAt],
    LR.[FindingCount],

    COUNT(F.[ComplianceFindingId]) AS [CurrentFindingCount],

    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [OpenFindingCount],

    SUM
    (
        CASE
            WHEN F.[EffectiveFindingStatus] = N'EXCEPTION'
                THEN 1
            ELSE 0
        END
    ) AS [ExceptionFindingCount],

    SUM
    (
        CASE
            WHEN F.[Severity] = 'CRITICAL'
             AND F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [CriticalOpenCount],

    SUM
    (
        CASE
            WHEN F.[Severity] = 'HIGH'
             AND F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [HighOpenCount],

    SUM
    (
        CASE
            WHEN F.[Severity] = 'MEDIUM'
             AND F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [MediumOpenCount],

    SUM
    (
        CASE
            WHEN F.[Severity] = 'LOW'
             AND F.[EffectiveFindingStatus] = N'OPEN'
                THEN 1
            ELSE 0
        END
    ) AS [LowOpenCount],

    COUNT(DISTINCT F.[InstanceId]) AS [AffectedInstanceCount],
    COUNT(DISTINCT F.[ObjectName]) AS [AffectedObjectCount]
FROM [report].[vLatestSuccessfulComplianceRun] AS LR
LEFT JOIN [report].[vCurrentJobComplianceFindings] AS F
    ON F.[ComplianceRunId] = LR.[ComplianceRunId]
GROUP BY
    LR.[ComplianceRunId],
    LR.[ScanRunId],
    LR.[StartedAt],
    LR.[FinishedAt],
    LR.[FindingCount];
GO

/*=============================================================================
  34. Findingi wymagające działania
=============================================================================*/
CREATE OR ALTER VIEW [report].[vJobComplianceActionQueue]
AS
SELECT
    F.[ComplianceFindingId],
    F.[ComplianceRunId],
    F.[ScanRunId],
    F.[ServerInstance],
    F.[EnvironmentCode],
    F.[RuleCode],
    F.[RuleName],
    F.[ObjectType],
    F.[ObjectKey],
    F.[ObjectName],
    F.[Severity],
    F.[CurrentValue],
    F.[ExpectedValue],
    F.[Recommendation],
    F.[FirstDetectedAt],
    F.[LastDetectedAt],

    CASE
        WHEN F.[Severity] = 'CRITICAL'
            THEN N'Natychmiast'

        WHEN F.[Severity] = 'HIGH'
            THEN N'7 dni'

        WHEN F.[Severity] = 'MEDIUM'
            THEN N'30 dni'

        WHEN F.[Severity] = 'LOW'
            THEN N'90 dni'

        ELSE N'Do ustalenia'
    END AS [RecommendedResolutionTime]
FROM [report].[vOpenJobComplianceFindings] AS F;
GO

/*=============================================================================
  35. Extended properties
=============================================================================*/
IF OBJECT_ID(N'[dbo].[usp_SetDescription]', N'P') IS NOT NULL
BEGIN
    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vCurrentJobComplianceFindings',
        @ObjectType = 'VIEW',
        @Description = N'Findingi z ostatniego poprawnego uruchomienia audytu zgodności jobów.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vOpenJobComplianceFindings',
        @ObjectType = 'VIEW',
        @Description = N'Otwarte findingi zgodności wymagające analizy lub działania.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vCriticalJobComplianceFindings',
        @ObjectType = 'VIEW',
        @Description = N'Otwarte findingi o ważności CRITICAL lub HIGH.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobOwnerComplianceAudit',
        @ObjectType = 'VIEW',
        @Description = N'Wyniki audytu właścicieli jobów.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobProxyComplianceAudit',
        @ObjectType = 'VIEW',
        @Description = N'Wyniki audytu proxy i credentials używanych przez joby.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobScheduleComplianceAudit',
        @ObjectType = 'VIEW',
        @Description = N'Wyniki audytu harmonogramów jobów.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobNotificationComplianceAudit',
        @ObjectType = 'VIEW',
        @Description = N'Wyniki audytu operatorów i powiadomień jobów.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vDisabledJobComplianceAudit',
        @ObjectType = 'VIEW',
        @Description = N'Wyłączone joby bez zatwierdzonego wyjątku.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobDocumentationRegistry',
        @ObjectType = 'VIEW',
        @Description = N'Centralny rejestr dokumentacji jobów wraz z oceną kompletności i aktualności.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobComplianceExceptions',
        @ObjectType = 'VIEW',
        @Description = N'Rejestr wyjątków od standardów zgodności jobów.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobComplianceByRule',
        @ObjectType = 'VIEW',
        @Description = N'Podsumowanie findingów zgodności według RuleCode.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobComplianceByInstance',
        @ObjectType = 'VIEW',
        @Description = N'Podsumowanie findingów zgodności według instancji.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobComplianceByJob',
        @ObjectType = 'VIEW',
        @Description = N'Podsumowanie findingów zgodności według joba.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobComplianceDashboard',
        @ObjectType = 'VIEW',
        @Description = N'Jednowierszowe podsumowanie ostatniego audytu zgodności do dashboardu Confluence.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobComplianceActionQueue',
        @ObjectType = 'VIEW',
        @Description = N'Kolejka otwartych findingów wraz z rekomendowanym czasem realizacji.';
END;
GO

/*=============================================================================
  36. Zapytania kontrolne po instalacji
=============================================================================*/
SELECT *
FROM [report].[vJobComplianceDashboard];
GO

SELECT
    [RuleCode],
    [RuleName],
    [Severity],
    [FindingCount],
    [OpenCount],
    [ExceptionCount],
    [ResolvedCount],
    [Recommendation]
FROM [report].[vJobComplianceByRule]
ORDER BY
    CASE [Severity]
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH'     THEN 2
        WHEN 'MEDIUM'   THEN 3
        WHEN 'LOW'      THEN 4
        ELSE 5
    END,
    [FindingCount] DESC;
GO

SELECT
    [ServerInstance],
    [EnvironmentCode],
    [FindingCount],
    [OpenCount],
    [ExceptionCount],
    [CriticalOpenCount],
    [HighOpenCount],
    [MediumOpenCount],
    [LowOpenCount],
    [AffectedObjectCount]
FROM [report].[vJobComplianceByInstance]
ORDER BY
    [CriticalOpenCount] DESC,
    [HighOpenCount] DESC,
    [OpenCount] DESC;
GO

SELECT TOP (100)
    [ServerInstance],
    [EnvironmentCode],
    [RuleCode],
    [RuleName],
    [ObjectName],
    [Severity],
    [CurrentValue],
    [ExpectedValue],
    [Recommendation],
    [RecommendedResolutionTime]
FROM [report].[vJobComplianceActionQueue]
ORDER BY
    CASE [Severity]
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH'     THEN 2
        WHEN 'MEDIUM'   THEN 3
        WHEN 'LOW'      THEN 4
        ELSE 5
    END,
    [ServerInstance],
    [ObjectName];
GO
