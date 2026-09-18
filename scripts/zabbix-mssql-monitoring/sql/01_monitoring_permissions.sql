/*
SQLManiak MSSQL monitoring - minimal permissions used by the tested setup.

Replace [zabbix] with the actual monitoring login/user name.

The script chooses the server-state permission by SQL Server major version:
- SQL Server 2016/2017/2019: VIEW SERVER STATE
- SQL Server 2022+: VIEW SERVER PERFORMANCE STATE
On SQL Server 2022+ it also grants VIEW SERVER SECURITY STATE for the TDE collector.

Review in accordance with your security policy before production deployment.
*/

USE [master];
GO

DECLARE @major int = TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion'));

IF @major >= 16
BEGIN
    GRANT VIEW SERVER PERFORMANCE STATE TO [zabbix];
    GRANT VIEW SERVER SECURITY STATE TO [zabbix];
END
ELSE
BEGIN
    GRANT VIEW SERVER STATE TO [zabbix];
END;

GRANT VIEW ANY DEFINITION TO [zabbix];
GO

USE [msdb];
GO

GRANT SELECT ON dbo.sysjobs TO [zabbix];
GRANT SELECT ON dbo.sysjobhistory TO [zabbix];
GRANT SELECT ON dbo.sysjobschedules TO [zabbix];
GO

USE [master];
GO

DECLARE @login sysname = N'zabbix';
DECLARE @db sysname;
DECLARE @sql nvarchar(max);

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state = 0
  AND source_database_id IS NULL;

OPEN c;
FETCH NEXT FROM c INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'USE ' + QUOTENAME(@db) + N';
IF USER_ID(N''' + REPLACE(@login,'''','''''') + N''') IS NULL
    CREATE USER ' + QUOTENAME(@login) + N' FOR LOGIN ' + QUOTENAME(@login) + N';

GRANT VIEW DATABASE STATE TO ' + QUOTENAME(@login) + N';
GRANT VIEW DEFINITION TO ' + QUOTENAME(@login) + N';';

    EXEC sys.sp_executesql @sql;
    FETCH NEXT FROM c INTO @db;
END

CLOSE c;
DEALLOCATE c;
GO
