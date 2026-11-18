/*
 E1 SETUP — laboratory instance ONLY.
 Creates BPS_E1 with SIMPLE recovery and 256 MB data growth.
 Does not delete an existing database or change server-wide settings.
*/
USE master;
GO
IF DB_ID(N'BPS_E1') IS NULL
BEGIN
    CREATE DATABASE BPS_E1;
END;
GO
ALTER DATABASE BPS_E1 SET RECOVERY SIMPLE;
GO
DECLARE @sql nvarchar(max);
SELECT @sql = STRING_AGG(
    CONVERT(nvarchar(max), N'ALTER DATABASE BPS_E1 MODIFY FILE (NAME = '
      + QUOTENAME(name,'''')
      + N', FILEGROWTH = '
      + CASE WHEN type = 0 THEN N'256MB' ELSE N'128MB' END + N');'),
    CHAR(10))
FROM sys.master_files
WHERE database_id = DB_ID(N'BPS_E1');
EXEC sys.sp_executesql @sql;
GO
USE BPS_E1;
GO
IF OBJECT_ID(N'dbo.LabPages',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LabPages
    (
        Id bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_BPS_E1_LabPages PRIMARY KEY CLUSTERED,
        Payload char(7000) NOT NULL
    );
END;
GO
SELECT DB_NAME() AS DatabaseName, COUNT_BIG(*) AS RowCount
FROM dbo.LabPages;
GO
