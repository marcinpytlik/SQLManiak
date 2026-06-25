USE msdb;
GO

/* ============================================================
   12_example_patching_window_disable_jobs.sql

   Cel:
   - Pokazuje przykładowe użycie modułu patchingowego.
   - Tworzy okno serwisowe.
   - Wykonuje Preview jobów do wyłączenia.
   - Wykonuje Execute wyłączenia jobów.
   - Pokazuje raport po wyłączeniu.

   UWAGA:
   - Przed uruchomieniem na produkcji najpierw użyj Preview.
   - Domyślnie chronione są joby: Backup, LOG, Monitoring,
     Alert, DBA, Restore, CheckDB, Integrity.
   ============================================================ */

SET NOCOUNT ON;
GO

DECLARE @PatchingRunId int;

EXEC msdb.dba.usp_StartSqlAgentPatchingWindow
    @Description = N'Patchowanie SQL Server - przykład okna serwisowego',
    @PlannedStartDateTime = NULL,
    @PlannedEndDateTime = NULL,
    @PatchingRunId = @PatchingRunId OUTPUT;

SELECT @PatchingRunId AS PatchingRunId;
GO

------------------------------------------------------------
-- WARIANT A: Preview dla wszystkich jobów
-- Joby krytyczne zostaną pokazane jako pominięte.
------------------------------------------------------------
DECLARE @PatchingRunId int =
(
    SELECT MAX(PatchingRunId)
    FROM msdb.dba.SqlAgentPatchingRun
    WHERE Description = N'Patchowanie SQL Server - przykład okna serwisowego'
);

EXEC msdb.dba.usp_DisableSqlAgentJobsForPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Preview',
    @JobNameLike = NULL,
    @CategoryName = NULL,
    @ExcludeJobNameLike = NULL,
    @ExcludeJobNameList = NULL,
    @IncludeBackupJobs = 0,
    @IncludeMonitoringJobs = 0,
    @Comment = N'Preview przed patchowaniem';
GO

------------------------------------------------------------
-- WARIANT B: Execute dla wybranych jobów
-- Dostosuj filtr @JobNameLike do swojego środowiska.
-- Przykład zostawia ochronę jobów backupowych i monitoringowych.
------------------------------------------------------------
DECLARE @PatchingRunId int =
(
    SELECT MAX(PatchingRunId)
    FROM msdb.dba.SqlAgentPatchingRun
    WHERE Description = N'Patchowanie SQL Server - przykład okna serwisowego'
);

EXEC msdb.dba.usp_DisableSqlAgentJobsForPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Execute',
    @JobNameLike = NULL,
    @CategoryName = NULL,
    @ExcludeJobNameLike = NULL,
    @ExcludeJobNameList = N'DBA - Monitoring,DBA - Alerting',
    @IncludeBackupJobs = 0,
    @IncludeMonitoringJobs = 0,
    @Comment = N'Wyłączenie jobów przed patchowaniem SQL Server';
GO

------------------------------------------------------------
-- Raport po wyłączeniu
------------------------------------------------------------
DECLARE @PatchingRunId int =
(
    SELECT MAX(PatchingRunId)
    FROM msdb.dba.SqlAgentPatchingRun
    WHERE Description = N'Patchowanie SQL Server - przykład okna serwisowego'
);

EXEC msdb.dba.usp_ReportSqlAgentPatchingWindow
    @PatchingRunId = @PatchingRunId;
GO
