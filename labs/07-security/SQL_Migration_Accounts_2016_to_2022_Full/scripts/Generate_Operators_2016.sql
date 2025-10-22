
/* Generate_Operators_2016.sql */
USE msdb;
SET NOCOUNT ON;

SELECT
'IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = N' + QUOTENAME(o.name,'''') + ')
BEGIN
    EXEC msdb.dbo.sp_add_operator
        @name = N' + QUOTENAME(o.name,'''') + ',
        @enabled = ' + CAST(o.enabled AS varchar(10)) + ',
        @weekday_pager_start_time = ' + CAST(o.weekday_pager_start_time AS varchar(10)) + ',
        @weekday_pager_end_time = ' + CAST(o.weekday_pager_end_time AS varchar(10)) + ',
        @weekday_email_start_time = ' + CAST(o.weekday_email_start_time AS varchar(10)) + ',
        @weekday_email_end_time = ' + CAST(o.weekday_email_end_time AS varchar(10)) + ',
        @email_address = N' + COALESCE(QUOTENAME(o.email_address,'''') ,'NULL') + ',
        @pager_address = N' + COALESCE(QUOTENAME(o.pager_address,'''') ,'NULL') + ';
END
GO
' AS [-- Run on SQL 2022]
FROM msdb.dbo.sysoperators AS o
ORDER BY o.name;
