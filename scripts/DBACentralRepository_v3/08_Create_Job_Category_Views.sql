USE [DBACentralRepository];
GO

/*
===============================================================================
Plik: 10_Create_Job_Category_Views.sql
Cel: Widoki raportowe dla kategorii jobów SQL Server Agent.
Wymagania: [report].[vCurrentJobs], [audit].[vCurrentJobSteps],
           [audit].[vCurrentJobSchedules], [audit].[JobDocumentation].
===============================================================================
*/

CREATE OR ALTER VIEW [report].[vJobInventory]
AS
SELECT
    J.[InstanceId], J.[ServerInstance], J.[EnvironmentCode], J.[JobId],
    J.[JobName], J.[CategoryName], J.[OwnerName], J.[Description],
    J.[IsEnabled], J.[StartStepId], J.[DateCreated], J.[DateModified],
    J.[NotifyLevelEmail], J.[OperatorName],
    ISNULL(ST.[StepCount],0) AS [StepCount],
    ISNULL(SC.[ScheduleCount],0) AS [ScheduleCount],
    ISNULL(SC.[EnabledScheduleCount],0) AS [EnabledScheduleCount],
    ISNULL(SC.[DisabledScheduleCount],0) AS [DisabledScheduleCount],
    SC.[NextRunAt],
    CASE WHEN ISNULL(J.[NotifyLevelEmail],0) IN (2,3)
              AND NULLIF(J.[OperatorName],N'') IS NOT NULL
         THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS [HasFailureNotification],
    CASE WHEN D.[JobDocumentationId] IS NOT NULL
              AND D.[IsDocumented]=1
              AND NULLIF(D.[ConfluencePageUrl],N'') IS NOT NULL
         THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS [IsDocumented],
    D.[DocumentationStatus], D.[ConfluencePageUrl], D.[TechnicalOwner],
    D.[BusinessOwner], D.[Criticality], D.[LastReviewedAt],
    CASE WHEN J.[IsEnabled]=0 THEN N'DISABLED'
         WHEN ISNULL(SC.[ScheduleCount],0)=0 THEN N'ON_DEMAND'
         WHEN ISNULL(SC.[EnabledScheduleCount],0)=0 THEN N'NO_ACTIVE_SCHEDULE'
         ELSE N'SCHEDULED' END AS [ExecutionMode]
FROM [report].[vCurrentJobs] AS J
OUTER APPLY
(
    SELECT COUNT(*) AS [StepCount]
    FROM [audit].[vCurrentJobSteps] AS S
    WHERE S.[InstanceId]=J.[InstanceId] AND S.[JobId]=J.[JobId]
) AS ST
OUTER APPLY
(
    SELECT COUNT(*) AS [ScheduleCount],
           SUM(CASE WHEN S.[IsEnabled]=1 THEN 1 ELSE 0 END) AS [EnabledScheduleCount],
           SUM(CASE WHEN S.[IsEnabled]=0 THEN 1 ELSE 0 END) AS [DisabledScheduleCount],
           MIN(S.[NextRunAt]) AS [NextRunAt]
    FROM [audit].[vCurrentJobSchedules] AS S
    WHERE S.[InstanceId]=J.[InstanceId] AND S.[JobId]=J.[JobId]
) AS SC
LEFT JOIN [audit].[JobDocumentation] AS D
  ON D.[InstanceId]=J.[InstanceId] AND D.[JobId]=J.[JobId];
GO

