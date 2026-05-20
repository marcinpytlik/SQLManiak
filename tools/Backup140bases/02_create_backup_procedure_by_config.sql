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
