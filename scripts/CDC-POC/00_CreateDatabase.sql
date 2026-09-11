/* SQLManiak - CDC POC | 00_CreateDatabase.sql
   Creates CDC_Lab and a dedicated filegroup for CDC change tables.
*/
USE master;
GO

IF DB_ID(N'CDC_Lab') IS NOT NULL
BEGIN
    ALTER DATABASE CDC_Lab SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CDC_Lab;
END;
GO

CREATE DATABASE CDC_Lab;
GO

ALTER DATABASE CDC_Lab SET RECOVERY FULL;
GO

/*
    Keep CDC change tables away from PRIMARY.
    The physical path is derived from the primary data file so the script
    remains portable across lab machines/instances.
*/
ALTER DATABASE CDC_Lab ADD FILEGROUP CDC_CT;
GO

DECLARE @PrimaryFile nvarchar(260),
        @DataPath    nvarchar(260),
        @SepPos      int,
        @Sql         nvarchar(max);

SELECT @PrimaryFile = physical_name
FROM sys.master_files
WHERE database_id = DB_ID(N'CDC_Lab')
  AND file_id = 1;

SET @SepPos = CASE
                  WHEN CHARINDEX(N'\', REVERSE(@PrimaryFile)) > 0
                      THEN LEN(@PrimaryFile) - CHARINDEX(N'\', REVERSE(@PrimaryFile)) + 1
                  WHEN CHARINDEX(N'/', REVERSE(@PrimaryFile)) > 0
                      THEN LEN(@PrimaryFile) - CHARINDEX(N'/', REVERSE(@PrimaryFile)) + 1
                  ELSE 0
              END;

IF @SepPos = 0
    THROW 50001, 'Cannot determine the SQL Server data directory for CDC_Lab.', 1;

SET @DataPath = LEFT(@PrimaryFile, @SepPos);

SET @Sql = N'ALTER DATABASE CDC_Lab ADD FILE
(
    NAME = N''CDC_Lab_CDC_CT'',
    FILENAME = N''' + REPLACE(@DataPath + N'CDC_Lab_CDC_CT.ndf', '''', '''''') + N''',
    SIZE = 128MB,
    FILEGROWTH = 128MB
)
TO FILEGROUP CDC_CT;';

EXEC sys.sp_executesql @Sql;
GO

SELECT
    d.name,
    d.recovery_model_desc,
    d.is_cdc_enabled
FROM sys.databases AS d
WHERE d.name = N'CDC_Lab';
GO

SELECT
    fg.name AS filegroup_name,
    fg.type_desc,
    df.name AS logical_file_name,
    df.physical_name,
    CAST(df.size / 128.0 AS decimal(18,2)) AS size_mb,
    CASE
        WHEN df.is_percent_growth = 1 THEN CONCAT(df.growth, N'%')
        ELSE CONCAT(CAST(df.growth / 128.0 AS decimal(18,2)), N' MB')
    END AS autogrowth
FROM CDC_Lab.sys.filegroups AS fg
LEFT JOIN CDC_Lab.sys.database_files AS df
    ON df.data_space_id = fg.data_space_id
ORDER BY fg.data_space_id, df.file_id;
GO
