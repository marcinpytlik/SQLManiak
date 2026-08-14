/*
===============================================================================
Plik końcowy: zapytania użytkowe i kontrolne.
Nie tworzy obiektów. Uruchamiać dopiero po zakończeniu instalacji 00–25.
===============================================================================
*/

USE [DBACentralRepository];
GO

SELECT * FROM [report].[vCurrentInstances] ORDER BY EnvironmentCode,ServerInstance;
GO

SELECT * FROM [report].[vCurrentJobs] ORDER BY ServerInstance,JobName;
GO

SELECT * FROM [report].[vCurrentDatabases] ORDER BY ServerInstance,DatabaseName;
GO

EXEC [report].[usp_BackupCompliance];
GO

EXEC [report].[usp_CapacityRisk];
GO

EXEC [report].[usp_HaHealth];
GO

DECLARE @ComplianceRunId bigint;
EXEC [audit].[usp_RunJobComplianceAudit]
    @ComplianceRunId=@ComplianceRunId OUTPUT;
SELECT @ComplianceRunId AS ComplianceRunId;
GO

EXEC [report].[usp_JobComplianceSummary];
GO

SELECT *
FROM [report].[vUndocumentedJobs]
WHERE AuditStatus<>N'OK'
ORDER BY EnvironmentCode,ServerInstance,JobName;
GO

EXEC [report].[usp_JobChanges] @Days=30;
GO

SELECT TOP(200)
    S.ScanStartedAt,I.ServerInstance,E.ModuleName,E.ObjectName,E.StageName,E.ErrorMessage,E.ErrorAt
FROM [dbo].[ScanError] E
JOIN [dbo].[ScanRun] S ON S.ScanRunId=E.ScanRunId
LEFT JOIN [dbo].[Instance] I ON I.InstanceId=E.InstanceId
ORDER BY E.ErrorAt DESC;
GO


/* TABLE USAGE */
SELECT
    I.ServerInstance,
    T.TableUsageTargetId,
    T.DatabaseName,
    T.IsEnabled,
    T.AuditName,
    T.AuditPath
FROM perf.TableUsageTarget AS T
JOIN dbo.Instance AS I ON I.InstanceId=T.InstanceId
ORDER BY I.ServerInstance,T.DatabaseName;
GO

-- Przykład po skonfigurowaniu targetu:
-- EXEC perf.usp_GetTableUsageByPrincipal
--     @ServerInstance=N'sql32',
--     @DatabaseName=N'CRM',
--     @From=DATEADD(day,-7,SYSUTCDATETIME()),
--     @To=SYSUTCDATETIME(),
--     @Top=100;
GO
