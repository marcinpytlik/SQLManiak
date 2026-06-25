USE msdb;
GO

/* ============================================================
   99_cleanup_work_calendar.sql

   Cel:
   - Sprząta obiekty utworzone przez pakiet SQL Agent Work Calendar.
   - Usuwa przykładowe joby SQL Agent.
   - Usuwa przykładowe harmonogramy.
   - Usuwa procedury, widok i tabelę kalendarza.
   - Usuwa schemat dba tylko wtedy, gdy po sprzątaniu jest pusty.

   UWAGA:
   - Skrypt usuwa dane z msdb.dba.WorkCalendar.
   - Uruchamiaj tylko wtedy, gdy chcesz całkowicie wycofać pakiet.
   ============================================================ */

SET NOCOUNT ON;
GO

PRINT '=== SQL Agent Work Calendar cleanup - START ===';
GO

------------------------------------------------------------
-- 1. Usuń przykładowe joby
------------------------------------------------------------
DECLARE @JobsToDelete table
(
    JobName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @JobsToDelete(JobName)
VALUES
    (N'DBA - Work Calendar - Any Working Day'),
    (N'DBA - Work Calendar - Last Working Day Of Month');

DECLARE @JobName sysname;

DECLARE job_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT JobName
FROM @JobsToDelete;

OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @JobName;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM msdb.dbo.sysjobs
        WHERE name = @JobName
    )
    BEGIN
        PRINT CONCAT('Deleting job: ', @JobName);

        EXEC msdb.dbo.sp_delete_job
            @job_name = @JobName,
            @delete_unused_schedule = 1;
    END
    ELSE
    BEGIN
        PRINT CONCAT('Job not found, skipping: ', @JobName);
    END;

    FETCH NEXT FROM job_cursor INTO @JobName;
END;

CLOSE job_cursor;
DEALLOCATE job_cursor;
GO

------------------------------------------------------------
-- 2. Usuń przykładowe harmonogramy, jeśli nadal istnieją
------------------------------------------------------------
DECLARE @SchedulesToDelete table
(
    ScheduleName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @SchedulesToDelete(ScheduleName)
VALUES
    (N'Daily 20:00'),
    (N'Daily 07:00');

DECLARE @ScheduleName sysname;

DECLARE schedule_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT ScheduleName
FROM @SchedulesToDelete;

OPEN schedule_cursor;
FETCH NEXT FROM schedule_cursor INTO @ScheduleName;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM msdb.dbo.sysschedules
        WHERE name = @ScheduleName
    )
    BEGIN
        PRINT CONCAT('Deleting schedule: ', @ScheduleName);

        EXEC msdb.dbo.sp_delete_schedule
            @schedule_name = @ScheduleName,
            @force_delete = 1;
    END
    ELSE
    BEGIN
        PRINT CONCAT('Schedule not found, skipping: ', @ScheduleName);
    END;

    FETCH NEXT FROM schedule_cursor INTO @ScheduleName;
END;

CLOSE schedule_cursor;
DEALLOCATE schedule_cursor;
GO

------------------------------------------------------------
-- 3. Usuń procedury
------------------------------------------------------------
IF OBJECT_ID(N'dba.usp_CheckWorkCalendarRuleForSqlAgent', N'P') IS NOT NULL
BEGIN
    PRINT 'Dropping procedure: dba.usp_CheckWorkCalendarRuleForSqlAgent';
    DROP PROCEDURE dba.usp_CheckWorkCalendarRuleForSqlAgent;
END
ELSE
BEGIN
    PRINT 'Procedure not found, skipping: dba.usp_CheckWorkCalendarRuleForSqlAgent';
END;
GO

IF OBJECT_ID(N'dba.usp_CheckWorkCalendarForSqlAgent', N'P') IS NOT NULL
BEGIN
    PRINT 'Dropping procedure: dba.usp_CheckWorkCalendarForSqlAgent';
    DROP PROCEDURE dba.usp_CheckWorkCalendarForSqlAgent;
END
ELSE
BEGIN
    PRINT 'Procedure not found, skipping: dba.usp_CheckWorkCalendarForSqlAgent';
END;
GO


------------------------------------------------------------
-- 3a. Usuń procedury modułu patchingowego
------------------------------------------------------------
IF OBJECT_ID(N'dba.usp_ReportSqlAgentPatchingWindow', N'P') IS NOT NULL
BEGIN
    PRINT 'Dropping procedure: dba.usp_ReportSqlAgentPatchingWindow';
    DROP PROCEDURE dba.usp_ReportSqlAgentPatchingWindow;
END
ELSE
BEGIN
    PRINT 'Procedure not found, skipping: dba.usp_ReportSqlAgentPatchingWindow';
END;
GO

IF OBJECT_ID(N'dba.usp_RestoreSqlAgentJobsAfterPatching', N'P') IS NOT NULL
BEGIN
    PRINT 'Dropping procedure: dba.usp_RestoreSqlAgentJobsAfterPatching';
    DROP PROCEDURE dba.usp_RestoreSqlAgentJobsAfterPatching;
