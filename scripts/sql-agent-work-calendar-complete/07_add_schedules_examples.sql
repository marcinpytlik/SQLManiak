USE msdb;
GO

/* ============================================================
   07_add_schedules_examples.sql

   Cel:
   - Przykładowe harmonogramy dla jobów.

   Uwaga:
   - Job może startować codziennie, a kalendarz decyduje,
     czy właściwe kroki mają się wykonać.
   ============================================================ */

------------------------------------------------------------
-- Schedule 1: codziennie 20:00
------------------------------------------------------------
DECLARE @ScheduleDaily2000 sysname = N'Daily 20:00';

IF EXISTS
(
    SELECT 1
    FROM msdb.dbo.sysschedules
    WHERE name = @ScheduleDaily2000
)
BEGIN
    EXEC msdb.dbo.sp_delete_schedule
        @schedule_name = @ScheduleDaily2000,
        @force_delete = 1;
END;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = @ScheduleDaily2000,
    @enabled = 1,
    @freq_type = 4,          -- daily
    @freq_interval = 1,
    @active_start_time = 200000;

------------------------------------------------------------
-- Schedule 2: codziennie 07:00
------------------------------------------------------------
DECLARE @ScheduleDaily0700 sysname = N'Daily 07:00';

IF EXISTS
(
    SELECT 1
    FROM msdb.dbo.sysschedules
    WHERE name = @ScheduleDaily0700
)
BEGIN
    EXEC msdb.dbo.sp_delete_schedule
        @schedule_name = @ScheduleDaily0700,
        @force_delete = 1;
END;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = @ScheduleDaily0700,
    @enabled = 1,
    @freq_type = 4,          -- daily
    @freq_interval = 1,
    @active_start_time = 070000;

------------------------------------------------------------
-- Attach examples
------------------------------------------------------------
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'DBA - Work Calendar - Any Working Day')
BEGIN
    EXEC msdb.dbo.sp_attach_schedule
        @job_name = N'DBA - Work Calendar - Any Working Day',
        @schedule_name = @ScheduleDaily2000;
END;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'DBA - Work Calendar - Last Working Day Of Month')
BEGIN
    EXEC msdb.dbo.sp_attach_schedule
        @job_name = N'DBA - Work Calendar - Last Working Day Of Month',
        @schedule_name = @ScheduleDaily0700;
END;
GO

-- Weryfikacja
SELECT
    j.name AS JobName,
    s.name AS ScheduleName,
    s.enabled,
    s.freq_type,
    s.freq_interval,
    s.active_start_time
FROM msdb.dbo.sysjobs AS j
INNER JOIN msdb.dbo.sysjobschedules AS js
    ON js.job_id = j.job_id
INNER JOIN msdb.dbo.sysschedules AS s
    ON s.schedule_id = js.schedule_id
WHERE j.name IN
(
    N'DBA - Work Calendar - Any Working Day',
    N'DBA - Work Calendar - Last Working Day Of Month'
)
ORDER BY
    j.name,
    s.name;
GO
