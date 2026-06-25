USE msdb;
GO

/* ============================================================
   14_test_patching_job_control.sql

   Cel:
   - Tworzy testowe joby SQL Agent.
   - Sprawdza Preview i Execute wyłączania jobów.
   - Sprawdza ochronę jobów krytycznych.
   - Sprawdza, że job wcześniej wyłączony nie zostanie przypadkowo włączony.
   - Przywraca joby i sprząta testowe obiekty.

   UWAGA:
   - Skrypt tworzy i usuwa joby o nazwach zaczynających się od:
     SQLManiak TEST Patching
   ============================================================ */

SET NOCOUNT ON;
GO

------------------------------------------------------------
-- 1. Sprzątanie poprzednich testów
------------------------------------------------------------
DECLARE @CleanupJobName sysname;

DECLARE cleanup_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM msdb.dbo.sysjobs
WHERE name LIKE N'SQLManiak TEST Patching%';

OPEN cleanup_cursor;
FETCH NEXT FROM cleanup_cursor INTO @CleanupJobName;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC msdb.dbo.sp_delete_job
        @job_name = @CleanupJobName,
        @delete_unused_schedule = 1;

    FETCH NEXT FROM cleanup_cursor INTO @CleanupJobName;
END;

CLOSE cleanup_cursor;
DEALLOCATE cleanup_cursor;
GO

------------------------------------------------------------
-- 2. Utworzenie testowych jobów
------------------------------------------------------------
DECLARE @JobId uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = N'SQLManiak TEST Patching - Normal Job A',
    @enabled = 1,
    @description = N'Job testowy do modułu patchingowego - powinien zostać wyłączony i przywrócony.',
    @job_id = @JobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_name = N'Test step',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'SELECT ''Normal Job A'' AS Info;';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobId,
    @server_name = N'(LOCAL)';

SET @JobId = NULL;

EXEC msdb.dbo.sp_add_job
    @job_name = N'SQLManiak TEST Patching - Normal Job B Disabled Before',
    @enabled = 0,
    @description = N'Job testowy wcześniej wyłączony - nie powinien zostać włączony po restore.',
    @job_id = @JobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_name = N'Test step',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'SELECT ''Normal Job B'' AS Info;';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobId,
    @server_name = N'(LOCAL)';

SET @JobId = NULL;

EXEC msdb.dbo.sp_add_job
    @job_name = N'SQLManiak TEST Patching - Backup Critical Job',
    @enabled = 1,
    @description = N'Job testowy krytyczny - domyślnie powinien być pominięty.',
    @job_id = @JobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_name = N'Test step',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'SELECT ''Backup Critical Job'' AS Info;';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobId,
    @server_name = N'(LOCAL)';
GO

------------------------------------------------------------
-- 3. Utworzenie okna patchowania
------------------------------------------------------------
DECLARE @PatchingRunId int;

EXEC msdb.dba.usp_StartSqlAgentPatchingWindow
    @Description = N'TEST - SQLManiak patching job control',
    @PlannedStartDateTime = NULL,
    @PlannedEndDateTime = NULL,
    @PatchingRunId = @PatchingRunId OUTPUT;

SELECT @PatchingRunId AS PatchingRunId;

------------------------------------------------------------
-- 4. Preview
------------------------------------------------------------
EXEC msdb.dba.usp_DisableSqlAgentJobsForPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Preview',
    @JobNameLike = N'SQLManiak TEST Patching%',
    @IncludeBackupJobs = 0,
    @IncludeMonitoringJobs = 0,
    @Comment = N'Test preview';

------------------------------------------------------------
-- 5. Execute wyłączenia
------------------------------------------------------------
EXEC msdb.dba.usp_DisableSqlAgentJobsForPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Execute',
    @JobNameLike = N'SQLManiak TEST Patching%',
    @IncludeBackupJobs = 0,
    @IncludeMonitoringJobs = 0,
    @Comment = N'Test disable';

------------------------------------------------------------
-- 6. Kontrola po Disable
------------------------------------------------------------
SELECT
    name AS JobName,
    enabled
FROM msdb.dbo.sysjobs
WHERE name LIKE N'SQLManiak TEST Patching%'
ORDER BY name;

EXEC msdb.dba.usp_ReportSqlAgentPatchingWindow
    @PatchingRunId = @PatchingRunId;

------------------------------------------------------------
-- 7. Preview i Execute przywrócenia
------------------------------------------------------------
EXEC msdb.dba.usp_RestoreSqlAgentJobsAfterPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Preview',
    @Comment = N'Test restore preview';

EXEC msdb.dba.usp_RestoreSqlAgentJobsAfterPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Execute',
    @Comment = N'Test restore execute';

------------------------------------------------------------
-- 8. Kontrola po Restore
-- Oczekiwane:
-- - Normal Job A: enabled = 1
-- - Normal Job B Disabled Before: enabled = 0
-- - Backup Critical Job: enabled = 1
------------------------------------------------------------
SELECT
    name AS JobName,
    enabled
FROM msdb.dbo.sysjobs
WHERE name LIKE N'SQLManiak TEST Patching%'
ORDER BY name;

------------------------------------------------------------
-- 9. Sprzątanie testowych jobów
------------------------------------------------------------
DECLARE @CleanupJobName sysname;

DECLARE cleanup_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM msdb.dbo.sysjobs
WHERE name LIKE N'SQLManiak TEST Patching%';

OPEN cleanup_cursor;
FETCH NEXT FROM cleanup_cursor INTO @CleanupJobName;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC msdb.dbo.sp_delete_job
        @job_name = @CleanupJobName,
        @delete_unused_schedule = 1;

    FETCH NEXT FROM cleanup_cursor INTO @CleanupJobName;
END;

CLOSE cleanup_cursor;
DEALLOCATE cleanup_cursor;
GO
