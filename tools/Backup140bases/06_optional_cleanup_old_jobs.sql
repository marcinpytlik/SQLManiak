USE [msdb];
GO

DECLARE @JobName sysname;

DECLARE jobs_to_delete CURSOR LOCAL FAST_FORWARD FOR
    SELECT JobName
    FROM (VALUES
        (N'DBA_Backup_FULL_SystemDatabases'),
        (N'DBA_Backup_FULL_UserDatabases'),
        (N'DBA_Backup_DIFF_UserDatabases'),
        (N'DBA_Backup_LOG_UserDatabases'),
        (N'DBA_Backup_FULL_AllUserDatabases'),
        (N'DBA_Backup_DIFF_AllUserDatabases'),
        (N'DBA_Backup_LOG_AllUserDatabases')
    ) AS j(JobName);

OPEN jobs_to_delete;
FETCH NEXT FROM jobs_to_delete INTO @JobName;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
    BEGIN
        EXEC msdb.dbo.sp_delete_job
            @job_name = @JobName,
            @delete_unused_schedule = 1;
    END;

    FETCH NEXT FROM jobs_to_delete INTO @JobName;
END;

CLOSE jobs_to_delete;
DEALLOCATE jobs_to_delete;
GO
