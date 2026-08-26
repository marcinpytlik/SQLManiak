/*
    Relacyjny Renesans
    Demo 04: Backfill in Batches — wersja FINAL

    

    Pokazujemy:
      1. Model początkowy
      2. Naiwny duży UPDATE - tylko jako przykład
      3. Tabelę stanu migracji
      4. Procedurę pojedynczego batcha
      5. Logowanie każdego batcha
      6. Wznawialność procesu
      7. WAITFOR pomiędzy batchami
      8. Raport postępu
      9. Walidację końcową

    Uruchamiaj wyłącznie w środowisku laboratoryjnym.
*/

USE master;
GO

IF DB_ID(N'RelationalRenaissanceBackfill') IS NOT NULL
BEGIN
    ALTER DATABASE RelationalRenaissanceBackfill
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

    DROP DATABASE RelationalRenaissanceBackfill;
END;
GO

CREATE DATABASE RelationalRenaissanceBackfill;
GO

ALTER DATABASE RelationalRenaissanceBackfill
SET RECOVERY SIMPLE;
GO

USE RelationalRenaissanceBackfill;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================
   ETAP 0. MODEL
   ============================================================ */

CREATE TABLE dbo.Orders
(
    OrderId        bigint IDENTITY(1,1) NOT NULL,
    OrderNumber    int NOT NULL,
    OrderNumberV2  nvarchar(30) NULL,
    CustomerName   nvarchar(200) NOT NULL,
    OrderAmount    decimal(12,2) NOT NULL,
    CreatedAt      datetime2(0) NOT NULL,

    CONSTRAINT PK_Orders
        PRIMARY KEY CLUSTERED (OrderId),

    CONSTRAINT UQ_Orders_OrderNumber
        UNIQUE (OrderNumber)
);
GO

;WITH
E1(N) AS
(
    SELECT N
    FROM (VALUES
        (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)
    ) AS d(N)
),
E2(N) AS
(
    SELECT 1
    FROM E1 AS a
    CROSS JOIN E1 AS b
),
E4(N) AS
(
    SELECT 1
    FROM E2 AS a
    CROSS JOIN E2 AS b
),
Nums AS
(
    SELECT TOP (50000)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM E4 AS a
    CROSS JOIN E1 AS b
)
INSERT INTO dbo.Orders
(
    OrderNumber,
    OrderNumberV2,
    CustomerName,
    OrderAmount,
    CreatedAt
)
SELECT
    100000 + rn,
    NULL,
    CONCAT(N'Klient ', rn),
    CONVERT(decimal(12,2), 100 + (rn % 5000)),
    DATEADD(MINUTE, -rn, SYSUTCDATETIME())
FROM Nums;
GO

SELECT
    TotalRows = COUNT_BIG(*),
    RowsToMigrate =
        SUM(CASE WHEN OrderNumberV2 IS NULL THEN 1 ELSE 0 END)
FROM dbo.Orders;
GO

/* ============================================================
   ETAP 1. NAIWNY WARIANT
   ============================================================ */

/*
UPDATE dbo.Orders
SET OrderNumberV2 =
    CONCAT(
        N'ORD-',
        YEAR(CreatedAt),
        N'-',
        CONVERT(nvarchar(20), OrderNumber)
    )
WHERE OrderNumberV2 IS NULL;
*/

/* ============================================================
   ETAP 2. STAN MIGRACJI
   ============================================================ */

CREATE TABLE dbo.BackfillState
(
    MigrationName       sysname NOT NULL,
    LastProcessedId     bigint NOT NULL
        CONSTRAINT DF_BackfillState_LastProcessedId
        DEFAULT (0),
    TotalRowsProcessed  bigint NOT NULL
        CONSTRAINT DF_BackfillState_TotalRowsProcessed
        DEFAULT (0),
    BatchSize           int NOT NULL,
    Status              varchar(20) NOT NULL,
    LastBatchStartedAt  datetime2(3) NULL,
    LastBatchEndedAt    datetime2(3) NULL,
    LastBatchRows       int NULL,
    UpdatedAt           datetime2(3) NOT NULL
        CONSTRAINT DF_BackfillState_UpdatedAt
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_BackfillState
        PRIMARY KEY (MigrationName),

    CONSTRAINT CK_BackfillState_Status
        CHECK (Status IN ('Ready','Running','Paused','Completed','Failed'))
);
GO

