/* =============================================================================
   SQL CONFIG GUARD (All-in-one) - SQL Server 2022+
   Author: marcin 
   Purpose:
     - Baseline table for sys.configurations
     - Snapshot BEFORE/AFTER each run
     - Drift log with optional audit correlation (SERVER_CONFIGURATION_CHANGE_GROUP)
     - Enforcement procedure: master.dbo.usp_EnforceInstanceConfigBaseline
     - Optional: CAPTURE current settings as baseline (recommended first run)

   HOW TO USE (quick):
     1) Edit @AuditPath below to an existing folder writable by SQL Server service.
     2) Run this script in master.
     3) (Optional but recommended) Run the CAPTURE section to "freeze" your current config.
     4) Run the job script (02_*.sql) to schedule enforcement every 5 minutes.

   Notes:
     - This DOES NOT block sysadmin from changing settings (nothing truly can).
       It detects drift, logs it, and reverts it.
     - For non-dynamic options, enforcement sets the value but effective change needs SQL restart.
   ============================================================================= */

USE master;
GO

/* -----------------------------------------------------------------------------
   0) CONFIG: Audit path (must exist + SQL Server service must have write rights)
   ---------------------------------------------------------------------------- */
DECLARE @AuditPath nvarchar(260) = N'D:\SQLAudit\';  -- <<< CHANGE ME if needed
GO

/* -----------------------------------------------------------------------------
   1) Ensure baseline table exists
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.InstanceConfigBaseline','U') IS NULL
BEGIN
  CREATE TABLE dbo.InstanceConfigBaseline
  (
      name           sysname       NOT NULL PRIMARY KEY,
      value_in_use   sql_variant   NOT NULL,
      is_dynamic     bit           NOT NULL,
      notes          nvarchar(200) NULL,
      updated_at     datetime2(0)  NOT NULL CONSTRAINT DF_ICB_UpdatedAt DEFAULT (sysdatetime())
  );
END
GO

/* -----------------------------------------------------------------------------
   2) Settings table (audit file pattern + lookback)
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.InstanceConfigGuardSettings','U') IS NULL
BEGIN
    CREATE TABLE dbo.InstanceConfigGuardSettings
    (
        SettingName  sysname        NOT NULL PRIMARY KEY,
        SettingValue nvarchar(4000) NOT NULL,
        UpdatedAt    datetime2(0)   NOT NULL CONSTRAINT DF_ICGS_UpdatedAt DEFAULT (sysdatetime())
    );
END
GO

/* -----------------------------------------------------------------------------
   3) Run table (each job execution)
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.InstanceConfigEnforceRun','U') IS NULL
BEGIN
    CREATE TABLE dbo.InstanceConfigEnforceRun
    (
        run_id         bigint IDENTITY(1,1) PRIMARY KEY,
        started_at     datetime2(0) NOT NULL CONSTRAINT DF_ICER_Started DEFAULT (sysdatetime()),
        ended_at       datetime2(0) NULL,

        executed_as    sysname NULL,
        original_login sysname NULL,
        host_name      nvarchar(128) NULL,
        app_name       nvarchar(128) NULL,
        spid           int NULL,

        drift_found    int NOT NULL CONSTRAINT DF_ICER_DriftFound DEFAULT (0),
        drift_reverted int NOT NULL CONSTRAINT DF_ICER_DriftReverted DEFAULT (0),
        drift_pending_restart int NOT NULL CONSTRAINT DF_ICER_DriftPending DEFAULT (0),

        notes          nvarchar(4000) NULL
    );
END
GO

/* -----------------------------------------------------------------------------
   4) Snapshot table (before/after)
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.InstanceConfigSnapshot','U') IS NULL
BEGIN
    CREATE TABLE dbo.InstanceConfigSnapshot
    (
        snapshot_id   bigint IDENTITY(1,1) PRIMARY KEY,
        run_id        bigint NOT NULL,
        phase         varchar(6) NOT NULL,  -- 'before' / 'after'
        captured_at   datetime2(0) NOT NULL CONSTRAINT DF_ICS_Captured DEFAULT (sysdatetime()),

        name          sysname NOT NULL,
        is_dynamic    bit NOT NULL,
        current_value sql_variant NULL,  -- effective current for compare (dynamic->value_in_use, static->value)
        value         int NULL,
        value_in_use  int NULL,
        baseline_value sql_variant NULL
    );

    CREATE INDEX IX_ICS_run_phase ON dbo.InstanceConfigSnapshot(run_id, phase, name);
END
GO

/* -----------------------------------------------------------------------------
   5) Drift log table (create or upgrade)
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.InstanceConfigDriftLog','U') IS NULL
BEGIN
    CREATE TABLE dbo.InstanceConfigDriftLog
    (
      drift_id       bigint IDENTITY(1,1) PRIMARY KEY,
      run_id         bigint NULL,
      drift_time     datetime2(0) NOT NULL CONSTRAINT DF_ICDL_Time DEFAULT (sysdatetime()),
      name           sysname      NOT NULL,
      old_value      sql_variant  NULL,
      new_value      sql_variant  NULL,
      action_taken   nvarchar(50) NOT NULL, -- detected / reverted / reverted_pending_restart / skipped
      details        nvarchar(4000) NULL,

      audit_event_time datetime2(3) NULL,
      audit_principal  sysname NULL,
      audit_statement  nvarchar(4000) NULL
    );

    CREATE INDEX IX_ICDL_run_time ON dbo.InstanceConfigDriftLog(run_id, drift_time DESC);
END
ELSE
BEGIN
    IF COL_LENGTH('dbo.InstanceConfigDriftLog','run_id') IS NULL
        ALTER TABLE dbo.InstanceConfigDriftLog ADD run_id bigint NULL;

    IF COL_LENGTH('dbo.InstanceConfigDriftLog','audit_event_time') IS NULL
        ALTER TABLE dbo.InstanceConfigDriftLog ADD audit_event_time datetime2(3) NULL;

    IF COL_LENGTH('dbo.InstanceConfigDriftLog','audit_principal') IS NULL
        ALTER TABLE dbo.InstanceConfigDriftLog ADD audit_principal sysname NULL;

    IF COL_LENGTH('dbo.InstanceConfigDriftLog','audit_statement') IS NULL
        ALTER TABLE dbo.InstanceConfigDriftLog ADD audit_statement nvarchar(4000) NULL;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ICDL_run_time' AND object_id = OBJECT_ID('dbo.InstanceConfigDriftLog'))
        CREATE INDEX IX_ICDL_run_time ON dbo.InstanceConfigDriftLog(run_id, drift_time DESC);
END
GO

/* -----------------------------------------------------------------------------
   6) SQL Server Audit: SERVER_CONFIGURATION_CHANGE_GROUP
   ----------------------------------------------------------------------------
   - Creates: Audit_ServerConfig + AuditSpec_ServerConfig
   - Writes to @AuditPath
   ---------------------------------------------------------------------------- */
