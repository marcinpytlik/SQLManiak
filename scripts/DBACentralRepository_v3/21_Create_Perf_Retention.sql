USE [DBACentralRepository];
GO

/*
DBACentralRepository v3 - PERF retention v1.0
Jawne kasowanie child tables przed SampleBatch.
*/
CREATE OR ALTER PROCEDURE [perf].[usp_PurgePerformanceHistory]
    @RetentionDays int = 90,
    @BatchSize int = 5000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RetentionDays < 1
        THROW 51020, 'RetentionDays must be >= 1.', 1;

    IF @BatchSize < 100
        SET @BatchSize = 100;

    DECLARE @Cutoff datetime2(0) =
        DATEADD(day, -@RetentionDays, SYSDATETIME());

    CREATE TABLE #BatchToDelete
    (
        SampleBatchId bigint NOT NULL PRIMARY KEY
    );

    WHILE 1 = 1
    BEGIN
        TRUNCATE TABLE #BatchToDelete;

        INSERT INTO #BatchToDelete (SampleBatchId)
        SELECT TOP (@BatchSize) B.SampleBatchId
        FROM [perf].[SampleBatch] AS B
        WHERE B.[CapturedAt] < @Cutoff
        ORDER BY B.[SampleBatchId];

        IF @@ROWCOUNT = 0
            BREAK;

        BEGIN TRANSACTION;

        DELETE C
        FROM [perf].[DatabaseConcurrencySnapshot] AS C
        INNER JOIN #BatchToDelete AS D
            ON D.SampleBatchId = C.SampleBatchId;

        DELETE L
        FROM [perf].[DatabaseLogSnapshot] AS L
        INNER JOIN #BatchToDelete AS D
            ON D.SampleBatchId = L.SampleBatchId;

        DELETE M
        FROM [perf].[DatabaseMemorySnapshot] AS M
        INNER JOIN #BatchToDelete AS D
            ON D.SampleBatchId = M.SampleBatchId;

        DELETE F
        FROM [perf].[FileIoSnapshot] AS F
        INNER JOIN #BatchToDelete AS D
            ON D.SampleBatchId = F.SampleBatchId;

        DELETE C
        FROM [perf].[DatabaseCpuSnapshot] AS C
        INNER JOIN #BatchToDelete AS D
            ON D.SampleBatchId = C.SampleBatchId;

        DELETE B
        FROM [perf].[SampleBatch] AS B
        INNER JOIN #BatchToDelete AS D
            ON D.SampleBatchId = B.SampleBatchId;

        COMMIT TRANSACTION;
    END;
END;
GO