CREATE OR ALTER VIEW [report].[vJobStepInventory]
AS
SELECT
    J.[InstanceId], J.[ServerInstance], J.[EnvironmentCode], J.[JobId],
    J.[JobName], J.[CategoryName], J.[OwnerName], J.[IsEnabled],
    J.[OperatorName], J.[NotifyLevelEmail], J.[ExecutionMode],
    S.[StepId], S.[StepName], S.[Subsystem], S.[DatabaseName],
    S.[CommandText], S.[ProxyName], S.[RetryAttempts], S.[RetryInterval],
    S.[OutputFileName], S.[OnSuccessAction], S.[OnSuccessStepId],
    S.[OnFailAction], S.[OnFailStepId],
    UPPER(ISNULL(S.[CommandText],N'')) AS [CommandTextUpper],
    UPPER(ISNULL(J.[JobName],N'')) AS [JobNameUpper],
    UPPER(ISNULL(S.[StepName],N'')) AS [StepNameUpper],
    UPPER(ISNULL(J.[CategoryName],N'')) AS [CategoryNameUpper]
FROM [report].[vJobInventory] AS J
JOIN [audit].[vCurrentJobSteps] AS S
  ON S.[InstanceId]=J.[InstanceId] AND S.[JobId]=J.[JobId];
GO

CREATE OR ALTER VIEW [report].[vActiveJobs] AS
SELECT * FROM [report].[vJobInventory] WHERE [IsEnabled]=1;
GO

CREATE OR ALTER VIEW [report].[vDisabledJobs] AS
SELECT * FROM [report].[vJobInventory] WHERE [IsEnabled]=0;
GO

CREATE OR ALTER VIEW [report].[vJobsWithoutSchedule] AS
SELECT * FROM [report].[vJobInventory] WHERE [ScheduleCount]=0;
GO

CREATE OR ALTER VIEW [report].[vOnDemandJobs] AS
SELECT * FROM [report].[vJobInventory] WHERE [ExecutionMode]=N'ON_DEMAND';
GO

CREATE OR ALTER VIEW [report].[vJobsWithDisabledSchedule] AS
SELECT * FROM [report].[vJobInventory]
WHERE [ScheduleCount]>0 AND [EnabledScheduleCount]=0;
GO

CREATE OR ALTER VIEW [report].[vJobsWithoutNotification] AS
SELECT * FROM [report].[vJobInventory]
WHERE [IsEnabled]=1 AND [HasFailureNotification]=0;
GO

CREATE OR ALTER VIEW [report].[vUndocumentedJobInventory] AS
SELECT * FROM [report].[vJobInventory] WHERE [IsDocumented]=0;
GO

CREATE OR ALTER VIEW [report].[vMultiStepJobs] AS
SELECT * FROM [report].[vJobInventory] WHERE [StepCount]>1;
GO

CREATE OR ALTER VIEW [report].[vMultiScheduleJobs] AS
SELECT * FROM [report].[vJobInventory] WHERE [ScheduleCount]>1;
GO

CREATE OR ALTER VIEW [report].[vTsqlJobs] AS
SELECT * FROM [report].[vJobStepInventory] WHERE [Subsystem]=N'TSQL';
GO

CREATE OR ALTER VIEW [report].[vPowerShellJobs] AS
SELECT * FROM [report].[vJobStepInventory] WHERE [Subsystem]=N'PowerShell';
GO

CREATE OR ALTER VIEW [report].[vCmdExecJobs] AS
SELECT * FROM [report].[vJobStepInventory] WHERE [Subsystem]=N'CmdExec';
GO

CREATE OR ALTER VIEW [report].[vSsisJobs] AS
SELECT * FROM [report].[vJobStepInventory] WHERE [Subsystem]=N'SSIS';
GO