END
ELSE
BEGIN
    PRINT 'Procedure not found, skipping: dba.usp_RestoreSqlAgentJobsAfterPatching';
END;
GO

IF OBJECT_ID(N'dba.usp_DisableSqlAgentJobsForPatching', N'P') IS NOT NULL
BEGIN
    PRINT 'Dropping procedure: dba.usp_DisableSqlAgentJobsForPatching';
    DROP PROCEDURE dba.usp_DisableSqlAgentJobsForPatching;
END
ELSE
BEGIN
    PRINT 'Procedure not found, skipping: dba.usp_DisableSqlAgentJobsForPatching';
END;
GO

IF OBJECT_ID(N'dba.usp_StartSqlAgentPatchingWindow', N'P') IS NOT NULL
BEGIN
    PRINT 'Dropping procedure: dba.usp_StartSqlAgentPatchingWindow';
    DROP PROCEDURE dba.usp_StartSqlAgentPatchingWindow;
END
ELSE
BEGIN
    PRINT 'Procedure not found, skipping: dba.usp_StartSqlAgentPatchingWindow';
END;
GO

------------------------------------------------------------
-- 3b. Usuń tabele modułu patchingowego
------------------------------------------------------------
IF OBJECT_ID(N'dba.SqlAgentPatchingJobState', N'U') IS NOT NULL
BEGIN
    PRINT 'Dropping table: dba.SqlAgentPatchingJobState';
    DROP TABLE dba.SqlAgentPatchingJobState;
END
ELSE
BEGIN
    PRINT 'Table not found, skipping: dba.SqlAgentPatchingJobState';
END;
GO

IF OBJECT_ID(N'dba.SqlAgentPatchingRun', N'U') IS NOT NULL
BEGIN
    PRINT 'Dropping table: dba.SqlAgentPatchingRun';
    DROP TABLE dba.SqlAgentPatchingRun;
END
ELSE
BEGIN
    PRINT 'Table not found, skipping: dba.SqlAgentPatchingRun';
END;
GO

------------------------------------------------------------
-- 4. Usuń widok
------------------------------------------------------------
IF OBJECT_ID(N'dba.vWorkCalendarEnriched', N'V') IS NOT NULL
BEGIN
    PRINT 'Dropping view: dba.vWorkCalendarEnriched';
    DROP VIEW dba.vWorkCalendarEnriched;
END
ELSE
BEGIN
    PRINT 'View not found, skipping: dba.vWorkCalendarEnriched';
END;
GO

------------------------------------------------------------
-- 5. Usuń tabelę kalendarza
------------------------------------------------------------
IF OBJECT_ID(N'dba.WorkCalendar', N'U') IS NOT NULL
BEGIN
    PRINT 'Dropping table: dba.WorkCalendar';
    DROP TABLE dba.WorkCalendar;
END
ELSE
BEGIN
    PRINT 'Table not found, skipping: dba.WorkCalendar';
END;
GO

------------------------------------------------------------
-- 6. Usuń schemat dba tylko wtedy, gdy jest pusty
------------------------------------------------------------
IF SCHEMA_ID(N'dba') IS NOT NULL
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.objects
        WHERE schema_id = SCHEMA_ID(N'dba')
    )
    BEGIN
        PRINT 'Dropping empty schema: dba';
        DROP SCHEMA dba;
    END
    ELSE
    BEGIN
        PRINT 'Schema dba still contains objects - schema was not dropped.';
    END;
END
ELSE
BEGIN
    PRINT 'Schema not found, skipping: dba';
END;
GO

------------------------------------------------------------
-- 7. Weryfikacja po sprzątaniu
------------------------------------------------------------
PRINT '=== Verification after cleanup ===';

SELECT
    j.name AS RemainingJobName
FROM msdb.dbo.sysjobs AS j
WHERE j.name IN
(
    N'DBA - Work Calendar - Any Working Day',
    N'DBA - Work Calendar - Last Working Day Of Month'
)
ORDER BY j.name;

SELECT
    s.name AS RemainingScheduleName
FROM msdb.dbo.sysschedules AS s
WHERE s.name IN
(
    N'Daily 20:00',
    N'Daily 07:00'
)
ORDER BY s.name;

SELECT
    SCHEMA_NAME(o.schema_id) AS SchemaName,
    o.name AS ObjectName,
    o.type_desc
FROM sys.objects AS o
WHERE SCHEMA_NAME(o.schema_id) = N'dba'
  AND o.name IN
  (
      N'WorkCalendar',
      N'vWorkCalendarEnriched',
      N'usp_CheckWorkCalendarForSqlAgent',
      N'usp_CheckWorkCalendarRuleForSqlAgent',
      N'SqlAgentPatchingRun',
      N'SqlAgentPatchingJobState',
      N'usp_StartSqlAgentPatchingWindow',
      N'usp_DisableSqlAgentJobsForPatching',
      N'usp_RestoreSqlAgentJobsAfterPatching',
      N'usp_ReportSqlAgentPatchingWindow'
  )
ORDER BY o.type_desc, o.name;
GO

PRINT '=== SQL Agent Work Calendar cleanup - END ===';
GO
