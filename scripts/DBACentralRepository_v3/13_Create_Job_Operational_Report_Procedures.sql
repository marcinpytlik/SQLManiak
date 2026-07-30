USE [DBACentralRepository];
GO

/*
===============================================================================
Plik: 13_Create_Job_Operational_Report_Procedures.sql
Projekt: DBACentralRepository v3

Cel:
    Utworzenie procedur raportowych dla sekcji Confluence:

    08. Monitoring i raportowanie
    ├── Raport dzienny
    ├── Raport tygodniowy
    └── Raport miesięczny

Procedury:
    [report].[usp_DailyJobControl]
    [report].[usp_WeeklyJobControl]
    [report].[usp_MonthlyJobConfigurationAudit]

Założenia:
    W bazie istnieją obiekty utworzone przez:
    - 09_Create_Audit_Compliance.sql
    - 10_Create_Job_Category_Views.sql
    - 11_Create_Job_Change_Views.sql
    - 12_Create_Job_Audit_Compliance_Views.sql

Zgodność:
    SQL Server 2016 SP1+ / 2019 / 2022.
===============================================================================
*/


/*=============================================================================
  1. Raport dzienny
=============================================================================*/
CREATE OR ALTER PROCEDURE [report].[usp_DailyJobControl]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @LatestScanRunId bigint,
        @LatestScanStatus varchar(30),
        @LatestScanStartedAt datetime2(0),
        @LatestScanFinishedAt datetime2(0),
        @LatestAuditRunId bigint,
        @LatestAuditStatus varchar(30),
        @GeneratedAt datetime2(0) = SYSDATETIME();

    SELECT TOP (1)
        @LatestScanRunId = SR.[ScanRunId],
        @LatestScanStatus = SR.[Status],
        @LatestScanStartedAt = SR.[ScanStartedAt],
        @LatestScanFinishedAt = SR.[ScanFinishedAt]
    FROM [dbo].[ScanRun] AS SR
    ORDER BY SR.[ScanRunId] DESC;

    SELECT TOP (1)
        @LatestAuditRunId = CR.[ComplianceRunId],
        @LatestAuditStatus = CR.[Status]
    FROM [audit].[ComplianceRun] AS CR
    ORDER BY CR.[ComplianceRunId] DESC;

    DECLARE @Results table
    (
        [CheckOrder] int NOT NULL,
        [CheckCode] varchar(100) NOT NULL,
        [CheckName] nvarchar(300) NOT NULL,
        [Status] varchar(20) NOT NULL,
        [FindingCount] int NOT NULL,
        [Details] nvarchar(2000) NULL,
        [Recommendation] nvarchar(2000) NULL
    );

    DECLARE @ScanErrorCount int =
    (
        SELECT COUNT(*)
        FROM [dbo].[ScanError]
        WHERE [ScanRunId] = @LatestScanRunId
    );

    DECLARE @UnreachableInstances int =
    (
        SELECT COUNT(*)
        FROM [report].[vCurrentInstances]
        WHERE [IsReachable] = 0
    );

    DECLARE @CriticalFindings int =
    (
        SELECT COUNT(*)
        FROM [report].[vCriticalJobComplianceFindings]
    );

    DECLARE @DisabledJobs int =
    (
        SELECT COUNT(*)
        FROM [report].[vDisabledJobComplianceAudit]
    );

    DECLARE @NoSchedule int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobScheduleComplianceAudit]
        WHERE [RuleCode] = 'JOB_NO_SCHEDULE'
    );

    DECLARE @NoNotification int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobNotificationComplianceAudit]
        WHERE [RuleCode] = 'JOB_NO_NOTIFICATION'
    );

    DECLARE @MissingDocumentation int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobsMissingDocumentation]
    );

    DECLARE @UnauthorizedChanges int =
    (
        SELECT COUNT(*)
        FROM [report].[vUnauthorizedJobChanges]
        WHERE [DetectedAt] >= DATEADD(hour, -24, @GeneratedAt)
    );

    DECLARE @UnreviewedChanges int =
    (
        SELECT COUNT(*)
        FROM [report].[vUnreviewedJobChanges]
        WHERE [DetectedAt] >= DATEADD(hour, -24, @GeneratedAt)
    );

    DECLARE @FailedAudits int =
    (
        SELECT COUNT(*)
        FROM [report].[vFailedJobComplianceRuns]
        WHERE [AuditStartedAt] >= DATEADD(hour, -24, @GeneratedAt)
    );

    DECLARE @FailedExecutions int =
    (
        SELECT COUNT(*)
        FROM [job].[JobExecution]
        WHERE [RunAt] >= DATEADD(hour, -24, @GeneratedAt)
          AND [RunStatus] = 0
    );

    DECLARE @ExpiredExceptions int =
    (
        SELECT COUNT(*)
        FROM [report].[vExpiredJobComplianceExceptions]
    );

    DECLARE @ExpiringExceptions int =
    (
        SELECT COUNT(*)
        FROM [report].[vExpiringJobComplianceExceptions]
    );

    INSERT @Results
    (
        [CheckOrder],
        [CheckCode],
        [CheckName],
        [Status],
        [FindingCount],
        [Details],
        [Recommendation]
    )
    VALUES
    (
        10,
        'LATEST_SCAN',
        N'Ostatni skan repozytorium',
        CASE
            WHEN @LatestScanRunId IS NULL THEN 'CRITICAL'
            WHEN @LatestScanStatus = 'SUCCESS' THEN 'OK'
            WHEN @LatestScanStatus = 'COMPLETED_WITH_ERRORS' THEN 'WARNING'
            ELSE 'CRITICAL'
        END,
        CASE
            WHEN @LatestScanStatus = 'SUCCESS' THEN 0
            ELSE 1
        END,
        CONCAT
        (
            N'ScanRunId=', COALESCE(CONVERT(nvarchar(30), @LatestScanRunId), N'BRAK'),
            N'; Status=', COALESCE(@LatestScanStatus, N'BRAK'),
            N'; Start=', COALESCE(CONVERT(nvarchar(19), @LatestScanStartedAt, 120), N'BRAK'),
            N'; Koniec=', COALESCE(CONVERT(nvarchar(19), @LatestScanFinishedAt, 120), N'BRAK')
        ),
        N'Sprawdź historię dbo.ScanRun oraz dbo.ScanError.'
    ),
    (
        20,
        'SCAN_ERRORS',
        N'Błędy kolektora',
        CASE WHEN @ScanErrorCount = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @ScanErrorCount,
        CONCAT(N'Liczba błędów ostatniego skanu: ', @ScanErrorCount),
        N'Sprawdź stronę „Błędy skanowania”.'
    ),
    (
        30,
        'UNREACHABLE_INSTANCES',
        N'Niedostępne instancje SQL Server',
        CASE WHEN @UnreachableInstances = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @UnreachableInstances,
        CONCAT(N'Liczba niedostępnych instancji: ', @UnreachableInstances),
        N'Sprawdź sieć, usługę SQL Server, port oraz uprawnienia kolektora.'
    ),
    (
        40,
        'LATEST_AUDIT',
        N'Ostatni audyt zgodności',
        CASE
            WHEN @LatestAuditRunId IS NULL THEN 'CRITICAL'
            WHEN @LatestAuditStatus = 'SUCCESS' THEN 'OK'
            ELSE 'CRITICAL'
        END,
        CASE
            WHEN @LatestAuditStatus = 'SUCCESS' THEN 0
            ELSE 1
        END,
        CONCAT
        (
            N'ComplianceRunId=',
            COALESCE(CONVERT(nvarchar(30), @LatestAuditRunId), N'BRAK'),
            N'; Status=',
            COALESCE(@LatestAuditStatus, N'BRAK')
        ),
        N'Sprawdź historię uruchomień audytu.'
    ),
    (
        50,
        'CRITICAL_FINDINGS',
        N'Otwarte findingi CRITICAL i HIGH',
        CASE WHEN @CriticalFindings = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @CriticalFindings,
        CONCAT(N'Liczba otwartych findingów CRITICAL/HIGH: ', @CriticalFindings),
        N'Sprawdź stronę „Findingi krytyczne”.'
    ),
    (
        60,
        'FAILED_JOB_EXECUTIONS',
        N'Nieudane wykonania jobów z ostatnich 24 godzin',
        CASE WHEN @FailedExecutions = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @FailedExecutions,
        CONCAT(N'Liczba nieudanych wykonań: ', @FailedExecutions),
        N'Sprawdź historię joba i pierwszy błędny krok.'
    ),
    (
        70,
        'DISABLED_JOBS',
        N'Joby wyłączone bez zatwierdzonego wyjątku',
        CASE WHEN @DisabledJobs = 0 THEN 'OK' ELSE 'WARNING' END,
        @DisabledJobs,
        CONCAT(N'Liczba jobów: ', @DisabledJobs),
        N'Włącz job albo dodaj zatwierdzony wyjątek.'
    ),
    (
        80,
        'JOBS_WITHOUT_SCHEDULE',
        N'Aktywne joby bez harmonogramu',
        CASE WHEN @NoSchedule = 0 THEN 'OK' ELSE 'WARNING' END,
        @NoSchedule,
        CONCAT(N'Liczba jobów: ', @NoSchedule),
        N'Dodaj harmonogram albo udokumentuj tryb ON_DEMAND.'
    ),
    (
        90,
        'JOBS_WITHOUT_NOTIFICATION',
        N'Joby bez powiadomienia po błędzie',
        CASE WHEN @NoNotification = 0 THEN 'OK' ELSE 'WARNING' END,
        @NoNotification,
        CONCAT(N'Liczba jobów: ', @NoNotification),
        N'Przypisz aktywnego operatora i powiadomienie po błędzie.'
    ),
    (
        100,
        'MISSING_DOCUMENTATION',
        N'Joby bez kompletnej dokumentacji',
        CASE WHEN @MissingDocumentation = 0 THEN 'OK' ELSE 'WARNING' END,
        @MissingDocumentation,
        CONCAT(N'Liczba jobów: ', @MissingDocumentation),
        N'Uzupełnij audit.JobDocumentation oraz stronę Confluence.'
    ),
    (
        110,
        'UNAUTHORIZED_CHANGES',
        N'Nieautoryzowane zmiany z ostatnich 24 godzin',
        CASE WHEN @UnauthorizedChanges = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @UnauthorizedChanges,
        CONCAT(N'Liczba zmian: ', @UnauthorizedChanges),
        N'Zweryfikuj zmianę, właściciela i numer zgłoszenia.'
    ),
    (
        120,
        'UNREVIEWED_CHANGES',
        N'Niezweryfikowane zmiany z ostatnich 24 godzin',
        CASE WHEN @UnreviewedChanges = 0 THEN 'OK' ELSE 'WARNING' END,
        @UnreviewedChanges,
        CONCAT(N'Liczba zmian: ', @UnreviewedChanges),
        N'Oznacz zmiany jako autoryzowane albo nieautoryzowane.'
    ),
    (
        130,
        'FAILED_AUDITS',
        N'Nieudane uruchomienia audytu z ostatnich 24 godzin',
        CASE WHEN @FailedAudits = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @FailedAudits,
        CONCAT(N'Liczba nieudanych audytów: ', @FailedAudits),
        N'Sprawdź ErrorMessage w historii audytów.'
    ),
    (
        140,
        'EXPIRED_EXCEPTIONS',
        N'Wygasłe wyjątki zgodności',
        CASE WHEN @ExpiredExceptions = 0 THEN 'OK' ELSE 'WARNING' END,
        @ExpiredExceptions,
        CONCAT(N'Liczba wygasłych wyjątków: ', @ExpiredExceptions),
        N'Zamknij wyjątek albo przeprowadź ponowną akceptację.'
    ),
    (
        150,
        'EXPIRING_EXCEPTIONS',
        N'Wyjątki wygasające w ciągu 30 dni',
        CASE WHEN @ExpiringExceptions = 0 THEN 'OK' ELSE 'WARNING' END,
        @ExpiringExceptions,
        CONCAT(N'Liczba wyjątków: ', @ExpiringExceptions),
        N'Podejmij decyzję przed datą wygaśnięcia.'
    );

    SELECT
        [CheckOrder],
        [CheckCode],
        [CheckName],
        [Status],
        [FindingCount],
        [Details],
        [Recommendation],
        CASE [Status]
            WHEN 'CRITICAL' THEN 1
            WHEN 'WARNING'  THEN 2
            WHEN 'OK'       THEN 3
            ELSE 4
        END AS [StatusOrder],
        @GeneratedAt AS [GeneratedAt]
    FROM @Results
    ORDER BY
        [CheckOrder];