CREATE OR ALTER VIEW [report].[vBackupJobs]
AS
SELECT J.*,
       CASE
         WHEN J.[CommandTextUpper] LIKE N'%BACKUP LOG%' THEN N'LOG'
         WHEN J.[CommandTextUpper] LIKE N'%BACKUP DATABASE%'
          AND J.[CommandTextUpper] LIKE N'%DIFFERENTIAL%' THEN N'DIFF'
         WHEN J.[CommandTextUpper] LIKE N'%DATABASEBACKUP%'
          AND J.[CommandTextUpper] LIKE N'%BACKUPTYPE%'
          AND J.[CommandTextUpper] LIKE N'%LOG%' THEN N'LOG'
         WHEN J.[CommandTextUpper] LIKE N'%DATABASEBACKUP%'
          AND J.[CommandTextUpper] LIKE N'%BACKUPTYPE%'
          AND J.[CommandTextUpper] LIKE N'%DIFF%' THEN N'DIFF'
         WHEN J.[CommandTextUpper] LIKE N'%DATABASEBACKUP%'
          AND J.[CommandTextUpper] LIKE N'%BACKUPTYPE%'
          AND J.[CommandTextUpper] LIKE N'%FULL%' THEN N'FULL'
         WHEN J.[CommandTextUpper] LIKE N'%COPY_ONLY%' THEN N'COPY_ONLY'
         WHEN J.[CommandTextUpper] LIKE N'%BACKUP DATABASE%' THEN N'FULL'
         WHEN J.[Subsystem] IN (N'PowerShell',N'CmdExec')
          AND J.[CommandTextUpper] LIKE N'%BACKUP%' THEN N'SCRIPT'
         ELSE N'UNCLASSIFIED' END AS [BackupType],
       CASE WHEN J.[CommandTextUpper] LIKE N'%BACKUP DATABASE%'
                  OR J.[CommandTextUpper] LIKE N'%BACKUP LOG%'
                  OR J.[CommandTextUpper] LIKE N'%DATABASEBACKUP%'
            THEN N'COMMAND'
            WHEN J.[Subsystem] IN (N'PowerShell',N'CmdExec')
             AND J.[CommandTextUpper] LIKE N'%BACKUP%' THEN N'SCRIPT'
            ELSE N'NAME_OR_CATEGORY' END AS [DetectionMethod]
FROM [report].[vJobStepInventory] AS J
WHERE J.[CommandTextUpper] LIKE N'%BACKUP DATABASE%'
   OR J.[CommandTextUpper] LIKE N'%BACKUP LOG%'
   OR J.[CommandTextUpper] LIKE N'%DATABASEBACKUP%'
   OR J.[CommandTextUpper] LIKE N'%SQLBACKUP%'
   OR J.[JobNameUpper] LIKE N'%BACKUP%'
   OR J.[StepNameUpper] LIKE N'%BACKUP%'
   OR J.[CategoryNameUpper] LIKE N'%BACKUP%';
GO

