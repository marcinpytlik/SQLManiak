/*
    10_demo_run_full_backup_10_10_5.sql

    Cel:
      - uruchomić realny FULL backup dla baz DBA_BCK_TEST_001 - DBA_BCK_TEST_025
        zgodnie z konfiguracją:
          001-010 -> C:\backup1
          011-020 -> C:\backup2
          021-025 -> C:\backup3

    Uwaga:
      - konto usługi SQL Server Engine musi mieć prawo zapisu do C:\backup1, C:\backup2, C:\backup3.
      - uruchamiaj po sprawdzeniu DryRun.
*/

USE [msdb];
GO

EXEC dbo.usp_BackupDatabases_ByConfig
    @BackupType = 'FULL',
    @DryRun = 0;
GO

SELECT TOP (100)
    ExecutionId,
    DatabaseName,
    BackupType,
    BackupBasePath,
    BackupFile,
    StartedAt,
    FinishedAt,
    Status,
    Message
FROM msdb.dbo.DBA_BackupExecutionLog
WHERE DatabaseName LIKE N'DBA_BCK_TEST[_]%'
ORDER BY LogId DESC;
GO