END;
GO


/*=============================================================================
  2. Raport tygodniowy
=============================================================================*/
CREATE OR ALTER PROCEDURE [report].[usp_WeeklyJobControl]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @GeneratedAt datetime2(0) = SYSDATETIME(),
        @PeriodStart datetime2(0) = DATEADD(day, -7, SYSDATETIME());

    DECLARE @Results table
    (
        [CheckOrder] int NOT NULL,
        [CheckCode] varchar(100) NOT NULL,
        [CheckName] nvarchar(300) NOT NULL,
        [Status] varchar(20) NOT NULL,
        [FindingCount] int NOT NULL,
        [Details] nvarchar(2000) NULL,
        [Recommendation] nvarchar(2000) NULL
    );

    DECLARE @FailedExecutions int =
    (
        SELECT COUNT(*)
        FROM [job].[JobExecution]
        WHERE [RunAt] >= @PeriodStart
          AND [RunStatus] = 0
    );

    DECLARE @DistinctFailedJobs int =
    (
        SELECT COUNT(*)
        FROM
        (
            SELECT DISTINCT
                [InstanceId],
                [JobId]
            FROM [job].[JobExecution]
            WHERE [RunAt] >= @PeriodStart
              AND [RunStatus] = 0
        ) AS X
    );

    DECLARE @Changes7Days int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobChangesLast7Days]
    );

    DECLARE @UnauthorizedChanges7Days int =
    (
        SELECT COUNT(*)
        FROM [report].[vUnauthorizedJobChanges]
        WHERE [DetectedAt] >= @PeriodStart
    );

    DECLARE @UnreviewedChanges7Days int =
    (
        SELECT COUNT(*)
        FROM [report].[vUnreviewedJobChanges]
        WHERE [DetectedAt] >= @PeriodStart
    );

    DECLARE @FrequentlyChangedJobs int =
    (
        SELECT COUNT(*)
        FROM [report].[vFrequentlyChangedJobs]
    );

    DECLARE @JobsWithoutSchedule int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobsWithoutSchedule]
    );

    DECLARE @JobsWithoutNotification int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobsWithoutNotification]
    );

    DECLARE @JobsWithoutProxy int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobsWithoutProxy]
    );

    DECLARE @JobsWithoutRetry int =
    (
        SELECT COUNT(DISTINCT CONCAT([InstanceId], N'|', CONVERT(nvarchar(36), [JobId])))
        FROM [report].[vJobsWithoutRetry]
    );

    DECLARE @JobsWithDisabledSchedule int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobsWithDisabledSchedule]
    );

    DECLARE @MissingDocumentation int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobsMissingDocumentation]
    );

    DECLARE @OutdatedDocumentation int =
    (
        SELECT COUNT(*)
        FROM [report].[vOutdatedJobDocumentation]
    );

    DECLARE @CriticalFindings int =
    (
        SELECT COUNT(*)
        FROM [report].[vCriticalJobComplianceFindings]
    );

    DECLARE @BackupJobs int =
    (
        SELECT COUNT(DISTINCT CONCAT([InstanceId], N'|', CONVERT(nvarchar(36), [JobId])))
        FROM [report].[vBackupJobs]
    );

    DECLARE @CheckDbJobs int =
    (
        SELECT COUNT(DISTINCT CONCAT([InstanceId], N'|', CONVERT(nvarchar(36), [JobId])))
        FROM [report].[vCheckDbJobs]
    );

    DECLARE @MaintenanceJobs int =
    (
        SELECT COUNT(DISTINCT CONCAT([InstanceId], N'|', CONVERT(nvarchar(36), [JobId])))
        FROM [report].[vMaintenanceJobs]
    );

    INSERT @Results
    (
        [CheckOrder],
        [CheckCode],
        [CheckName],
        [Status],
        [FindingCount],
        [Details],
        [Recommendation]
    )
    VALUES
    (
        10,
        'FAILED_EXECUTIONS_7D',
        N'Nieudane wykonania jobów w ostatnich 7 dniach',
        CASE WHEN @FailedExecutions = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @FailedExecutions,
        CONCAT
        (
            N'Liczba nieudanych wykonań: ', @FailedExecutions,
            N'; Liczba jobów: ', @DistinctFailedJobs
        ),
        N'Przeanalizuj powtarzalne błędy i pierwszy błędny krok.'
    ),
    (
        20,
        'CHANGES_7D',
        N'Zmiany jobów z ostatnich 7 dni',
        CASE WHEN @Changes7Days = 0 THEN 'OK' ELSE 'INFO' END,
        @Changes7Days,
        CONCAT(N'Liczba wykrytych zmian: ', @Changes7Days),
        N'Zweryfikuj zgodność zmian ze zgłoszeniami.'
    ),
    (
        30,
        'UNAUTHORIZED_CHANGES_7D',
        N'Nieautoryzowane zmiany z ostatnich 7 dni',
        CASE WHEN @UnauthorizedChanges7Days = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @UnauthorizedChanges7Days,
        CONCAT(N'Liczba zmian: ', @UnauthorizedChanges7Days),
        N'Wyjaśnij i udokumentuj każdą nieautoryzowaną zmianę.'
    ),
    (
        40,
        'UNREVIEWED_CHANGES_7D',
        N'Niezweryfikowane zmiany z ostatnich 7 dni',
        CASE WHEN @UnreviewedChanges7Days = 0 THEN 'OK' ELSE 'WARNING' END,
        @UnreviewedChanges7Days,
        CONCAT(N'Liczba zmian: ', @UnreviewedChanges7Days),
        N'Przypisz status autoryzacji i numer zgłoszenia.'
    ),
    (
        50,
        'FREQUENTLY_CHANGED_JOBS',
        N'Joby często zmieniane',
        CASE WHEN @FrequentlyChangedJobs = 0 THEN 'OK' ELSE 'WARNING' END,
        @FrequentlyChangedJobs,
        CONCAT(N'Liczba jobów wielokrotnie zmienianych: ', @FrequentlyChangedJobs),
        N'Sprawdź przyczynę częstych zmian i stabilność konfiguracji.'
    ),
    (
        60,
        'CRITICAL_FINDINGS',
        N'Otwarte findingi CRITICAL i HIGH',
        CASE WHEN @CriticalFindings = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @CriticalFindings,
        CONCAT(N'Liczba findingów: ', @CriticalFindings),
        N'Przejrzyj kolejkę działań naprawczych.'
    ),
    (
        70,
        'JOBS_WITHOUT_SCHEDULE',
        N'Joby bez harmonogramu',
        CASE WHEN @JobsWithoutSchedule = 0 THEN 'OK' ELSE 'WARNING' END,
        @JobsWithoutSchedule,
        CONCAT(N'Liczba jobów: ', @JobsWithoutSchedule),
        N'Udokumentuj ON_DEMAND albo dodaj harmonogram.'
    ),
    (
        80,
        'JOBS_WITH_DISABLED_SCHEDULE',
        N'Joby bez aktywnego harmonogramu',
        CASE WHEN @JobsWithDisabledSchedule = 0 THEN 'OK' ELSE 'WARNING' END,
        @JobsWithDisabledSchedule,
        CONCAT(N'Liczba jobów: ', @JobsWithDisabledSchedule),
        N'Włącz właściwy harmonogram albo dodaj wyjątek.'
    ),
    (
        90,
        'JOBS_WITHOUT_NOTIFICATION',
        N'Joby bez powiadomienia po błędzie',
        CASE WHEN @JobsWithoutNotification = 0 THEN 'OK' ELSE 'WARNING' END,
        @JobsWithoutNotification,
        CONCAT(N'Liczba jobów: ', @JobsWithoutNotification),
        N'Skonfiguruj operatora i powiadomienie po błędzie.'
    ),
    (
        100,
        'JOBS_WITHOUT_PROXY',
        N'Kroki PowerShell, CmdExec lub SSIS bez proxy',
        CASE WHEN @JobsWithoutProxy = 0 THEN 'OK' ELSE 'WARNING' END,
        @JobsWithoutProxy,
        CONCAT(N'Liczba kroków: ', @JobsWithoutProxy),
        N'Zweryfikuj, czy wykonanie przez konto usługi Agenta jest świadome.'
    ),
    (
        110,
        'JOBS_WITHOUT_RETRY',
        N'Joby bez skonfigurowanego retry',
        CASE WHEN @JobsWithoutRetry = 0 THEN 'OK' ELSE 'INFO' END,
        @JobsWithoutRetry,
        CONCAT(N'Liczba jobów: ', @JobsWithoutRetry),
        N'Dla kroków podatnych na błędy przejściowe rozważ retry.'
    ),
    (
        120,
        'MISSING_DOCUMENTATION',
        N'Joby bez dokumentacji',
        CASE WHEN @MissingDocumentation = 0 THEN 'OK' ELSE 'WARNING' END,
        @MissingDocumentation,
        CONCAT(N'Liczba jobów: ', @MissingDocumentation),
        N'Uzupełnij właścicieli, krytyczność i link do Confluence.'
    ),
    (
        130,
        'OUTDATED_DOCUMENTATION',
        N'Nieaktualna dokumentacja jobów',
        CASE WHEN @OutdatedDocumentation = 0 THEN 'OK' ELSE 'WARNING' END,
        @OutdatedDocumentation,
        CONCAT(N'Liczba jobów: ', @OutdatedDocumentation),
        N'Wykonaj ponowny przegląd dokumentacji.'
    ),
    (
        140,
        'BACKUP_JOBS',
        N'Zidentyfikowane joby backupowe',
        'INFO',
        @BackupJobs,
        CONCAT(N'Liczba jobów backupowych: ', @BackupJobs),
        N'Porównaj z oczekiwanym zakresem backupów.'
    ),
    (
        150,
        'CHECKDB_JOBS',
        N'Zidentyfikowane joby CHECKDB',
        'INFO',
        @CheckDbJobs,
        CONCAT(N'Liczba jobów CHECKDB: ', @CheckDbJobs),
        N'Porównaj z listą wszystkich baz wymagających kontroli integralności.'
    ),
    (
        160,
        'MAINTENANCE_JOBS',
        N'Zidentyfikowane joby maintenance',
        'INFO',
        @MaintenanceJobs,
        CONCAT(N'Liczba jobów maintenance: ', @MaintenanceJobs),
        N'Zweryfikuj zakres i nakładanie się harmonogramów.'
    );

    SELECT
        [CheckOrder],
        [CheckCode],
        [CheckName],
        [Status],
        [FindingCount],
        [Details],
        [Recommendation],
        CASE [Status]
            WHEN 'CRITICAL' THEN 1
            WHEN 'WARNING'  THEN 2
            WHEN 'INFO'     THEN 3
            WHEN 'OK'       THEN 4
            ELSE 5
        END AS [StatusOrder],
        @PeriodStart AS [PeriodStart],
        @GeneratedAt AS [PeriodEnd],
        @GeneratedAt AS [GeneratedAt]
    FROM @Results
    ORDER BY
        [CheckOrder];
