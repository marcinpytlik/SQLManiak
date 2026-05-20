USE [msdb];
GO

IF OBJECT_ID(N'dbo.DBA_BackupDatabaseConfig', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DBA_BackupDatabaseConfig
    (
        DatabaseName   sysname        NOT NULL CONSTRAINT PK_DBA_BackupDatabaseConfig PRIMARY KEY,
        BackupBasePath nvarchar(4000) NOT NULL,
        IsEnabled      bit            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_IsEnabled DEFAULT (1),
        BackupFull     bit            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_BackupFull DEFAULT (1),
        BackupDiff     bit            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_BackupDiff DEFAULT (1),
        BackupLog      bit            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_BackupLog DEFAULT (1),
        Priority       int            NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_Priority DEFAULT (100),
        Notes          nvarchar(1000) NULL,
        CreatedAt      datetime2(0)   NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_CreatedAt DEFAULT (SYSDATETIME()),
        UpdatedAt      datetime2(0)   NOT NULL CONSTRAINT DF_DBA_BackupDatabaseConfig_UpdatedAt DEFAULT (SYSDATETIME()),
        CONSTRAINT CK_DBA_BackupDatabaseConfig_BackupBasePath_NotEmpty CHECK (LEN(LTRIM(RTRIM(BackupBasePath))) > 0)
    );
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_DBA_BackupDatabaseConfig_SetUpdatedAt
ON dbo.DBA_BackupDatabaseConfig
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE c
        SET UpdatedAt = SYSDATETIME()
    FROM dbo.DBA_BackupDatabaseConfig AS c
    INNER JOIN inserted AS i
        ON i.DatabaseName = c.DatabaseName;
END;
GO

IF OBJECT_ID(N'dbo.DBA_BackupExecutionLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DBA_BackupExecutionLog
    (
        LogId          bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DBA_BackupExecutionLog PRIMARY KEY,
        ExecutionId    uniqueidentifier     NOT NULL,
        DatabaseName   sysname              NOT NULL,
        BackupType     varchar(10)          NOT NULL,
        BackupBasePath nvarchar(4000)       NULL,
        BackupFile     nvarchar(4000)       NULL,
        StartedAt      datetime2(0)         NOT NULL CONSTRAINT DF_DBA_BackupExecutionLog_StartedAt DEFAULT (SYSDATETIME()),
        FinishedAt     datetime2(0)         NULL,
        Status         varchar(20)          NOT NULL CONSTRAINT DF_DBA_BackupExecutionLog_Status DEFAULT ('STARTED'),
        Message        nvarchar(4000)       NULL
    );

    CREATE INDEX IX_DBA_BackupExecutionLog_ExecutionId
        ON dbo.DBA_BackupExecutionLog(ExecutionId, LogId);

    CREATE INDEX IX_DBA_BackupExecutionLog_DatabaseName_StartedAt
        ON dbo.DBA_BackupExecutionLog(DatabaseName, StartedAt DESC);
END;
GO


USE [msdb];
GO

CREATE OR ALTER PROCEDURE dbo.usp_BackupDatabases_ByConfig
(
    @BackupType   varchar(10),
    @DatabaseName sysname = NULL,
    @DryRun       bit = 0,
    @StopOnError  bit = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
        @ExecutionId uniqueidentifier = NEWID(),
        @DbName sysname,
        @RecoveryModel nvarchar(60),
        @DatabaseId int,
        @BasePath nvarchar(4000),
        @DbFolder nvarchar(4000),
        @SafeDbName nvarchar(512),
        @FileName nvarchar(4000),
        @DateSuffix varchar(20),
        @Extension varchar(10),
        @LockResult int,
        @LockName nvarchar(255),
        @LogId bigint,
        @HadErrors bit = 0,
        @Message nvarchar(4000);

    SET @BackupType = UPPER(LTRIM(RTRIM(@BackupType)));

    IF @BackupType NOT IN ('FULL', 'DIFF', 'LOG')
    BEGIN
        THROW 50001, 'Niepoprawny typ backupu. Dozwolone: FULL, DIFF, LOG.', 1;
    END;

    IF @DatabaseName IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.DBA_BackupDatabaseConfig WHERE DatabaseName = @DatabaseName AND IsEnabled = 1)
    BEGIN
        THROW 50002, 'Podana baza nie istnieje w dbo.DBA_BackupDatabaseConfig albo jest wyłączona.', 1;
    END;

    SET @Extension = CASE @BackupType
        WHEN 'FULL' THEN 'bak'
        WHEN 'DIFF' THEN 'dif'
        WHEN 'LOG'  THEN 'trn'
    END;

    DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            d.name,
            d.recovery_model_desc,
            d.database_id,
            c.BackupBasePath
        FROM sys.databases AS d
        INNER JOIN dbo.DBA_BackupDatabaseConfig AS c
            ON c.DatabaseName = d.name
        WHERE
            c.IsEnabled = 1
            AND d.state_desc = 'ONLINE'
            AND d.is_read_only = 0
            AND d.name <> N'tempdb'
            AND (@DatabaseName IS NULL OR d.name = @DatabaseName)
            AND
            (
                (@BackupType = 'FULL' AND c.BackupFull = 1)
                OR (@BackupType = 'DIFF' AND c.BackupDiff = 1)
                OR (@BackupType = 'LOG'  AND c.BackupLog  = 1)
            )
        ORDER BY
            c.Priority,
            CASE WHEN d.database_id <= 4 THEN 0 ELSE 1 END,
            d.name;

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DbName, @RecoveryModel, @DatabaseId, @BasePath;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @LockName = NULL;
        SET @LogId = NULL;
        SET @FileName = NULL;
        SET @Message = NULL;

        BEGIN TRY
            IF @DatabaseId <= 4 AND @BackupType <> 'FULL'
            BEGIN
                SET @Message = CONCAT('SKIP: baza systemowa ', @DbName, ' - dla baz systemowych wykonujemy tylko FULL.');

                INSERT dbo.DBA_BackupExecutionLog
                    (ExecutionId, DatabaseName, BackupType, BackupBasePath, Status, Message, FinishedAt)
                VALUES
                    (@ExecutionId, @DbName, @BackupType, @BasePath, 'SKIPPED', @Message, SYSDATETIME());

                RAISERROR('%s', 10, 1, @Message) WITH NOWAIT;
                FETCH NEXT FROM db_cursor INTO @DbName, @RecoveryModel, @DatabaseId, @BasePath;
                CONTINUE;
            END;

            IF @BackupType = 'LOG' AND @RecoveryModel = 'SIMPLE'
            BEGIN
                SET @Message = CONCAT('SKIP: baza ', @DbName, ' ma recovery model SIMPLE - backup LOG niemożliwy.');

                INSERT dbo.DBA_BackupExecutionLog
                    (ExecutionId, DatabaseName, BackupType, BackupBasePath, Status, Message, FinishedAt)
                VALUES
                    (@ExecutionId, @DbName, @BackupType, @BasePath, 'SKIPPED', @Message, SYSDATETIME());

                RAISERROR('%s', 10, 1, @Message) WITH NOWAIT;
                FETCH NEXT FROM db_cursor INTO @DbName, @RecoveryModel, @DatabaseId, @BasePath;
                CONTINUE;
            END;

            SET @SafeDbName = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@DbName,
                    N'\', N'_'), N'/', N'_'), N':', N'_'), N'*', N'_'), N'?', N'_'),
                    N'"', N'_'), N'<', N'_'), N'>', N'_'), N'|', N'_');

            SET @DbFolder = CASE
                WHEN RIGHT(@BasePath, 1) IN (N'\', N'/') THEN @BasePath + @SafeDbName
                ELSE @BasePath + N'\' + @SafeDbName
            END;

            SET @DateSuffix = CONVERT(char(8), GETDATE(), 112)
                            + '_'
                            + REPLACE(CONVERT(char(8), GETDATE(), 108), ':', '');

            SET @FileName = @DbFolder + N'\'
                          + @SafeDbName
                          + N'_'
                          + @DateSuffix
                          + N'_'
                          + @BackupType
                          + N'.'
                          + @Extension;

            INSERT dbo.DBA_BackupExecutionLog
                (ExecutionId, DatabaseName, BackupType, BackupBasePath, BackupFile, Status, Message)
            VALUES
                (@ExecutionId, @DbName, @BackupType, @BasePath, @FileName, 'STARTED', 'Backup started.');

            SET @LogId = SCOPE_IDENTITY();

            IF @DryRun = 1
            BEGIN
                SET @Message = CONCAT('DRYRUN: ', @BackupType, ' backup bazy ', @DbName, ' do ', @FileName);

                UPDATE dbo.DBA_BackupExecutionLog
                    SET Status = 'DRYRUN', Message = @Message, FinishedAt = SYSDATETIME()
                WHERE LogId = @LogId;

                RAISERROR('%s', 10, 1, @Message) WITH NOWAIT;
                FETCH NEXT FROM db_cursor INTO @DbName, @RecoveryModel, @DatabaseId, @BasePath;
                CONTINUE;
            END;

            EXEC master.dbo.xp_create_subdir @BasePath;
            EXEC master.dbo.xp_create_subdir @DbFolder;

            SET @LockName = N'DBA_BACKUP_' + @DbName;

            EXEC @LockResult = sp_getapplock
                @Resource = @LockName,
                @LockMode = 'Exclusive',
                @LockOwner = 'Session',
                @LockTimeout = 0;

            IF @LockResult < 0
            BEGIN
                SET @Message = CONCAT('SKIP: inny backup bazy ', @DbName, ' jest aktualnie wykonywany.');

                UPDATE dbo.DBA_BackupExecutionLog
                    SET Status = 'SKIPPED', Message = @Message, FinishedAt = SYSDATETIME()
                WHERE LogId = @LogId;

                RAISERROR('%s', 10, 1, @Message) WITH NOWAIT;
                FETCH NEXT FROM db_cursor INTO @DbName, @RecoveryModel, @DatabaseId, @BasePath;
                CONTINUE;
            END;

            IF @BackupType = 'FULL'
            BEGIN
                BACKUP DATABASE @DbName
                TO DISK = @FileName
                WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;
            END;

            IF @BackupType = 'DIFF'
            BEGIN
                BACKUP DATABASE @DbName
                TO DISK = @FileName
                WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, STATS = 10;
            END;

            IF @BackupType = 'LOG'
            BEGIN
                BACKUP LOG @DbName
                TO DISK = @FileName
                WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;
            END;

            EXEC sp_releaseapplock
                @Resource = @LockName,
                @LockOwner = 'Session';

            UPDATE dbo.DBA_BackupExecutionLog
                SET Status = 'SUCCESS', Message = 'Backup finished successfully.', FinishedAt = SYSDATETIME()
            WHERE LogId = @LogId;
        END TRY
        BEGIN CATCH
            SET @HadErrors = 1;
            SET @Message = ERROR_MESSAGE();

            IF @LockName IS NOT NULL
            BEGIN
                EXEC sp_releaseapplock
                    @Resource = @LockName,
                    @LockOwner = 'Session';
            END;

            IF @LogId IS NOT NULL
            BEGIN
                UPDATE dbo.DBA_BackupExecutionLog
                    SET Status = 'FAILED', Message = @Message, FinishedAt = SYSDATETIME()
                WHERE LogId = @LogId;
            END
            ELSE
            BEGIN
                INSERT dbo.DBA_BackupExecutionLog
                    (ExecutionId, DatabaseName, BackupType, BackupBasePath, BackupFile, Status, Message, FinishedAt)
                VALUES
                    (@ExecutionId, ISNULL(@DbName, N'<unknown>'), @BackupType, @BasePath, @FileName, 'FAILED', @Message, SYSDATETIME());
            END;

            RAISERROR('Błąd backupu bazy %s: %s', 10, 1, @DbName, @Message) WITH NOWAIT;

            IF @StopOnError = 1
            BEGIN
                CLOSE db_cursor;
                DEALLOCATE db_cursor;
                THROW;
            END;
        END CATCH;

        FETCH NEXT FROM db_cursor INTO @DbName, @RecoveryModel, @DatabaseId, @BasePath;
    END;

    CLOSE db_cursor;
    DEALLOCATE db_cursor;

    IF @HadErrors = 1
    BEGIN
        THROW 50100, 'Co najmniej jeden backup zakończył się błędem. Szczegóły: msdb.dbo.DBA_BackupExecutionLog.', 1;
    END;
END;
GO


USE [msdb];
GO

MERGE dbo.DBA_BackupDatabaseConfig AS target
USING
(
    VALUES
        (N'baza1', N'X:\backup', 1, 1, 1, 1, 10, N'Grupa X'),
        (N'baza2', N'X:\backup', 1, 1, 1, 1, 10, N'Grupa X'),
        (N'baza3', N'X:\backup', 1, 1, 1, 1, 10, N'Grupa X'),
        (N'baza5', N'Z:\backup', 1, 1, 1, 1, 20, N'Grupa Z'),
        (N'baza6', N'Z:\backup', 1, 1, 1, 1, 20, N'Grupa Z'),
        (N'baza7', N'Z:\backup', 1, 1, 1, 1, 20, N'Grupa Z'),
        (N'master', N'X:\backup', 1, 1, 0, 0, 1, N'Baza systemowa - tylko FULL'),
        (N'model',  N'X:\backup', 1, 1, 0, 0, 1, N'Baza systemowa - tylko FULL'),
        (N'msdb',   N'X:\backup', 1, 1, 0, 0, 1, N'Baza systemowa - tylko FULL')
) AS source(DatabaseName, BackupBasePath, IsEnabled, BackupFull, BackupDiff, BackupLog, Priority, Notes)
ON target.DatabaseName = source.DatabaseName
WHEN MATCHED THEN
    UPDATE SET
        BackupBasePath = source.BackupBasePath,
        IsEnabled = source.IsEnabled,
        BackupFull = source.BackupFull,
        BackupDiff = source.BackupDiff,
        BackupLog = source.BackupLog,
        Priority = source.Priority,
        Notes = source.Notes
WHEN NOT MATCHED THEN
    INSERT (DatabaseName, BackupBasePath, IsEnabled, BackupFull, BackupDiff, BackupLog, Priority, Notes)
    VALUES (source.DatabaseName, source.BackupBasePath, source.IsEnabled, source.BackupFull, source.BackupDiff, source.BackupLog, source.Priority, source.Notes);
GO

/* Generator brakujących wpisów - skopiuj wynik i przypisz X:\backup albo Z:\backup według potrzeb. */
SELECT
    d.name AS DatabaseName,
    SuggestedMergeRow = CONCAT(
        '(N''', REPLACE(d.name, '''', ''''''), ''', N''X:\backup'', 1, 1, 1, ',
        CASE WHEN d.recovery_model_desc = 'SIMPLE' THEN '0' ELSE '1' END,
        ', 100, N''TODO''),' )
FROM sys.databases AS d
WHERE
    d.state_desc = 'ONLINE'
    AND d.is_read_only = 0
    AND d.name <> N'tempdb'
    AND NOT EXISTS
    (
        SELECT 1
        FROM dbo.DBA_BackupDatabaseConfig AS c
        WHERE c.DatabaseName = d.name
    )
ORDER BY d.name;
GO

SELECT *
FROM dbo.DBA_BackupDatabaseConfig
ORDER BY Priority, DatabaseName;
GO


USE [msdb];
GO

DECLARE @JobName sysname;

DECLARE managed_jobs CURSOR LOCAL FAST_FORWARD FOR
    SELECT JobName
    FROM (VALUES
        (N'DBA_Backup_FULL_Configured_Databases'),
        (N'DBA_Backup_DIFF_Configured_Databases'),
        (N'DBA_Backup_LOG_Configured_Databases')
    ) AS j(JobName);

OPEN managed_jobs;
FETCH NEXT FROM managed_jobs INTO @JobName;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
    BEGIN
        EXEC msdb.dbo.sp_delete_job
            @job_name = @JobName,
            @delete_unused_schedule = 1;
    END;

    FETCH NEXT FROM managed_jobs INTO @JobName;
END;

CLOSE managed_jobs;
DEALLOCATE managed_jobs;
GO

DECLARE @JobIdFull uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = N'DBA_Backup_FULL_Configured_Databases',
    @enabled = 1,
    @description = N'FULL backup baz skonfigurowanych w msdb.dbo.DBA_BackupDatabaseConfig.',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @job_id = @JobIdFull OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobIdFull,
    @step_name = N'FULL backup configured databases',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'EXEC dbo.usp_BackupDatabases_ByConfig @BackupType = ''FULL'';',
    @retry_attempts = 1,
    @retry_interval = 5;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Daily configured databases FULL at 20:00',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 200000;

EXEC msdb.dbo.sp_attach_schedule
    @job_id = @JobIdFull,
    @schedule_name = N'Daily configured databases FULL at 20:00';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobIdFull,
    @server_name = N'(LOCAL)';
GO

DECLARE @JobIdDiff uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = N'DBA_Backup_DIFF_Configured_Databases',
    @enabled = 1,
    @description = N'DIFF backup baz skonfigurowanych w msdb.dbo.DBA_BackupDatabaseConfig. Bazy systemowe są pomijane.',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @job_id = @JobIdDiff OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobIdDiff,
    @step_name = N'DIFF backup configured databases',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'EXEC dbo.usp_BackupDatabases_ByConfig @BackupType = ''DIFF'';',
    @retry_attempts = 1,
    @retry_interval = 5;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Configured databases DIFF every 3 hours',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 3,
    @active_start_time = 060000,
    @active_end_time = 235959;

EXEC msdb.dbo.sp_attach_schedule
    @job_id = @JobIdDiff,
    @schedule_name = N'Configured databases DIFF every 3 hours';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobIdDiff,
    @server_name = N'(LOCAL)';
GO

DECLARE @JobIdLog uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = N'DBA_Backup_LOG_Configured_Databases',
    @enabled = 1,
    @description = N'LOG backup baz skonfigurowanych w msdb.dbo.DBA_BackupDatabaseConfig. Bazy SIMPLE są pomijane.',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @job_id = @JobIdLog OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobIdLog,
    @step_name = N'LOG backup configured databases',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'EXEC dbo.usp_BackupDatabases_ByConfig @BackupType = ''LOG'';',
    @retry_attempts = 1,
    @retry_interval = 5;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Configured databases LOG every 10 minutes',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 10,
    @active_start_time = 000000,
    @active_end_time = 235959;

EXEC msdb.dbo.sp_attach_schedule
    @job_id = @JobIdLog,
    @schedule_name = N'Configured databases LOG every 10 minutes';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobIdLog,
    @server_name = N'(LOCAL)';
GO


USE [msdb];
GO

EXEC dbo.usp_BackupDatabases_ByConfig
    @BackupType = 'FULL',
    @DryRun = 1;
GO

-- Test jednej bazy - podmień nazwę:
-- EXEC dbo.usp_BackupDatabases_ByConfig @BackupType = 'FULL', @DatabaseName = N'baza1';
-- GO

SELECT
    c.DatabaseName,
    d.state_desc,
    d.recovery_model_desc,
    c.BackupBasePath,
    c.IsEnabled,
    c.BackupFull,
    c.BackupDiff,
    c.BackupLog,
    c.Priority,
    c.UpdatedAt
FROM dbo.DBA_BackupDatabaseConfig AS c
LEFT JOIN sys.databases AS d
    ON d.name = c.DatabaseName
ORDER BY c.Priority, c.DatabaseName;
GO

SELECT
    d.name,
    d.recovery_model_desc,
    d.state_desc
FROM sys.databases AS d
WHERE
    d.state_desc = 'ONLINE'
    AND d.is_read_only = 0
    AND d.name <> N'tempdb'
    AND NOT EXISTS
    (
        SELECT 1
        FROM dbo.DBA_BackupDatabaseConfig AS c
        WHERE c.DatabaseName = d.name
    )
ORDER BY d.name;
GO

SELECT TOP (200)
    LogId,
    ExecutionId,
    DatabaseName,
    BackupType,
    BackupBasePath,
    BackupFile,
    StartedAt,
    FinishedAt,
    Status,
    Message
FROM dbo.DBA_BackupExecutionLog
ORDER BY LogId DESC;
GO

SELECT
    j.name AS job_name,
    j.enabled,
    s.name AS schedule_name,
    s.enabled AS schedule_enabled,
    s.freq_type,
    s.freq_subday_type,
    s.freq_subday_interval,
    s.active_start_time,
    s.active_end_time
FROM msdb.dbo.sysjobs AS j
LEFT JOIN msdb.dbo.sysjobschedules AS js
    ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules AS s
    ON js.schedule_id = s.schedule_id
WHERE j.name LIKE N'DBA_Backup_%_Configured_Databases'
ORDER BY j.name;
GO

SELECT TOP (200)
    bs.database_name,
    CASE bs.type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFF'
        WHEN 'L' THEN 'LOG'
    END AS backup_type,
    bs.backup_start_date,
    bs.backup_finish_date,
    CAST(bs.backup_size / 1024.0 / 1024.0 AS decimal(18,2)) AS backup_size_mb,
    bmf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name <> 'tempdb'
ORDER BY bs.backup_finish_date DESC;
GO
