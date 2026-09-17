SET NOCOUNT ON;

CREATE TABLE #fg
(
    db sysname NOT NULL,
    filegroup sysname NOT NULL,
    allocated_mb decimal(19,2) NOT NULL,
    used_mb decimal(19,2) NOT NULL
);

DECLARE @db sysname, @sql nvarchar(max);

DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state = 0
  AND source_database_id IS NULL;

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'USE ' + QUOTENAME(@db) + N';
        INSERT #fg(db, filegroup, allocated_mb, used_mb)
        SELECT
            DB_NAME(),
            fg.name,
            CAST(SUM(CONVERT(bigint, df.size)) * 8.0 / 1024.0 AS decimal(19,2)),
            CAST(SUM(CONVERT(bigint, FILEPROPERTY(df.name, ''SpaceUsed''))) * 8.0 / 1024.0 AS decimal(19,2))
        FROM sys.filegroups AS fg
        JOIN sys.database_files AS df
          ON df.data_space_id = fg.data_space_id
         AND df.type = 0
        GROUP BY fg.name;';

    BEGIN TRY
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH
        /* Skip databases that cannot be inspected by the monitoring login. */
    END CATCH;

    FETCH NEXT FROM dbs INTO @db;
END;

CLOSE dbs;
DEALLOCATE dbs;

SELECT
    db,
    filegroup,
    allocated_mb,
    used_mb,
    CAST(allocated_mb - used_mb AS decimal(19,2)) AS free_mb,
    CAST(CASE WHEN allocated_mb > 0 THEN 100.0 * used_mb / allocated_mb ELSE 0 END AS decimal(9,4)) AS used_pct
FROM #fg
ORDER BY db, filegroup;