END;
GO


/*=============================================================================
  3. Raport miesięczny — audyt konfiguracji jobów
=============================================================================*/
CREATE OR ALTER PROCEDURE [report].[usp_MonthlyJobConfigurationAudit]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @GeneratedAt datetime2(0) = SYSDATETIME(),
        @PeriodStart datetime2(0) = DATEADD(month, -1, SYSDATETIME());

    DECLARE @Results table
    (
        [CheckOrder] int NOT NULL,
        [AuditArea] nvarchar(100) NOT NULL,
        [CheckCode] varchar(100) NOT NULL,
        [CheckName] nvarchar(300) NOT NULL,
        [Status] varchar(20) NOT NULL,
        [FindingCount] int NOT NULL,
        [Details] nvarchar(2000) NULL,
        [Recommendation] nvarchar(2000) NULL
    );

    DECLARE @AllJobs int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobInventory]
    );

    DECLARE @ActiveJobs int =
    (
        SELECT COUNT(*)
        FROM [report].[vActiveJobs]
    );

    DECLARE @DisabledJobs int =
    (
        SELECT COUNT(*)
        FROM [report].[vDisabledJobs]
    );

    DECLARE @OwnerIssues int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobOwnerComplianceAudit]
        WHERE [EffectiveFindingStatus] = N'OPEN'
    );

    DECLARE @ProxyIssues int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobProxyComplianceAudit]
        WHERE [EffectiveFindingStatus] = N'OPEN'
    );

    DECLARE @ScheduleIssues int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobScheduleComplianceAudit]
        WHERE [EffectiveFindingStatus] = N'OPEN'
    );

    DECLARE @NotificationIssues int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobNotificationComplianceAudit]
        WHERE [EffectiveFindingStatus] = N'OPEN'
    );

    DECLARE @DocumentationIssues int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobDocumentationComplianceAudit]
        WHERE [EffectiveFindingStatus] = N'OPEN'
    );

    DECLARE @JobsWithoutProxy int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobsWithoutProxy]
    );

    DECLARE @JobsWithoutRetry int =
    (
        SELECT COUNT(DISTINCT CONCAT([InstanceId], N'|', CONVERT(nvarchar(36), [JobId])))
        FROM [report].[vJobsWithoutRetry]
    );

    DECLARE @JobsWithOutputFile int =
    (
        SELECT COUNT(DISTINCT CONCAT([InstanceId], N'|', CONVERT(nvarchar(36), [JobId])))
        FROM [report].[vJobsWithOutputFile]
    );

    DECLARE @MultiStepJobs int =
    (
        SELECT COUNT(*)
        FROM [report].[vMultiStepJobs]
    );

    DECLARE @MultiScheduleJobs int =
    (
        SELECT COUNT(*)
        FROM [report].[vMultiScheduleJobs]
    );

    DECLARE @UnclassifiedJobs int =
    (
        SELECT COUNT(*)
        FROM [report].[vUnclassifiedJobs]
    );

    DECLARE @ExpiredExceptions int =
    (
        SELECT COUNT(*)
        FROM [report].[vExpiredJobComplianceExceptions]
    );

    DECLARE @ExceptionsWithoutTicket int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobComplianceExceptionsWithoutTicket]
    );

    DECLARE @DisabledRules int =
    (
        SELECT COUNT(*)
        FROM [report].[vDisabledJobComplianceRules]
    );

    DECLARE @ChangesWithoutTicket int =
    (
        SELECT COUNT(*)
        FROM [report].[vJobChangesWithoutTicket]
        WHERE [DetectedAt] >= @PeriodStart
    );

    DECLARE @UnauthorizedChanges int =
    (
        SELECT COUNT(*)
        FROM [report].[vUnauthorizedJobChanges]
        WHERE [DetectedAt] >= @PeriodStart
    );

    DECLARE @UnreviewedChanges int =
    (
        SELECT COUNT(*)
        FROM [report].[vUnreviewedJobChanges]
        WHERE [DetectedAt] >= @PeriodStart
    );

    DECLARE @FailedExecutions int =
    (
        SELECT COUNT(*)
        FROM [job].[JobExecution]
        WHERE [RunAt] >= @PeriodStart
          AND [RunStatus] = 0
    );

    INSERT @Results
    (
        [CheckOrder],
        [AuditArea],
        [CheckCode],
        [CheckName],
        [Status],
        [FindingCount],
        [Details],
        [Recommendation]
    )
    VALUES
    (
        10,
        N'Inwentaryzacja',
        'ALL_JOBS',
        N'Wszystkie joby',
        'INFO',
        @AllJobs,
        CONCAT
        (
            N'Wszystkie=', @AllJobs,
            N'; Aktywne=', @ActiveJobs,
            N'; Wyłączone=', @DisabledJobs
        ),
        N'Potwierdź zgodność liczby jobów z oczekiwanym zakresem środowiska.'
    ),
    (
        20,
        N'Właściciele',
        'OWNER_COMPLIANCE',
        N'Zgodność właścicieli jobów',
        CASE WHEN @OwnerIssues = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @OwnerIssues,
        CONCAT(N'Liczba otwartych findingów właścicieli: ', @OwnerIssues),
        N'Ustaw zatwierdzone konto techniczne i usuń zależność od kont osobistych.'
    ),
    (
        30,
        N'Proxy i bezpieczeństwo',
        'PROXY_COMPLIANCE',
        N'Zgodność proxy i credentials',
        CASE WHEN @ProxyIssues = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @ProxyIssues,
        CONCAT(N'Liczba otwartych findingów proxy: ', @ProxyIssues),
        N'Napraw proxy, credential albo dodaj zatwierdzony wyjątek.'
    ),
    (
        40,
        N'Proxy i bezpieczeństwo',
        'STEPS_WITHOUT_PROXY',
        N'Kroki PowerShell, CmdExec i SSIS bez proxy',
        CASE WHEN @JobsWithoutProxy = 0 THEN 'OK' ELSE 'WARNING' END,
        @JobsWithoutProxy,
        CONCAT(N'Liczba kroków: ', @JobsWithoutProxy),
        N'Zweryfikuj świadome użycie konta usługi SQL Server Agent.'
    ),
    (
        50,
        N'Harmonogramy',
        'SCHEDULE_COMPLIANCE',
        N'Zgodność harmonogramów',
        CASE WHEN @ScheduleIssues = 0 THEN 'OK' ELSE 'WARNING' END,
        @ScheduleIssues,
        CONCAT(N'Liczba otwartych findingów: ', @ScheduleIssues),
        N'Uzupełnij harmonogramy, włącz je albo udokumentuj ON_DEMAND.'
    ),
    (
        60,
        N'Harmonogramy',
        'MULTI_SCHEDULE_JOBS',
        N'Joby z wieloma harmonogramami',
        'INFO',
        @MultiScheduleJobs,
        CONCAT(N'Liczba jobów: ', @MultiScheduleJobs),
        N'Zweryfikuj nakładanie i cel każdego harmonogramu.'
    ),
    (
        70,
        N'Powiadomienia',
        'NOTIFICATION_COMPLIANCE',
        N'Zgodność operatorów i powiadomień',
        CASE WHEN @NotificationIssues = 0 THEN 'OK' ELSE 'WARNING' END,
        @NotificationIssues,
        CONCAT(N'Liczba otwartych findingów: ', @NotificationIssues),
        N'Przypisz aktywnego operatora i powiadomienie po błędzie.'
    ),
    (
        80,
        N'Odporność',
        'JOBS_WITHOUT_RETRY',
        N'Joby bez retry',
        CASE WHEN @JobsWithoutRetry = 0 THEN 'OK' ELSE 'INFO' END,
        @JobsWithoutRetry,
        CONCAT(N'Liczba jobów: ', @JobsWithoutRetry),
        N'Dla operacji podatnych na błędy przejściowe rozważ retry.'
    ),
    (
        90,
        N'Logowanie',
        'JOBS_WITH_OUTPUT_FILE',
        N'Joby zapisujące wynik do pliku',
        'INFO',
        @JobsWithOutputFile,
        CONCAT(N'Liczba jobów: ', @JobsWithOutputFile),
        N'Zweryfikuj retencję i lokalizację plików wyjściowych.'
    ),
    (
        100,
        N'Dokumentacja',
        'DOCUMENTATION_COMPLIANCE',
        N'Zgodność dokumentacji jobów',
        CASE WHEN @DocumentationIssues = 0 THEN 'OK' ELSE 'WARNING' END,
        @DocumentationIssues,
        CONCAT(N'Liczba otwartych findingów dokumentacyjnych: ', @DocumentationIssues),
        N'Uzupełnij właścicieli, krytyczność, opis i link do Confluence.'
    ),
    (
        110,
        N'Klasyfikacja',
        'UNCLASSIFIED_JOBS',
        N'Joby niesklasyfikowane funkcjonalnie',
        CASE WHEN @UnclassifiedJobs = 0 THEN 'OK' ELSE 'WARNING' END,
        @UnclassifiedJobs,
        CONCAT(N'Liczba jobów: ', @UnclassifiedJobs),
        N'Przypisz kategorię funkcjonalną albo rozbuduj reguły klasyfikacji.'
    ),
    (
        120,
        N'Złożoność',
        'MULTI_STEP_JOBS',
        N'Joby wielokrokowe',
        'INFO',
        @MultiStepJobs,
        CONCAT(N'Liczba jobów: ', @MultiStepJobs),
        N'Zweryfikuj ścieżki sukcesu, błędu i numery kroków.'
    ),
    (
        130,
        N'Wyjątki',
        'EXPIRED_EXCEPTIONS',
        N'Wygasłe wyjątki zgodności',
        CASE WHEN @ExpiredExceptions = 0 THEN 'OK' ELSE 'WARNING' END,
        @ExpiredExceptions,
        CONCAT(N'Liczba wyjątków: ', @ExpiredExceptions),
        N'Zamknij wyjątek albo przeprowadź ponowną akceptację.'
    ),
    (
        140,
        N'Wyjątki',
        'EXCEPTIONS_WITHOUT_TICKET',
        N'Wyjątki bez numeru zgłoszenia',
        CASE WHEN @ExceptionsWithoutTicket = 0 THEN 'OK' ELSE 'WARNING' END,
        @ExceptionsWithoutTicket,
        CONCAT(N'Liczba wyjątków: ', @ExceptionsWithoutTicket),
        N'Uzupełnij numer zgłoszenia i osobę zatwierdzającą.'
    ),
    (
        150,
        N'Reguły audytu',
        'DISABLED_AUDIT_RULES',
        N'Wyłączone reguły audytu',
        CASE WHEN @DisabledRules = 0 THEN 'OK' ELSE 'WARNING' END,
        @DisabledRules,
        CONCAT(N'Liczba wyłączonych reguł: ', @DisabledRules),
        N'Potwierdź, że wyłączenie każdej reguły jest świadome.'
    ),
    (
        160,
        N'Zarządzanie zmianą',
        'CHANGES_WITHOUT_TICKET',
        N'Zmiany bez numeru zgłoszenia w ostatnim miesiącu',
        CASE WHEN @ChangesWithoutTicket = 0 THEN 'OK' ELSE 'WARNING' END,
        @ChangesWithoutTicket,
        CONCAT(N'Liczba zmian: ', @ChangesWithoutTicket),
        N'Uzupełnij numer ticketu i status autoryzacji.'
    ),
    (
        170,
        N'Zarządzanie zmianą',
        'UNAUTHORIZED_CHANGES',
        N'Nieautoryzowane zmiany w ostatnim miesiącu',
        CASE WHEN @UnauthorizedChanges = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @UnauthorizedChanges,
        CONCAT(N'Liczba zmian: ', @UnauthorizedChanges),
        N'Przeprowadź analizę i ustal właściciela działania.'
    ),
    (
        180,
        N'Zarządzanie zmianą',
        'UNREVIEWED_CHANGES',
        N'Niezweryfikowane zmiany w ostatnim miesiącu',
        CASE WHEN @UnreviewedChanges = 0 THEN 'OK' ELSE 'WARNING' END,
        @UnreviewedChanges,
        CONCAT(N'Liczba zmian: ', @UnreviewedChanges),
        N'Przypisz status autoryzacji i ticket.'
    ),
    (
        190,
        N'Niezawodność',
        'FAILED_EXECUTIONS',
        N'Nieudane wykonania jobów w ostatnim miesiącu',
        CASE WHEN @FailedExecutions = 0 THEN 'OK' ELSE 'CRITICAL' END,
        @FailedExecutions,
        CONCAT(N'Liczba nieudanych wykonań: ', @FailedExecutions),
        N'Przeanalizuj powtarzalne błędy oraz joby o największej liczbie awarii.'
    );

    SELECT
        [CheckOrder],
        [AuditArea],
        [CheckCode],
        [CheckName],
        [Status],
        [FindingCount],
        [Details],
        [Recommendation],
        CASE [Status]
            WHEN 'CRITICAL' THEN 1
            WHEN 'WARNING'  THEN 2
            WHEN 'INFO'     THEN 3
            WHEN 'OK'       THEN 4
            ELSE 5
        END AS [StatusOrder],
        @PeriodStart AS [PeriodStart],
        @GeneratedAt AS [PeriodEnd],
        @GeneratedAt AS [GeneratedAt]
    FROM @Results
    ORDER BY
        [CheckOrder];
END;
GO


/*=============================================================================
  4. Extended properties
=============================================================================*/
IF OBJECT_ID(N'[dbo].[usp_SetDescription]', N'P') IS NOT NULL
BEGIN
    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'usp_DailyJobControl',
        @ObjectType = 'PROCEDURE',
        @Description = N'Automatyczny dzienny raport kontroli jobów SQL Server Agent.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'usp_WeeklyJobControl',
        @ObjectType = 'PROCEDURE',
        @Description = N'Automatyczny tygodniowy raport kontroli jobów SQL Server Agent.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'usp_MonthlyJobConfigurationAudit',
        @ObjectType = 'PROCEDURE',
        @Description = N'Miesięczny audyt konfiguracji jobów SQL Server Agent.';
END;
GO


/*=============================================================================
  5. Testy po instalacji
=============================================================================*/
EXEC [report].[usp_DailyJobControl];
GO

EXEC [report].[usp_WeeklyJobControl];
GO

EXEC [report].[usp_MonthlyJobConfigurationAudit];
GO