CREATE OR ALTER VIEW [report].[vCheckDbJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [CommandTextUpper] LIKE N'%DBCC CHECKDB%'
   OR [CommandTextUpper] LIKE N'%DATABASEINTEGRITYCHECK%'
   OR [JobNameUpper] LIKE N'%CHECKDB%'
   OR [JobNameUpper] LIKE N'%INTEGRITY%'
   OR [StepNameUpper] LIKE N'%CHECKDB%';
GO

CREATE OR ALTER VIEW [report].[vIndexMaintenanceJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [CommandTextUpper] LIKE N'%ALTER INDEX%'
   OR [CommandTextUpper] LIKE N'%INDEXOPTIMIZE%'
   OR [CommandTextUpper] LIKE N'%DBREINDEX%'
   OR [CommandTextUpper] LIKE N'%INDEXDEFRAG%'
   OR [JobNameUpper] LIKE N'%INDEX%'
   OR [StepNameUpper] LIKE N'%INDEX%';
GO

CREATE OR ALTER VIEW [report].[vStatisticsJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [CommandTextUpper] LIKE N'%UPDATE STATISTICS%'
   OR [CommandTextUpper] LIKE N'%SP_UPDATESTATS%'
   OR [JobNameUpper] LIKE N'%STATISTIC%'
   OR [StepNameUpper] LIKE N'%STATISTIC%';
GO

CREATE OR ALTER VIEW [report].[vMaintenanceJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [CategoryNameUpper] LIKE N'%DATABASE MAINTENANCE%'
   OR [JobNameUpper] LIKE N'%MAINT%'
   OR [JobNameUpper] LIKE N'%CLEANUP%'
   OR [CommandTextUpper] LIKE N'%DATABASEINTEGRITYCHECK%'
   OR [CommandTextUpper] LIKE N'%INDEXOPTIMIZE%'
   OR [CommandTextUpper] LIKE N'%COMMANDLOGCLEANUP%'
   OR [CommandTextUpper] LIKE N'%OUTPUTFILECLEANUP%';
GO

CREATE OR ALTER VIEW [report].[vCleanupJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [CommandTextUpper] LIKE N'%TRUNCATE TABLE%'
   OR [CommandTextUpper] LIKE N'%HISTORYCLEANUP%'
   OR [CommandTextUpper] LIKE N'%COMMANDLOGCLEANUP%'
   OR [CommandTextUpper] LIKE N'%OUTPUTFILECLEANUP%'
   OR [CommandTextUpper] LIKE N'%SP_PURGE_JOBHISTORY%'
   OR [CommandTextUpper] LIKE N'%SP_DELETE_BACKUPHISTORY%'
   OR [CommandTextUpper] LIKE N'%RETENTION%'
   OR [JobNameUpper] LIKE N'%CLEANUP%'
   OR [JobNameUpper] LIKE N'%PURGE%'
   OR [JobNameUpper] LIKE N'%RETENTION%';
GO

CREATE OR ALTER VIEW [report].[vReplicationJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [CategoryNameUpper] LIKE N'%REPL%'
   OR [JobNameUpper] LIKE N'%REPL%'
   OR [CommandTextUpper] LIKE N'%DISTRIBUTION%'
   OR [CommandTextUpper] LIKE N'%LOGREADER%'
   OR [CommandTextUpper] LIKE N'%SP_REPL%';
GO

CREATE OR ALTER VIEW [report].[vHaDrJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [JobNameUpper] LIKE N'%AVAILABILITY%'
   OR [JobNameUpper] LIKE N'%ALWAYSON%'
   OR [JobNameUpper] LIKE N'%FAILOVER%'
   OR [JobNameUpper] LIKE N'%LOG SHIPPING%'
   OR [JobNameUpper] LIKE N'%LOGSHIP%'
   OR [JobNameUpper] LIKE N'%MIRROR%'
   OR [CommandTextUpper] LIKE N'%HADR%'
   OR [CommandTextUpper] LIKE N'%AVAILABILITY GROUP%'
   OR [CommandTextUpper] LIKE N'%LOG_SHIPPING%';
GO

CREATE OR ALTER VIEW [report].[vEtlIntegrationJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [Subsystem]=N'SSIS'
   OR [JobNameUpper] LIKE N'%ETL%'
   OR [JobNameUpper] LIKE N'%IMPORT%'
   OR [JobNameUpper] LIKE N'%EXPORT%'
   OR [JobNameUpper] LIKE N'%INTEGRATION%'
   OR [JobNameUpper] LIKE N'%INTERFACE%'
   OR [CommandTextUpper] LIKE N'%DTEXEC%'
   OR [CommandTextUpper] LIKE N'%SSISDB%'
   OR [CommandTextUpper] LIKE N'%BULK INSERT%'
   OR [CommandTextUpper] LIKE N'%BCP %';
GO

CREATE OR ALTER VIEW [report].[vReportingJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [JobNameUpper] LIKE N'%REPORT%'
   OR [JobNameUpper] LIKE N'%SSRS%'
   OR [JobNameUpper] LIKE N'%POWER BI%'
   OR [JobNameUpper] LIKE N'%POWERBI%'
   OR [CommandTextUpper] LIKE N'%REPORTSERVER%'
   OR [CommandTextUpper] LIKE N'%SSRS%'
   OR [CommandTextUpper] LIKE N'%POWERBI%';
GO

CREATE OR ALTER VIEW [report].[vMonitoringJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [JobNameUpper] LIKE N'%MONITOR%'
   OR [JobNameUpper] LIKE N'%ALERT%'
   OR [JobNameUpper] LIKE N'%HEALTH%'
   OR [CommandTextUpper] LIKE N'%SP_SEND_DBMAIL%'
   OR [CommandTextUpper] LIKE N'%DM_OS_PERFORMANCE_COUNTERS%'
   OR [CommandTextUpper] LIKE N'%DM_EXEC_REQUESTS%';
GO

CREATE OR ALTER VIEW [report].[vSecurityAuditJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [JobNameUpper] LIKE N'%SECURITY%'
   OR [JobNameUpper] LIKE N'%AUDIT%'
   OR [JobNameUpper] LIKE N'%LOGIN%'
   OR [JobNameUpper] LIKE N'%PERMISSION%'
   OR [CommandTextUpper] LIKE N'%SERVER_AUDIT%'
   OR [CommandTextUpper] LIKE N'%DATABASE_AUDIT%'
   OR [CommandTextUpper] LIKE N'%[sys].[SERVER_PRINCIPALS]%'
   OR [CommandTextUpper] LIKE N'%[sys].[DATABASE_PRINCIPALS]%';
GO

CREATE OR ALTER VIEW [report].[vDatabaseMailJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [CommandTextUpper] LIKE N'%SP_SEND_DBMAIL%'
   OR [JobNameUpper] LIKE N'%MAIL%'
   OR [JobNameUpper] LIKE N'%EMAIL%';
GO

CREATE OR ALTER VIEW [report].[vStoredProcedureJobs] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [Subsystem]=N'TSQL'
  AND ([CommandTextUpper] LIKE N'%EXEC %' OR [CommandTextUpper] LIKE N'%EXECUTE %');
GO

CREATE OR ALTER VIEW [report].[vJobsWithoutProxy] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE [Subsystem] IN (N'PowerShell',N'CmdExec',N'SSIS')
  AND NULLIF([ProxyName],N'') IS NULL;
GO

CREATE OR ALTER VIEW [report].[vJobsWithRetry] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE ISNULL([RetryAttempts],0)>0;
GO

CREATE OR ALTER VIEW [report].[vJobsWithoutRetry] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE ISNULL([RetryAttempts],0)=0;
GO

CREATE OR ALTER VIEW [report].[vJobsWithOutputFile] AS
SELECT * FROM [report].[vJobStepInventory]
WHERE NULLIF([OutputFileName],N'') IS NOT NULL;
GO

CREATE OR ALTER VIEW [report].[vJobsRequiringAttention]
AS
SELECT J.*,
       CASE WHEN J.[IsEnabled]=0 THEN N'JOB_DISABLED'
            WHEN J.[ScheduleCount]=0 THEN N'JOB_NO_SCHEDULE'
            WHEN J.[ScheduleCount]>0 AND J.[EnabledScheduleCount]=0 THEN N'JOB_NO_ACTIVE_SCHEDULE'
            WHEN J.[HasFailureNotification]=0 THEN N'JOB_NO_NOTIFICATION'
            WHEN J.[IsDocumented]=0 THEN N'JOB_NOT_DOCUMENTED'
            ELSE N'OTHER' END AS [AttentionReason]
FROM [report].[vJobInventory] AS J
WHERE J.[IsEnabled]=0
   OR J.[ScheduleCount]=0
   OR (J.[ScheduleCount]>0 AND J.[EnabledScheduleCount]=0)
   OR J.[HasFailureNotification]=0
   OR J.[IsDocumented]=0;
GO

CREATE OR ALTER VIEW [report].[vJobCategoryMembership]
AS
SELECT DISTINCT X.*
FROM
(
    SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'BACKUP' [CategoryCode],N'Backup' [CategoryName] FROM [report].[vBackupJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'CHECKDB',N'Integralność / CHECKDB' FROM [report].[vCheckDbJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'INDEX_MAINTENANCE',N'Utrzymanie indeksów' FROM [report].[vIndexMaintenanceJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'STATISTICS',N'Aktualizacja statystyk' FROM [report].[vStatisticsJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'REPLICATION',N'Replikacja' FROM [report].[vReplicationJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'HA_DR',N'HA / DR' FROM [report].[vHaDrJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'ETL_INTEGRATION',N'ETL / Integracja' FROM [report].[vEtlIntegrationJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'REPORTING',N'Raportowanie' FROM [report].[vReportingJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'MONITORING',N'Monitoring / Alerting' FROM [report].[vMonitoringJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'CLEANUP',N'Czyszczenie / Retencja' FROM [report].[vCleanupJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'SECURITY_AUDIT',N'Bezpieczeństwo / Audyt' FROM [report].[vSecurityAuditJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'DATABASE_MAIL',N'Database Mail' FROM [report].[vDatabaseMailJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'SSIS',N'SSIS' FROM [report].[vSsisJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'POWERSHELL',N'PowerShell' FROM [report].[vPowerShellJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'CMDEXEC',N'CmdExec' FROM [report].[vCmdExecJobs]
    UNION ALL SELECT [InstanceId],[ServerInstance],[EnvironmentCode],[JobId],[JobName],[OwnerName],[IsEnabled],N'TSQL',N'T-SQL' FROM [report].[vTsqlJobs]
) AS X;
GO

CREATE OR ALTER VIEW [report].[vUnclassifiedJobs]
AS
SELECT J.*
FROM [report].[vJobInventory] AS J
WHERE NOT EXISTS
(
    SELECT 1 FROM [report].[vJobCategoryMembership] AS C
    WHERE C.[InstanceId]=J.[InstanceId] AND C.[JobId]=J.[JobId]
      AND C.[CategoryCode] NOT IN (N'TSQL',N'POWERSHELL',N'CMDEXEC',N'SSIS')
);
GO

CREATE OR ALTER VIEW [report].[vJobCategorySummary]
AS
SELECT [EnvironmentCode],[ServerInstance],[CategoryCode],[CategoryName],
       COUNT(*) AS [JobCount],
       SUM(CASE WHEN [IsEnabled]=1 THEN 1 ELSE 0 END) AS [EnabledJobCount],
       SUM(CASE WHEN [IsEnabled]=0 THEN 1 ELSE 0 END) AS [DisabledJobCount]
FROM [report].[vJobCategoryMembership]
GROUP BY [EnvironmentCode],[ServerInstance],[CategoryCode],[CategoryName];
GO

IF OBJECT_ID(N'[dbo].[usp_SetDescription]',N'P') IS NOT NULL
BEGIN
    EXEC [dbo].[usp_SetDescription] N'report',N'vJobInventory','VIEW',N'Jeden wiersz na job wraz z harmonogramem, powiadomieniem i dokumentacją.';
    EXEC [dbo].[usp_SetDescription] N'report',N'vJobStepInventory','VIEW',N'Jeden wiersz na krok joba wraz z komendą i subsystemem.';
    EXEC [dbo].[usp_SetDescription] N'report',N'vBackupJobs','VIEW',N'Kroki jobów wykonujące backupy FULL, DIFF, LOG, COPY_ONLY lub skryptowe.';
    EXEC [dbo].[usp_SetDescription] N'report',N'vJobCategoryMembership','VIEW',N'Przypisanie jobów do wielu kategorii funkcjonalnych i technicznych.';
    EXEC [dbo].[usp_SetDescription] N'report',N'vJobCategorySummary','VIEW',N'Podsumowanie liczby jobów według instancji i kategorii.';
END;
GO

/* Kontrola po wdrożeniu */
SELECT *
FROM [report].[vJobCategorySummary]
ORDER BY [EnvironmentCode],[ServerInstance],[CategoryName];
GO

SELECT COUNT(*) AS [AllJobs] FROM [report].[vJobInventory];
SELECT COUNT(*) AS [JobsRequiringAttention] FROM [report].[vJobsRequiringAttention];
GO
