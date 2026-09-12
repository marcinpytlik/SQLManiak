/*
    POC: Secure export without unconstrained delegation
    Stage 5 - queue worker schema, retry metadata and internal worker procedures
*/

USE [SSIS_Delegation_Lab];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* Extend the queue with retry/concurrency metadata. */
IF COL_LENGTH(N'dbo.ExportRequest', N'AttemptCount') IS NULL
BEGIN
    ALTER TABLE dbo.ExportRequest
        ADD AttemptCount int NOT NULL
            CONSTRAINT DF_ExportRequest_AttemptCount DEFAULT (0);
END;
GO

IF COL_LENGTH(N'dbo.ExportRequest', N'MaxAttempts') IS NULL
BEGIN
    ALTER TABLE dbo.ExportRequest
        ADD MaxAttempts int NOT NULL
            CONSTRAINT DF_ExportRequest_MaxAttempts DEFAULT (3);
END;
GO

IF COL_LENGTH(N'dbo.ExportRequest', N'LastAttemptAt') IS NULL
BEGIN
    ALTER TABLE dbo.ExportRequest
        ADD LastAttemptAt datetime2(0) NULL;
END;
GO

IF COL_LENGTH(N'dbo.ExportRequest', N'NextAttemptAt') IS NULL
BEGIN
    ALTER TABLE dbo.ExportRequest
        ADD NextAttemptAt datetime2(0) NULL;
END;
GO

IF COL_LENGTH(N'dbo.ExportRequest', N'WorkerToken') IS NULL
BEGIN
    ALTER TABLE dbo.ExportRequest
        ADD WorkerToken uniqueidentifier NULL;
END;
GO

/* Replace the Stage 1 status check with a Stage 5-aware definition. */
IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.ExportRequest')
      AND name = N'CK_ExportRequest_Status'
)
BEGIN
    ALTER TABLE dbo.ExportRequest
        DROP CONSTRAINT CK_ExportRequest_Status;
END;
GO

ALTER TABLE dbo.ExportRequest WITH CHECK
    ADD CONSTRAINT CK_ExportRequest_Status
        CHECK (Status IN ('NEW','RETRY','PROCESSING','DONE','FAILED'));
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.ExportRequest')
      AND name = N'CK_ExportRequest_Attempts'
)
BEGIN
    ALTER TABLE dbo.ExportRequest WITH CHECK
        ADD CONSTRAINT CK_ExportRequest_Attempts
            CHECK (AttemptCount >= 0 AND MaxAttempts >= 1 AND AttemptCount <= MaxAttempts);
END;
GO

/* Rebuild the queue lookup index to include retry scheduling metadata. */
IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.ExportRequest')
      AND name = N'IX_ExportRequest_Status_RequestedAt'
)
BEGIN
    DROP INDEX IX_ExportRequest_Status_RequestedAt ON dbo.ExportRequest;
END;
GO

CREATE INDEX IX_ExportRequest_WorkQueue
    ON dbo.ExportRequest(Status, NextAttemptAt, RequestedAt)
    INCLUDE (RequestId, CustomerId, ReportDate, RequestedBy, AttemptCount, MaxAttempts);
GO

