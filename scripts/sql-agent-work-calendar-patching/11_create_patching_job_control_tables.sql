USE msdb;
GO

/* ============================================================
   11_create_patching_job_control_tables.sql

   Cel:
   - Rozbudowuje pakiet SQL Agent Work Calendar o moduł
     okna serwisowego / patchowania SQL Server.
   - Tworzy tabele historii oraz procedury do:
       * rozpoczęcia okna patchowania,
       * podglądu i wyłączenia jobów SQL Agent,
       * podglądu i przywrócenia jobów SQL Agent,
       * raportowania stanu okna patchowania.

   Założenia:
   - Baza techniczna: msdb.
   - Schemat własny: dba.
   - Nie modyfikujemy bezpośrednio tabel systemowych SQL Agent.
   - Do zmiany stanu jobów używamy msdb.dbo.sp_update_job.
   - Skrypt jest idempotentny.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF SCHEMA_ID(N'dba') IS NULL
    BEGIN
        EXEC(N'CREATE SCHEMA dba');
    END;

    IF OBJECT_ID(N'dba.SqlAgentPatchingRun', N'U') IS NULL
    BEGIN
        CREATE TABLE dba.SqlAgentPatchingRun
        (
            PatchingRunId int IDENTITY(1,1) NOT NULL,
            InstanceName sysname NOT NULL,
            ServerName sysname NOT NULL,
            PlannedStartDateTime datetime2(0) NULL,
            PlannedEndDateTime datetime2(0) NULL,
            Description nvarchar(1000) NULL,
            CreatedAtUtc datetime2(0) NOT NULL
                CONSTRAINT DF_SqlAgentPatchingRun_CreatedAtUtc DEFAULT sysutcdatetime(),
            CreatedBy sysname NOT NULL
                CONSTRAINT DF_SqlAgentPatchingRun_CreatedBy DEFAULT original_login(),
            Status nvarchar(40) NOT NULL
                CONSTRAINT DF_SqlAgentPatchingRun_Status DEFAULT N'OPEN',
            ClosedAtUtc datetime2(0) NULL,
            ClosedBy sysname NULL,
            Comment nvarchar(1000) NULL,

            CONSTRAINT PK_SqlAgentPatchingRun
                PRIMARY KEY CLUSTERED (PatchingRunId),
            CONSTRAINT CK_SqlAgentPatchingRun_Status
                CHECK (Status IN (N'OPEN', N'DISABLED', N'RESTORE_STARTED', N'RESTORED', N'PARTIAL_RESTORE', N'CLOSED', N'CANCELLED'))
        );
    END;

    IF OBJECT_ID(N'dba.SqlAgentPatchingJobState', N'U') IS NULL
    BEGIN
        CREATE TABLE dba.SqlAgentPatchingJobState
        (
            PatchingRunId int NOT NULL,
            JobId uniqueidentifier NOT NULL,
            JobName sysname NOT NULL,
            CategoryName sysname NULL,
            WasEnabled bit NOT NULL,
            CurrentEnabledAtSnapshot bit NOT NULL,
            IsDisabledByTool bit NOT NULL
                CONSTRAINT DF_SqlAgentPatchingJobState_IsDisabledByTool DEFAULT (0),
            Decision nvarchar(40) NOT NULL
                CONSTRAINT DF_SqlAgentPatchingJobState_Decision DEFAULT N'UNKNOWN',
            SkipReason nvarchar(400) NULL,
            DisabledAtUtc datetime2(0) NULL,
            DisabledBy sysname NULL,
            RestoredAtUtc datetime2(0) NULL,
            RestoredBy sysname NULL,
            RestoreStatus nvarchar(40) NULL,
            Comment nvarchar(1000) NULL,

            CONSTRAINT PK_SqlAgentPatchingJobState
                PRIMARY KEY CLUSTERED (PatchingRunId, JobId),
            CONSTRAINT FK_SqlAgentPatchingJobState_Run
                FOREIGN KEY (PatchingRunId)
                REFERENCES dba.SqlAgentPatchingRun(PatchingRunId)
        );
    END;

    IF COL_LENGTH(N'dba.SqlAgentPatchingRun', N'ClosedAtUtc') IS NULL
        ALTER TABLE dba.SqlAgentPatchingRun ADD ClosedAtUtc datetime2(0) NULL;

    IF COL_LENGTH(N'dba.SqlAgentPatchingRun', N'ClosedBy') IS NULL
        ALTER TABLE dba.SqlAgentPatchingRun ADD ClosedBy sysname NULL;

    IF COL_LENGTH(N'dba.SqlAgentPatchingRun', N'Comment') IS NULL
        ALTER TABLE dba.SqlAgentPatchingRun ADD Comment nvarchar(1000) NULL;

    IF COL_LENGTH(N'dba.SqlAgentPatchingJobState', N'CurrentEnabledAtSnapshot') IS NULL
        ALTER TABLE dba.SqlAgentPatchingJobState ADD CurrentEnabledAtSnapshot bit NOT NULL CONSTRAINT DF_SqlAgentPatchingJobState_CurrentEnabledAtSnapshot DEFAULT (0);

    IF COL_LENGTH(N'dba.SqlAgentPatchingJobState', N'Decision') IS NULL
        ALTER TABLE dba.SqlAgentPatchingJobState ADD Decision nvarchar(40) NOT NULL CONSTRAINT DF_SqlAgentPatchingJobState_Decision DEFAULT N'UNKNOWN';

    IF COL_LENGTH(N'dba.SqlAgentPatchingJobState', N'SkipReason') IS NULL
        ALTER TABLE dba.SqlAgentPatchingJobState ADD SkipReason nvarchar(400) NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dba.SqlAgentPatchingRun', N'U')
          AND name = N'IX_SqlAgentPatchingRun_Status_CreatedAtUtc'
    )
    BEGIN
        CREATE INDEX IX_SqlAgentPatchingRun_Status_CreatedAtUtc
            ON dba.SqlAgentPatchingRun(Status, CreatedAtUtc DESC)
            INCLUDE (InstanceName, ServerName, Description);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dba.SqlAgentPatchingJobState', N'U')
          AND name = N'IX_SqlAgentPatchingJobState_JobName'
    )
    BEGIN
        CREATE INDEX IX_SqlAgentPatchingJobState_JobName
            ON dba.SqlAgentPatchingJobState(JobName)
            INCLUDE (PatchingRunId, WasEnabled, IsDisabledByTool, RestoreStatus);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DECLARE @ErrorMessage nvarchar(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity int = ERROR_SEVERITY();
    DECLARE @ErrorState int = ERROR_STATE();

    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;
GO

CREATE OR ALTER PROCEDURE dba.usp_StartSqlAgentPatchingWindow
    @Description nvarchar(1000),
    @PlannedStartDateTime datetime2(0) = NULL,
    @PlannedEndDateTime datetime2(0) = NULL,
    @PatchingRunId int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Description)), N'') IS NULL
    BEGIN
        RAISERROR(N'Parametr @Description jest wymagany.', 16, 1);
        RETURN;
    END;

    IF @PlannedStartDateTime IS NOT NULL
       AND @PlannedEndDateTime IS NOT NULL
       AND @PlannedEndDateTime < @PlannedStartDateTime
    BEGIN
        RAISERROR(N'Planowana data zakończenia nie może być wcześniejsza niż data rozpoczęcia.', 16, 1);
        RETURN;
    END;

    INSERT INTO dba.SqlAgentPatchingRun
    (
        InstanceName,
        ServerName,
        PlannedStartDateTime,
        PlannedEndDateTime,
        Description,
        CreatedAtUtc,
        CreatedBy,
        Status
    )
    VALUES
    (
        CAST(SERVERPROPERTY(N'ServerName') AS sysname),
        CAST(SERVERPROPERTY(N'MachineName') AS sysname),
        @PlannedStartDateTime,
        @PlannedEndDateTime,
        @Description,
        sysutcdatetime(),
        original_login(),
        N'OPEN'
    );

    SET @PatchingRunId = CONVERT(int, SCOPE_IDENTITY());

    SELECT
        PatchingRunId,
        InstanceName,
        ServerName,
        PlannedStartDateTime,
        PlannedEndDateTime,
        Description,
        CreatedAtUtc,
        CreatedBy,
        Status
    FROM dba.SqlAgentPatchingRun
    WHERE PatchingRunId = @PatchingRunId;
END;
GO

CREATE OR ALTER PROCEDURE dba.usp_DisableSqlAgentJobsForPatching
    @PatchingRunId int,
    @Mode nvarchar(20) = N'Preview',
    @JobNameLike nvarchar(255) = NULL,
    @CategoryName nvarchar(255) = NULL,
    @ExcludeJobNameLike nvarchar(255) = NULL,
    @ExcludeJobNameList nvarchar(max) = NULL,
    @IncludeBackupJobs bit = 0,
    @IncludeMonitoringJobs bit = 0,
    @Comment nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Mode = UPPER(LTRIM(RTRIM(@Mode)));

    IF @Mode NOT IN (N'PREVIEW', N'EXECUTE')
    BEGIN
        RAISERROR(N'Nieprawidłowy @Mode. Dozwolone wartości: Preview, Execute.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dba.SqlAgentPatchingRun WHERE PatchingRunId = @PatchingRunId)
    BEGIN
        RAISERROR(N'Nie istnieje wskazany @PatchingRunId.', 16, 1);
        RETURN;
    END;

    IF OBJECT_ID(N'tempdb..#JobsForPatching', N'U') IS NOT NULL
        DROP TABLE #JobsForPatching;

    CREATE TABLE #JobsForPatching
    (
        JobId uniqueidentifier NOT NULL PRIMARY KEY,
        JobName sysname NOT NULL,
        CategoryName sysname NULL,
        CurrentEnabled bit NOT NULL,
        IsCritical bit NOT NULL,
        CriticalReason nvarchar(400) NULL,
        IsExcluded bit NOT NULL,
        ExcludeReason nvarchar(400) NULL,
        Decision nvarchar(40) NOT NULL,
        SkipReason nvarchar(400) NULL
    );

    ;WITH ExcludedNames AS
    (
        SELECT LTRIM(RTRIM(value)) AS JobName
        FROM string_split(COALESCE(@ExcludeJobNameList, N''), N',')
        WHERE LTRIM(RTRIM(value)) <> N''
    )
    INSERT INTO #JobsForPatching
    (
        JobId,
        JobName,
        CategoryName,
        CurrentEnabled,
        IsCritical,
        CriticalReason,
        IsExcluded,
        ExcludeReason,
        Decision,
        SkipReason
    )
    SELECT
        j.job_id,
        j.name,
        c.name AS CategoryName,
        CONVERT(bit, j.enabled) AS CurrentEnabled,
        CONVERT(bit,
            CASE
                WHEN @IncludeBackupJobs = 0
                     AND (j.name LIKE N'%Backup%' OR j.name LIKE N'%LOG%' OR j.name LIKE N'%Restore%' OR j.name LIKE N'%CheckDB%' OR j.name LIKE N'%Integrity%')
                    THEN 1
                WHEN @IncludeMonitoringJobs = 0
                     AND (j.name LIKE N'%Monitoring%' OR j.name LIKE N'%Alert%' OR j.name LIKE N'%DBA%')
                    THEN 1
                ELSE 0
            END) AS IsCritical,
        CASE
            WHEN @IncludeBackupJobs = 0
                 AND (j.name LIKE N'%Backup%' OR j.name LIKE N'%LOG%' OR j.name LIKE N'%Restore%' OR j.name LIKE N'%CheckDB%' OR j.name LIKE N'%Integrity%')
                THEN N'Job zabezpieczony jako backup/restore/log/checkdb/integrity. Użyj @IncludeBackupJobs = 1, jeśli świadomie chcesz go wyłączyć.'
            WHEN @IncludeMonitoringJobs = 0
                 AND (j.name LIKE N'%Monitoring%' OR j.name LIKE N'%Alert%' OR j.name LIKE N'%DBA%')
                THEN N'Job zabezpieczony jako monitoring/alert/DBA. Użyj @IncludeMonitoringJobs = 1, jeśli świadomie chcesz go wyłączyć.'
            ELSE NULL
        END AS CriticalReason,
        CONVERT(bit,
            CASE
                WHEN @ExcludeJobNameLike IS NOT NULL AND j.name LIKE @ExcludeJobNameLike
                    THEN 1
                WHEN EXISTS (SELECT 1 FROM ExcludedNames AS e WHERE e.JobName = j.name)
                    THEN 1
                ELSE 0
            END) AS IsExcluded,
        CASE
            WHEN @ExcludeJobNameLike IS NOT NULL AND j.name LIKE @ExcludeJobNameLike
                THEN CONCAT(N'Job pominięty przez @ExcludeJobNameLike = ', @ExcludeJobNameLike)
            WHEN EXISTS (SELECT 1 FROM ExcludedNames AS e WHERE e.JobName = j.name)
                THEN N'Job pominięty przez @ExcludeJobNameList.'
            ELSE NULL
        END AS ExcludeReason,
        N'UNKNOWN' AS Decision,
        NULL AS SkipReason
    FROM msdb.dbo.sysjobs AS j
    LEFT JOIN msdb.dbo.syscategories AS c
        ON c.category_id = j.category_id
    WHERE (@JobNameLike IS NULL OR j.name LIKE @JobNameLike)
      AND (@CategoryName IS NULL OR c.name = @CategoryName);

    UPDATE #JobsForPatching
    SET
        Decision = CASE
            WHEN CurrentEnabled = 0 THEN N'ALREADY_DISABLED'
            WHEN IsExcluded = 1 THEN N'SKIP_EXCLUDED'
            WHEN IsCritical = 1 THEN N'SKIP_CRITICAL'
            ELSE N'DISABLE'
        END,
        SkipReason = CASE
            WHEN CurrentEnabled = 0 THEN N'Job był już wyłączony przed uruchomieniem narzędzia.'
            WHEN IsExcluded = 1 THEN ExcludeReason
            WHEN IsCritical = 1 THEN CriticalReason
            ELSE NULL
        END;

    SELECT
        @Mode AS Mode,
        @PatchingRunId AS PatchingRunId,
        JobName,
        CategoryName,
        CurrentEnabled,
        Decision,
        SkipReason
    FROM #JobsForPatching
    ORDER BY
        CASE Decision
            WHEN N'DISABLE' THEN 1
            WHEN N'SKIP_CRITICAL' THEN 2
            WHEN N'SKIP_EXCLUDED' THEN 3
            WHEN N'ALREADY_DISABLED' THEN 4
            ELSE 5
        END,
        JobName;

    SELECT
        COUNT(*) AS JobsFound,
        SUM(CASE WHEN Decision = N'DISABLE' THEN 1 ELSE 0 END) AS JobsToDisable,
        SUM(CASE WHEN Decision = N'SKIP_CRITICAL' THEN 1 ELSE 0 END) AS JobsSkippedCritical,
        SUM(CASE WHEN Decision = N'SKIP_EXCLUDED' THEN 1 ELSE 0 END) AS JobsSkippedByExclusion,
        SUM(CASE WHEN Decision = N'ALREADY_DISABLED' THEN 1 ELSE 0 END) AS JobsAlreadyDisabled
    FROM #JobsForPatching;

    IF @Mode = N'PREVIEW'
        RETURN;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dba.SqlAgentPatchingJobState
        (
            PatchingRunId,
            JobId,
            JobName,
            CategoryName,
            WasEnabled,
            CurrentEnabledAtSnapshot,
            IsDisabledByTool,
            Decision,
            SkipReason,
            Comment
        )
        SELECT
            @PatchingRunId,
            JobId,
            JobName,
            CategoryName,
            CurrentEnabled,
            CurrentEnabled,
            0,
            Decision,
            SkipReason,
            @Comment
        FROM #JobsForPatching AS src
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dba.SqlAgentPatchingJobState AS st
            WHERE st.PatchingRunId = @PatchingRunId
              AND st.JobId = src.JobId
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @InsertError nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@InsertError, 16, 1);
        RETURN;
    END CATCH;

    DECLARE @JobId uniqueidentifier;
    DECLARE @JobName sysname;

    DECLARE disable_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT JobId, JobName
    FROM #JobsForPatching
    WHERE Decision = N'DISABLE'
    ORDER BY JobName;

    OPEN disable_cursor;
    FETCH NEXT FROM disable_cursor INTO @JobId, @JobName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC msdb.dbo.sp_update_job
                @job_id = @JobId,
                @enabled = 0;

            UPDATE dba.SqlAgentPatchingJobState
            SET
                IsDisabledByTool = 1,
                DisabledAtUtc = sysutcdatetime(),
                DisabledBy = original_login(),
                RestoreStatus = NULL
            WHERE PatchingRunId = @PatchingRunId
              AND JobId = @JobId;

            PRINT CONCAT(N'Wyłączono job: ', @JobName);
        END TRY
        BEGIN CATCH
            UPDATE dba.SqlAgentPatchingJobState
            SET
                IsDisabledByTool = 0,
                RestoreStatus = N'DISABLE_FAILED',
                Comment = CONCAT(COALESCE(Comment + N' | ', N''), N'Błąd wyłączania: ', ERROR_MESSAGE())
            WHERE PatchingRunId = @PatchingRunId
              AND JobId = @JobId;

            PRINT CONCAT(N'Błąd wyłączania joba: ', @JobName, N' | ', ERROR_MESSAGE());
        END CATCH;

        FETCH NEXT FROM disable_cursor INTO @JobId, @JobName;
    END;

    CLOSE disable_cursor;
    DEALLOCATE disable_cursor;

    UPDATE dba.SqlAgentPatchingRun
    SET Status = N'DISABLED'
    WHERE PatchingRunId = @PatchingRunId
      AND Status = N'OPEN';

    SELECT
        st.PatchingRunId,
        st.JobName,
        st.CategoryName,
        st.WasEnabled,
        st.IsDisabledByTool,
        st.Decision,
        st.SkipReason,
        st.DisabledAtUtc,
        st.DisabledBy,
        j.enabled AS CurrentEnabled
    FROM dba.SqlAgentPatchingJobState AS st
    LEFT JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = st.JobId
    WHERE st.PatchingRunId = @PatchingRunId
    ORDER BY st.JobName;
END;
GO

CREATE OR ALTER PROCEDURE dba.usp_RestoreSqlAgentJobsAfterPatching
    @PatchingRunId int,
    @Mode nvarchar(20) = N'Preview',
    @Comment nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Mode = UPPER(LTRIM(RTRIM(@Mode)));

    IF @Mode NOT IN (N'PREVIEW', N'EXECUTE')
    BEGIN
        RAISERROR(N'Nieprawidłowy @Mode. Dozwolone wartości: Preview, Execute.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dba.SqlAgentPatchingRun WHERE PatchingRunId = @PatchingRunId)
    BEGIN
        RAISERROR(N'Nie istnieje wskazany @PatchingRunId.', 16, 1);
        RETURN;
    END;

    IF OBJECT_ID(N'tempdb..#JobsForRestore', N'U') IS NOT NULL
        DROP TABLE #JobsForRestore;

    CREATE TABLE #JobsForRestore
    (
        JobId uniqueidentifier NOT NULL PRIMARY KEY,
        JobName sysname NOT NULL,
        WasEnabled bit NOT NULL,
        IsDisabledByTool bit NOT NULL,
        CurrentEnabled bit NULL,
        RestoreDecision nvarchar(40) NOT NULL,
        RestoreReason nvarchar(400) NULL
    );

    INSERT INTO #JobsForRestore
    (
        JobId,
        JobName,
        WasEnabled,
        IsDisabledByTool,
        CurrentEnabled,
        RestoreDecision,
        RestoreReason
    )
    SELECT
        st.JobId,
        st.JobName,
        st.WasEnabled,
        st.IsDisabledByTool,
        CONVERT(bit, j.enabled) AS CurrentEnabled,
        CASE
            WHEN j.job_id IS NULL THEN N'JOB_NOT_FOUND'
            WHEN st.WasEnabled = 1 AND st.IsDisabledByTool = 1 AND j.enabled = 0 THEN N'RESTORE'
            WHEN st.WasEnabled = 1 AND st.IsDisabledByTool = 1 AND j.enabled = 1 THEN N'ALREADY_ENABLED'
            WHEN st.IsDisabledByTool = 0 THEN N'SKIP_NOT_DISABLED_BY_TOOL'
            ELSE N'SKIP_WAS_DISABLED_BEFORE'
        END AS RestoreDecision,
        CASE
            WHEN j.job_id IS NULL THEN N'Job istnieje w historii, ale nie istnieje już w msdb.dbo.sysjobs.'
            WHEN st.WasEnabled = 1 AND st.IsDisabledByTool = 1 AND j.enabled = 0 THEN N'Job zostanie przywrócony do enabled = 1.'
            WHEN st.WasEnabled = 1 AND st.IsDisabledByTool = 1 AND j.enabled = 1 THEN N'Job jest już włączony, prawdopodobnie został włączony ręcznie.'
            WHEN st.IsDisabledByTool = 0 THEN N'Job nie został wyłączony przez narzędzie, więc nie będzie włączany.'
            ELSE N'Job przed patchowaniem nie był włączony, więc nie będzie włączany.'
        END AS RestoreReason
    FROM dba.SqlAgentPatchingJobState AS st
    LEFT JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = st.JobId
    WHERE st.PatchingRunId = @PatchingRunId;

    SELECT
        @Mode AS Mode,
        @PatchingRunId AS PatchingRunId,
        JobName,
        WasEnabled,
        IsDisabledByTool,
        CurrentEnabled,
        RestoreDecision,
        RestoreReason
    FROM #JobsForRestore
    ORDER BY
        CASE RestoreDecision
            WHEN N'RESTORE' THEN 1
            WHEN N'ALREADY_ENABLED' THEN 2
            WHEN N'JOB_NOT_FOUND' THEN 3
            ELSE 4
        END,
        JobName;

    SELECT
        COUNT(*) AS JobsInSnapshot,
        SUM(CASE WHEN RestoreDecision = N'RESTORE' THEN 1 ELSE 0 END) AS JobsToRestore,
        SUM(CASE WHEN RestoreDecision = N'ALREADY_ENABLED' THEN 1 ELSE 0 END) AS JobsAlreadyEnabled,
        SUM(CASE WHEN RestoreDecision = N'JOB_NOT_FOUND' THEN 1 ELSE 0 END) AS JobsNotFound,
        SUM(CASE WHEN RestoreDecision LIKE N'SKIP%' THEN 1 ELSE 0 END) AS JobsSkipped
    FROM #JobsForRestore;

    IF @Mode = N'PREVIEW'
        RETURN;

    UPDATE dba.SqlAgentPatchingRun
    SET Status = N'RESTORE_STARTED'
    WHERE PatchingRunId = @PatchingRunId;

    UPDATE st
    SET
        RestoreStatus = r.RestoreDecision,
        Comment = CASE
            WHEN @Comment IS NULL THEN st.Comment
            ELSE CONCAT(COALESCE(st.Comment + N' | ', N''), @Comment)
        END
    FROM dba.SqlAgentPatchingJobState AS st
    INNER JOIN #JobsForRestore AS r
        ON r.JobId = st.JobId
    WHERE st.PatchingRunId = @PatchingRunId
      AND r.RestoreDecision <> N'RESTORE';

    DECLARE @JobId uniqueidentifier;
    DECLARE @JobName sysname;

    DECLARE restore_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT JobId, JobName
    FROM #JobsForRestore
    WHERE RestoreDecision = N'RESTORE'
    ORDER BY JobName;

    OPEN restore_cursor;
    FETCH NEXT FROM restore_cursor INTO @JobId, @JobName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC msdb.dbo.sp_update_job
                @job_id = @JobId,
                @enabled = 1;

            UPDATE dba.SqlAgentPatchingJobState
            SET
                RestoredAtUtc = sysutcdatetime(),
                RestoredBy = original_login(),
                RestoreStatus = N'RESTORED',
                Comment = CASE
                    WHEN @Comment IS NULL THEN Comment
                    ELSE CONCAT(COALESCE(Comment + N' | ', N''), @Comment)
                END
            WHERE PatchingRunId = @PatchingRunId
              AND JobId = @JobId;

            PRINT CONCAT(N'Przywrócono job: ', @JobName);
        END TRY
        BEGIN CATCH
            UPDATE dba.SqlAgentPatchingJobState
            SET
                RestoreStatus = N'RESTORE_FAILED',
                Comment = CONCAT(COALESCE(Comment + N' | ', N''), N'Błąd przywracania: ', ERROR_MESSAGE())
            WHERE PatchingRunId = @PatchingRunId
              AND JobId = @JobId;

            PRINT CONCAT(N'Błąd przywracania joba: ', @JobName, N' | ', ERROR_MESSAGE());
        END CATCH;

        FETCH NEXT FROM restore_cursor INTO @JobId, @JobName;
    END;

    CLOSE restore_cursor;
    DEALLOCATE restore_cursor;

    IF EXISTS
    (
        SELECT 1
        FROM dba.SqlAgentPatchingJobState
        WHERE PatchingRunId = @PatchingRunId
          AND RestoreStatus IN (N'RESTORE_FAILED', N'JOB_NOT_FOUND')
    )
    BEGIN
        UPDATE dba.SqlAgentPatchingRun
        SET Status = N'PARTIAL_RESTORE'
        WHERE PatchingRunId = @PatchingRunId;
    END
    ELSE
    BEGIN
        UPDATE dba.SqlAgentPatchingRun
        SET
            Status = N'RESTORED',
            ClosedAtUtc = sysutcdatetime(),
            ClosedBy = original_login()
        WHERE PatchingRunId = @PatchingRunId;
    END;

    EXEC dba.usp_ReportSqlAgentPatchingWindow
        @PatchingRunId = @PatchingRunId;
END;
GO

CREATE OR ALTER PROCEDURE dba.usp_ReportSqlAgentPatchingWindow
    @PatchingRunId int
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dba.SqlAgentPatchingRun WHERE PatchingRunId = @PatchingRunId)
    BEGIN
        RAISERROR(N'Nie istnieje wskazany @PatchingRunId.', 16, 1);
        RETURN;
    END;

    SELECT
        PatchingRunId,
        InstanceName,
        ServerName,
        PlannedStartDateTime,
        PlannedEndDateTime,
        Description,
        CreatedAtUtc,
        CreatedBy,
        Status,
        ClosedAtUtc,
        ClosedBy,
        Comment
    FROM dba.SqlAgentPatchingRun
    WHERE PatchingRunId = @PatchingRunId;

    SELECT
        st.PatchingRunId,
        st.JobName,
        st.CategoryName,
        st.WasEnabled,
        st.CurrentEnabledAtSnapshot,
        st.IsDisabledByTool,
        CONVERT(bit, j.enabled) AS CurrentEnabled,
        CASE
            WHEN j.job_id IS NULL THEN N'JOB_NOT_FOUND'
            WHEN st.WasEnabled = 1 AND st.IsDisabledByTool = 1 AND j.enabled = 0 AND st.RestoreStatus IS NULL THEN N'DISABLED_WAITING_FOR_RESTORE'
            WHEN st.WasEnabled = 1 AND st.IsDisabledByTool = 1 AND j.enabled = 1 AND st.RestoreStatus IS NULL THEN N'ENABLED_MANUALLY_AFTER_DISABLE'
            WHEN st.RestoreStatus IS NOT NULL THEN st.RestoreStatus
            ELSE st.Decision
        END AS CurrentStateAgainstSnapshot,
        st.Decision,
        st.SkipReason,
        st.DisabledAtUtc,
        st.DisabledBy,
        st.RestoredAtUtc,
        st.RestoredBy,
        st.RestoreStatus,
        st.Comment
    FROM dba.SqlAgentPatchingJobState AS st
    LEFT JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = st.JobId
    WHERE st.PatchingRunId = @PatchingRunId
    ORDER BY st.JobName;

    SELECT
        COUNT(*) AS JobsInSnapshot,
        SUM(CASE WHEN IsDisabledByTool = 1 THEN 1 ELSE 0 END) AS JobsDisabledByTool,
        SUM(CASE WHEN Decision = N'SKIP_CRITICAL' THEN 1 ELSE 0 END) AS JobsSkippedCritical,
        SUM(CASE WHEN Decision = N'SKIP_EXCLUDED' THEN 1 ELSE 0 END) AS JobsSkippedExcluded,
        SUM(CASE WHEN Decision = N'ALREADY_DISABLED' THEN 1 ELSE 0 END) AS JobsAlreadyDisabled,
        SUM(CASE WHEN RestoreStatus = N'RESTORED' THEN 1 ELSE 0 END) AS JobsRestored,
        SUM(CASE WHEN RestoreStatus IN (N'RESTORE_FAILED', N'JOB_NOT_FOUND') THEN 1 ELSE 0 END) AS JobsWithRestoreProblem
    FROM dba.SqlAgentPatchingJobState
    WHERE PatchingRunId = @PatchingRunId;
END;
GO

-- Weryfikacja obiektów modułu patchingowego
SELECT
    s.name AS SchemaName,
    o.name AS ObjectName,
    o.type_desc
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE s.name = N'dba'
  AND o.name IN
  (
      N'SqlAgentPatchingRun',
      N'SqlAgentPatchingJobState',
      N'usp_StartSqlAgentPatchingWindow',
      N'usp_DisableSqlAgentJobsForPatching',
      N'usp_RestoreSqlAgentJobsAfterPatching',
      N'usp_ReportSqlAgentPatchingWindow'
  )
ORDER BY o.type_desc, o.name;
GO