CREATE TABLE dbo.BackfillLog
(
    BackfillLogId     bigint IDENTITY(1,1) NOT NULL,
    MigrationName     sysname NOT NULL,
    BatchNumber       bigint NOT NULL,
    StartOrderId      bigint NULL,
    EndOrderId        bigint NULL,
    RowsProcessed     int NOT NULL,
    StartedAt         datetime2(3) NOT NULL,
    EndedAt           datetime2(3) NOT NULL,
    DurationMs        bigint NOT NULL,
    WasSuccessful     bit NOT NULL,
    ErrorNumber       int NULL,
    ErrorMessage      nvarchar(4000) NULL,

    CONSTRAINT PK_BackfillLog
        PRIMARY KEY CLUSTERED (BackfillLogId)
);
GO

INSERT INTO dbo.BackfillState
(
    MigrationName,
    BatchSize,
    Status
)
VALUES
(
    N'OrderNumberV2',
    1000,
    'Ready'
);
GO

/* ============================================================
   ETAP 3. PROCEDURA POJEDYNCZEGO BATCHA
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_Backfill_OrderNumberV2_RunBatch
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @MigrationName sysname = N'OrderNumberV2',
        @BatchSize int,
        @LastProcessedId bigint,
        @BatchNumber bigint,
        @StartedAt datetime2(3),
        @EndedAt datetime2(3),
        @Rows int = 0,
        @StartOrderId bigint,
        @EndOrderId bigint,
        @RemainingRows bigint;

    SELECT
        @BatchSize = BatchSize,
        @LastProcessedId = LastProcessedId
    FROM dbo.BackfillState WITH (UPDLOCK, HOLDLOCK)
    WHERE MigrationName = @MigrationName;

    IF @BatchSize IS NULL
        THROW 50030, 'Brak konfiguracji migracji.', 1;

    SELECT
        @BatchNumber = ISNULL(MAX(BatchNumber), 0) + 1
    FROM dbo.BackfillLog
    WHERE MigrationName = @MigrationName;

    SET @StartedAt = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        CREATE TABLE #Batch
        (
            OrderId bigint NOT NULL
                PRIMARY KEY
        );

        INSERT INTO #Batch(OrderId)
        SELECT TOP (@BatchSize)
            o.OrderId
        FROM dbo.Orders AS o WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE o.OrderNumberV2 IS NULL
          AND o.OrderId > @LastProcessedId
        ORDER BY o.OrderId;

        /*
            Jeśli checkpoint doszedł do końca,
            ale wcześniej coś zostało pominięte przez READPAST,
            wykonujemy drugi przebieg od początku.
        */
        IF NOT EXISTS (SELECT 1 FROM #Batch)
        BEGIN
            INSERT INTO #Batch(OrderId)
            SELECT TOP (@BatchSize)
                o.OrderId
            FROM dbo.Orders AS o WITH (UPDLOCK, READPAST, ROWLOCK)
            WHERE o.OrderNumberV2 IS NULL
            ORDER BY o.OrderId;
        END;

        SELECT
            @StartOrderId = MIN(OrderId),
            @EndOrderId   = MAX(OrderId)
        FROM #Batch;

        /*
            Brak rekordów do pracy oznacza, że migracja jest już zakończona.
        */
        IF @StartOrderId IS NULL
        BEGIN
            SET @EndedAt = SYSUTCDATETIME();

            UPDATE dbo.BackfillState
            SET
                Status = 'Completed',
                LastBatchStartedAt = @StartedAt,
                LastBatchEndedAt = @EndedAt,
                LastBatchRows = 0,
                UpdatedAt = @EndedAt
            WHERE MigrationName = @MigrationName;

            COMMIT;
            RETURN;
        END;

        UPDATE o
        SET OrderNumberV2 =
            CONCAT(
                N'ORD-',
                YEAR(o.CreatedAt),
                N'-',
                CONVERT(nvarchar(20), o.OrderNumber)
            )
        FROM dbo.Orders AS o
        JOIN #Batch AS b
            ON b.OrderId = o.OrderId
        WHERE o.OrderNumberV2 IS NULL;

        SET @Rows = @@ROWCOUNT;

        /*
            Poprawka:
            po wykonaniu batcha od razu sprawdzamy,
            czy pozostały jeszcze rekordy do migracji.
        */
        SELECT
            @RemainingRows = COUNT_BIG(*)
        FROM dbo.Orders
        WHERE OrderNumberV2 IS NULL;

        SET @EndedAt = SYSUTCDATETIME();

        UPDATE dbo.BackfillState
        SET
            LastProcessedId = @EndOrderId,
            TotalRowsProcessed = TotalRowsProcessed + @Rows,
            Status =
                CASE
                    WHEN @RemainingRows = 0
                        THEN 'Completed'
                    ELSE 'Running'
                END,
            LastBatchStartedAt = @StartedAt,
            LastBatchEndedAt = @EndedAt,
            LastBatchRows = @Rows,
            UpdatedAt = @EndedAt
        WHERE MigrationName = @MigrationName;

        INSERT INTO dbo.BackfillLog
        (
            MigrationName,
            BatchNumber,
            StartOrderId,
            EndOrderId,
            RowsProcessed,
            StartedAt,
            EndedAt,
            DurationMs,
            WasSuccessful
        )
        VALUES
        (
            @MigrationName,
            @BatchNumber,
            @StartOrderId,
            @EndOrderId,
            @Rows,
            @StartedAt,
            @EndedAt,
            DATEDIFF_BIG(MILLISECOND, @StartedAt, @EndedAt),
            1
        );

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @EndedAt = SYSUTCDATETIME();

        UPDATE dbo.BackfillState
        SET
            Status = 'Failed',
            UpdatedAt = @EndedAt
        WHERE MigrationName = @MigrationName;

        INSERT INTO dbo.BackfillLog
        (
            MigrationName,
            BatchNumber,
            StartOrderId,
            EndOrderId,
            RowsProcessed,
            StartedAt,
            EndedAt,
            DurationMs,
            WasSuccessful,
            ErrorNumber,
            ErrorMessage
        )
        VALUES
        (
            @MigrationName,
            ISNULL(@BatchNumber, 0),
            @StartOrderId,
            @EndOrderId,
            0,
            ISNULL(@StartedAt, @EndedAt),
            @EndedAt,
            DATEDIFF_BIG(
                MILLISECOND,
                ISNULL(@StartedAt, @EndedAt),
                @EndedAt
            ),
            0,
            ERROR_NUMBER(),
            ERROR_MESSAGE()
        );

        THROW;
    END CATCH;
END;
GO

/* ============================================================
   ETAP 4. JEDEN BATCH
   ============================================================ */

EXEC dbo.usp_Backfill_OrderNumberV2_RunBatch;
GO

SELECT *
FROM dbo.BackfillState;
GO

SELECT TOP (10) *
FROM dbo.BackfillLog
ORDER BY BackfillLogId DESC;
GO

/* ============================================================
   ETAP 5. RAPORT POSTĘPU
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_BackfillProgress
AS
    SELECT
        MigrationName = N'OrderNumberV2',
        TotalRows = COUNT_BIG(*),
        MigratedRows =
            SUM(
                CONVERT(
                    bigint,
                    CASE WHEN OrderNumberV2 IS NOT NULL THEN 1 ELSE 0 END
                )
            ),
        RemainingRows =
            SUM(
                CONVERT(
                    bigint,
                    CASE WHEN OrderNumberV2 IS NULL THEN 1 ELSE 0 END
                )
            ),
        PercentComplete =
            CONVERT
            (
                decimal(6,2),
                100.0 *
                SUM(
                    CONVERT(
                        decimal(19,4),
                        CASE WHEN OrderNumberV2 IS NOT NULL THEN 1 ELSE 0 END
                    )
                )
                /
                NULLIF(COUNT_BIG(*), 0)
            )
    FROM dbo.Orders;
GO

SELECT *
FROM dbo.vw_BackfillProgress;
GO

/* ============================================================
   ETAP 6. PĘTLA DEMONSTRACYJNA
   ============================================================ */

DECLARE @Remaining bigint = 1;
DECLARE @Iteration int = 0;
DECLARE @MaxIterations int = 1000;

WHILE @Remaining > 0
  AND @Iteration < @MaxIterations
BEGIN
    SET @Iteration += 1;

    EXEC dbo.usp_Backfill_OrderNumberV2_RunBatch;

    SELECT
        @Remaining = RemainingRows
    FROM dbo.vw_BackfillProgress;

    SELECT
        Iteration = @Iteration,
        RemainingRows = @Remaining;

    WAITFOR DELAY '00:00:00.050';
END;
GO

/* ============================================================
   ETAP 7. WYNIK
   ============================================================ */

SELECT *
FROM dbo.vw_BackfillProgress;
GO

SELECT *
FROM dbo.BackfillState;
GO

SELECT
    BatchNumber,
    StartOrderId,
    EndOrderId,
    RowsProcessed,
    DurationMs,
    WasSuccessful
FROM dbo.BackfillLog
ORDER BY BatchNumber;
GO

/* ============================================================
   ETAP 8. WALIDACJA
   ============================================================ */

SELECT
    NullRows = COUNT_BIG(*)
FROM dbo.Orders
WHERE OrderNumberV2 IS NULL;
GO

SELECT
    InvalidRows = COUNT_BIG(*)
FROM dbo.Orders
WHERE OrderNumberV2 <>
    CONCAT(
        N'ORD-',
        YEAR(CreatedAt),
        N'-',
        CONVERT(nvarchar(20), OrderNumber)
    );
GO

SELECT
    OrderNumberV2,
    DuplicateCount = COUNT_BIG(*)
FROM dbo.Orders
GROUP BY OrderNumberV2
HAVING COUNT_BIG(*) > 1;
GO

/* ============================================================
   ETAP 9. MONITORING
   ============================================================ */

SELECT
    total_log_size_mb =
        total_log_size_in_bytes / 1024.0 / 1024.0,
    used_log_space_mb =
        used_log_space_in_bytes / 1024.0 / 1024.0,
    used_log_space_in_percent
FROM sys.dm_db_log_space_usage;
GO

SELECT
    name,
    recovery_model_desc,
    log_reuse_wait_desc
FROM sys.databases
WHERE database_id = DB_ID();
GO

SELECT
    r.session_id,
    r.status,
    r.command,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    r.cpu_time,
    r.total_elapsed_time,
    r.reads,
    r.writes
FROM sys.dm_exec_requests AS r
WHERE r.database_id = DB_ID();
GO

/* ============================================================
   PODSUMOWANIE
   ============================================================ */

SELECT
    1 AS StepNumber,
    N'Small transactions' AS RuleName,
    N'Każdy batch jest osobną krótką transakcją' AS Description
UNION ALL
SELECT
    2,
    N'Checkpoint',
    N'Postęp jest zapisany i proces można wznowić'
UNION ALL
SELECT
    3,
    N'Idempotency',
    N'Ponowne uruchomienie pomija zmigrowane rekordy'
UNION ALL
SELECT
    4,
    N'Throttling',
    N'Batch size i pauza kontrolują wpływ na produkcję'
UNION ALL
SELECT
    5,
    N'Observability',
    N'Każdy batch oraz postęp są logowane'
UNION ALL
SELECT
    6,
    N'Validation',
    N'Na końcu potwierdzamy kompletność i poprawność danych';
GO
