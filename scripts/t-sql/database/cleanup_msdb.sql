USE [msdb];
GO

-- =================================================================
-- 1) Procedura: dbo.usp_CleanupMsdbHistory (z Twoim kodem w środku)
-- =================================================================
IF OBJECT_ID('dbo.usp_CleanupMsdbHistory') IS NOT NULL
    DROP PROCEDURE dbo.usp_CleanupMsdbHistory;
GO

CREATE PROCEDURE dbo.usp_CleanupMsdbHistory
    @DaysToKeep INT = 60
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @msg nvarchar(200) = N'Start czyszczenia msdb, keep=' + CAST(@DaysToKeep AS nvarchar(10))
                                    + N' [' + CONVERT(nvarchar(19), GETDATE(), 120) + N']';
        PRINT @msg;

        -- 1) Backup history
        PRINT N'Usuwam historię backupów starszą niż ' + CAST(@DaysToKeep AS NVARCHAR(10)) + N' dni...';
        EXEC sp_delete_backuphistory @oldest_date = DATEADD(DAY, -@DaysToKeep, GETDATE());

        -- 2) Job history
        PRINT N'Usuwam historię jobów starszą niż ' + CAST(@DaysToKeep AS NVARCHAR(10)) + N' dni...';
        EXEC sp_purge_jobhistory @oldest_date = DATEADD(DAY, -@DaysToKeep, GETDATE());

        -- 3) Maintenance Plans (jeśli są)
        PRINT N'Usuwam historię Maintenance Plans starszą niż ' + CAST(@DaysToKeep AS NVARCHAR(10)) + N' dni...';
        DELETE FROM dbo.sysmaintplan_log
        WHERE start_time < DATEADD(DAY, -@DaysToKeep, GETDATE());

        DELETE FROM dbo.sysmaintplan_logdetail
        WHERE start_time < DATEADD(DAY, -@DaysToKeep, GETDATE());

        PRINT N'Czyszczenie msdb zakończone pomyślnie: ' + CONVERT(NVARCHAR(30), GETDATE(), 120);
    END TRY
    BEGIN CATCH
        PRINT N'Błąd: ' + ERROR_MESSAGE();
        ;THROW; -- opcjonalnie podnieś błąd do Agenta
    END CATCH
END;
GO

-- ==========================================================
-- 2) Job SQL Agent: wywołuje procedurę co tydzień 02:00
-- ==========================================================
DECLARE @job_id UNIQUEIDENTIFIER;

-- Usuń poprzedni job, jeśli istnieje
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Cleanup_MSDB_History')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'Cleanup_MSDB_History';
END
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'Cleanup_MSDB_History',
    @enabled = 1,
    @description = N'Usuwa stare wpisy o backupach, jobach i maintenance plans z msdb',
    @start_step_id = 1,
    @job_id = @job_id OUTPUT;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Cleanup_MSDB_History',
    @step_name = N'Cleanup msdb data',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'EXEC msdb.dbo.usp_CleanupMsdbHistory @DaysToKeep = 60;',
    @on_success_action = 1, -- Quit with success
    @on_fail_action = 2; -- Quit with failure
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Weekly_MSDB_Cleanup',
    @freq_type = 8,           -- weekly
    @freq_interval = 2,       -- Monday
    @active_start_time = 20000; -- 02:00
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'Cleanup_MSDB_History',
    @schedule_name = N'Weekly_MSDB_Cleanup';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'Cleanup_MSDB_History';
GO