DECLARE @AuditPath2 nvarchar(260) = N'D:\SQLAudit\'; -- <<< MUST MATCH the path you want (edit above too)
-- NOTE: T-SQL batch variable scope resets at GO, so we keep it here as well.

IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = N'Audit_ServerConfig')
BEGIN
    DECLARE @sql nvarchar(max) =
N'CREATE SERVER AUDIT [Audit_ServerConfig]
TO FILE
(
    FILEPATH = ' + QUOTENAME(@AuditPath2,'''') + N',
    MAXSIZE = 2048 MB,
    MAX_ROLLOVER_FILES = 20,
    RESERVE_DISK_SPACE = OFF
)
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);';

    EXEC sys.sp_executesql @sql;
END
GO

ALTER SERVER AUDIT [Audit_ServerConfig] WITH (STATE = ON);
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = N'AuditSpec_ServerConfig')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION [AuditSpec_ServerConfig]
    FOR SERVER AUDIT [Audit_ServerConfig]
        ADD (SERVER_CONFIGURATION_CHANGE_GROUP)
    WITH (STATE = ON);
END
ELSE
BEGIN
    ALTER SERVER AUDIT SPECIFICATION [AuditSpec_ServerConfig] WITH (STATE = ON);
END
GO

/* -----------------------------------------------------------------------------
   7) Seed guard settings: audit file pattern + lookback minutes
   ---------------------------------------------------------------------------- */
MERGE dbo.InstanceConfigGuardSettings AS t
USING (VALUES
    (N'AuditFilePattern', N'D:\SQLAudit\Audit_ServerConfig*'), -- <<< CHANGE if your @AuditPath differs
    (N'AuditLookbackMinutes', N'1440') -- 24h
) AS s(SettingName, SettingValue)
ON t.SettingName = s.SettingName
WHEN MATCHED THEN UPDATE SET t.SettingValue = s.SettingValue, t.UpdatedAt = sysdatetime()
WHEN NOT MATCHED THEN INSERT(SettingName, SettingValue) VALUES(s.SettingName, s.SettingValue);
GO

/* -----------------------------------------------------------------------------
   8) CAPTURE BASELINE (recommended): freeze current instance configuration
   ----------------------------------------------------------------------------
   Run this ONCE right after you set your desired instance options.
   Comment out if you prefer to populate baseline manually.
   ---------------------------------------------------------------------------- */
-- MERGE master.dbo.InstanceConfigBaseline AS t
-- USING
-- (
--     SELECT
--         c.name,
--         CAST(c.value_in_use AS sql_variant) AS value_in_use,
--         CAST(c.is_dynamic AS bit)           AS is_dynamic,
--         CAST(N'captured from sys.configurations' AS nvarchar(200)) AS notes
--     FROM sys.configurations c
-- ) AS s
-- ON t.name = s.name
-- WHEN MATCHED THEN
--   UPDATE SET
--     t.value_in_use = s.value_in_use,
--     t.is_dynamic   = s.is_dynamic,
--     t.notes        = s.notes,
--     t.updated_at   = sysdatetime()
-- WHEN NOT MATCHED THEN
--   INSERT (name, value_in_use, is_dynamic, notes)
--   VALUES (s.name, s.value_in_use, s.is_dynamic, s.notes);
-- GO

/* -----------------------------------------------------------------------------
   9) Enforcement procedure: snapshots + audit correlation + revert drift
   ---------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.usp_EnforceInstanceConfigBaseline
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @run_id bigint;

    INSERT dbo.InstanceConfigEnforceRun
    (
        executed_as, original_login, host_name, app_name, spid, notes
    )
    VALUES
    (
        SUSER_SNAME(),
        ORIGINAL_LOGIN(),
        HOST_NAME(),
        APP_NAME(),
        @@SPID,
        N'Config baseline enforcement run'
    );

    SET @run_id = SCOPE_IDENTITY();

    DECLARE @AuditPattern nvarchar(4000) =
        (SELECT SettingValue FROM dbo.InstanceConfigGuardSettings WHERE SettingName = N'AuditFilePattern');

    DECLARE @LookbackMinutes int =
        TRY_CONVERT(int, (SELECT SettingValue FROM dbo.InstanceConfigGuardSettings WHERE SettingName = N'AuditLookbackMinutes'));

    IF @LookbackMinutes IS NULL OR @LookbackMinutes <= 0 SET @LookbackMinutes = 1440;

    /* Snapshot BEFORE */
    INSERT dbo.InstanceConfigSnapshot(run_id, phase, name, is_dynamic, current_value, value, value_in_use, baseline_value)
    SELECT
        @run_id,
        'before',
        b.name,
        CAST(c.is_dynamic AS bit),
        CAST(CASE WHEN c.is_dynamic = 1 THEN c.value_in_use ELSE c.value END AS sql_variant) AS current_value,
        c.value,
        c.value_in_use,
        b.value_in_use
    FROM dbo.InstanceConfigBaseline b
    JOIN sys.configurations c ON c.name = b.name;

    /* Detect drift (effective current: dynamic->value_in_use, static->value) */
    ;WITH Drift AS
    (
        SELECT
            c.name,
            c.is_dynamic,
            CAST(CASE WHEN c.is_dynamic = 1 THEN c.value_in_use ELSE c.value END AS sql_variant) AS current_effective,
            b.value_in_use AS baseline_value
        FROM sys.configurations c
        JOIN dbo.InstanceConfigBaseline b
          ON b.name = c.name
        WHERE CAST(CASE WHEN c.is_dynamic = 1 THEN c.value_in_use ELSE c.value END AS sql_variant) <> b.value_in_use
    )
    SELECT
        name, is_dynamic, current_effective, baseline_value
    INTO #drift
    FROM Drift;

    DECLARE @drift_found int = (SELECT COUNT(*) FROM #drift);
    DECLARE @reverted int = 0, @pending int = 0;

    IF @drift_found > 0
    BEGIN
        DECLARE
            @name sysname,
            @is_dynamic bit,
            @current sql_variant,
            @target sql_variant,
            @targetInt int,
            @audit_time datetime2(3),
            @audit_principal sysname,
            @audit_stmt nvarchar(4000);

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT name, CAST(is_dynamic AS bit), current_effective, baseline_value
            FROM #drift
            ORDER BY CASE WHEN name = N'show advanced options' THEN 0 ELSE 1 END, name;

        OPEN cur;
        FETCH NEXT FROM cur INTO @name, @is_dynamic, @current, @target;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @audit_time = NULL;
            SET @audit_principal = NULL;
            SET @audit_stmt = NULL;

            /* Try get last audit event related to this config option */
            BEGIN TRY
                IF @AuditPattern IS NOT NULL AND LEN(@AuditPattern) > 0
                BEGIN
                    ;WITH A AS
                    (
                        SELECT TOP (1)
                            event_time,
                            server_principal_name,
                            statement
                        FROM sys.fn_get_audit_file(@AuditPattern, DEFAULT, DEFAULT)
                        WHERE event_time >= DATEADD(MINUTE, -@LookbackMinutes, SYSUTCDATETIME())
                          AND statement LIKE N'%' + @name + N'%'
                        ORDER BY event_time DESC
                    )
                    SELECT
                        @audit_time = event_time,
                        @audit_principal = server_principal_name,
                        @audit_stmt = LEFT(statement, 4000)
                    FROM A;
                END
            END TRY
            BEGIN CATCH
                SET @audit_stmt = CONCAT(N'Audit lookup failed: ERROR ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
            END CATCH

            INSERT dbo.InstanceConfigDriftLog(run_id, name, old_value, new_value, action_taken, details, audit_event_time, audit_principal, audit_statement)
            VALUES
            (
                @run_id,
                @name,
                @current,
                @target,
                N'detected',
                N'Drift detected vs baseline',
                @audit_time,
                @audit_principal,
                @audit_stmt
            );

            /* Apply change (sp_configure expects int for these options) */
            SET @targetInt = TRY_CONVERT(int, @target);

            IF @targetInt IS NULL
            BEGIN
                INSERT dbo.InstanceConfigDriftLog(run_id, name, old_value, new_value, action_taken, details, audit_event_time, audit_principal, audit_statement)
                VALUES
                (
                    @run_id,
                    @name,
                    @current,
                    @target,
                    N'skipped',
                    N'Baseline value is not int-convertible; skipped (check dbo.InstanceConfigBaseline)',
                    @audit_time,
                    @audit_principal,
                    @audit_stmt
                );
            END
            ELSE
            BEGIN
                BEGIN TRY
                    EXEC sys.sp_configure @configname = @name, @configvalue = @targetInt;
                    RECONFIGURE;

                    DECLARE @post_effective int =
                    (
                        SELECT CASE WHEN is_dynamic = 1 THEN value_in_use ELSE value END
                        FROM sys.configurations
                        WHERE name = @name
                    );

                    IF @post_effective = @targetInt
                    BEGIN
                        SET @reverted += 1;

                        INSERT dbo.InstanceConfigDriftLog(run_id, name, old_value, new_value, action_taken, details, audit_event_time, audit_principal, audit_statement)
                        VALUES
                        (
                            @run_id,
                            @name,
                            @current,
                            @target,
                            N'reverted',
                            N'Reverted to baseline',
                            @audit_time,
                            @audit_principal,
                            @audit_stmt
                        );
                    END
                    ELSE
                    BEGIN
                        SET @pending += 1;

                        INSERT dbo.InstanceConfigDriftLog(run_id, name, old_value, new_value, action_taken, details, audit_event_time, audit_principal, audit_statement)
                        VALUES
                        (
                            @run_id,
                            @name,
                            @current,
                            @target,
                            N'reverted_pending_restart',
                            N'Config set to baseline but requires SQL Server restart to take effect (non-dynamic)',
                            @audit_time,
                            @audit_principal,
                            @audit_stmt
                        );
                    END
                END TRY
                BEGIN CATCH
                    INSERT dbo.InstanceConfigDriftLog(run_id, name, old_value, new_value, action_taken, details, audit_event_time, audit_principal, audit_statement)
                    VALUES
                    (
                        @run_id,
                        @name,
                        @current,
                        @target,
                        N'skipped',
                        CONCAT(N'Apply failed: ERROR ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()),
                        @audit_time,
                        @audit_principal,
                        @audit_stmt
                    );
                END CATCH
            END

            FETCH NEXT FROM cur INTO @name, @is_dynamic, @current, @target;
        END

        CLOSE cur;
        DEALLOCATE cur;
    END

    /* Snapshot AFTER */
    INSERT dbo.InstanceConfigSnapshot(run_id, phase, name, is_dynamic, current_value, value, value_in_use, baseline_value)
    SELECT
        @run_id,
        'after',
        b.name,
        CAST(c.is_dynamic AS bit),
        CAST(CASE WHEN c.is_dynamic = 1 THEN c.value_in_use ELSE c.value END AS sql_variant) AS current_value,
        c.value,
        c.value_in_use,
        b.value_in_use
    FROM dbo.InstanceConfigBaseline b
    JOIN sys.configurations c ON c.name = b.name;

    UPDATE dbo.InstanceConfigEnforceRun
      SET ended_at = sysdatetime(),
          drift_found = @drift_found,
          drift_reverted = @reverted,
          drift_pending_restart = @pending
    WHERE run_id = @run_id;
END
GO

/* -----------------------------------------------------------------------------
   10) Quick sanity queries
   ---------------------------------------------------------------------------- */
SELECT TOP (5) *
FROM dbo.InstanceConfigEnforceRun
ORDER BY run_id DESC;

SELECT TOP (50) *
FROM dbo.InstanceConfigDriftLog
ORDER BY drift_id DESC;
GO

-- Read audit (change path/prefix if needed)
-- SELECT TOP (200)
--     event_time, succeeded, server_principal_name, action_id, object_name, statement
-- FROM sys.fn_get_audit_file(N'D:\SQLAudit\Audit_ServerConfig*', DEFAULT, DEFAULT)
-- ORDER BY event_time DESC;
GO
