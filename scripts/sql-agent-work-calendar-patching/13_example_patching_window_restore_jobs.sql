USE msdb;
GO

/* ============================================================
   13_example_patching_window_restore_jobs.sql

   Cel:
   - Pokazuje przywrócenie jobów po patchowaniu SQL Server.
   - Restore włącza tylko te joby, które:
       * przed patchowaniem były włączone,
       * zostały wyłączone przez moduł patchingowy.
   - Nie włącza jobów, które przed patchowaniem były wyłączone.

   UWAGA:
   - Ustaw poprawny @PatchingRunId z okna patchowania.
   ============================================================ */

SET NOCOUNT ON;
GO

------------------------------------------------------------
-- 1. Znajdź ostatnie okno patchowania, jeśli nie pamiętasz ID
------------------------------------------------------------
SELECT TOP (20)
    PatchingRunId,
    InstanceName,
    ServerName,
    Description,
    CreatedAtUtc,
    CreatedBy,
    Status
FROM msdb.dba.SqlAgentPatchingRun
ORDER BY PatchingRunId DESC;
GO

------------------------------------------------------------
-- 2. Podaj właściwy PatchingRunId
------------------------------------------------------------
DECLARE @PatchingRunId int = NULL; -- TODO: wpisz np. 1

IF @PatchingRunId IS NULL
BEGIN
    RAISERROR(N'Ustaw zmienną @PatchingRunId przed wykonaniem restore.', 16, 1);
    RETURN;
END;

------------------------------------------------------------
-- 3. Preview przywrócenia
------------------------------------------------------------
EXEC msdb.dba.usp_RestoreSqlAgentJobsAfterPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Preview',
    @Comment = N'Preview restore po patchowaniu';

------------------------------------------------------------
-- 4. Execute przywrócenia
------------------------------------------------------------
EXEC msdb.dba.usp_RestoreSqlAgentJobsAfterPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Execute',
    @Comment = N'Przywrócenie jobów po patchowaniu SQL Server';

------------------------------------------------------------
-- 5. Raport po przywróceniu
------------------------------------------------------------
EXEC msdb.dba.usp_ReportSqlAgentPatchingWindow
    @PatchingRunId = @PatchingRunId;
GO