/*
    Atomically claim exactly one eligible request.
    UPDLOCK + READPAST lets multiple workers coexist without claiming the same row.
*/
CREATE OR ALTER PROCEDURE dbo.usp_ClaimExportRequest
    @WorkerToken uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @WorkerToken IS NULL
        THROW 58001, 'WorkerToken is required.', 1;

    DECLARE @Now datetime2(0) = SYSDATETIME();
    DECLARE @RequestId uniqueidentifier;

    BEGIN TRANSACTION;

    SELECT TOP (1)
        @RequestId = r.RequestId
    FROM dbo.ExportRequest AS r WITH (UPDLOCK, READPAST, ROWLOCK)
    WHERE r.Status IN ('NEW','RETRY')
      AND r.AttemptCount < r.MaxAttempts
      AND (r.NextAttemptAt IS NULL OR r.NextAttemptAt <= @Now)
    ORDER BY
        CASE r.Status WHEN 'NEW' THEN 0 ELSE 1 END,
        r.RequestedAt,
        r.RequestId;

    IF @RequestId IS NOT NULL
    BEGIN
        UPDATE dbo.ExportRequest
        SET Status        = 'PROCESSING',
            StartedAt     = @Now,
            FinishedAt    = NULL,
            LastAttemptAt = @Now,
            NextAttemptAt = NULL,
            AttemptCount  = AttemptCount + 1,
            WorkerToken   = @WorkerToken,
            ErrorMessage  = NULL
        WHERE RequestId = @RequestId;
    END;

    COMMIT TRANSACTION;

    SELECT
        r.RequestId,
        r.CustomerId,
        r.ReportDate,
        r.RequestedBy,
        r.RequestedAt,
        r.Status,
        r.AttemptCount,
        r.MaxAttempts,
        r.WorkerToken
    FROM dbo.ExportRequest AS r
    WHERE r.RequestId = @RequestId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CompleteExportRequest
    @RequestId uniqueidentifier,
    @WorkerToken uniqueidentifier,
    @OutputFile nvarchar(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RequestId IS NULL OR @WorkerToken IS NULL
        THROW 58011, 'RequestId and WorkerToken are required.', 1;

    IF NULLIF(LTRIM(RTRIM(@OutputFile)), N'') IS NULL
        THROW 58012, 'OutputFile is required.', 1;

    UPDATE dbo.ExportRequest
    SET Status        = 'DONE',
        FinishedAt    = SYSDATETIME(),
        OutputFile    = @OutputFile,
        ErrorMessage  = NULL,
        NextAttemptAt = NULL,
        WorkerToken   = NULL
    WHERE RequestId = @RequestId
      AND Status = 'PROCESSING'
      AND WorkerToken = @WorkerToken;

    IF @@ROWCOUNT <> 1
        THROW 58013, 'Request could not be completed because the worker lease no longer matches.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_FailExportRequest
    @RequestId uniqueidentifier,
    @WorkerToken uniqueidentifier,
    @ErrorMessage nvarchar(4000),
    @RetryDelaySeconds int = 60
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RequestId IS NULL OR @WorkerToken IS NULL
        THROW 58021, 'RequestId and WorkerToken are required.', 1;

    IF @RetryDelaySeconds < 0
        THROW 58022, 'RetryDelaySeconds cannot be negative.', 1;

    DECLARE @AttemptCount int;
    DECLARE @MaxAttempts int;

    SELECT
        @AttemptCount = AttemptCount,
        @MaxAttempts = MaxAttempts
    FROM dbo.ExportRequest WITH (UPDLOCK, ROWLOCK)
    WHERE RequestId = @RequestId
      AND Status = 'PROCESSING'
      AND WorkerToken = @WorkerToken;

    IF @AttemptCount IS NULL
        THROW 58023, 'Request could not be failed because the worker lease no longer matches.', 1;

    UPDATE dbo.ExportRequest
    SET Status = CASE WHEN @AttemptCount < @MaxAttempts THEN 'RETRY' ELSE 'FAILED' END,
        FinishedAt = CASE WHEN @AttemptCount < @MaxAttempts THEN NULL ELSE SYSDATETIME() END,
        NextAttemptAt = CASE
            WHEN @AttemptCount < @MaxAttempts
                THEN DATEADD(SECOND, @RetryDelaySeconds, SYSDATETIME())
            ELSE NULL
        END,
        ErrorMessage = LEFT(COALESCE(@ErrorMessage, N'Unknown worker error.'), 4000),
        WorkerToken = NULL
    WHERE RequestId = @RequestId
      AND Status = 'PROCESSING'
      AND WorkerToken = @WorkerToken;
END;
GO

/* Dedicated execution identity: procedure-only access, no direct table access. */
USE [master];
GO

IF SUSER_ID(N'SQLLAB\poc-ssis-export') IS NULL
BEGIN
    CREATE LOGIN [SQLLAB\poc-ssis-export] FROM WINDOWS;
END;
GO

USE [SSIS_Delegation_Lab];
GO

IF DATABASE_PRINCIPAL_ID(N'SQLLAB\poc-ssis-export') IS NULL
BEGIN
    CREATE USER [SQLLAB\poc-ssis-export] FOR LOGIN [SQLLAB\poc-ssis-export];
END;
GO

GRANT EXECUTE ON dbo.usp_ClaimExportRequest TO [SQLLAB\poc-ssis-export];
GRANT EXECUTE ON dbo.usp_CompleteExportRequest TO [SQLLAB\poc-ssis-export];
GRANT EXECUTE ON dbo.usp_FailExportRequest TO [SQLLAB\poc-ssis-export];

DENY SELECT, INSERT, UPDATE, DELETE ON dbo.ExportRequest TO [SQLLAB\poc-ssis-export];
GO

SELECT
    c.name AS ColumnName,
    t.name AS DataType,
    c.max_length,
    c.is_nullable
FROM sys.columns AS c
JOIN sys.types AS t
    ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'dbo.ExportRequest')
ORDER BY c.column_id;
GO
