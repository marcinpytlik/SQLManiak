/*
 E1 FILL — execute against BPS_E1, not master.
 @TargetMiB: 512 -> 1024 -> 2048.
 Each row is ~7000 bytes and normally consumes one 8 KB leaf page.
 Limit: 2048 MiB target and max 100 batches (1000 rows each) per run.
 Check Windows host C: free space BEFORE every run; VHDX free space is not host free space.
 Avoid running while other SQLManiak containers are active.
*/
USE BPS_E1;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TargetMiB int = 512;               -- Change to 1024 or 2048 later
DECLARE @RowsPerBatch int = 1000;
DECLARE @MaxBatchesPerRun int = 100;
DECLARE @RowsTarget bigint;
DECLARE @RowsBefore bigint;
DECLARE @Batches int = 0;

IF @TargetMiB NOT IN (512,1024,2048)
    THROW 51010, 'Allowed target values: 512, 1024, 2048 MiB.', 1;

-- Approximately one 8 KB leaf page per row. Reconcile with page counts below.
SET @RowsTarget = CONVERT(bigint,@TargetMiB) * 128;

SELECT @RowsBefore = COUNT_BIG(*)
FROM dbo.LabPages;

WHILE @RowsBefore < @RowsTarget AND @Batches < @MaxBatchesPerRun
BEGIN
    DECLARE @RowsThisBatch int =
        CONVERT(int, CASE WHEN @RowsTarget - @RowsBefore < @RowsPerBatch
                          THEN @RowsTarget - @RowsBefore ELSE @RowsPerBatch END);

    ;WITH N AS
    (
        SELECT TOP (@RowsThisBatch) 1 AS Marker
        FROM sys.all_objects AS a CROSS JOIN sys.all_objects AS b
    )
    INSERT dbo.LabPages (Payload)
    SELECT CONVERT(char(7000), REPLICATE('X',7000)) FROM N;

    SET @RowsBefore += @@ROWCOUNT;
    SET @Batches += 1;
END;

CHECKPOINT;

SELECT @TargetMiB AS RequestedTargetMiB,
       @RowsBefore AS RowsAfter,
       @Batches AS BatchesThisRun,
       CASE WHEN @RowsBefore >= @RowsTarget THEN 'TARGET_REACHED'
            ELSE 'CONTINUE_IN_NEXT_RUN' END AS Progress;

SELECT SUM(used_page_count)*8.0/1024 AS UsedMiB,
       SUM(reserved_page_count)*8.0/1024 AS ReservedMiB,
       SUM(row_count) AS RowsFromDMV
FROM sys.dm_db_partition_stats
WHERE object_id = OBJECT_ID(N'dbo.LabPages') AND index_id IN (0,1);
GO
